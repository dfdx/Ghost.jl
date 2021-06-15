```@meta
CurrentModule = Ghost
```

# Loops

By default, Ghost records all function calls as they are executed. If a particular function is executed several times inside of a loop, Ghost will record each execution separately:


```@example
using Ghost


function loop1(x, n)
    while n > 0
        x = 2x
        n = n - 1
    end
    return x
end

_, tape1 = trace(loop1, 2.0, 3)
```

Ghost also has experimental support for tracing loops as a special [`Loop`](@ref) operation which can be turned on using [`should_trace_loops!(true)`](@ref should_trace_loops!)

```@example
using Ghost
import Ghost: should_trace_loops!

should_trace_loops!(true)

function loop1(x, n)
    while n > 0
        x = 2x
        n = n - 1
    end
    return x
end

_, tape2 = trace(loop1, 2.0, 3)
```

Unlike fully static tape which always executes as many iterations as there were during the tracing, tape with loops follows the control flow of the original function:


```julia-repl
play!(tape1, loop1, 2.0, 3)  # ==> 16.0
play!(tape1, loop1, 2.0, 4)  # ==> 16.0
play!(tape1, loop1, 2.0, 5)  # ==> 16.0

play!(tape2, loop1, 2.0, 3)  # ==> 16.0
play!(tape2, loop1, 2.0, 4)  # ==> 32.0
play!(tape2, loop1, 2.0, 5)  # ==> 64.0
```

Note that [`Loop`](@ref) itself contains a subtape and is quite independent from the outer tape.

```julia
tape2[V(4)].subtape
```

```
Tape{Dict{Any, Any}}
  inp %1::Int64
  inp %2::Float64
  %3 = >(%1, 0)::Bool
  %4 = *(2, %2)::Float64
  %5 = -(%1, 1)::Int64
```

!!! warning

    To work correctly, [`Loop`](@ref) expects at least one full iteration during both - tracing and execution.