module NestedStructInitialiser
using Requires

export parameters, initialiser

struct Parameters
    type
    free
    fixed
end
free_param_length(::Type{<:Number}) = 1
free_param_length(::Any) = NaN
free_param_length(::Type{<:NTuple{N}}) where N = N
parameters(::Any; kwargs...) = nothing
function parameters(s::Type; kwargs...)
    free = []
    fixed = []
    for (i, f) in enumerate(fieldnames(s))
        if haskey(kwargs, f)
            val = kwargs[f]
            val === s && error("Value for field $f of $s is $val.")
            push!(fixed, f => val)
            fp = parameters(val; kwargs...)
            if fp !== nothing
                append!(free, fp.free)
                append!(fixed, fp.fixed)
            end
        else
            push!(free, f => fieldtype(s, i))
        end
    end
    Parameters(s, free, fixed)
end
function Base.show(io::IO, ::MIME"text/plain", p::Parameters)
    println(io, "$(p.type) Parameters")
    println(io, "Fixed")
    if length(p.fixed) == 0
        println(io, " none")
    end
    for (name, value) in p.fixed
        println(io, " $name = $value")
    end
    println(io, "Free")
    if length(p.free) == 0
        println(io, " none")
    end
    for (name, value) in p.free
        d = free_param_length(value)
        ds = isnan(d) ? "indeterminable dimensionality" : "$d dimensional"
        println(io, " $name: $ds")
    end
end



isleaf(::Number) = true
isleaf(::VecOrMat{<:Number}) = true
isleaf(::Any) = false
function free_param(::Type{<:Number}, x, k)
    k[] += 1
    :($x[$(k[]-1)])
end
function free_param(::Type{<:NTuple{N}}, x, k) where N
    k[] += N
    args = [:($x[$i]) for i in k[] - N:k[] - 1]
    :(tuple($(args...)))
end
function field_initialiser(name, type, x, k; kwargs...)
    if haskey(kwargs, name)
        val = kwargs[name]
        isleaf(val) && return val
        type_initialiser(val, x, k; kwargs...)
    else
        free_param(type, x, k)
    end
end
function type_initialiser(s, x, k; kwargs...)
    :($s($([field_initialiser(f, fieldtype(s, i), x, k; kwargs...)
            for (i, f) in enumerate(fieldnames(s))]...)))
end
function initialiser(s::Type; kwargs...)
    k = Ref(1)
    rhs = type_initialiser(s, :x, k; kwargs...)
    println("Number of Free Parameters: $(k[] - 1)")
    eval(:(x -> $rhs))
end
initialiser(p::Parameters) = initialiser(p.type; p.fixed...)

function __init__()
    @require StaticArrays = "90137ffa-7385-5640-81b9-e52037218182" begin
        function free_param(::Type{<:StaticArrays.SArray{S,T,N,L}}, x, k) where {S,T,N,L}
            k[] += L
            :(StaticArrays.SArray{S}(view($x, $(k[] - L:k[] - 1))))
        end
        free_param_length(::Type{<:StaticArrays.SArray{S,T,N,L}}) where {S,T,N,L} = L
    end
end

end # module
