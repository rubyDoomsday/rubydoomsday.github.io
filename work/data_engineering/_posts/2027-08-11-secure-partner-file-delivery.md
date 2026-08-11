---
layout: post
title:  Stop Emailing CSVs, Designing a Secure Partner File Delivery Pipeline
subtitle: Data Engineering
date:   2027-08-11
tags:   data architecture security design
draft:  true
---

## Background

At some point almost every data team ends up delivering files to someone outside the company. A partner needs a daily extract, a vendor needs a reconciliation file, a regulator needs a report. And almost every data team backs into the same three ways of doing it, none of which anyone would design on purpose if they sat down and thought about it first:

1. Push an unencrypted file to a partner's SFTP server.
2. Email an unencrypted file to whoever asked for it.
3. Push an encrypted file to your own SFTP server for the partner to pick up.

The first two are the default because they're the fastest thing that works the first time someone asks. The problem shows up later, once there are a dozen of these running quietly in production: unencrypted files sitting on external servers, sensitive data emailed to individual inboxes instead of a controlled channel, no unified visibility into whether any of it actually succeeded, and failure notifications scattered across email, chat, and whatever tool built the file in the first place. None of that is a single bug. It's an architecture that grew by accretion, one urgent request at a time, and it needs to be replaced on purpose instead of patched again.

## The Requirements, Stated Plainly

Before picking a design, it's worth writing down what actually has to be true, separate from how it gets built:

| Must have | Nice to have | Out of scope for this pass |
| --- | --- | --- |
| Files are encrypted | Automated recovery on failure | Migrating every legacy delivery in one shot |
| Access is authenticated | | Rebuilding the notification tooling itself |
| Delivery is observable (you know it worked) | | |
| Failures alert someone | | |
| Safe to carry the most sensitive fields (SSNs, account numbers) | | |

That last requirement is the one worth sitting with. A design that's "secure enough" for a name and an email address is not automatically secure enough for a government ID number. If the pipeline needs to carry the second category even occasionally, design for the second category from the start, because retrofitting encryption onto a system built for lighter data is a much bigger project than building it in from day one.

## The Design

[![secure partner delivery pipeline, encrypted path alongside the legacy email path it replaces](/assets/img/work/secure-delivery-flow.png)](/assets/img/work/secure-delivery-flow.png)

**Encryption:** PGP, keyed to the partner's own public key, not a shared or internal key. The partner already holds the private key that can decrypt it, and this means the file is unreadable to anyone else the moment it leaves your control, including anyone with access to the intermediate storage it passes through on the way out.

**Delivery:** files land in an internal, time-boxed staging area (an object store bucket with a short retention window, not a permanent archive) before an encryption step picks them up, encrypts them, and pushes the result out over SFTP. The unencrypted copy never leaves your own infrastructure and disappears on a schedule rather than lingering indefinitely.

**Notification:** opt-in subscriptions instead of individually addressed emails baked into the pipeline. A shared team inbox or distribution channel, not a hardcoded list of individual recipients that goes stale the moment someone changes teams.

**Observability:** every hop of the pipeline (build, land, encrypt, deliver) reports into one place, so "did this work?" has a single answer instead of requiring someone to check three different tools before they can say yes or no.

That end-to-end path breaks into three concerns, and keeping them separate is what makes the system maintainable once there are more than a couple of partners on it:

1. **Build the file.** Whatever produces the raw data doesn't need to know anything about encryption or delivery, just that it's writing to a defined staging location.
2. **Provision the plumbing.** The storage and infrastructure that the build step writes to, and that the encryption step watches, managed as code rather than clicked together by hand.
3. **Encrypt and deliver.** A small, focused piece of compute (a Lambda, a scheduled job, whatever fits your stack) that watches the staging location, encrypts anything that lands there, and ships it out.

The value of that split is that onboarding a new partner touches step 3's configuration, not steps 1 or 2. A report and a partner are two separate configuration concerns: *where do I watch for new files* and *where do I send them once they're encrypted*. Decoupling those means either one can be reused independently, the same report can go to two partners, and the same delivery config pattern can carry a totally different report, without duplicating logic for each new combination.

## Three Things That Will Actually Bite You

The interesting failure modes in a system like this are almost never the cryptography. They're the boring operational seams around it.

**Get the partner's public key over a different channel than the one you're about to encrypt for them.** If you're standing up SFTP delivery, don't request the encryption key over that same SFTP connection. Use a separate, already-trusted channel, an existing account contact, a verified email thread, whatever your relationship already has, so a compromised delivery channel can't also compromise the key exchange that's supposed to protect it. And track the key's expiration date explicitly. An expired key doesn't throw a helpful error, it just silently breaks encryption the next time the job runs, and the failure mode you discover it through is a partner asking why nothing has arrived in a week.

**Never let infrastructure-as-code populate a real secret.** Provisioning tooling can and should create the *shell* of a credential, a named secret with placeholder values, but the actual credential belongs in a secrets manager, entered by a human with the least privilege necessary to do it, after the infrastructure exists. If your deploy tooling can write real secrets into version control or into its own state, that secret isn't actually secret. The extra manual step is friction on purpose.

**Test the full round-trip before anyone schedules it.** Not "the file lands somewhere," the whole thing: build, land, encrypt, deliver, and confirm the partner can actually decrypt it and that the schema matches what was signed off. I've seen a pipeline pass every internal check and still fail in production because of a single case-sensitivity mismatch between how a config value was defined and how the code that consumed it expected to read it, both individually "correct," incompatible with each other. That's not a cryptography bug, it's an interface contract that nobody actually verified end to end before turning the schedule on. Confirm decryption with the actual recipient before the first live run, not after.

## What This Replaces, Not All at Once

None of this required ripping out the legacy unencrypted paths on day one. New reports, especially anything carrying sensitive fields, go through the new pattern by default. Existing ones migrate as they come up for other reasons, a schema change, a partner asking for a new field, rather than a forced big-bang cutover. A security improvement that requires migrating everything simultaneously to get any benefit usually doesn't ship. One that delivers value on the very first new report, and lets the backlog migrate opportunistically, does.

## Conclusion

The unencrypted-email version of this isn't a design mistake so much as a design that was never actually made on purpose. Nobody sits down and decides "we should email sensitive files to individual inboxes with no unified visibility into failures." It just accretes, one reasonable-sounding one-off request at a time, until it's load-bearing. The fix isn't cleverness, it's writing down what "secure enough" actually requires before the next request comes in, and building the boring plumbing, key exchange, secrets, a real end-to-end test, that makes the design hold up outside of a demo.
