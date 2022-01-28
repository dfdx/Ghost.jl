"""
Base type for operations on a tape
"""
abstract type AbstractOp end

########################################################################
#                             VARIABLE                                 #
########################################################################

"""
Variable represents a reference to an operation on a tape.
Variables can be used to index tape or keep reference to
a specific operation on the tape.

Variables (also aliesed as `V`) can be:

* free, created as `V(id)` - used for indexing into tape
* bound, created as `V(op)`` - used to keep a robust reference
  to an operation on the tape
"""
mutable struct Variable
    _id::Union{<:Integer,Nothing}
    _op::Union{AbstractOp,Nothing}
    _hash::Union{UInt64, Nothing}
end

Variable(id::Integer) = Variable(id, nothing, nothing)
Variable(op::AbstractOp) = Variable(nothing, op, nothing)

Base.show(io::IO, v::Variable) = print(io, "%$(v.id)")


function Base.getproperty(v::Variable, p::Symbol)
    if p == :id
        if v._op !== nothing
            # variable bound to a specific operation on a tapea
            return v._op.id
        else
            # free variable with only ID
            return v._id
        end
    else
        return getfield(v, p)
    end
end

function Base.setproperty!(v::Variable, p::Symbol, x)
    if p == :id
        if v._op !== nothing
            # variable bound to a specific operation on a tapea
            v._op.id = x
        else
            # free variable with only ID
            v.id = x
        end
    else
        return setfield!(v, p, x)
    end
end


function Base.:(==)(v1::Variable, v2::Variable)
    # variables are equal if:
    # * both are bound to the same operation, or
    # * both are unbound and their IDs are equal
    return v1._op === v2._op && v1.id == v2.id
end

function Base.hash(v::Variable, h::UInt)
    if isnothing(v._hash)
        h = hash(v.id, hash(v._op, h))
        v._hash = h
    end
    return v._hash
end


const V = Variable



########################################################################
#                            OPERATIONS                                #
########################################################################

function Base.getproperty(op::AbstractOp, f::Symbol)
    if f == :typ
        return typeof(op.val)
    elseif f == :var
        return Variable(nothing, op)
    else
        getfield(op, f)
    end
end

## Input

"Operation representing input data of a tape"
mutable struct Input <: AbstractOp
    id::Int
    val::Any
    tape
end

Input(val::Any) = Input(0, val, nothing)

Base.show(io::IO, op::Input) = print(io, "inp %$(op.id)::$(op.typ)")


## Constant

"Operation representing a constant value on a tape"
mutable struct Constant <: AbstractOp
    id::Int
    typ::Type
    val
    tape
end


Constant(id::Int, val) = Constant(id, typeof(val), val, nothing)
Constant(val) = Constant(0, typeof(val), val, nothing)
Base.show(io::IO, op::Constant) = print(io, "const %$(op.id) = $(op.val)::$(op.typ)")


## Call

"""
Operation represening function call on tape. Typically, calls
are constructed using [`mkcall`](@ref) function.

Important fields of a Call{T}:

* `fn::T` - function or object to be called
* `args::Vector` - vector of variables or values used as arguments
* `val::Any` - the result of the function call
"""
mutable struct Call{T} <: AbstractOp
    id::Int
    val::Any
    fn::T
    args::Vector{Any}   # vector of Variables or const values
    tape
end
Call(id, val, fn::T, args) where T = Call{T}(id, val, fn, args, nothing)

pretty_type_name(T) = string(T)
pretty_type_name(T::Type{<:Broadcast.Broadcasted}) = "Broadcasted{}"

function Base.show(io::IO, op::Call)
    arg_str = join(["$v" for v in op.args], ", ")
    typ_str = pretty_type_name(op.typ)
    print(io, "%$(op.id) = $(op.fn)($arg_str)::$typ_str")
end


"""
Helper function to map a function only to Variable arguments of a Call
leaving constant values as is
"""
function map_vars(fn::Function, args::Union{Vector,Tuple})
    return map(v -> v isa Variable ? fn(v) : v, args)
end


"""
    mkcall(fn, args...; val=missing)

Convenient constructor for Call operation. If val is `missing` (default)
and call value can be calculated from (bound) variables and constants,
they are calculated. To prevent this behavior, set val to some neutral value.
"""
function mkcall(fn, args...; val=missing)
    fargs = (fn, args...)
    calculable = all(
        a -> !isa(a, Variable) ||                      # not variable
        (a._op !== nothing && a._op.val !== missing),  # bound variable
        fargs
    )
    if val === missing && calculable
        fargs_ = map_vars(v -> v._op.val, fargs)
        fn_, args_ = fargs_[1], fargs_[2:end]
        val_ = fn_(args_...)
    else
        val_ = val
    end
    return Call(0, val_, fn, [args...])
