---
title: On types in evolving microfrontend communication
author: Pavlo Kerestey
---

[A very insightful article on dev.to](https://dev.to/luistak/cross-micro-frontends-communication-30m3) discusses multiple ways for cross microfrontends communication. One interesting aspect that I'd like to add is the type safety of values passed between microfrontends as the application is being developed.

## The planning

When developing an application consisting of several microfrontends, the motivation is to give autonomy to the teams responsible for the different parts of the application. Dependencies between the microfrontends evolve, and the development usually has to be a coordinated undertaking. The way a company chooses to coordinate the development affects the implementation, and I have found several scenarios and how they possibly affect code.

## The setup

For example, I describe an application similar to the article about cross microfrontend communication: 
**a container** responsible for loading and laying out all the microfrontends, and the **two microfrontends** that show actual content.

For the sake of the example, at the beginning of the development lifecycle, the container passes a switch to the microfrontends indicating that the user is using a dark mode in their OS. This way, the microfrontends can adapt their styling accordingly. Future features are still being analyzed as the business figures out the right set of functionality. Until then, the application goes live with minimum content so that users get to know about it.

Usually, in the microfrontends, I would type the properties exactly as they are receiving it from the container, i.e.: 

```typescript
{ dark: boolean }
```

The mechanism of receiving the value does not matter in this case.

After some time, the company figured out that users care very much about the responsiveness of their view. So they want to add size in pixels of the microfrontend for it to adapt.

## The sequential coordination

The company decides that the changes will be done sequentially:

- first, a new field is going to be added to the passed on properties in the container. The new parameters are, therefore:

	```typescript
	interface Parameters { 
		dark: boolean;
		size: { width: number };
	}
	```

- the container team needs to publish the new version of the application before the microfrontend teams can start adding the value to their dependencies and make their content adjustable
- now, the microfrontends can add the property to their dependent parameters, and use it to adjust the styles according to it
- only when every microfrontend has deployed their adaptiveness can the container also add resizing functionality to the website so that the application does not show different microfrontends in a broken way

As a picture: 

```text
--------|-------------------------|--------------------|------------------|-> time
        v                         v                    v                  v
in the container add   implement resizing      implement resizing  publish the resizing
size: {width: number}  in the microfrontends   in the container    functionality
that doesn't change                                                to production
```

_Pros:_

- the microfrontends can use the `size` value and not worry if it is passed or not
- the microfrontends can add the right type as actually seen in the passed parameters

_Cons:_

- the process takes a long time, and there is potential for improvement

## The parallel coordination

The company figures out that they want to deploy faster and ask the developers of microfrontends to work on the new feature right away, while the container developers already start working on resizing the application in parallel.

The only decision the has been made: the type of the size property will be: `size: { width: number }`


```text
                   --------|-------------------------|-> time
                           v                         v   
                    implement resizing      publish the resizing
                   in the microfrontends    functionality
                                            to production
                    implement resizing
                     of the container
```

Here, the microfrontends can not rely on the fact that the value of size is available to them right away. The type they have to add to the properties will probably first look something like this:

```typescript
interface Parameters { 
	dark: boolean;
	size: { width: number? }?;
}
```

Until the container implements and publishes the resizing, the microfrontends will have to check if the size is already available before adapting the content.

_Pros:_

- much faster delivery and less coordination effort

_Cons:_

- reduced coordination needs to be dealt with in the code by logic for null or undefined values
- the logic is possibly never removed as the application grows and the developers of different micfrofrontends move on to developing other features before the resizing is published

## Consistent approach for dealing with parallel coordination

The above are the types I have seen on most projects. Some fields in parameter data structures are apparently certainly available to the application, some might not be. And it often breaks in unexpected ways when the assumptions about the certain ones do not hold any more. 

I think there is a better way for representing the uncertainty about the changing data in time. It should consistently allow all the microfrontends to be developed in parallel without the fear of breakage.

In fact, a community of software developers has solved this problem since 1986 - more than 34 years ago. Their chosen language is erlang, and they develop highly distributed systems at scale, powering systems like WhatsApp. Their idea is always to make sure the completeness of the data received from outside of the application. In other words - never relying that all the fields are present and explicitly prepare for inconsistencies upfront.

There could be two stages for all the incoming data in the microfrontends:

1. wrapping the Parameters type with `Partial<Parameters>`
2. [parse](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) the incoming data, crash if the parameters do not fulfill our expectations
3. use the output of the parsed data as a verifiably correct structure.

We would therefore have the types as follows:

```typescript
interface Parameters { 
	dark: boolean;
	size: { width: number };
}

type RawParameters = Partial<Parameters>;
```

In fact, this approach has been used by us on my last project. We have relied on two questions for this approach:

1. What if the data we rely upon is missing?
2. What if the data received is not in the format we assumed?

Explicitly dealing with both situations in a consistent manner has helped us avoid many unpleasant surprises way before the applications went into production. Additinally, all the logic for dealing with this uncertainty was in one place and was easy to understand and look for.

_Pros:_

- we have therefore all the niceness of the sequential solution in our logic
- we treat all the data the same way

_Cons:_

- there is a small overhead connected with verifying that the input data fulfills all the necessary assumptions we have. I'd argue that we usually would verify the values regardless, somewhere later in the business logic.

## Additional thoughts

There may be a way to reduce the overhead of parsing by creating a very fast (preferably linear or better) library to assert the right structure of data in ts.

For parsing types at runtime, there is the [io_ts](https://github.com/gcanti/io-ts) library. It might look quite intimidating at first, but I think it does a very good job at using long known constructs from functional programming and deal with errors properly using `Either`.