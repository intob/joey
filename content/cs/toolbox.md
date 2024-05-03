---
title: Toolbox
status: DONE
description: "An almost enterprise-scale web-app with almost zero dependencies."
date: 2024-03-15
img: /img/cs/toolbox/status/
---
Swissinfo needed a web-qpp for a bunch of new APIs. Some of them more featured than others, such as a multi-lingual video hosting service.

I built the front-end using **only** Google's Lit library (abstraction around native Web Components).

I managed to avoid even a build process, thanks to importmap. The app only loads the necessary modules.

The app is only 175KB, no minification.

I wrote an 87-line hash-based router just for this app.

Both devs & users are very happy with it so far.

More to follow when I find time...