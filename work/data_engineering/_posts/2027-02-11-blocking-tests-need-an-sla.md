---
layout: post
title:  From Warning to Blocking, Why Your Data Tests Need a Response SLA
subtitle: Data Engineering
date:   2027-02-11
tags:   data quality ci/cd documentation
draft:  true
---

## Background

I've [written before]({% link work/data_engineering/_posts/2024-04-04-data-convention-over-configuration.md %}) about wiring test coverage into a data project the same way a well-run Rails codebase wires in CI: pre-commit hooks, dbt's built-in test suite, a minimum bar before a PR is even reviewable. That covers the moment code ships. It says nothing about the moment a test actually fails in production, which is the part that decides whether all that testing infrastructure was worth building in the first place.

## Two Ways to Fail

Historically, most teams treat a dbt test failure as a warning. It gets logged, maybe posted to a channel, and the pipeline keeps running anyway. Downstream marts build on schedule regardless of whether the data underneath them just failed a data quality check. The upside is obvious: nothing ever goes stale because of a test. The downside is exactly as obvious once you say it out loud: nothing stops bad data from shipping either.

Flipping a test's severity to blocking, so a failure halts the pipeline before the bad data reaches the mart, fixes that downside. But it's not a strict improvement, it's a trade. You're giving up "always current" in exchange for "never wrong." That's a legitimate trade for a lot of business-critical data. It's a bad one to make silently, because the moment you've made it, you've taken on an obligation you didn't have before: fixing the failure fast enough that "blocked" doesn't quietly turn into "stale forever."

That's the part that's easy to skip and expensive to skip. If a warning-only pipeline goes eight hours without anyone looking at a failed test, the mart is late and wrong. If a blocking pipeline goes eight hours without anyone looking at the same failure, the mart is late, full stop, and now worse off than it would have been under the policy you just replaced. Blocking without a response commitment isn't safer than warning. It's warning with extra downtime bolted on.

## Key the Response Time to the Build Frequency

The fix is to commit, explicitly, to how fast a blocking failure gets mitigated, and to key that commitment to how often the affected resource already builds. A near-real-time mart that goes stale erodes trust in minutes. A daily mart going stale for the same length of time barely registers. Treating both the same either over-promises on the daily mart or under-serves the near-real-time one.

| Build tier | Build frequency | Max time to mitigate |
| --- | --- | --- |
| Near-real-time | Every 15 minutes | ≤ 2 business hours |
| High | Every 30 minutes | ≤ 4 business hours |
| Intraday | Hourly | ≤ 8 business hours |
| Standard | A few times a day | ≤ 16 business hours, or by the next scheduled run |
| Daily | Once, at the start of the day | ≤ 48 business hours, or by the next scheduled run |

A few things about that table that matter more than the specific numbers, which you should tune to your own team's staffing and risk tolerance:

**"Mitigate" isn't "resolve."** Mitigating a failure means the pipeline stops being blocked, whether that's from fixing the failing test, correcting the underlying data, or applying an approved temporary override (more on that below). It doesn't require the root cause to be permanently fixed by the deadline. That distinction is what keeps the SLA honest — it's a commitment to stop the bleeding fast, not a promise that every root cause gets solved on a stopwatch.

**This is layered on top of your existing delivery commitment, not a replacement for it.** A delivery SLA says how often a mart builds. This is a separate commitment about how fast you clear a failure once the delivery SLA has already been missed, because a blocked mart has, by definition, already missed it.

**Detection and ownership need a default, or the SLA is theoretical.** A blocking failure should raise an automated alert to wherever your team actually watches for this kind of thing, with on-call as the default responsible party for triage and mitigation, and an explicit escalation path (typically to the team lead) if the window gets breached.

## The Override Guardrail

Sooner or later, a test fails for a reason that isn't "the data is actually wrong." A test itself was miscalibrated, or the failure is real but genuinely low-priority. Holding data hostage over a false positive is its own kind of failure, so overrides need to exist. But every override, downgrading a test from blocking to warning, disabling it outright, or excluding a model from the blocking job's selector, is a small step back toward the exact behavior blocking was supposed to replace. That's fine as an exception. It's a problem as a habit. So each one gets the same guardrails:

- **Approval, not a unilateral call.** Whoever is mitigating the failure doesn't get to also decide it's fine to override. That's a second set of eyes, the same reason a PR gets reviewed instead of self-merged.
- **A ticket, not tribal knowledge.** The reason for the override, the model and test affected, who approved it, and an expected re-enable date, written down before or immediately after it's applied.
- **A time-box.** Overrides are capped at a fixed number of days. If the underlying issue isn't fixed by then, the override has to be explicitly renewed, with justification, rather than left in place by default because nobody revisited it.
- **Visibility.** Post the override, with its ticket link and expected re-enable date, wherever your team already watches for this kind of thing. An override that only the person who applied it knows about isn't a guardrail, it's a liability with a delay on it.
- **A real closing condition.** The tracking ticket doesn't close until the test is back at blocking severity. It either resolves back to blocking or gets escalated. There's no third state where it just quietly stays downgraded forever.

## When the Window Gets Breached Anyway

If a business-critical resource blows through its max-time-to-mitigate window, that's the point where this stops being routine data engineering work and becomes a formal incident, escalated through whatever process your organization already uses for outages, with the same severity classification and communication cadence as any other incident. Don't invent a parallel, quieter process for data incidents just because the pipeline doesn't page a customer directly. A blocked business-critical mart is exactly as much an incident as any other outage; it just has a data team instead of a customer as the audience noticing first.

## Conclusion

Adding tests is the easy half of a data quality program. The hard half is deciding, in advance and in writing, what happens the first time one fails for real, at 2am, on a mart someone actually depends on. Do that work before you flip the switch to blocking, not after the first multi-day outage forces the conversation. The SLA is what keeps "fail closed" from becoming "closed indefinitely."
