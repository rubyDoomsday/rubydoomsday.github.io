---
layout: post
title:  Skip the Rebuild, Not the Freshness, A State-Aware Orchestration Pattern
subtitle: Data Engineering
date:   2027-05-11
tags:   data architecture orchestration design
draft:  true
---

## Background

Every scheduled dbt run I've seen, by default, rebuilds every table model whether or not anything upstream actually changed. That's not a criticism of dbt, it's just how scheduled orchestration normally works: the schedule doesn't know the difference between "the source moved" and "the clock ticked." dbt's own `state:modified+` selector catches *code* changes at merge time, which is great, but nothing out of the box catches *data* changes between merges. A model scheduled hourly rebuilds twenty-four times a day even on the days its source never moved at all.

For most models that's a rounding error. For a warehouse with a few hundred `table`-materialized models, a meaningful share of them changing only a handful of times a day, it's a lot of warehouse compute spent re-deriving the exact same output over and over. So I built a gate that sits in front of the expensive ones: check for a real signal that something changed, and only pay for the rebuild if one exists.

I open-sourced the proof of concept described in this post as a standalone dbt package, [dbt-tripwire](https://github.com/rubyDoomsday/dbt-tripwire), if you'd rather read the actual decision logic than take my word for how it works.

## Why a Package, Not a Feature Flag Buried in the Project

The first design decision wasn't the algorithm, it was where the code lives. I built this as a standalone dbt package rather than logic scattered through the main project, for three reasons:

* **It's all-in or all-out.** The surface area, wrapping every table materialization's decision logic, is significant enough that it deserves to ship as one coherent unit instead of getting entangled piecemeal into project-specific code. It's also a fully generic feature: nothing about it requires intimate knowledge of any particular project's models.
* **Version and release control.** Enhancements can land incrementally, or as a bigger breaking change, without polluting the core project's own release cadence. The package gets its own versioning story.
* **It's a real alternative to a paid feature.** A handful of managed orchestration platforms sell some version of "skip if nothing changed" as a premium capability. Building this as an open, self-contained package means a team that can't or won't pay for that tier has a real option, not just a wish.

## The Problem, Concretely

Picture a model scheduled to run hourly. Without any gating, that's eight runs a day (limiting to a representative window), full rebuild every time:

| Invocation | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Without a gate | RUN | RUN | RUN | RUN | RUN | RUN | RUN | RUN |
| With a gate | skip | skip | RUN | skip | skip | skip | skip | RUN |

Six of those eight runs did real work to produce a table that was already correct. The "with a gate" row isn't skipping on a timer, every skip tick still checked for a signal and found none. The table underneath sat there, untouched, exactly as fresh as it needs to be.

## How a Model Decides

Before either wrapper materialization runs any SQL against a model's own target, a decision function works down a ladder from cheap to expensive and stops at the first thing that actually fires:

[![state-aware orchestration decision flow](/assets/img/work/sao-decision-flow.png)](/assets/img/work/sao-decision-flow.png)

1. **No previous state exists** → build. First run, a dropped table, a freshly cloned environment, whatever the reason, there's nothing to compare against, so build.
2. **A "force it" override is set** → build. Sometimes you just want to force a rebuild regardless of signal, and that escape hatch needs to exist.
3. **Cheap checks (Tier 0):** the last run errored (force a retry instead of silently staying skipped forever), a maximum staleness window has elapsed (a safety valve so "no signal" can't turn into "never rebuilt again"), or a max-consecutive-skips count has been hit (a second, independent safety valve for the same failure mode) → build.
4. **A qualifying upstream ancestor already rebuilt this invocation** → build. If something feeding this model already decided it needed to run, that's a signal on its own.
5. **The source actually changed (Tier 1–2, more expensive):** first a metadata-only check against the source, no table scan, no cost beyond a system call. Only if that finds nothing does it fall back to a row count and a min/max watermark comparison, if a watermark column is configured.
6. **None of the above** → skip. Return the existing table untouched. No SQL runs against it at all.

The source check always runs on its own, even when an upstream ancestor already triggered a build. Inheriting the ancestor's answer alone would miss a signal on a source this model references directly and its ancestor doesn't.

## The One Optimization That Actually Mattered

The naive version of this design checks the source every time a model that depends on it gets evaluated. That's fine when a source only feeds one or two models. It falls apart when a handful of upstream sources each feed hundreds of downstream candidates: checked naively, one hourly invocation runs the exact same metadata check hundreds of times over, once per model, all asking the identical question and getting the identical answer.

The fix is a per-invocation cache, keyed by source, not by model. The check runs once per source per invocation, gets written to a log table, and every model touching that source for the rest of that run reads the cached answer instead of re-checking. This is the single change that made the difference between "a clever idea" and "a design that survives contact with a warehouse that has a few genuinely busy upstream sources."

## Two Clocks

There end up being two different lifetimes of state running at once, and conflating them is an easy way to build something that looks right in testing and then behaves strangely in production:

| Table | Scope | Written | Contains |
| --- | --- | --- | --- |
| Run log | This invocation only | The moment each model is checked | Should-run decision + reason, per model |
| Source check log | This invocation only | The moment each source is checked | The cheap/expensive check result, per source |
| Model state | Persistent, read by future invocations | Once, batched, at the end of the run | Last run outcome, skip count, last error |
| Source state | Persistent, read by future invocations | Once, batched, at the end of the run | Last known signal (commit time, row count, watermark) |

The first two exist purely to make one invocation efficient and are gone the moment it ends. The second two are the actual memory the system relies on to make a decision next time. Getting the write timing right, batched once at the end of a run rather than scattered throughout it, matters more than it looks; writing persistent state mid-run, before you know whether the run itself succeeded, is how you end up trusting state from a run that never actually finished.

## Where This Stands Honestly

This is not a finished platform feature, and I'd rather say that plainly than oversell a proof of concept.

**Proven so far:**

* The full skip/build decision chain works against a real warehouse, not just a test fixture.
* The per-invocation cache means shared ancestors or sources cost one check, not one check per dependent model.
* An errored build forces a retry on the next invocation instead of silently staying skipped forever.
* A dropped or missing target table self-heals (falls back to "no previous state, build") instead of erroring out.

**Still ahead of it before a real rollout:**

* A dedicated, package-owned schema for the four state tables, instead of borrowing space in a shared one.
* An infrastructure-as-code driven rollout across every candidate model, not a hand-picked subset.
* A retention job for the two transient log tables, so per-invocation logging doesn't grow unbounded.
* Finer-grained, per-(model, source) baselines, if a future need for scoped partial runs demands it.

## Try It

The full implementation, both `sao_table`/`sao_incremental` materializations and the decision chain described above, is on GitHub: [github.com/rubyDoomsday/dbt-tripwire](https://github.com/rubyDoomsday/dbt-tripwire). It's a real, runnable proof of concept with integration tests against Snowflake, not just pseudocode.

## Conclusion

The instinct to build something like this usually shows up the same way: someone notices a model rebuilding on a schedule that has nothing to do with how often its data actually changes, and it nags at them. The trap is jumping straight to "we need smarter orchestration" as a platform-wide rewrite. What actually worked was scoping it as small as possible, a single decision function, a cheap-to-expensive ladder, two clocks instead of one, and proving each piece against a real warehouse before promising anything about the rest of the warehouse's candidate models that haven't been migrated yet.
