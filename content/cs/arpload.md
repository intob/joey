---
title: arpload
description: "I wanted to upload a 4k video to Arweave network... and failed at first. Safely upload large files to Arweave network with arpload."
date: 2024-03-09
img: /img/cs/arpload/2/
---
## Arweave is a decentralized storage network that offers a unique approach to data storage.
The network is designed to provide permanent information storage, where users pay a one-time fee to store data for at least 200 years, with the potential for it to last much longer, possibly forever. 

This is based on the assumption that the cost of storage will continue to decrease over time, and the initial fee paid by the uploader is invested in an endowment that accrues value, similar to interest in a bank account.

The endowment is a critical component of Arweave's economic model. It is designed to ensure that the rewards for storing data remain higher than the cost of storage over time. The network uses a portion of the storage fees to pay miners in the future, which should theoretically allow the model to sustain itself indefinitely.

This approach is expected to provide a solution to the problem of data impermanence on the internet.

Arweave's network is often compared to Bitcoin but for data, creating a permanent and decentralized web within an open ledger.

The network uses a blockchain-like structure called the blockweave, which allows for the storage of large datasets and incentivizes miners to store a larger amount of data.

The Arweave protocol is also designed to be accessible through traditional web browsers, making it user-friendly and widely adoptable.

The AR token is the native cryptocurrency of the Arweave network and is used to pay for transactions and storage fees. The supply of AR tokens is capped, which contributes to the economic model of the network.

In short, the network aims to ensure data permanence by leveraging the decreasing cost of storage and the economic incentives provided to miners to maintain the data over centuries.

## Finally, I got around to somewhat finishing a simple Arweave file uploader.
The story goes like this; I wanted to upload a [4k video](/going-fast/2024-01-24-serene-reflections) to Arweave network.

### Web wallet? Nope
I first tried to use the [Arweave web wallet](https://arweave.app). This would have worked, but the upload hung for so long without visible feedback (I forgot to open dev tools). I incorrectly assumed that the upload was failing. I quickly realised that I paid for the failed transactions, so I should stop wasting AR.

### ArDrive? Nope
I tried ArDrive, because I just wanted a nice UI for safe & easy upload of a large file. The web interface, is indeed user-friendly. However, ArDrive uses bundling, and I want a standalone transaction.

## Ok... let's build
Finally, I concluded that I should write an application to do this. Thankfully, there is a great library from everFinance, [goar](https://github.com/everFinance/goar). This made it trivial to write the uploader.

Today, I finally got around to somewhat finishing it by implementing the functionality to resume an interrupted upload. It can now serve as an example, or maybe even help you to upload something.

## Demo
Tx: [TK60GE39cvuTh_DlLK5ZCnhcoOkN42YFQjsJfzwvrk4](https://viewblock.io/arweave/tx/TK60GE39cvuTh_DlLK5ZCnhcoOkN42YFQjsJfzwvrk4)
![image](https://jsxligcn7vzpxe4h6dsszlszbj4fzihjbxrwmbkchmex6pbpvzha.arweave.net/TK60GE39cvuTh_DlLK5ZCnhcoOkN42YFQjsJfzwvrk4)

## Repo
https://github.com/intob/arpload