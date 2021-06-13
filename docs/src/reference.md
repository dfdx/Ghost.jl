```@meta
CurrentModule = Ghost
```

## Public API

### Tracing

```@docs
trace
is_primitive
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
```

## Index

```@index
```