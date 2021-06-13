# Tape anatomy

```@meta
CurrentModule = Ghost
```

## Operations

The very core of every tape is a list of operations. Let's take a look at one particular tape:

```@example
using Ghost

foo(x) = 2x + 1
_, tape = trace(foo, 2.0)
print(tape)
```
Each indented line in this output represents an operation. The first 2 designate the tape inputs and have type [`Input`](@ref). Note that the traced function itself is also recorded as an input and can be referenced from other operations on the tape, which is a typical case in closures and other callable objects. We can set new inputs to the tape as `inputs!(tape, foo, 3.0)`.

Operations 3 and 4 represent function calls and have type [`Call`](@ref Ghost.Call). For example, the notation `%4 = +(%3, 1)` means that variable `%4` is equal to the addition of variable `%3` and a constant `1` (we will talk about variables in a minute). The easiest way to construct this operation is by using [`mkcall`](@ref).

Although constants can be used directly inside `Call`s, sometimes we need them as separate objects on the tape. [`Constant`](@ref) operation serves exactly this role.

Finally, there's an experimental [`Loop`](@ref) operation which presents whole loops in a computational graphs and contain their own subtapes.

## Variables

[`Variable`](@ref) (also aliased as just `V`) is a reference to  an operation on tape. Variables can be bound or unbound.

Unbound variables are constructed as `V(id)` and point to an operation by its _position_ on a tape. Their primary use is for indexing and short-living handling, e.g.:

```@example
using Ghost                 # hide
import Ghost.V
foo(x) = 2x + 1             # hide
_, tape = trace(foo, 2.0)   # hide

op = tape[V(4)]
```

On the contrary, bound variables (created as `V(op)`) point to a _specific operation_ on the tape. Even if the tape is modified, the reference is preserved. Here's an illustrative example:

```@example
using Ghost                 # hide
import Ghost: V, Constant   # hide
foo(x) = 2x + 1             # hide
_, tape = trace(foo, 2.0)   # hide

vu = V(4)         # unbound
vb = V(tape[vu])  # bound, can also be created as `bound(tape, vu)`

# insert a dummy operation
insert!(tape, 3, Constant(42))
println(tape)
println("Unbound variable is still $vu")
println("Bound variable is now $vb")
```

Most functions in Ghost create bound variables to make them resistant to transformations. Note, for example, how in the tape above the last operation automatically updated itself from `+(%3, 1)` to `+(%4, 1)`. Yet sometimes explicit rebinding is neccessary, in which case [`rebind!`](@ref) can be used. Note that for [`rebind!`](@ref) to work properly with a user-defined tape context (see below), one must also implement [`rebind_context!`](@ref)


## Transformations

Tapes can be modified in a variaty of ways. For this set of examples, we won't trace any function, but instead construct a tape manually:


```@example
using Ghost
import Ghost: V, inputs!, mkcall

tape = Tape()
# record inputs, using nothing instead of a function argument
v1, v2, v3 = inputs!(tape, nothing, 1.0, 2.0)
```

[`push!`](@ref) is the standard way to add new operations to the tape, e.g.:


```@example
using Ghost                             # hide
import Ghost: V, inputs!, mkcall        # hide
tape = Tape()                           # hide
v1, v2, v3 = inputs!(tape, nothing, 1.0, 2.0)  # hide

v4 = push!(tape, mkcall(*, v2, v3))
println(tape)
```

[`insert!`](@ref) is similar to `push!`, but adds operation to the specified position:


```@example
using Ghost                             # hide
import Ghost: V, inputs!, mkcall        # hide
tape = Tape()                           # hide
v1, v2, v3 = inputs!(tape, nothing, 1.0, 2.0)  # hide
v4 = push!(tape, mkcall(*, v2, v3))     # hide

v5 = insert!(tape, 4, mkcall(-, v2, 1))  # inserted before v4
println(tape)
```

[`replace!`](@ref) is useful when you need to replace an operation with one or more other operations.

```@example
using Ghost                             # hide
import Ghost: V, inputs!, mkcall        # hide
tape = Tape()                           # hide
v1, v2, v3 = inputs!(tape, nothing, 1.0, 2.0)  # hide
v4 = push!(tape, mkcall(*, v2, v3))      # hide
v5 = insert!(tape, 4, mkcall(-, v2, 1))  # hide

new_op1 = mkcall(/, V(2), 2)
new_op2 = mkcall(+, V(new_op1), 1)
replace!(tape, 4 => [new_op1, new_op2]; rebind_to=2)
println(tape)
```

## Tape execution & compilation

There are 2 ways to execute a tape. For debug purposes it's easiest to run [`play!`](@ref):

```@example
using Ghost
import Ghost: play!

foo(x) = 2x + 1
_, tape = trace(foo, 2.0)

play!(tape, foo, 3.0)
```

[`compile`](@ref) turns the tape into a normal Julia function (subject to the [World Age restriction](https://discourse.julialang.org/t/how-to-bypass-the-world-age-problem/7012)):


```@example
using Ghost
import Ghost: compile

foo(x) = 2x + 1
_, tape = trace(foo, 2.0)

foo2 = compile(tape)
foo2(foo, 3.0)   # note: providing the original `foo` as the 1st argument
```
It's possible to see what exactly is being compiled using [`to_expr`](@ref) function.


## Tape context