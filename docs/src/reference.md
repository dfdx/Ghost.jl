```@meta
CurrentModule = Ghost
```

## Public API

### Tracing

```@docs
trace
is_primitive
call_signature
__new__
```

### Variables

```@docs
Variable
bound
rebind!
rebind_context!
```

### Tape structure

```@docs
Tape
AbstractOp
Input
Constant
Call
Loop
inputs
inputs!
mkcall
```

### Tape transformations

```@docs
push!
insert!
replace!
deleteat!
primitivize!
```

## Tape execution

```@docs
play!
compile
to_expr
```

### Loops

```@docs
should_trace_loops!
should_trace_loops
```

## Internal API

The following types and functions might be useful for better understanding of Ghost behavior, but are not part of the public API and may not hold backward compatibility guarantees.

```@docs
FunctionResolver
Frame
TracerOptions
_LoopEnd
record_or_recurse!
push_frame!
pop_frame!
enter_loop!
stop_loop_tracing!
exit_loop!
```

## Index

```@index
```