end


########################################################################
#                                 TAPE                                 #
########################################################################

"""
Linearized representation of a function execution.

Fields
======

* `ops` - vector of operations on the tape
* `result` - variable pointing to the operation to be used as the result
* `parent` - parent tape if any
* `meta` - internal metadata
* `c` - application-specific context
"""
mutable struct Tape{C}
    # linearized execution graph
    ops::Vector{<:AbstractOp}
    # result variable
    result::Variable
    # for subtapes - parent tape
    parent::Union{Tape,Nothing}
    # tape metadata (depends on the context)
    meta::Dict
    # application-specific context
    c::C
end

Tape(c::C) where C = Tape(AbstractOp[], Variable(0), nothing, Dict(), c)
# by default context is just a Dict{Any, Any}
Tape() = Tape(Dict{Any,Any}())


function Base.show(io::IO, tape::Tape{C}) where C
    println(io, "Tape{$C}")
    for op in tape.ops
        println(io, "  $op")
    end
end


function Base.getproperty(tape::Tape, p::Symbol)
    if p == :retval
        return tape[tape.result].val
    else
        return getfield(tape, p)
    end
end

"Get list of a tape input variables"
inputs(tape::Tape) = [V(op) for op in tape.ops if op isa Input]

"Set values of a tape inputs"
function inputs!(tape::Tape, vals...)
    @assert(isempty(tape) || length(inputs(tape)) == length(vals) || get(tape.meta, :isva, false),
            "This tape contains $(length(inputs(tape))) inputs, but " *
            "$(length(vals)) value(s) were provided")
    if isempty(tape)
        # initialize inputs
        for val in vals
            push!(tape, Input(val))
        end
    else
        # rewrite input values
        if get(tape.meta, :isva, false)
            # group varargs into a single tuple
            nargs = length(inputs(tape))
            vals = (vals[1:nargs - 1]..., vals[nargs:end])
        end
        for (i, val) in enumerate(vals)
            tape[V(i)].val = val
        end
    end
    return [V(op) for op in tape.ops[1:length(vals)]]
end

Base.getindex(tape::Tape, v::Variable) = tape.ops[v.id]

function Base.setindex!(tape::Tape, op::AbstractOp, v::Variable)
    op.id = v.id
    tape.ops[v.id] = op
    v._op = op   # bind to op, overriding v.id
end

Base.lastindex(tape::Tape) = lastindex(tape.ops)
Base.length(tape::Tape) = length(tape.ops)
Base.iterate(tape::Tape) = iterate(tape.ops)       # exclude inputs?
Base.iterate(tape::Tape, s) = iterate(tape.ops, s)


"""
    push!(tape::Tape, op::AbstractOp)

Push a new operation to the end of the tape.
"""
function Base.push!(tape::Tape, op::AbstractOp)
    new_id = length(tape) + 1
    op.id = new_id
    op.tape = tape
    push!(tape.ops, op)
    return V(op)
end


"""
    insert!(tape::Tape, idx::Integer, ops::AbstractOp...)

Insert new operations into tape starting from position idx.
"""
function Base.insert!(tape::Tape, idx::Integer, ops::AbstractOp...)
    num_new_ops = length(ops)
    old_ops = tape.ops
    new_ops = Vector{AbstractOp}(undef, length(tape) + num_new_ops)
    # copy old ops before insertion point
    for i = 1:idx - 1
        new_ops[i] = old_ops[i]
    end
    # insert target ops, assign ids
    for i = 1:num_new_ops
        id = idx + i - 1
        new_ops[id] = ops[i]
        new_ops[id].id = id
    end
    # insert the rest of old ops
    for i = idx:length(old_ops)
        id = i + num_new_ops
        new_ops[id] = old_ops[i]
        new_ops[id].id = id
    end
    tape.ops = new_ops
    return [V(op) for op in ops]
end


"""
    replace!(tape, op  => new_ops; rebind_to=length(new_ops), old_new=Dict())

Replace specified operation with 1 or more other operations,
rebind variables in the reminder of the tape to ops[rebind_to].

Operation can be specified directly, by a variable or by ID.
"""
function Base.replace!(tape::Tape, idx_ops::Pair{<:Integer,<:Union{Tuple,Vector}};
                       rebind_to=length(idx_ops[2]), old_new=Dict{Int,Int}())
    idx, ops = idx_ops
    tape[V(idx)] = ops[1]
    if idx < length(tape)
        insert!(tape, idx + 1, ops[2:end]...)
    else
        for op in ops[2:end]
            push!(tape, op)
        end
    end

    st = merge(old_new, Dict(idx => ops[rebind_to].id))
    rebind!(tape, st; from=idx + length(ops))
    return V(ops[rebind_to])
