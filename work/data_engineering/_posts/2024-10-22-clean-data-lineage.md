---
layout: post
title: Designing Data Lineage
subtitle: Data Engineering
date:   2024-10-22
tags:   data development lineage architecture
---

# Purpose

Modeling data is the core component of our ELT pipelines and workflows. The strategies provided in this article are designed to help build
more manageable data platforms that use less time, energy and resources to move large amounts of data effectively

## Understanding Materialization

The DBT Framework offers several materializations strategies. For a complete list visit materializations visit [DBT Developer Hub](https://docs.getdbt.com/docs/build/materializations). We are only going to focus on 3 specific types:

- <span style="color:green">GREEN</span>: Table - a table is the direct storage of data in rows and columns
- <span style="color:purple">PURPLE</span>: View - a store SQL query that can be run against a database
- <span style="color:red">RED</span>: Incremental - to insert or update records into a table since the last time that model was run

# Data Lineage

## Common Problems

The following diagram represents a typical data lineage I have seen many teams struggle to manage. You can explore this DAG in the DBT Cloud
Explorer. For the sake of simplicity we have reduced this to a generic example to help demonstrate the point

[![common data lineage](/assets/img/work/typical-lineage.png)](/assets/img/work/typical-lineage.png)

### Identifying The Symptoms

This current access pattern has allowed the platform to serve up an immense amount of data very quickly. However, it is not scalable through
views alone. As the data becomes larger compute and query times become long and bothersome. Converting the bloated L02 models to tables only
bogs down the system further due to the need to move large quantities of data for all resources. Ill defined layers promote unproductive
access patterns lead to further rigidity in the code.

[![common-problems](/assets/img/work/idenitfying-symptoms.png)](/assets/img/work/idenitfying-symptoms.png)

| Problem   | Description                                                                                                        | Example                                                                                  | Impact                                                                     |
| --- | --- | --- | --- |
| Overreach | Layers extend their reach beyond the scope of reasonable aggregation.                                              | L03 aggregates data from L02 and L01.                                                    | Directly hinders our ability to orchestrate sane data workflows            |
| Access    | Consumers of data are reading from all layers of the platform                                                      | Consumers read L01 data directly.                                                        | Limits ability to refactor layers without breaking contracts               |
| Backflow  | Data flows left to right, up and down, right to left                                                               | L02 models aggregate other L02 models                                                    | Lineage is not direct and hinders logical separation of data               |
| Bloat     | Loosely defined marts create a “super table” that is both wide and deep. Fails the single responsibility principle | L02 aggregates 12+ upstream resources creating single mart used by all downstream marts. | Creates processing bottlenecks and excessive scanning.                     |
| All Views | Lack of direct storage of important data creates large slow queries                                                | Lack of tables                                                                           | Requires real time compiling and execution of SQL at all layers of the DAG |
| Implicit  | Passthrough of data hides what data is leveraged and allows unexpected data through.                               | Select * from table | More difficult to debug. Suprise data. unexpected results. |

### The Core Issue

As data platforms evolve, the main blocker to any successful data team is lack of definition. Without proper understanding of the purpose of
a layer access patterns become tightly coupled and refactoring becomes a chore. The above diagrams layers are loosely defined and
limitations are not enforced.

- Layer 01 - Is a pass through to move data from raw data lake to the data warehouse without any management of the data, tests or qualification
- Layer 02 - Deep and wide data marts bring data together for a complete picture, but with little wiggle room often become bloated and difficult to compute
- Layer 03 - Business focused and team specific data marts are often the easiest to assemble because of specific requirement from a stakeholder but may lack structure and controls

### Proposing Solutions

The following is an example of the ideal state that data and analytics engineers should be working towards. Though there are exceptions to
the rule, this is provided as a guide to assist in engineers making decisions for complex problems. The proposed design can be repeated
and/or nested to perpetually iterate and further refine the DAG. This design is called Source-Secondary-Primary or SSnP.

```
  Source → (Secondary Contract * n) → Primary Contract
```

Primary contracts are stable(ish). They don't change much and if they do it is not a breaking change. They also get more stable as we mover
left to right and therefore more rigid. Changes to these contracts should be slow and deliberate.

Secondary contracts are more unstable. They can shift, be refactored, and re-shape data with greater flexibility because they only have to
support their next closest primary contract. There are a lot of secondary contracts (hence * n) because they are very narrow in their responsibility.

Sources can be external or internal primary contracts isolating access patterns and uncoupling layers of data allowing for quicker
iteration.

With this in mind we can identify logical layers like this:

- RAW → Intermediate(s) →  L01
- L01 → Intermediate(s) → L02
- L02 → Intermediate(s) → L03
- L03 → External Consumer

Which we can then extrapolate to a single lineage like this:

```
  RAW -> INT -> L01 -> INT -> L02 -> INT -> L03 -> Consumer
```

In addition to encapsulating change, this creates a distinct order of operations allowing us to create a job that runs the following
command(s) to build the entire project without any knowledge of the code or data.

```
  dbt run -s models/L01
  dbt run -s models/L02/intermediate
  dbt run -s models/L02
  dbt run -s models/L03/intermediate
  dbt run -s models/L03
```

The following diagram refactors the previous example to match the SSnP design.

[![refactored lineage](/assets/img/work/ideal-state.png)](/assets/img/work/ideal-state.png)

### Defining A Layer

Layers are internal/external data contracts. These are the models that are defined as stable and structured resources. Each layer has a distinct and specific purpose.

#### Layer 01 - The “Gate keeper”

  - Should explicitly select columns we want to include in the data platform (less is more)
  - Documents and defines what we are looking at through properties files (eg schema.yml)
  - Reduces compute time
  - incremental materializations should be used at this layer with enthusiasm
  - table materializations are great for small data sets
  - views are great for frequently changing and small data sets

#### Intermediate (Layer 1-2)

  - Should duck type data into logical buckets
  - Should isolate complex ETL logic
  - Often created to support a specific L02 model

#### Layer 02 - Internal Contract

  - Should test any calculated data that is not strictly a column from upstream
  - Should be monitored for efficiency
  - when large or complex →  promote ETL to an intermediate materialization
  - when bloated → split up to smaller semantic objects

#### Intermediate (layer 2-3)

  - Should isolate complex ETL logic
  - Often created to support a specific L03 model
  - Should act as an “adapter” or “wrapper” for limiting or expanding L02

#### Layer 03 - Exposure

  - Stable and slowly changing data contract
  - The “presentation” layer that is consumed by our stakeholders
  - Business/Team centric data set(s)


### Identifying Solutions

| Problem   | Solution                                                                                                                                                     | Example                                                                                          |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Overreach | Examine the lineage graph and isolate the access pattern to ensure models are only accessing previous or intermediate layers. Avoid over reaching to maintain logical step-wise ordering| [![overreach](/assets/img/work/overreach.png)](/assets/img/work/overreach.png)                   |
| Backflow  | Create intermediate hops to expose the data in the correct mart even if that is an implicit select. A wrapper bridges the gap between disparate layers and enforces isolation of layers. | [![backflow](/assets/img/work/backflow.png)](/assets/img/work/backflow.png)                      |
| Bloat     | Refactor, refactor, refactor! Move duplicate logic to a macro or shared resource. Split up “super tables” into more discrete semantic resources. Keep the data flowing forward like a funnel.               | [![bloat](/assets/img/work/bloat.png)](/assets/img/work/bloat.png)                               |
| Views     | Configure different materializations dependent on the depth, width, and layer of the data. Table materializations are preferred for marts accessed by external services while views are better for less mature data and intermediate contracts.                                                                   | [![materialization](/assets/img/work/materialization.png)](/assets/img/work/materialization.png) |
| Implicit  | Explicitly list columns where/when appropriate. Rule of thumb is that L01/02/03 should be explicit whereas intermediate can be implicit. Use your judgement. Implicit slelects are harder to read and refactor, they are also more likly to expose data unexpectedly. | [![select](/assets/img/work/select.png)](/assets/img/work/select.png)                            |

## Conclusion

By establishing definitions and purpose for areas of the system we can effectively manage change, create step-wise ETL, and reduce resources
required to host a functional data platform.
