# NestedStructInitialiser.jl
![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)<!--
![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![Lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg) -->
[![Build Status](https://travis-ci.com/jbrea/NestedStructInitialiser.jl.svg?branch=master)](https://travis-ci.com/jbrea/NestedStructInitialiser.jl)
[![codecov.io](http://codecov.io/github/jbrea/NestedStructInitialiser.jl/coverage.svg?branch=master)](http://codecov.io/github/jbrea/NestedStructInitialiser.jl?branch=master)
<!--
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://jbrea.github.io/NestedStructInitialiser.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://jbrea.github.io/NestedStructInitialiser.jl/dev)
-->

`NestedStructInitialiser` exports two functions: `parameters` helps to explore
nested structures and `initialiser` creates efficient constructors for nested
structures.

```julia
julia> using NestedStructInitialiser, StaticArrays, Unitful
julia> struct A{N}
        b
        c
        t::NTuple{N, Float64}
    end
julia> struct B{T}
        m::T
        n::Float64
        o::Int
    end
julia> struct C{N}
        x::SVector{N, Float64}
    end

julia> p = parameters(A)
A Parameters
Fixed
 none
Free
 b: Any (indeterminable dimensionality)
 c: Any (indeterminable dimensionality)
 t: Tuple{Vararg{Float64,N}} where N (indeterminable dimensionality)

julia> p = parameters(A{2}, b = B{typeof(1.0u"s")}, c = C{2}, o = 42, n = () -> rand())
A{2} Parameters
Fixed
 b = B{Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}}
 n = #9
 o = 42
 c = C{2}
Free
 m: Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}
 x: SArray{Tuple{2},Float64,1,2}
 t: Tuple{Float64,Float64}

julia> constructor = initialiser(p)

julia> constructor([1, 2, 3, 4, 5])
A{2}(B{Quantity{Float64,𝐓,Unitful.FreeUnits{(s,),𝐓,nothing}}}(1.0 s, 0.5556739449879704, 42), C{2}([2.0, 3.0]), (4.0, 5.0))
```

## Motivation

When we simulate complex phenomena, we have usually multiple options
to approximate certain aspects. For example, in simulations of trajectories of
tennis balls we can approximate the ball as a point mass, a rigid ball or
an elastic ball, and we have multiple choices for how the ball interacts with
the air and the court. Each approximation depends on some parameters, like the
mass of the ball, its radius or some drag coefficients. Some of these parameters
are well known or easy to measure; others we may want to determine indirectly by
comparing simulations with measurements. For example, the mass and radius of a
ball are easy to measure, but we may want to find drag coefficients by comparing
simulated trajectories with measured trajectories. To achieve this we can run
an optimisation method that runs the simulator with different values for the
free parameters until simulations and measurements match.

Nested structures are convenient to express choices (see example below).
This package provides the function `parameters` to inspect the parameters
of nested structures and the function `initialiser` to get an efficient
constructor for nested structures that can be used in optimisation.
More specifically, we can tell the `initialiser` all the known parameters
and it returns a function that takes as input a vector with length equal to the
number of free parameters and outputs the nested structure.
The number of free parameters is currently determined in the following way:
for fields of subtype `Number`: 1, for fields of subtype `NTuple{N}`: `N`
and for fields of subtype `SArray{S}`: `prod(S)`.

## Example

Here are some structures that we may want to define in a tennis simulator.

```julia
using StaticArrays, Unitful

struct Simulator{A,B,C}
    air::A
    ball::B
    court::C
end

# Air
struct Vacuum end
struct SimpleDrag
    ρ::Float64
end
struct WithMagnusEffect
    ρ::Float64
end

# Balls
struct PointMass{U}
    mass::U
end
struct RigidBall{S}
    surface::S
    radius::Float64
    mass::Float64
end
struct ElasticBall{S,E}
    surface::S
    elasticity::E
    radius::Float64
    mass::Float64
end

# Surfaces
struct SimpleSurface end
struct FeltSurface
    drag_coefficient::Float64
end

# Elasticity
struct LinearIsotropic
    k::Float64
end
struct StiffnessTensor
    C::SMatrix{6, 6, Float64, 36}
end

# Court
struct ClayCourt{N}
    some_parameters::NTuple{N, Float64}
end
struct GrassCourt
    grass_length::Float64
end
```

Let us inspect the parameters of this simulator with the function `parameters`.
```julia
julia> using NestedStructInitialiser

julia> parameters(Simulator)
Simulator Parameters
Fixed
 none
Free
 air: Any (indeterminable dimensionality)
 ball: Any (indeterminable dimensionality)
 court: Any (indeterminable dimensionality)
```

Let us now fix some of the free parameters (in a not so meaningful, but hopefully
instructive way). Note that we define the units in which the mass of the ball is measured
and the dimensionality of `some_parameters` in the respective type parameters.
```
julia> p = parameters(Simulator, air = SimpleDrag, ball = PointMass{typeof(1.0u"kg")}, ρ = () -> rand(), court = ClayCourt{3})
Simulator Parameters
Fixed
 air = SimpleDrag
 ρ = #9
 ball = PointMass{Quantity{Float64,𝐌,Unitful.FreeUnits{(kg,),𝐌,nothing}}}
 court = ClayCourt{3}
Free
 mass: Quantity{Float64,𝐌,Unitful.FreeUnits{(kg,),𝐌,nothing}}
 some_parameters: Tuple{Float64,Float64,Float64}
```
The "fixed" value for `ρ` is a function without arguments, which is evaluated
every time the constructor is called. This can be useful, when you want to
initialise a state variable with an array, e.g. `() -> zeros(10)`.

Let us now use the `initialiser` function to get a constructor that takes
a 4-dimensional vector as input and returns the initialised nested structure.
```julia
julia> c = initialiser(p)
Number of Free Parameters: 4
#35 (generic function with 1 method)

julia> c([1, 2, 3, 4])
Simulator{SimpleDrag,PointMass{Quantity{Float64,𝐌,Unitful.FreeUnits{(kg,),𝐌,nothing}}},ClayCourt{3}}(SimpleDrag(0.5521639102892784), PointMass{Quantity{Float64,𝐌,Unitful.FreeUnits{(kg,),𝐌,nothing}}}(1.0 kg), ClayCourt{3}((2.0, 3.0, 4.0)))
```

We could have also called the `initialiser` directly with the known parameters
to get the same function as above.
```julia
julia> c = initialiser(Simulator, air = SimpleDrag, ball = PointMass{typeof(1.0u"kg")}, ρ = 2., court = ClayCourt{3})
Number of Free Parameters: 4
#37 (generic function with 1 method)
```

This initialiser can now be used in optimisation. For the sake of demonstration,
let us define a dummy method to simulate and compute the loss between simulation
and measured data.
```julia
simulate(s::Simulator{SimpleDrag,<:PointMass,<:ClayCourt}) = sum(s.court.some_parameters) - s.air.ρ
loss(s, data) = (simulate(s) - data)^2
const data = 1.2
loss(x) = loss(c(x), data)
loss(rand(4))
```
We can evaluate this loss function for any value of the four free parameters.
Therefore we can use it in an optimisation method. And if gradients are needed,
one can use for example [Zygote](https://github.com/FluxML/Zygote.jl).
```
using Zygote
gradient(loss, rand(4))
```

## Alternative, but related approaches
- [Parameters.jl](https://github.com/mauro3/Parameters.jl)
- [Setfield.jl](https://github.com/jw3126/Setfield.jl)
- [ComponentArrays.jl](https://github.com/jonniedie/ComponentArrays.jl)
