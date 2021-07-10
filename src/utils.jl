"""
    __new__(T, args...)

User-level version of the `new()` pseudofunction.
Can be used to construct most Julia types, including structs
without default constructors, closures, etc.
"""
@generated function __new__(T, args...)
    return Expr(:splatnew, :T, :args)
end


"Check if an object is of a struct type, i.e. not a number or array"
isstruct(::Type{T}) where T = !isempty(fieldnames(T))
isstruct(obj) = isstruct(typeof(obj))


if !isdefined(@__MODULE__, :__EXPRESSION_HASHES__)
    __EXPRESSION_HASHES__ = Set{AbstractString}()
end


function get_type_parameters(sig)
    if sig isa UnionAll
        return get_type_parameters(sig.body)
    elseif sig isa DataType
        return sig.parameters
    else
        error("Unsupported type: $sig")
    end
end


function map_type_parameters(fn, sig)
    if sig isa UnionAll
        new_body = map_type_parameters(fn, sig.body)
        return UnionAll(sig.var, new_body)
    elseif sig isa DataType
        params = sig.parameters
        return Tuple{fn(params)...}
    else
        error("Unsupported type: $sig")
    end
end


remove_first_parameter(sig) = map_type_parameters(ps -> ps[2:end], sig)
kwfunc_signature(sig) = map_type_parameters(sig) do ps
    F = ps[1]
    isabstracttype(F) && return []
    Ts = ps[2:end]
    kw_F = Core.kwftype(F)
    return [kw_F, Any, F, Ts...]
end