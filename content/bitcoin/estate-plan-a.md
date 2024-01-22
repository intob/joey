---
title: "Estate plan A"
date: 2024-01-22
categories: ["Bitcoin"]
description: "If you die, or become incapacitated, what do you wish to happen with your Bitcoin?"
img: "/img/art/cubes/"
needToKnow: ["key", "wallet", "multi-sig"]
teaches: "estate-planning"
---
# Important: This is a work in progress
---

We holders of bitcoin must consider what we would like to happen to our bitcoin after our death.

Fundamentally, we have two choices:
- Let our bitcoin burn
- Pass the bitcoin on to trusted individuals

Letting our bitcoin burn is no bad thing as the total supply is fixed. Every participant in the network would benefit equally. The energy is dissipated evenly.

Rather than burning our bitcoin, we may wish that our close and trusted friends and family receive it. Estate planning is the process of defining a protocol that will execute after our eventual demise.

I've spent quite some time wondering how to implement a protocol that is sure to execute correctly.

A protocol that does not compromise my funds while I am alive, but also ensures that the funds are distributed to the intended holders.

The following is precisely that protocol.

## Pre-requisites
- A multi-sig wallet of at least 2-of-3
- A list of at least 3 trusted individuals (members)

## Create a file that identifies each member
Create a file with a list of members who will receive your bitcoin.
Include their name, bitcoin address, physical address, family physical address, phone number, email address, etc.

Include as much information about each of them as you wish. The more information you include, the more likely it is that some of these people can collaborate to execute the protocol.

For example:
```yaml
- name: "Larry"
  bitcoin_address: "bc1qw2af3e6r84rxku3hxqr5audq3sxfzrt683t0q6"
  email_address: "your-mate-larry@fink.com"
  physical_address: "123 Maple Street, Toronto, Ontario, Canada"
  family_physical_address: "456 Birch Road, Vancouver, British Columbia, Canada"
  phone_number: "(416) 123-4567"

- name: "Billy"
  bitcoin_address: "bc1q89263463ns06r4sjuarqmngx4zqtc3lwjs2jeq"
  email_address: "billy@heavenlygates.com"
  physical_address: "789 High Street, London, England, UK"
  family_physical_address: "321 Oak Lane, Edinburgh, Scotland, UK"
  phone_number: "+44 20 7946 0857"

- name: "Tony"
  bitcoin_address: "bc1qxstlh4shye6p2y82vk2qh30tmvfgc0wc7c4yph"
  email_address: "slim-tony@fauci.com"
  physical_address: "111 Pine Street, Sydney, New South Wales, Australia"
  family_physical_address: "222 Kangaroo Court, Melbourne, Victoria, Australia"
  phone_number: "+61 2 9876 5432"
```

## Create PSBTs
Each member will receive the list of members, plus a partially signed bitcoin transaction (PSBT).

In a 2-of-3 configuration, each member receives a PSBT with 1-of-2 required signatures.

The transaction distributes your funds as you wish. For example:
![example tx](/img/tech/psbt/original.png)

### Optional: Locktime (added security)
Include a locktime, such that the transaction is not valid until a specific date. As long as you are alive, you must issue new PSBTs. This can be integrated into your key rotation protocol. This completely removes the possibility for any 2 of the members to execute the transaction prematurely.

### Partially sign each transaction
Using one of your 3 keys, partially sign each transaction. Each member will be unable to broadcast the transaction alone.

In order to broadcast the transaction, in a 2-of-3 configuration, 2 of the members must collaborate to broadcast the trasaction.

Note that the trasaction cannot be modified. This eliminates the possibility of any member deviating from the protocol.

The only risk is that any member may choose to ignore the protocol. Therefore, you should choose enough members for your desired redundancy.

## Distribute PSBTs & member list
Now your estate plan is almost done. There are, however, still some important considerations.

The list of members is a vulnerability of the protocol. If this list is compromised, all members are in danger, and the security of the entire protocol will be compromised.

For this reason, it is essential that the member list is well secured.

I suggest the following for secure distribution.

### 1. Preparation
Zip PSBT & member list into a single file.

### 2. For each member individually
Step 1: Generate & securely record a password (eg. 24 BIP-39 words in a Billfodl)

Step 2: Encrypt file with AES-GCM using the generated password

Step 3: Label the Billfodl & file with the name of the member.

### 3. Transmit to each member their encrypted file
Transmit each encypted file to the corresponding member, ensuring that they have recieved it.

Ensure that they store it in multiple places. They could possibly also print a QR code to eliminate risk of compromise from electromagnetism.

### 4. Securely hand each member their password
Now, you must securely give each member the password to decrypt the file. This is obviously best done in person.