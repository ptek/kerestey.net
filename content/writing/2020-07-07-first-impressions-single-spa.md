---
title: First impressions with Single-SPA
author: Pavlo Kerestey
---

Recently I have been using the [single-spa
framework](https://single-spa.js.org/) to create a dashboard where developers
can publish small bits of data visualization on a page.

The decision for using micro-frontends in general, and single-spa in
particular, has happened long before I have joined the team, and we have more
than five other teams integrating with it - so the adoption has been broad.

Single-spa is good at solving the complex problem of interoperability with
different javascript frameworks as micro-frontends. It also has some
architectural choices forcing us to write code that is hard to reason about.

In short, I am not quite sure how I feel about it. I have no other
micro-frontend framework to compare it to, but I often struggle with the way
the integration works.

### Examples of issues we ran into

##### Unhandled Exception

We are using the `<Parcel/>` component from `single-spa-react` package to load
the widgets onto the dashboard.

We want to replace the widget with a user friendly error message when it
breaks at mounting. The `<Parcel/>` component allows us to handle such an
error in a following way:

```typescript
<Parcel
  config={parcelConfig}
  handleError={err => console.error(err)}
  ...
/>
```

however, single-spa still throws the error asynchronously on the window,
without any entry point to catch it.

A solution we came up with is wrapping it in a stateful component. We replace
the Parcel component in a switch-case logic whenever the handleError function
is called, toggling the widget to a broken state. Although it works, it seems
that it is more complicated than it should be.

On top of that, an error thrown on the `window` means that we can not
write an automated unit test for it. Jest unit tests are always broken with
an unhandled asynchronous exception. So we resort to testing it in a browser test.

The whole journey reminded me of the article by Raymond Chen from 2005:
["Cleaner, more elegant, and harder to
recognize."](https://devblogs.microsoft.com/oldnewthing/20050114-00/?p=36693)

##### Unchecked required props

In another instance, each of the lifecycle functions (bootstrap, mount, and
unmount) [requires a `name`
prop](https://single-spa.js.org/docs/building-applications/#lifecyle-props).
But single-spa does not check for the presence of it when the function is
called. 

When we create an entrypoint to an application with

```typescript
function mount(): {
  return singleSpa.mount(props);
}
```

our props did not contain the `name` property.

The application was mounted and shown properly on a page but did not get
removed when needed. Only after quite some research, we discovered that the
name prop was required. We suspect that it needs it for singleSpa to find our
application in its internal registry. Note to self: open a ticket for
improving the documentation on this one.

We are currently switching to using the single-spa parcel API directly,
effectively replacing the `single-spa-react/parcel` module for our needs.
Using low-level API allows us to be more granular.

### Conclusion

The framework solves a difficult interoperability problem between
micro-frontends written in multiple frameworks. It does so quite well. It
also, unfortunately, hides a lot of issues under the rug when I am inevitably
making a mistake.

I prefer that errors escalate as close to where they appear as possible, so I
don’t need to trace the root cause of my mistakes throughout the codebase. And
if I make a mistake, I’d like to be told about it via types or automated tests
before my code reaches production. However, I found that some things are quite
difficult to test in this framework.

After two months with it, my impression is that it still has some ways to go.
I will work with it longer and hope to get a much more complete overview of
its merits. But for now, I am not sure if I would start with it on a new
project right away.
