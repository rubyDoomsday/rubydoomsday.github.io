---
layout: post
title:  What a Data Contract Actually Looks Like
subtitle: Data Engineering
date:   2026-11-11
tags:   data architecture design documentation
draft:  true
---

## Background

A while back I wrote about [defining boundaries in a data platform]({% link work/data_engineering/_posts/2024-03-16-defining-data-boundaries.md %}) — source, integration, transformation, and access, each one a contract that lets teams work on either side without stepping on each other. That post was the diagram. This one is what happens when you skip drawing it, and what it actually takes to fix that once a warehouse has grown past the point where anyone remembers why two models disagree.

## The Symptom

Picture a mid-sized warehouse where the canonical layer, the "silver" tier sitting between raw source data and the marts everyone actually queries, has grown flat. A few hundred models, no declared grain, no primary key requirement, shared canonical logic and mart-specific pre-computation all living side by side with no structural line between them. Nothing enforces a contract, so nothing catches a change before it breaks a downstream consumer. This isn't a hypothetical; it's the default state of most warehouses that grew organically instead of by design, mine included at times.

Here's what that actually looks like in practice, and it's uglier in the small details than in the architecture diagram:

**Casing drift breaks a join silently.** Two marts in the same domain both track order status. One stores it upper-cased. The other only upper-cases it inside a `WHERE` filter, so the stored column keeps whatever case the source system happened to use. Join the two on `status = status` and rows quietly disappear wherever the case doesn't match. No error. No warning. The query still returns something, so nobody looks twice.

**Scale drift breaks a number silently.** One mart stores a rate column as a raw basis-point integer. Another divides the same underlying value by 100 before storing it. Both columns are named `DISCOUNT_RATE`. An analyst who joins across them gets a number that's off by two orders of magnitude, with no indication anything is wrong.

Neither of these is a bug in the traditional sense. Every individual model does exactly what its author intended. The bug is architectural: the same business concept got defined twice, independently, with no shared contract forcing agreement.

## Why "Draw Better Boundaries" Isn't Enough

Once you've spotted the pattern, the instinct is to reconcile the two models and move on. That fixes today's two models and does nothing to stop a third one from reintroducing the same drift next sprint, because nothing is actually enforcing the boundary. A diagram is a description of intent. A contract is the thing that fails a build when intent gets violated.

I considered three ways to close that gap:

| Option | Verdict |
| --- | --- |
| **Data Vault** (hubs/links/satellites) | Rejected. Full auditability and insert-only history are real strengths, but it's three artifact types per entity, tooling support in most transformation frameworks is still immature, and there was no regulatory requirement forcing that level of overhead. |
| **Full star schema, all at once** | Deferred, not rejected. This is the right end state, but it requires grain sign-off on every fact table simultaneously, which is a bad bet when half those models have no documented grain today. It's the eventual Phase 3, sequenced after the groundwork below. |
| **Status quo, incremental cleanup** | Rejected. This is the approach that produced the mess in the first place. Without a structural boundary, cleanup will always lose a race against new models getting added faster than old ones get fixed. |

What actually shipped: a thin canonical layer of conformed entities. This is Kimball's conformed dimension idea, just applied a layer earlier than Kimball originally described it: an entity is conformed when it means the same thing to every team that touches it. When two different domains both reference the same canonical customer entity, they are structurally guaranteed to agree on what a customer is, because there is only one model answering that question.

A simplified version of that shape looks something like this: one conformed `customer` entity sitting at the center, referenced by every fact that touches a customer, instead of each fact quietly growing its own copy of "who is this person."

[![conformed entity ERD](/assets/img/work/conformed-entity-erd.png)](/assets/img/work/conformed-entity-erd.png)

## What Actually Changed

**Grain and primary key, declared and enforced.** Every canonical entity gets an explicit grain statement and a schema contract that fails the build on any violation, instead of drifting silently until an analyst notices a duplicate row six months later.

**One entity, not two near-identical ones.** A common pattern in an ungoverned warehouse is two almost-identical models, split only by some product or category dimension, that some team unioned by hand in every downstream query:

```sql
-- Before: every consumer re-derives the union and re-solves the category difference themselves
SELECT * FROM silver_orders_retail
UNION ALL
SELECT * FROM silver_orders_wholesale

-- After: one canonical entity, a column distinguishes the category
SELECT * FROM fact_order
WHERE order_channel = 'wholesale'  -- only if a consumer actually needs to filter
```

The second version isn't just shorter. It's the difference between "every consumer solves this problem" and "one model solves this problem, once."

**Vocabulary normalization moved into a mapping table, not a CASE statement.** The order-status drift from earlier gets fixed by replacing the inline `CASE` logic in each mart with a join against a single seed table mapping every raw status, per source, to one canonical vocabulary:

```yaml
# seeds/order_status_mapping.yml
version: 2
seeds:
  - name: order_status_mapping
    description: >
      Canonical order status mapping. Maps raw per-source status codes to a
      single shared vocabulary. Add a row when a new source system is onboarded.
      Never embed status normalization logic in model SQL.
    columns:
      - name: canonical_status
        data_tests:
          - not_null
          - accepted_values:
              values: [PLACED, FULFILLED, CANCELLED, RETURNED, OTHER]
```

Onboarding a new source now means adding a row to a CSV, not editing model SQL and triggering a full rebuild. And `OTHER` isn't a resting state; it's a smoke alarm. A dbt test alerting whenever unmapped rows cross some small threshold turns "silent drift" back into "an alert someone actually sees."

## Trade-Offs, Honestly

| Dimension | Flat, undifferentiated layer | Conformed canonical entities |
| --- | --- | --- |
| Grain declaration | Implicit, inconsistent, undocumented | Explicit, enforced at build time |
| Metric consistency | Recomputed per mart, disagreements live in the dashboard | One definition, every mart derives from it |
| New source onboarding | New model plus updates to every consumer | New union branch in one canonical model, consumers unchanged |
| Implementation effort | None — it's the status quo | Real. This is a multi-stage migration, not a weekend refactor |
| Rollback risk | N/A | Low, if the new entities are built in parallel and old models aren't removed until every reference has migrated and been validated |

That last row matters more than it looks. The riskiest part of this kind of migration isn't the design, it's the cutover. Build the new canonical entities alongside the old models, migrate one mart at a time starting with the highest-value, lowest-risk one, and validate row counts and key metrics before and after each cutover. Nobody needs a big-bang rewrite to get the benefit, and a big-bang rewrite is exactly how this kind of project stalls out.

## Conclusion

Boundaries and contracts aren't the same thing, even though it's tempting to treat a clean architecture diagram as if it were self-enforcing. The diagram tells you where the line should be. The contract, declared grain, enforced schema, a shared vocabulary table instead of five copies of the same `CASE` statement, is what actually holds that line when someone's in a hurry and reaching for the fastest path to ship. Draw the boundary first. Then go build the thing that makes it real.
