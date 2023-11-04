---
layout: post
title: How Readup is Built
description: An overview of Readup's architecture, from Git repositories to AWS services.
date: 2021-12-10
author: Jeff Camera
---
## All Aboard
The [bus factor](https://en.wikipedia.org/wiki/Bus_factor) is defined on Wikipedia as follows:

> ...a measurement of the risk resulting from information and capabilities not being shared among team members, derived from the phrase "in case they get hit by a bus".

The core idea is that it's not just about how many team members you can afford to lose at any given point in time, but about how replaceable they are. A higher bus factor is better than a low bus factor. If the loss of a single member of your team means the team can no longer function, then you've got a bus factor of one and a high level of risk. The article continues:

> The concept is similar to the much older idea of key person risk, but considers the consequences of losing key technical experts, versus financial or managerial executives (who are theoretically replaceable at an insurable cost).

This must have been written by a programmer! At first blush it might appear flattering to be considered irreplaceable, but I'd argue that the strong association between the bus factor and software development is due more to our tendency to write unreadable code and fail to document anything than it is to the fact that each software developer is a beautiful and unique snowflake. I'm at least as guilty of these malefactions as anyone, but there are sometimes diminishing returns to consider as well.

For the first four years, the Readup team was just me and my co-founder and I was the only programmer. Sure, I could have written copious amounts of documentation and made Bill my LastPass next of kin, but I think it would have been foolish to spend time planning for the demise of a co-founder in a nascent startup. The equation changed, however, when Thor [joined the team](https://blog.readup.com/2021/09/08/why-I-joined-readup.html) as a front-end developer this past year.

There was an initial scramble to create minimal, just-in-time documentation so that Thor could set up his development environment and start hacking away, but a high-level view of the whole tech stack and infrastructure was always missing. Last week I finally began the process of filling in those missing pieces of the puzzle with the goal of leveling up Readup's bus factor. Let's take it from the top!

## Vendors

Before we even get into any code, lets start by taking a look at the external services that Readup relies on to operate. Chances are that if a team member vanishes one day you'll still have the opportunity to rummage though their work product in an effort to pick up where they left off. Accounts and services that are outside your company's direct control can be much more difficult to audit and secure access to, but are sometimes just as important.

Readup depends on 10 different vendors to operate. Managing shared access to these accounts is absolutely crucial. Here's a high-level look at our vendors, their primary responsibilities, and the resources that flow between them.

[![Readup Vendors Chart](https://blog.readup.com/assets/2021/12/Vendors@2x.png)](https://blog.readup.com/assets/2021/12/Vendors@2x.png)

Pretty standard fare and plenty of familiar faces, but it's much easier to manage access to some of these accounts than others.

- Apple, AWS, Github, Google, Stripe, and Twitter all make it super easy to manage team accounts with multiple members.
- Microsoft, at least at the time we signed up, required the use of a personal Microsoft account, instead of a business Microsoft account, in order to submit an Edge Add-on. This was strange, but at least I could create a personal account using my business email address, which is also strange. Everything about Microsoft account management is strange.
- Mozilla's Add-on Developer Hub does not support team accounts and requires the use of an authenticator app to sign in. As a result, this is the one account that is the most difficult to share access to and we don't currently have a solution in place.
- I made the mistake of registering our domains using my personal account. If you think about it, this actually makes sense though since we could not create our business email accounts until our domains were registered. Thankfully I don't have any personal domains registered with GoDaddy so this is an easy email change and GoDaddy does support delegating access to other accounts.

    Also, in case anyone is wondering why we registered our domains with GoDaddy, our original domain name was reallyread.it and GoDaddy made it easy to register Italian domain names.

Finally there is the Comodo account which is at least a thousand times weirder than all the others combined. I could write a 10,000 word rant about the insanity of the Windows code signing process but here it is in short: You navigate a byzantine, weeks-long verification process for the ability to pay $319 for a hardware signing certificate that is good for one year so that end-users don't see a virus warning when they download or run your Windows installer.

Behold!

[![Magical USB Certificate](https://blog.readup.com/assets/2021/12/ev-cert-photo-redacted.jpg)](https://blog.readup.com/assets/2021/12/ev-cert-photo-redacted.jpg)

I guess I'll bequeath this to Thor so that should I actually get hit by a bus Readup doesn't have to pay an additional fee for a re-issued certificate. This kind of nonsense really makes one appreciate the App Store in spite of all its flaws.

Why didn't we just submit our app through the Microsoft Store instead? Because the Readup desktop application needs to write to the registry in order to register its browser extension [native messaging manifests](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_manifests#windows). Sandboxed Windows Store apps cannot even write to [`HKCU`](https://en.wikipedia.org/wiki/Windows_Registry#HKEY_CURRENT_USER_(HKCU)) and unlike sandboxed macOS apps there is no provision for requesting an exception.

## AWS

Next up, let's drill down into AWS. The sheer volume of services that AWS offers can be totally overwhelming but Readup only makes use of a handful of them.

[![Readup AWS Chart](https://blog.readup.com/assets/2021/12/AWS@2x.png)](https://blog.readup.com/assets/2021/12/AWS@2x.png)

Let's break it down by service:

### Route 53

All the DNS records for Readup's three top-level domains are handled here. There's nothing special about the configuration other than that we can take advantage of [aliases](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html) for some records that point to other AWS resources like CloudFront, S3, and ELB. Only a subset of `A` records are shown for clarity.

### CloudFront

The CloudFront distributions only serve a single purpose: to enable secure HTTPS connections to our S3 static website buckets using our own domain name instead of the S3 bucket domain name. For instance, you can access our blog directly from S3 using [http://blog.readup.com.s3-website.us-east-2.amazonaws.com/](http://blog.readup.com.s3-website.us-east-2.amazonaws.com/) but in order to use [https://blog.readup.com/](https://blog.readup.com/) we must use a CloudFront distribution configured with that domain name and the blog S3 bucket as its origin, essentially using CloudFront as a simple reverse-proxy server.

### S3

Our S3 buckets are configured as follows:

- readup.org (Static Website Redirect): A public bucket that just redirects HTTP requests from readup.org to readup.com. This is configured only to handle the edge case of someone typing in "readup.org" instead of "readup.com". More elaborate redirect handling is limited by the fact that HTTPS is not supported.
- blog.readup.com (Static Website Host): What you're reading right now is being served from this bucket!
- static.readup.com (Static Website Host): Hosts static resources for multiple Readup clients.
    - JS and CSS bundles for the Readup web app.
    - Fonts and images for multiple Readup clients.
    - JS and CSS bundles for the Readup blog embed.
    - JS bundles used for dynamic [OTA](https://en.wikipedia.org/wiki/Over-the-air_programming) updates from Readup native client apps.
    - Readup Windows and Linux installer downloads.
- aws.reallyread.it (Static Website Disabled): A private bucket used to support the provisioning and operation of the Readup web servers.
    - Binary installers and resources required to provision new EC2 instances.
    - Archive location for web server logs shipped from EC2 instances.
    - PowerShell scripts for provisioning and updating EC2 instances.
    - Zip archives used to deploy Readup code to EC2 instances.

### EC2

This is the big one. We've got ourselves a curious mix of Windows and Linux servers. All Readup code, including our server code, is cross-platform, but I feel slightly more comfortable configuring IIS over other web servers. This used to matter more back when the web servers were exposed directly to the internet instead of being placed behind a reverse-proxy. All of the servers have been remarkably stable so I simply never felt the need to switch over to Linux after that. In addition to simplifying server configuration, placing the public servers behind an Elastic Load Balancer (ELB) also enables the following:

- Scaling server capacity by adding multiple EC2 instances behind a single ELB.
- Performing zero-downtime code deploys using the [blue-green deployment strategy](https://martinfowler.com/bliki/BlueGreenDeployment.html).
- Not having to worry about SSL certificates. HTTPS terminates at the ELB and the ELB is configured to use auto-renewing SSL certificates provided by AWS Certificate Manager (ACM).

Let's take a look at what each server does:

- **reallyreadit-server**: This server almost doesn't even need to exist. ELBs can be configured to perform redirects and return static content all on their own and that's all this server does, but the conditional logic is just a little beyond what's possible with the ELB rules. Here's how it works:
    - If a legacy reallyread.it client app is requesting the reallyread.it web app, return a notice to the user that they must update to the Readup app.
    - If the request is from an iOS device, redirect to the Readup App Store page. This is an important part of enabling an "Open in App" button on readup.com web pages that can escape a `SFSafariViewController`. An example scenario:
        - Someone shares a Readup link on Twitter: https://readup.com/comments/the-new-yorker/the-dead-zone
        - A Readup user taps that link in the Twitter iOS app expecting the Readup app to open due to the `applinks:readup.com` domain association.
        - The Twitter app opens the URL in a `SFSafariViewController` instance instead of handing the navigation off to the system.
        - The readup.com webpage shows an "Open in App" button to the iOS user but it is impossible to know if the user has the Readup app installed. The button is just a link to the current page with the host set to reallyread.it instead of readup.com.
        - When the user taps "Open in App" the additional `applinks:reallyread.it` domain association will kick in and the Readup app will open if it's installed. If it's not installed the request will reach this server and we should redirect the user to the App Store.
    - If the request is not from an iOS device perform a regular redirect to readup.com, preserving the path.
- **readup-app-server-x**: This server serves up the readup.com web pages and the Readup web app which is used as the main app interface by the native Readup client apps. The `-x` suffix is replaced by letters to distinguish the various instances.
- **readup-api-server-x**: The API server used by readup.com web pages, the Readup web app, and the native Readup client apps. Like the app server, there can also be multiple instances running at the same time.
- **file-server**: An innocuous name for an extremely important server. This single instance serves two critical functions:
    - Hosting the data protection keys used by the API servers on a Samba share. The API servers use these keys to encrypt authentication cookies, and in order for the API servers to be stateless they must all be configured to use a [shared key storage location](https://docs.microsoft.com/en-us/aspnet/core/security/data-protection/configuration/overview?view=aspnetcore-3.1#persistkeystofilesystem).
    - Running scheduled commands using `cron` that either make a call to the API server using `curl` or query the database directly using `psql`:
        - Scoring articles.
        - Refreshing materialized views.
        - Closing out lapsed subscription cycles.
        - Selecting the article of the day.
        - Triggering daily and weekly notification digest emails.
- **analytics**: This server's primary purpose is to run a script that processes raw IIS log files that have been shipped to the aws.reallyread.it S3 bucket for the purpose of extracting analytics from the web traffic. After processing the log files, the script updates the database with the latest analytics data. This server also runs a script to synchronize data between the Readup database and AirTable which allows AirTable to be used as a front-end data entry tool.
- **open-vpn**: A [bastion host](https://en.wikipedia.org/wiki/Bastion_host) running an OpenVPN server that allows administrators access to services not exposed to the public internet.

### ACM

[Free](https://aws.amazon.com/certificate-manager/pricing/), auto-renewing SSL certificates. What's not to love? One interesting note here is that while all Readup's AWS services are located in the `us-east-2` region, CloudFront can only reference certificates created in `us-east-1` so we need to maintain readup.com certificates in both regions.

### RDS

The PostgreSQL database that is the core of Readup.

### SES

Outgoing email service for all transactional and marketing email generated by the API server. SES is also used to process incoming messages when a user replies via email to a "replyable" notification. Such replies are routed to the API server via SNS, as are any delivery error reports generated by outgoing messages.

### SNS

The only topics are those used by replies or delivery errors from SES. When SES generates a notification for either topic, SNS will send a request to the API server for processing.

## Github

Another monster! We're only going to be looking at a subset of the Readup repositories since this diagram is already way too big. "Source repositories" is referring to all repositories that meet the following conditions:
1. Contains a build process.
2. Is part of the Readup product.

In addition to the nine repositories that meet that definition, we also have quite a few others that fall into different categories:
- We're working on an Android app but it's not complete so the `android` repository is not included.
- We have an `article-test-server` and `twitter-test-server` that are used during development only and are not part of the actual Readup product.
- We have `private-api-examples` and `blog-tech-samples` which are public repos containing sample code.
- We've got `aotd-algorithms` and `privacy-policy` which are public excerpts from the `web` repository.
- We've got several internal repositories for static resources such as logos, icons, dev-ops scripts, documentation, etc.

[![Readup Repositories Chart](https://blog.readup.com/assets/2021/12/Repos@2x.png)](https://blog.readup.com/assets/2021/12/Repos@2x.png)

Pictured above are the repositories, their various production build commands, and the production build output along with the distribution destination, with the exception of the `parser-testing` repository which is labelled as "Dev Testing Only." Even though this repository isn't really part of the Readup product, it's still important to show here because it is part of the many inter-repository resource relationships depicted by the dashed orange and yellow arrows. There are quite a few of them and they make reasoning about and managing the repositories considerably more difficult. While Thor and I have discussed various ways to manage this complexity we have not yet settled on a one-size-fits-all solution. For example, there are already two different strategies in place, both with their pros and cons:

- **References**: The `parser-testing` scripts reference the `web` parser scripts during the test procedure and the `desktop` build commands reference the `browser-extension-app` binaries for inclusion in the installer packages. Both use cases are pretty straight forward but there is still the problem of versioning. If the public API of the referenced files changes then things will break, but there is no real enforcement mechanism in place to prevent that from happening.
- **Includes**: The `ios` and `desktop` repositories take another approach and include files generated by the `web` repository in their own repositories. This has the advantage of always ensuring that the included file is compatible with the rest of the files in the repository, but it's also [pretty undesirable](https://robinwinslow.uk/dont-ever-commit-binary-files-to-git) since these are "binary" files in a sense. Even though they're all text files and are not large in size, they are minified so the diffs are unreadable. They're also the output of another repository so they could become "stale" if someone forgets to copy over a new version the next time there is a change in `web` that effects that file.

    Even if we wanted to change all these "includes" to "references" there is an issue with the XCode project structure that would make this difficult for the `ios` repository. The `SafariExtension` target includes the uncompressed browser extension package files within the `Resources` directory. The browser extension package files include additional subdirectories which XCode needs a reference to from the `project.pbxproj` file which is included in the repository. This means we'd need to either temporarily modify this file during the build process or find some other workaround for copying over the browser extension package directory tree.

With all that said, let's quickly run through what each of the repositories does:

- **web**: This is kind of a mini-[mono repo](https://en.wikipedia.org/wiki/Monorepo) containing the readup.com server and web pages, the Readup web app, the browser extension, the blog embed, and the article parsing and reading scripts. Basically anything web-related that serves web pages, runs in a browser, or runs in a webview is included in this repository.
- **ios**: The Readup iOS app which is also the Readup macOS app thanks to [Mac Catalyst](https://developer.apple.com/mac-catalyst/). Safari extensions must be bundled with a macOS app so the `SafariExtension` app extension is included here as well, along with the iOS share extension for importing articles to the Readup iOS app, `AppKitBridge` which allows the macOS app to reference `AppKit` libraries (currently just used to fix a Mac Catalyst toolbar bug), and the `BrowserExtensionApp` command line interface (CLI) application which allows Chrome and Firefox to communicate with the Readup app via native messaging (more on that later).
- **desktop**: The Readup Electron app for Windows and Linux. The Windows installer is generated using `electron-winstaller` which uses the aforementioned hardware signing certificate to sign the installer and all bundled executables and also uses [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows) to provide support for serverless auto-updates with deltas. Very convenient!

    Generating a `.deb` package for Linux using `electron-installer-debian` is pretty straight forward but there is no built-in support for auto-updating. The Linux app polls the `RELEASES` file generated for Squirrel and notifies the user if an update is available but it will not automatically download and install the update.
- **browser-extension-app**: The CLI app for Windows and Linux that allows for native messaging between the GUI app and the browser extension.
- **blog**: The Jekyll blog that you're reading right now!
- **reallyread.it**: The simple reallyread.it redirect server that was discussed in the AWS section.
- **api**: The Readup API server.
- **db**: [Logic in the database](https://sive.rs/pg) is controversial, but at least in the case of Readup I am a big fan of it. I don't go as far as exposing a REST API (and I'm not a fan of triggers), but all access to the database does happen through stored procedures via [Npgsql](https://www.npgsql.org/). There is no SQL in, or generated by, my C# code and I feel like that's how it should be (Do you write C# code in your JavaScript?!).

    Yes, this does make version control a bit more inconvenient but there are plenty of reasonable workflows. I used to manage a directory tree of `.sql` source files that were responsible for creating their respective tables, views, stored procedures, types, etc. but found that to be difficult because adding a column to a file with a `CREATE TABLE` statement doesn't help with the actual database migration, so you end up with duplicate (potentially stale) data definition language (DDL) files everywhere in addition to the actual migration scripts.
    
    These days I just write the migration script, run a schema dump using `pg_dump` after the script is applied to the database, and include both files in a new commit. The schema diff provide a nice readable record of the changes that are produced by the migration script and every graphical database management tool I've used provides the nice tree visualization of database objects via schema introspection.
- **parser-testing**: This repository is responsible for quantifying the performance of the Readup article metadata and content parser scripts. This is achieved by running the scripts against an article web page in a headless browser and comparing the results from the parsers to known correct results. This repository contains the source code for the testing scripts, the article web pages, and the data files that contain the known correct results for each web page. 

    Even though the article web page acquisition, data labelling, and testing procedures are all working and at least partially automated I have unfortunately not yet had time to build up a repository of test samples and work on improving the performance of the parsers. All this infrastructure makes parser improvements possible ([regression bugs](https://en.wikipedia.org/wiki/Software_regression) are all but guaranteed without it) but it's still a time-consuming task that is always competing with feature development work.

Before we conclude, let's zoom in one level further in our meta-repo analysis to the one inter-repo relationship that we haven't explored yet. The `BrowserExtensionApp` target within the `ios` repository is a port of the `browser-extension-app` app (or vise-versa). In addition, the `NSExtensionRequestHandling` class of the `SafariExtension` target is something of a semi-port of both. All this noise is there to support native messaging between the browser extensions and the Readup desktop apps.

## Browser Extension Native Messaging

The diagram below shows how native messaging between all four major browsers and the Readup client app is achieved on Windows, Linux, and macOS.

[![Browser Extension Native Messaging Chart](https://blog.readup.com/assets/2021/12/BrowserExtensionApp@2x.png)](https://blog.readup.com/assets/2021/12/BrowserExtensionApp@2x.png)

No matter what, we're going to have some duplicate logic going on due to the non-standard way that Safari communicates with native applications. Safari extensions are bundled with a macOS app as an App Extension and use the `NSExtensionRequestHandling` protocol to communicate with the host app. Chrome, Firefox, and Edge all support the standard [native messaging protocol](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging), with some minor exceptions.

The standard protocol uses standard input and output to communicate with a host application, which means that the Readup GUI client app is an unsuitable candidate for communicating directly with the browser extensions. Instead we use an intermediate CLI application that can relay messages between the browser extension and the GUI application.

The .NET Core CLI Host and the Swift CLI Host both implement the same protocol and perform the exact same functions. Theoretically the .NET Core CLI Host could also be built for macOS, but I have not yet explored what it would take to bundle and distribute a .NET Core CLI app with a sandboxed macOS app in the Mac App Store. Signing and bundling the Swift CLI app was difficult enough that I thought it would be easier to port the limited functionality instead of trying to include a macOS executable built from the .NET project.

Another peculiarity of this arrangement is the need to [P/Invoke](https://docs.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke) the `CreateProcess` function from the `kernel32.dll` Win32 library on Windows. This is required due to the fact that Firefox [puts the native application's process into a Job object](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging#closing_the_native_app), and kills the job once a response to the native message is received. This has the effect of also killing the GUI app if it was spawned as a result of the user invoking the browser extension, unless the `CREATE_BREAKAWAY_FROM_JOB` flag is used when creating a child process. Unfortunately that flag is not available via the managed `Process.Start` code, hence the P/Invoke.

Communication between the browser extension host CLI app and the Readup GUI app is currently implemented via a custom `readup://` scheme that is registered with the operating system. Since both Electron and Mac Catalyst support enforcing single instances of running apps, this makes it surprisingly easy to open the Readup app with the specified URL or effectively send a message to an already running instance. Bi-directional communication using this method would be tricky but might be possible since the GUI apps also know the locations of the CLI apps and have permission to execute them. Though if we ever require that functionality it might be preferable to implement more traditional [inter-process communication](https://en.wikipedia.org/wiki/Inter-process_communication) methods such as sockets or named pipes.

## Final Stop

That was a lot! I wouldn't say that we only scratched the surface, but diving into the browser extension native messaging a bit gives one an idea of just how deep each of these repo rabbit holes go. Each repository has lengthy `README`s of their own, documenting their own internal behavior and quirks.

As I sit here writing this, I've got a post-it on my monitor that reads "APNS Cert Dec 13th", reminding me to renew our Apple Push Notification Service certificate before that date. Doing so requires generating a certificate signing request, requesting a new certificate from Apple's App Store Connect interface, converting and bundling the certificate and key into a PKCS #12 container, uploading the container to the S3 bucket that contains the EC2 resources, importing the container into the certificate manager of the EC2 API servers, updating the API server configuration files to reference the thumbprint of the new certificate, and deploying new versions of the API server code.

More than half of those steps are only loosely documented in a text file on my computer that is not shared with anyone else, but hopefully at least some of that made sense after reading this post. The rest I'll be sure to document this time around and add to the mountain of documentation required to keep Readup running.