end


Base.replace!(
    tape::Tape,
    idx_ops::Pair{Variable, <:Union{Tuple,Vector}};
    kwargs...) = replace!(tape, idx_ops[1].id => idx_ops[2]; kwargs...)

Base.replace!(
        tape::Tape,
        idx_ops::Pair{<:AbstractOp, <:Union{Tuple,Vector}};
        kwargs...) = replace!(tape, idx_ops[1].id => idx_ops[2]; kwargs...)

"""
    deleteat!(tape::Tape, idx; rebind_to = nothing)

Remove `tape[V(idx)]` from the `tape`.
If `rebind_to` is not `nothing`, then
replace all references to `V(idx)` with `V(rebind_to)`.

`idx` may be an index or `Variable`/`AbstractOp` directly.
"""
function Base.deleteat!(tape::Tape, idx::Integer; rebind_to = nothing)
    # delete and rebind
    deleteat!(tape.ops, idx)
    isnothing(rebind_to) || rebind!(tape, Dict(idx => rebind_to))

    # shift indices for outputs up
    for i in idx:length(tape)
        tape.ops[i].id -= 1
    end

    return tape
end
Base.deleteat!(tape::Tape, idx::Variable; kwargs...) =
    deleteat!(tape, idx.id; kwargs...)
Base.deleteat!(tape::Tape, idx::AbstractOp; kwargs...) =
    deleteat!(tape, idx.id; kwargs...)

########################################################################
#                       SPECIAL OPERATIONS                             #
########################################################################

## Loop

"""
Operation representing a loop in an computational graph.
See the online documentation for details.
"""
mutable struct Loop <: AbstractOp
    id::Int
    parent_inputs::Vector{Variable}
    condition::Variable
    cont_vars::Vector{Variable}
    exit_vars::Vector{Variable}
    subtape::Tape
    val::Any
    tape
end

Loop(id, parent_inputs, condition, cont_vars, exit_vars, subtape, val) =
    Loop(id, parent_inputs, condition, cont_vars, exit_vars, subtape, val, nothing)

function Base.show(io::IO, loop::Loop)
    input_str = join(map(string, loop.parent_inputs), ", ")
    print(io, "%$(loop.id) = Loop($input_str)")
end

###############################################################################
#                                 REBIND                                      #
###############################################################################

"""Returned version of the var bound to the tape op"""
bound(tape::Tape, v::Variable) = Variable(tape[v])


"""
    rebind!(tape::Tape, op, st::Dict)
    rebind!(tape::Tape, st::Dict; from, to)

Rebind all variables according to substitution table. Example:

    tape = Tape()
    v1, v2 = inputs!(tape, nothing, 3.0, 5.0)
    v3 = push!(tape, mkcall(*, v1, 2))
    st = Dict(v1.id => v2.id)
    rebind!(tape, st)
    @assert tape[v3].args[1].id == v2.id

See also: rebind_context!()
"""
function rebind!(tape::Tape, v::Variable, st::Dict)
    if haskey(st, v.id)
        # rebind to a new op
        v._op = tape[V(st[v.id])]
end
end

rebind!(::Tape, ::Input, ::Dict) = ()
rebind!(::Tape, ::Constant, ::Dict) = ()

function rebind!(tape::Tape, op::Call, st::Dict)
    for v in op.args
        if v isa Variable
            rebind!(tape, v, st)
        end
    end
    return op
end


"""
    rebind_context!(tape::Tape, st::Dict)

Rebind variables in the tape's context according to substitution table.
By default does nothing, but can be overwitten for specific Tape{C}
"""
rebind_context!(tape::Tape, st::Dict) = ()


function rebind!(tape::Tape, st::Dict; from=1, to=length(tape))
    for id = from:to
        rebind!(tape, tape[V(id)], st)
    end
    rebind!(tape, tape.result, st)
    rebind_context!(tape, st)
    return tape
end


########################################################################
#                              EXECUTION                               #
########################################################################

exec!(::Tape, ::Input) = ()
exec!(::Tape, ::Constant) = ()

function exec!(tape::Tape, op::Call)
    fn = op.fn isa V ? tape[op.fn].val : op.fn
    arg_vals = map_vars(v -> tape[v].val, op.args)
    op.val = fn(arg_vals...)
end


