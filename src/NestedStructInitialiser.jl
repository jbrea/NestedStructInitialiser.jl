module NestedStructInitialiser
using RuntimeGeneratedFunctions
using Unitful
using StaticArrays
RuntimeGeneratedFunctions.init(@__MODULE__)

export parameters, initialiser

free_param_length(::Type{<:Number}) = 1
free_param_type(::Type{<:Number}) = true
free_param_length(::Any) = NaN
free_param_type(::Any) = false
free_param_length(::Type{<:NTuple{N}}) where N = N
free_param_type(::Type{<:NTuple}) = true

extendable(ft) = isconcretetype(ft) && !free_param_type(ft)
extendable(ft::Type{<:AbstractArray}) = false
extendable(ft::Type{<:Dict}) = false
extendable(ft::Type{<:Set}) = false

function extend!(free, fixed, val; kwargs...)
    fp = parameters(val; kwargs...)
    if fp !== nothing
        append!(free, fp.free)
        append!(fixed, fp.fixed)
    end
end

struct Parameters
    type
    free
    fixed
end
parameters(::Any; kwargs...) = nothing
function parameters(s::Type; kwargs...)
    free = []
    fixed = []
    for (i, f) in enumerate(fieldnames(s))
        if haskey(kwargs, f)
            val = kwargs[f]
            val === s && error("Value for field $f of $s is $val.")
            push!(fixed, f => val)
            extend!(free, fixed, val; kwargs...)
        else
            ft = fieldtype(s, i)
            if extendable(ft)
                extend!(free, fixed, ft; kwargs...)
            else
                push!(free, f => ft)
            end
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
        ds = isnan(d) ? " (indeterminable dimensionality)" : ""
        println(io, " $name: $value$ds")
    end
end

isleaf(::Number) = true
isleaf(::AbstractArray{<:Number}) = true
isleaf(::NTuple) = true
isleaf(f) = applicable(f)

function free_param(::Type{<:Number}, x, k)
    k[] += 1
    :($x[$(k[]-1)])
end
function free_param(::Type{<:NTuple{N}}, x, k) where N
    k[] += N
    args = [:($x[$i]) for i in k[] - N:k[] - 1]
    :(tuple($(args...)))
end
function free_param(::Type{<:StaticArrays.SArray{S,T,N,L}}, x, k) where {S,T,N,L}
    k[] += L
    :(StaticArrays.SArray{$S}(view($x, $(k[] - L:k[] - 1))))
end
free_param_length(::Type{<:StaticArrays.SArray{S,T,N,L}}) where {S,T,N,L} = L
free_param_type(::Type{<:StaticArrays.SArray}) = true
function free_param(t::Type{<:Unitful.Quantity{<:Number}}, x, k)
    k[] += 1
    :($t($x[$(k[]-1)]))
end

function field_initialiser(name, type, x, k; kwargs...)
    if haskey(kwargs, name)
        val = kwargs[name]
        isleaf(val) && return applicable(val) ? :($val()) : val
        type_initialiser(val, x, k; kwargs...)
    else
        if free_param_type(type)
            free_param(type, x, k)
        else
            type_initialiser(type, x, k; kwargs...)
        end
    end
end
function type_initialiser(s, x, k; kwargs...)
    :($s($([field_initialiser(f, fieldtype(s, i), x, k; kwargs...)
            for (i, f) in enumerate(fieldnames(s))]...)))
end
function initialiser(s::Type; silent = true, kwargs...)
    k = Ref(1)
    rhs = type_initialiser(s, :x, k; kwargs...)
    silent || println("Number of Free Parameters: $(k[] - 1)")
    @RuntimeGeneratedFunction(:(x -> $rhs))
end
initialiser(p::Parameters; silent = true) = initialiser(p.type; silent, p.fixed...)

end # module
