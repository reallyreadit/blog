---
layout: post
title: How Readup Pays Writers When You Read Their Articles
description: A detailed look at the financial model and technical infrastructure that powers Readup's reader/writer marketplace.
date: 2021-06-08
author: Jeff Camera
---
## The Readup Proposition

It takes time and money to write and publish an article that's worth reading. Those costs need to be recouped, but there's a big problem with the Web's most pervasive method of monetization: Advertising ruins the experience of reading. There are alternatives, but they all have drawbacks.

I wanted to create a neat infographic here to compare various monetization schemes, but many of the alternatives don't fit into nice neat categories. For instance, some publishers, like The New Yorker, still display ads on premium, subscription-only content. Some premium subscription bundlers, like Apple News Plus, will get you access to only a small subset of the articles from a partnered publisher and may also still contain ads.

There are subscription newsletters, but subscribing to individual writers can quickly become even more expensive than subscribing to individual publishers if you value reading a diversity of opinions. There are existing contribution services like Coil, which is based on the [Web Monetization API](https://webmonetization.org/), and Flattr, but both require content creators to link their work to the platform before they can be eligible for compensation, and very few writers have done so.

What if instead you only needed a single subscription to read any article on the Web ad-free? What if your subscription revenue was automatically, fairly, and transparently divided up between the writers you've read? What if we could make this happen using the existing infrastructure of the Web, without the need for any new protocols or changes to the way articles are currently being published?

## A Subscription Reading Service for the Whole Web

The Web is a federated document publishing platform. The hypertext standards that comprise the foundation of the Web, HTML and HTTP, are over 30 years old and have contained within them since day one all the information that we need for a universal subscription service: content and attribution. That, however, is a bit like saying "There's gold in them thar hills." It may be true, but that doesn't mean it'll be easy to get out. Even though HTML documents can be structured semantically, they don't have to be and there are many different standard and non-standard methods for specifying authorship. Readup's algorithms do the work of digging through the mountains of markup to extract the gold.

This of course means that Readup needs access to the article HTML document, which is achieved in different ways depending on what kind of device you're using. The [Readup iOS app](https://apps.apple.com/us/app/readup-social-reading/id1441825432) functions as a specialized reading browser. Articles are loaded in a Web view which enables us to inject the code required to remove ads, identify and format the primary text and image content of the article, extract the article metadata, and perform the read tracking. On desktop devices, readers use the Readup browser extensions to perform the same operations with a single click of the extension button. This approach allows Readup to work on any article on the internet, regardless of where, when or how it was written or published.

![Reader Mode](/assets/2021/06/reader-mode.png)

Readers choose their own subscription price, with a minimum of $4.99 per month. Readup keeps 5% as a fee, subtracts the exact amount charged by the payment processor, and distributes the rest to writers. As you read during the course of the subscription cycle, the dollar amounts allocated to each writer fluctuate in proportion to the amount of time you've spent reading them. At the end of each cycle the dollar amounts are finalized and distributed to the writers' Readup accounts.

Readup is the first and only subscription platform to use the read as a basis for writer compensation. This is revolutionary, and absolutely crucial to the simplicity and clarity of our subscription model. Even other reading-focused services like Medium and Scroll use a murky time-on-page "engagement" metric to divide up subscription revenue. We think that's ridiculous. Reading an article is fundamentally different from scrolling through a feed or skimming headlines. If a piece is well written, it is deserving of your full attention. Skimming and scanning and other half-focused behavior doesn't count. [You either read something or you didn't](/2020/11/02/how-readup-knows-whether-or-not-youve-read-an-article.html). We believe that so many of the ills that are plaguing the incumbent social media platforms are [due to a failure to appreciate the importance of that distinction](/2021/02/08/the-readup-manifesto.html).

![My Impact](/assets/2021/06/my-impact.png)

In order to receive their payouts, writers must first be verified and have an account balance of at least $10 USD. Verification is a manual, human-to-human process that ensures we're sending the money to the right person. Once a writer has been verified, they can link their bank account to their Readup account via our integration with Stripe. Payouts will then be sent automatically every month as long as the current balance is at least $10 USD. All writers have to do is sit back and collect their earnings from every article that they've ever written anywhere on the Web.

## The Bigger Picture

Understanding the technical details of Readup's model is one thing, but believing in it, and us, is another. Thankfully our incentives are aligned from top to bottom with those of our readers and writers. Readup's goal is to provide the best online reading experience possible and to encourage people to spend more time reading and writing high quality articles. Our simple commission-based business model enables us to embrace privacy and transparency in a way that simply isn't possible when advertisers are involved.

To start with, we only collect data from our readers and writers that is necessary to run Readup and we never share any of it with any third parties. As a reader, your reading history and subscription contributions always remain completely private. [We're proud of our privacy policy](/2020/10/26/readup-has-the-worlds-best-privacy-policy.html). We wrote it from scratch to be as readable and understandable as possible and we encourage everyone to read it.

We also believe that transparency is just as important as privacy. Our total amount of revenue and the amount allocated to writers is public and updated in real time right on our home page. All writer account balances and payout amounts are public and earnings never expire. Check out [readup.com/earnings](https://readup.com/earnings) to see the full accounting. Every reader can always see exactly where their subscription money is going, right down to the penny.

Looking forward, Readup will have a lot to offer publishers as well. Once we have a large enough subscription base we could offer publishers a substantial new revenue stream in exchange for access to articles that are currently locked behind paywalls.

## Get on, Pay in, Read up

If you like our vision for a sustainable, ad-free future for online reading then [get started on Readup](https://readup.com/) today and try it out for yourself! You can create an account for free and see what articles our readers are talking about without having to create a subscription. In you're looking for some additional reading inspiration check out our [recent and best ever Article of the Day winners](https://readup.com/aotd/history). Even at our small scale the power of reading has the ability to surface amazing articles and spark meaningful conversations and connections. There truly is no better way to spend time online.