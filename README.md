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
an optimization method that runs the simulator with different values for the
free parameters until simulations and measurements match.

Nested structures are convenient to express choices (see example below).
This package provides the function `parameters` to inspect the parameters
of nested structures and the function `initialiser` to get an efficient
constructor for nested structures that can be used in an optimization loop.
More specifically, we can tell the `initialiser` all the known parameters
and it returns a function that takes as input a vector with length equal to the
number of free parameters and outputs the nested structure.

## Example

Here are some structures that we may want to define in a tennis simulator.

```julia
using StaticArrays

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
struct PointMass
    mass::Float64
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
Fixed
 none
Free
 air: indeterminable dimensionality
 ball: indeterminable dimensionality
 court: indeterminable dimensionality
 
julia> p = parameters(Simulator, air = SimpleDrag, ball = PointMass, mass = 0.5, court = ClayCourt{3})
Simulator Parameters
Fixed
 air = SimpleDrag
 ball = PointMass
 mass = 0.5
 court = ClayCourt{3}
Free
 ρ: 1 dimensional
 some_parameters: 3 dimensional
```

Let us now use the `initialiser` function to get a constructor that takes
a 4-dimensional vector as input and returns the initialised nested structure.
```julia
julia> c = initialiser(p)
Number of Free Parameters: 4
#35 (generic function with 1 method)

julia> c([1, 2, 3, 4])
Simulator{SimpleDrag,PointMass,ClayCourt{3}}(SimpleDrag(1.0), PointMass(0.5), ClayCourt{3}((2.0, 3.0, 4.0)))
```

We could have also called the `initialiser` directly with the known parameters
to get the same function as above.
```julia
julia> c = initialiser(Simulator, air = SimpleDrag, ball = PointMass, mass = 0.5, court = ClayCourt{3})
Number of Free Parameters: 4
#37 (generic function with 1 method)
```


