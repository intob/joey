---
title: "Perfect bitcoin key rotation"
date: 2024-01-20
categories: ["Tech"]
description: "With a multi-sig bitcoin wallet, what is the best way to safely rotate your keys?"
img: "/img/art/cryptic-wall/"
needToKnow: ["key", "wallet", "multi-sig"]
teaches: "rotation"
---
Be forewarned, GPT-4 helped me write this, as I wanted to write a rotation protocol for myself. After a couple of tweaks, I now think it's not a bad start.


---


Designing a "perfect" key rotation protocol for a 2-of-3 multi-sig Bitcoin wallet involves balancing security, redundancy, and operational practicality.

Key rotation in a multi-sig context means updating one or more of the keys involved in the signature process.

This protocol aims to ensure that at no point is the wallet's security compromised
while also making sure that the transition from one set of keys to another is smooth,
transparent, and leaves no room for errors or funds getting locked due to mismanagement.

## Initial setup

Start with a 2-of-3 multi-sig wallet.

Let's label the keys as: Key A, Key B and Key C.

Ensure that each key is securely and independently stored.
Define a regular rotation schedule (e.g., annually, biannually).

## Pre-rotation

Notify all key holders of the upcoming rotation.

Perform a test transaction to ensure all keys are operational.

## Rotation process

Step 1: Generate a new key (Key D)

Step 2: Create a new 2-of-3 multi-sig wallet using Key B, Key C, and Key D (assuming you're rotating out Key A).

Step 3: Sign a transaction with all 3 keys as a test.

Step 4: Transfer a small amount of Bitcoin to the new wallet as a test.

Step 5: Once confirmed, transfer the remaining Bitcoin from the old wallet to the new one.

Step 6: Retire Key A securely. Ensure it is no longer used.

## Post-rotation

Update all relevant documentation and access protocols to reflect the new key setup.

Schedule the next rotation.

## Redundancy and recovery

Ensure each key holder has a secure and independent backup and recovery process.

Regularly test recovery processes to ensure they work as expected.

## Security considerations

Perform all key generation and transactions in a secure environment.

Use hardware wallets or other secure methods to store private keys.

Regularly audit and update security practices.

## Transparency and communication

Keep all stakeholders informed about the key rotation schedule and any changes.

Maintain clear records of who has access to each key.

## Frequency of rotation

The rotation frequency should balance operational practicality with security.

Too frequent rotations can be operationally cumbersome, while infrequent rotations may increase risk.

## Emergency protocols

Have a plan for emergency situations, like key compromise or loss.
