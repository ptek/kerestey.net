---
title: First impressions with Single-SPA
author: Pavlo Kerestey
---

Recently I have been using the [single-spa
framework](https://single-spa.js.org/) to create a dashboard where developers
can publish small bits of data visualization for the users of the page.

My impression after the first two months with it is that it still has some way
to go. Being quite good at solving the complex problem of making different
frameworks to interoperate as micro-frontends - the developers of single-spa,
have made some architectural choices that force me to write the code in a way
that is hard to reason about. They certainly had their reasons for it, and here
is what little I have found out.

### Problem we are trying to solve

The application I am currently working on is quite simple on the frontend, but
it involves a lot of data discovery behind the scenes - the numbers that the
users are seeing are quite complex to get. Hence, there is a need to parallelize
the process and cut it into small chunks for different teams to pick up.

The team I am part of decided to go with existing technology - single-spa
framework - and provide a frame for other developers to fill in. A
micro-frontend approach is something that comes naturally as a solution - we are
combining live stats from multiple domains onto one page.

### Technological context

On the code side, I am not quite sure how I feel about it. I have no other
micro-frontend frameworks to compare it to, but I often struggle with the way
single-spa integration works.

For example - the framework allows us to handle errors when calling its
functions but throws those errors asynchronously anyway without any entry point
to catch them. This has led us on a week-long journey to make it work and create
workarounds like global state variables indicating if everything is still ok
with the lifecycle of children elements, and a lot of if-then-else to control
the display of those elements on these toggles.

In another instance, it requires particular arguments to be passed to its
lifecycle functions (bootstrap, mount, unmount), but never actually checks for
their presence. It leads to breakage much later in the lifecycle, where
single-spa discovers that it can’t do what the developer asks it to do because
some error happened before.

### Conclusion

The framework solves an interoperability problem between micro-frontends being
written with multiple frameworks quite well. Doing that, it also, unfortunately,
hides a lot of issues that those micro-fronteds sometimes produce under the
carpet when I inevitably am making a mistake.

I prefer that errors appear as close to where they appear as possible, so I
don’t need to trace the root cause of my mistakes through the whole codebase.
And If I make a mistake, I’d like to be told about that in the application or my
automated tests before my code reaches production. Some things, though, are
quite difficult to test automatically in single-spa, so I am not very happy yet.

I will work with the framework further and hope to get a much more complete
overview of its merits. But for now, I am not sure if I would choose it again
for a new project.