"""
Collect variables which will be used at loop exit if it happens
at this point on tape.
"""
function loop_exit_vars_at_point(op::Loop, id::Int)
    input_vars = inputs(op.subtape)
    exit_idxs = findall(v -> v in op.exit_vars, op.cont_vars)
    vars = Vector{Variable}(undef, length(exit_idxs))
    for (i, idx) in enumerate(exit_idxs)
        if id > op.cont_vars[idx].id
            # if condition is checked after this continue var is changed,
            # use continue var
            vars[i] = op.cont_vars[idx]
        else
            # otherwise use input var
            vars[i] = input_vars[idx]
        end
    end
    return vars
end


function exec!(tape::Tape, op::Loop)
    subtape = op.subtape
    # initialize inputs
    inputs!(subtape, [tape[v].val for v in op.parent_inputs]...)
    # run the loop strictly while continue condition is true
    # note that subtape execution may finish before the full
    # iteration is done
    cond_var = op.condition
    vi0 = length(op.parent_inputs) + 1
    vi = vi0
    while true
        # @show vi
        # @show subtape[V(1)].val
        # @show subtape[V(2)].val
        # @show subtape[V(7)].val
        # sleep(1)
        exec!(subtape, subtape[V(vi)])
        if vi == cond_var.id && subtape[V(vi)].val == false
            actual_exit_vars = loop_exit_vars_at_point(op, vi)
            op.val = ([v._op.val for v in actual_exit_vars]...,)
            break
        end
        vi += 1
        if vi > length(subtape)
            vi = vi0
            inputs!(subtape, [subtape[v].val for v in op.cont_vars]...)
        end
    end
    # # exit_var is special - it's a tuple combining all the exit variables
    # # since it doesn't exist in the original code, it may be not executed
    # # by loop logic at the last iteration; hence, we execute it manually
    # exec!(subtape, subtape[op.exit_var])
    # op.val = subtape[op.exit_var].val
end


"""
    play!(tape::Tape, args...; debug=false)

Execute operations on the tape one by one.
If `debug=true`, print each operation before execution.
"""
function play!(tape::Tape, args...; debug=false)
    # for (i, val) in enumerate(args)
    #     @assert(tape[V(i)] isa Input, "More arguments than the original function had")
    #     tape[V(i)].val = val
    # end
    inputs!(tape, args...)
    for op in tape
        if debug
            println(op)
        end
        exec!(tape, op)
    end
    return tape[tape.result].val
end


########################################################################
#                                 UTILS                                #
########################################################################

"""
    call_signature(fn, args...)
    call_signature(tape::Tape, op::Call)

Get a signature of a function call. The obtain signature is suitable
for `is_primitive(sig)`.
"""
function call_signature(tape::Tape, op::Call)
    farg_vals = map_vars(v -> tape[v].val, [op.fn, op.args...])
    return Tuple{map(typeof, farg_vals)...}
end

function call_signature(fn, args...)
    return Tuple{map(typeof, (fn, args...))...}
end


"""
    primitivize!(tape::Tape; is_primitive=is_primitive)

Trace non-primitive function calls on a tape and decompose them
into a list of corresponding primitive calls.

# Example

    f(x) = 2x - 1
    g(x) = f(x) + 5

    tape = Tape()
    _, x = inputs!(tape, g, 3.0)
    y = push!(tape, mkcall(f, x))
    z = push!(tape, mkcall(+, y, 5))
    tape.result = z

    primitivize!(tape)

    # output

    Tape{Dict{Any, Any}}
      inp %1::typeof(g)
      inp %2::Float64
      %3 = *(2, %2)::Float64
      %4 = -(%3, 1)::Float64
      %5 = +(%4, 5)::Float64
"""
function primitivize!(tape::Tape, op::AbstractOp)
    id = op.id
    fn = op.fn isa V ? tape[op.fn].val : op.fn
    args = map_vars(a -> tape[a].val, op.args)
    _, sub = trace(fn, args...)

    new_ops = sub.ops[length(inputs(sub))+1:end]
    old_new = Dict{Int, Int}()
    for (i, v) in enumerate((op.fn, op.args...))
        if v isa V
            old_new[i] = v.id
        end
    end
    replace!(tape, id => new_ops, old_new=old_new)
    # note: not touching the context since replacement
    # may be ambiguous for it
end


function primitivize!(tape::Tape; is_primitive=is_primitive)
    # note: referencing concrete operations on the original tape
    # they will stay the same even when we modify the tape
    vars = [V(op) for op in tape]
    for v in vars
        op = tape[v]
        if op isa Call && !is_primitive(call_signature(tape, op))
            primitivize!(tape, op)
        end
    end
end