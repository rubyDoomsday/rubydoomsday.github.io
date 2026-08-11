---
layout: post
title:  Is It a Metric? A Test for Data Teams
subtitle: Data Engineering
date:   2026-08-11
tags:   data architecture metrics documentation
draft:  true
---

## Background

Every data team eventually hits the same wall. Two dashboards report a different number for what is supposedly the same thing, and nobody can say with confidence which one is right, because both are "right" according to the model that built them. An analyst asks "which model should I use for X?" and the honest answer is "it depends which mart you're in." That answer should bother you. It's a sign that a business decision has been made twice, independently, in two different files, by two different people who never talked to each other.

The instinct is to patch it: reconcile the two numbers, add a comment explaining the discrepancy, move on. That fixes today's dashboard and guarantees a third version shows up next quarter. The actual fix is upstream of the SQL: deciding, once, what counts as a metric versus what is just a column, and refusing to let the metric get re-derived every time someone needs it.

## What Is a Metric?

A metric is a business-meaningful derived value with a single authoritative definition that any downstream model can consume without re-deriving it. Not everything calculated in SQL clears that bar. Plenty of "logic" in a mart is just arithmetic, and treating arithmetic like a metric is how you end up with fifty near-identical models guarding fifty trivial column transformations.

Here's the test, and it's meant to be self-checking, not something you have to ask me about every time:

*Would two different teams, working independently, make different choices about how to compute this?*

If yes, it's a metric. Define it once, in one place, at the canonical layer. If no, it's a column transformation and belongs directly in whichever mart needs it.

| Is a metric | Is not a metric |
| --- | --- |
| "Active customer" (does a 30-day window count? does a free trial count?) | `UPPER(customer_name)` — formatting, not a business concept |
| A risk or health score (which source wins when two disagree, and in what order) | `DATEDIFF(day, start_date, end_date)` — arithmetic on two well-understood dates |
| Order or account status (vocabulary and casing drift by source system) | `price_cents / 100` — a known unit conversion, no ambiguity |
| Churn rate (numerator/denominator definition shifts as the product changes) | A column passed straight through from the canonical entity, untouched |

The left column has one thing in common: two reasonable engineers, given the same raw data and no conversation with each other, would plausibly land on different SQL. The right column doesn't have that property. There's only one correct way to divide by 100.

## Signals You've Found a Metric Candidate

You don't have to wait for a dashboard fire to catch these. Any one of the following is enough to flag something as a candidate:

| Signal | Example |
| --- | --- |
| The same calculation shows up in two or more marts | "Active customer" computed differently in Marketing and in Finance |
| The logic has a threshold or bucket baked into it | "30+ days = at risk" — who actually owns that number? |
| The logic encodes a business policy that could change | "use source A's score, fall back to source B" is a policy, not math |
| An analyst asks "which model should I use for X?" | If the honest answer is "it depends," it needs a single home |
| Two dashboards disagree on a number that should match | Confirmed inconsistency — find where each one derives it, and stop letting both derive it |
| A new mart needs a concept some other mart already built | Reuse the definition. Don't copy the SQL. |

## Building One

1. **Name it and declare its grain before writing any SQL.** One row per what? Say it out loud.
2. **Write the business definition in one plain-English sentence** that a non-technical stakeholder could confirm or correct. "A customer is churned when they haven't ordered in 90 days and have no active subscription." If you can't get to one sentence, the metric isn't well-defined enough to build yet — go get alignment before you write code, not after.
3. **Source it from the canonical layer, not raw data.** If your platform uses a bronze/silver/gold split, that means pulling from silver, never straight from bronze. Skipping the canonical layer to save a join is how the next inconsistency gets born.
4. **Check whether it already exists before you build it.** If the same logic is sitting in two marts already, you don't have a "new metric" problem, you have a "go extract the one that already exists" problem.
5. **Keep it narrow and tall.** One metric, or one tightly related family, per model. The columns are the metric, the join keys, and whatever minimal context (a severity rank, a flag) consumers actually need to use it. Resist the urge to build a fifty-column "metrics mart." That's not a shared definition, that's a second warehouse.
6. **Make it discoverable.** Tag it, document its owner and grain in the model's metadata, and make sure the next engineer who needs "churn" finds your model before they write their own.

## Anti-Patterns

| Anti-pattern | Do this instead |
| --- | --- |
| Copying metric logic from one mart into another | If it exists twice, it was already a candidate. Extract it. |
| Building one enormous "metrics mart" | One metric per model. Let the marts do the joining. |
| Filtering inside the shared metric for one segment or customer | No filtering upstream. Consumers filter downstream, in their own mart. |
| Naming the model after the mart that first needed it | Name it after the concept. The concept will outlive that mart's specific need. |
| Skipping the plain-English definition because "everyone knows what X means" | Everyone has a slightly different X in their head. That's the whole problem. |

## Why the Test Matters More Than the Definition

I could hand a team a glossary instead of a test, and for a while it would work. Glossaries go stale the moment a new edge case shows up that nobody thought to define. A test travels better, because it teaches the reasoning instead of just the label. Anyone on the team can run it against a new piece of logic without waiting for me to weigh in, and that's the actual goal: not that I've approved every metric, but that the team has a shared, self-service way to tell the difference between "this is arithmetic" and "this is a decision," and knows which one deserves a single, durable home.
