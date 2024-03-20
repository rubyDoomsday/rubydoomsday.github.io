---
layout: post
title:  Migrating Customer Data to Custom CRM
subtitle: Software Engineering
date:   2021-06-21
tags:   elt architecture design documentation rails systems
---

# Background

I am working on a concept project that was built as a single tenant application. We have been tasked with refactoring this concept inot a
multi-tenant application. During the onboarding process the company uses an [ELT Tool] to import customer data. As such the [ETL Tool], the
defacto ETL utility used to import customer data into a new database instance of MadeUp Co., was initially designed to work with only ONE
database technology and was meant to be run ONCE against said database. However, this utility now has the need to function against multiple
database technologies and be run in a repeatable fashion. Some inroads have been made to make this utility work with additional databases,
but the time has come to expand this prototype to a more scalable solution.

# Goals

The goal of this document will be to define a meaningful path forward for the [ETL Tool] project so that we can reduce onboarding time for
our customers and development time for engineering team with a more scalable solution that will support MANY database technologies and run
MANY times. This “final phase” can then be used to work backward and define a phased roll out of the updates required.

# Initial Assessment

## Workflow Summary

[![current design](/assets/img/work/current-design.png)](/assets/img/work/current-design.png)

- A defined exporter class is initialized with a block of Vendor X record IDs.
- The exporter queries the DB for the records and any related entities related to them.
- Export Phases
  - The exporter enqueues a delayed job with the individual entity hash.
  - The importer builds the entity and any cascading records
  - The exporter enqueues a delayed job with the individual record hash.
  - The importer builds the record and any cascading records

## Technical Debt

- This project has to be synchronized with Core DB and Model validations (duplication)
- All transformation are run on a single server and single thread (single threaded operation)
- Throughput is limited by the server running the task
- Dividing data into manageable sections is a manual process
- Each exporter is custom-tailored to the Vendor (does not ascribe to a contract)
- Extraction and Transformation are handled by a single class (overloaded)
- Low amount of encapsulation among classes (no unit testing does not ascribe to TDD)
- Multiple DB connections/technologies to maintain/manage (manageable but not ideal)

# Options For Improvement

To assess our ability and resources required to accomplish a refactor of this tool the following
options have been provided. Regardless of the technology path chosen the solution must adhere to
these basic requirements.

## Requirements

- Must remove duplication created by keeping ETL project in sync with [Main Project project
- Must be thread safe to process more transformations in less time
- Must be testable (unit, integration and end-to-end)

|             | Option 1                       | Option 2                               |
| ----------- | ------------------------------ | -------------------------------------- |
| Description | Kafka Backbone (see diagram)   | REST API (see diagram)                 |
| Pros        | removes duplication            | removes duplication                    |
|             | leverages existing export code | leverages existing export code         |
|             | creates thread-safe export     | creates thread-safe export             |
|             | asynchronous loaded            | asynchronous loader                    |
|             | ERD is owned by [Main Project] | ERD is owned by [Main Project]         |
|             | Built in redundancy (Kafka)    | Creates/Exposes a RESTful API          |
| Cons        | Dev-Ops overhead               | Bottlenecking dependent on replication |
| Cost        | **Large**                      | **Medium**                             |

## Kafka Diagram

[![kafka design proposal](/assets/img/work/kafka-design.png)](/assets/img/work/kafka-design.png)

## REST Diagram

[![rest design proposal](/assets/img/work/rest-design.png)](/assets/img/work/rest-design.png)
]

# Conclusion

In an effort to keep infrastructure low and reduce complexity we will move forward with the RESTful approach. This solution prooved to
increase throughput and significantly reduced development time and code complexity. The clear interface and separation of responibility was
key to the solution.
