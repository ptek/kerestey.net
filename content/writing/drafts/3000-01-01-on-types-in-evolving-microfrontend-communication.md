---
title: On types in evolving microfrontend communication
author: Pavlo Kerestey
---

[A very insightful article on dev.to](https://dev.to/luistak/cross-micro-frontends-communication-30m3) discusses multiple ways for cross microfrontends communication. One interesting aspect that I'd like to add is the type safety of values passed between microfrontends as the application is being developed.

## The planning

When developing an application consisting of several microfrontends, the motivation is to give autonomy to the teams responsible for the different parts of the application. Dependencies between the microfrontends evolve, and the development usually has to be a coordinated undertaking. The way a company chooses to coordinate the development affects the implementation, and I have found several scenarios and how they possibly affect code.

## The setup

As an example, I'll discuss an application similar to the one in the article about cross microfrontend communication consisting of two microfrontends passing values from a _provider_ microfrontend to a _consumer_.

For the sake of the example, at the beginning of the development lifecycle, the provider passes a switch to the microfrontends indicating that the user is using a dark mode in their OS. This way, the microfrontends can adapt their styling accordingly. Future features are still being analyzed as the business figures out the right set of functionality. Until then, the application goes live with minimum content so that users get to know about it.

Usually, in the microfrontends, I would type the properties exactly as they are receiving it from the provider, i.e.: 

```typescript
{ dark: boolean }
```

The mechanism of receiving the value does not matter in this case.

After some time, the company figured out that users care very much about the responsiveness of their view. So they want to add size in pixels of the microfrontend for it to adapt.

## Sequential coordination

The company decides that the changes will be done sequentially:

- first, a new field is going to be added to the passed on properties in the provider. The new properties are, therefore:

	```typescript
	interface Properties { 
		dark: boolean;
		size: { width: number };
	}
	```

- the provider team needs to publish the new version of the application before the consumer teams can start adding the value to their dependencies and make their content adjustable
- now, the consumer microfrontends can add the property to their dependent properties, and use it to adjust the styles according to it. Accessing the width from properties can be done directly: `props.size.width`
- only when every consumer has deployed their adaptiveness can the provider also add resizing functionality to the website so that the application does not show different consumer microfrontends in a broken way

As a picture: 

```text
--------|-------------------------|--------------------|------------------|-> time
        v                         v                    v                  v
in the provider add    implement resizing      implement resizing  publish the resizing
size: {width: number}  in the consumer          in the provider     functionality
that doesn't change    microfrontends                               to production
```

_Pros:_

- the consumer microfrontends can rely on the fact that the value is always present 
- the type of the passed data can reflect the reality as seen in that point of time

_Cons:_

- the process takes a long time, and there is potential for improvement
- logic for dealing with fields that are optional, or missing, is often spread across the application

## Parallel coordination

The company figures out that they want to deploy faster and ask the developers of consumer microfrontends to work on the new feature right away, while the provider developers already start working on resizing the application in parallel.

The only decision the has been made: the type of the size property will be: `size: { width: number }`


```text
                   --------|-------------------------|-> time
                           v                         v   
                    implement resizing      publish the resizing
                   in the microfrontends    functionality
                                            to production
                    implement resizing
                     of the provider
```

Here, the consumer microfrontends can not rely on the fact that the value of size is available to them right away. The type they have to add to the properties will probably first look something like this:

```typescript
interface Properties { 
	dark: boolean;
	size: { width: number? }?;
}
```

The dark mode parameter is still accessed directly via `props.dark`. Since TypeScript 3.7, accessing width is just slightly more tedious: `props.size?.width`. The problem is rather that such access tends to be scattered around the codebase, often interspersed with the code for business logic. In those cases there are often no simple means of validating the value structure, or logging and reporting an error if the assumptions about the value are not met. We, the developers, usually resort to leaving the validation out completely at this point. Until the provider implements and publishes the resizing, the consumer microfrontends may break in unsuspected ways.

_Pros:_

- much faster delivery and less coordination effort

_Cons:_

- one needs to deal with the fact that new fields might not yet be available when application is published
- logic for dealing with new fields is scattered around the codebase

## Consistent approach for dealing with parallel coordination

The above are the types I have seen on most projects. Some fields in parameter data structures are apparently certainly available to the application, some might not be. And it often breaks in unexpected ways when the assumptions about the certain ones do not hold any more. 

I think there is a better way for representing the uncertainty about the changing data in time. It should consistently allow all the microfrontends to be developed in parallel without the fear of breakage.

In fact, a community of software developers has solved this problem since 1986 - more than 34 years ago. Their chosen language is erlang, and they develop highly distributed systems at scale, powering systems like WhatsApp. Their idea is always to make sure the completeness of the data received from outside of the application. In other words - never relying that all the fields are present and explicitly prepare for inconsistencies upfront.

The types will therefore look as follows:

```typescript
interface Properties { 
	dark: boolean;
	size: { width: number };
}

type RawProperties = Partial<Properties>;
```

And there are two stages for all the incoming data in the microfrontends:

1. [parse](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) the incoming data, fail fast at the edge of the application if the properties do not fulfill our expectations: `props = parse(rawProps)`
2. use the output of the parsed data as a verifiably correct structure: `props.size.width`

In fact, this approach has been used by us on my last project. We have relied on three questions for this approach:

* What if the data we rely upon is missing?
* What if the data received is not in the format we assumed?
* If the data can be optional, what is the default value that is used instead?

Explicitly dealing with these situations has helped us avoid many surprises way before the applications went into production. Additinally, all the logic naturally appeared in one place and was easy to look for and understand.

_Pros:_

- all the logic for dealing with uncertain data is in one place
- the uncertainty is explicitly dealt with upfront
- all the input data is dealt with in a consistent way

_Cons:_

- there is a runtime overhead for verifying that the input data fulfills all the assumptions
- more upfront thinking required

## Closing thoughts

There may be a way to reduce the overhead of parsing by creating a very fast (preferably linear or better) library to assert the right structure of data in ts.

For parsing types at runtime, there is the [io_ts](https://github.com/gcanti/io-ts) library. It might look quite intimidating at first, but I think it does a very good job at using long known constructs from functional programming and deal with errors properly using `Either`.

I would also like to mention that the idea of treating all properties as uncertain came from a conversation with Simon Zelazny. He has some good articles [on erlang](https://well-ironed.com/) and [other interesting development topics](https://pzel.name/).

Also, thanks for putting up with the ideas to the team I have been implementing these with. I would really like to learn if it stood the test of time.