---
title: Serializing kotlin sealed classes (algebraic datatypes) to JSON
author: Pavlo Kerestey
---

At my current project, I am trying to discover how to represent [algebraic
datatypes][1] in Kotlin. The reason I'd like to use them is the ability to
exhaustively specify all the cases of a thing that I care about.

So, across the internet, people suggest using [sealed classes for this
purpose][2]. This structure allows the typechecker to tell me if I have
forgotten to handle some case deep down in the code.

Eventually, I need to communicate with the outside world using JSON and it took
some time to understand how to serialise a sealed class with objects in it. The
problem is, that the inner objects represent both a type, and a constructor of
that type, but they are not values that can be written in JSON.

Using ideas from a [StackOverflow answer][3], I have come up with this trick to
help Jackson do the right thing:

    import com.fasterxml.jackson.annotation.JsonGetter
    
    sealed class Fruit {
        object Orange : Fruit()
        object Apple : Fruit()
        object Apricot : Fruit()
    
        @JsonGetter(“Fruit”)
        fun serialize(): String? = this::class.simpleName
    }

If we now want to serialise an `Orange` into JSON,
`jsonMapper.writeValueAsString(Fruit.Orange)` will produce something like this:

    { “Fruit”: “Orange” }

The reason it works in my understanding, is that every object in `Fruit`
inherits the `serialize()` function and the `@JsonGetter` too. So
`Fruit.Orange.serialize()` will be `"Orange"`

[1]: https://en.wikipedia.org/wiki/Algebraic_data_type
[2]: http://engineering.pivotal.io/post/algebraic-data-types-in-kotlin/
[3]: https://stackoverflow.com/a/54423515
