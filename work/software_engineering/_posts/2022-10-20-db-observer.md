---
layout: post
title:  Streaming Data From a Rails Application
subtitle: Software Engineering
date:   2022-10-20
tags:   data architecture design documentation rails gem engine
---

<a href="https://github.com/rubyDoomsday/data_producer" target="_blank">View the project</a>

## Background

We have several Rails applications using various database technologies to manipulate and store data. The underlying ERD is not well defined
and many of the relationships, transformations and domain objects are handled in the application layer. This makes querying the database
directly problematic and tracking/defining much of the stored information has landed on a manual process for those not under the engineering
umbrella such as data analysts

## Goals

The goals of this project would be to programmatically gain access to the data stored in these applications in a cohesive and human readable
format via a single Postgres database. The resulting data should be decoupled from and not interfere with the SDLC of the applications in
place.

### Requirements

- The data should be human readable
- The data should be available in a Postgres DB (SQL)
- The data should remove all polymorphic relationships
- The data should live as a relatable ERD
- The data should be separated from the application

## Proposal

To leverage the application layer transformations and relationships as well as getting around the different DB technologies, we should
access the data within the application layer. The best and least impactful way to accomplish this would be by installing a gem that can be
shared across the various applications. The gem would observe CRUD operations via Active Record models and publish out the resulting changes
to a message bus that could be ingested by a downstream consumer.

### Design

#### Diagram

[![db observer gem](/assets/img/work/db-observer-gem.jpg)](/assets/img/work/db-observer-gem.jpg)

#### Design notes

- Application
  - Config.yml - The Rails application provides configuration details to the gem via a config.yml which is interpreted by the
    initializer.rb. These details include credentials and behavioral switches.
  - Models - Models tagged with a monitor flag indicating which writes are to be observed by the gem. When one of these write operations are
    invoked, the state of the record is passed through the gem via a corresponding concern. (see below) This can be explicitly set on
    individual models are enabled for all Application Records within each application.
  - Rails CLI - Rake may leverage tasks provided by the gem via a bundle exec rake command. This type of access will provide means to debug
    data exports as well as run historical backfills on new/existing records.
- Gem
  - Core/Lib
    - Models - An abstract class that exposes/manages the callbacks for the main application. Models will include the required concerns which
      trigger the corresponding action. Models#monitor is made available to all classes that inherit from ActiveRecord and/or ActiveSupport
      via an initializer provided by the gem
    - Concerns - Encapsulate logic specific to the named trigger.
    - Reporting service - A wrapper that shapes arguments received from a model into a data payload to conform to the under lying publishing
      service. This would act as the main proxy/interface for the concerns.
    - Publishing service - A wrapper class that exposes an interface for publishing messages/events to the messaging bus. This is also
      encapsulates the ownership of the message contract. Changes to this contract will have downstream effects.
  - CLI
    - Tasks - Includes data producer rake tasks to the main application. This is the primary interface to initiate a historical backfill.
    - Backfilling service - Responsible for publishing out current state of records for a given time period. It uses batch processing
      for individual Models/tables to ensure most up to date data.

## Risk/Rewards

### Risks

- We do not want to open source this gem to the greater public, it will require being hosted on a private repo which require
  credentials for each application in order to access/install
- The gem is agnostic to the host application and if enabled for all Application Records, would put the onus on downstream services to
  update their processing to support new columns/tables as they are made available.
- Usage of the Rails helper `has_and_belongs_to_many` may introduce problems and should be avoided by the application team.
- Defining the message bus technology is a perquisite for this to operate as it will have downstream effects and consequences.

### Rewards

- Since all data columns are handled at the application layer we get many of the transformations for free allowing the application teams
  to update without concern of additional overhead or manual management.
- This can be leveraged by all application currently running on the platform
- Data is decoupled from the host application and is now accessible for other purposes via the message bus.
- Consuming and transforming data can be accomplished via any means/technologies that are compatible with mesage bus.
- A companion data consumer gem could be installed to provide similar shared resources for downstream applications.
- As a gem all development can exist outside of the individual applications and would require versioned updates/releases to those
  applications on an as needed basis

<a href="https://github.com/rubyDoomsday/data_producer" target="_blank">View the project</a>
