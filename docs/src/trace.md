# Linearized traces

Usually, programs are executed as a sequence of nested function calls, e.g.:

```@example
foo(x) = 2x
bar(x, y) = foo(x) + 3y
baz(x, y) = bar(x, y) - 1

baz(1.0, 2.0)
```
Sometimes, however, it's more convenient to work with a linearized representation of the computation. Example use cases include collecting computational graphs for automatic differentiation, exporting to ONNX, serialization of functions to library-independent format, etc. [`trace()`](@ref) lets you obtain such a linearized representation:

```@example
foo(x) = 2x                # hide
bar(x, y) = foo(x) + 3y    # hide
baz(x, y) = bar(x, y) - 1  # hide

using Ghost

val, tape = trace(baz, 1.0, 2.0)
```

[`trace()`](@ref) returns two values - the result of the original function call and the generated tape. The structure of the tape is described in [Tape anatomy](@ref) section, here just note that [`trace()`](@ref) recursed into `baz()`, `bar()` and `foo()`, but recorded `+`, `-` and `*` onto the tape as is. This is because `+`, `-` and `*` are considered "primitives", i.e. the most basic operations which all other functions consist of. This behavior can be customized using one of the two keyword arguments:

* `primitives` - an iterable of functions to be considered primitive
* `is_primitive(sig)` - a function which takes a method call signature and returns `true` if this method must be considered primitive and `false` otherwise

Here's an example:

```@example
foo(x) = 2x                # hide
bar(x, y) = foo(x) + 3y    # hide
baz(x, y) = bar(x, y) - 1  # hide

using Ghost                # hide

val, tape = trace(baz, 1.0, 2.0; primitives=Set([+, -, *, foo]))
```

The default behavior is defined by [`Ghost.is_primitive`](@ref) function and can be extended e.g. like this:

```@example
foo(x) = 2x                # hide
bar(x, y) = foo(x) + 3y    # hide
baz(x, y) = bar(x, y) - 1  # hide

using Ghost                # hide


function custom_is_primitive(sig)
    return Ghost.is_primitive(sig) || sig == Tuple{typeof(foo), Float64}
end

val, tape = trace(baz, 1.0, 2.0; is_primitive=custom_is_primitive)
```

An easy way to get a valid call signature is to use [`Ghost.call_signature`](@ref).

See also [`Ghost.FunctionResolver`](@ref) for better understanding of the implementation of `is_primitive`.

In complex scenarios it may be useful to bring additional application-specific data together with a tape. For this purpose [`Tape`](@ref Ghost.Tape) is parametrized by a context type which is `Dict{Any, Any}` by default, but can be anything. A context object can be attached during tracing using the `ctx` keyword:

```@example
foo(x) = 2x                # hide
bar(x, y) = foo(x) + 3y    # hide
baz(x, y) = bar(x, y) - 1  # hide

using Ghost                # hide

mutable struct MyCtx
    a
    b
end

val, tape = trace(baz, 1.0, 2.0; ctx=MyCtx(0, 0))
```

The presense of the context doesn't affect tracing, but can be used during further tape processing. See [Tape context](@ref) for more details.