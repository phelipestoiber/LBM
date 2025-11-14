# src/NavalLBM/core/types.jl

"""
    D2Q9Params

Immutable struct holding the D2Q9 lattice parameters: weights (`w`) and discrete velocity vectors (`c`).

# Architectural Note
We use `StaticArrays` (`SVector`, `SMatrix`) instead of standard Julia arrays because these parameters 
are small, constant, and known at compile time. This allows the Julia compiler to:
1. Store them in CPU registers rather than RAM.
2. Perform aggressive loop unrolling (e.g., in the `calculate_feq!` kernel).
3. Eliminate heap allocations, dramatically improving performance in hot loops.

# Fields
- `w::SVector{9, Float64}`: Lattice weights (w_i).
- `c::SMatrix{9, 2, Int}`: Lattice velocity vectors (c_i). Stored as [cx, cy].
"""
struct D2Q9Params
    w::SVector{9, Float64}
    c::SMatrix{9, 2, Int}
end

"""
    D2Q9Params()

Default constructor for `D2Q9Params`.
Initializes the weights and velocity vectors for the D2Q9 model.
"""
function D2Q9Params()
    # D2Q9 weights (w_i)
    # Julia is 1-based index. Mapping:
    # k=1    -> Center (Rest)
    # k=2-5  -> Axis-aligned (Right, Up, Left, Down)
    # k=6-9  -> Diagonals (NE, NW, SW, SE)
w = SVector{9, Float64}(
        4/9,  # k=1 (Center)
        1/9,  # k=2 (E)
        1/9,  # k=3 (N)
        1/9,  # k=4 (W)
        1/9,  # k=5 (S)
        1/36, # k=6 (NE)
        1/36, # k=7 (NW)
        1/36, # k=8 (SW)
        1/36  # k=9 (SE)
    )
    
    # D2Q9 velocity vectors (c_i)
    # Access: c[k, 1] -> cx, c[k, 2] -> cy
    c_matrix = [
         0  0;  # k=1
         1  0;  # k=2
         0  1;  # k=3
        -1  0;  # k=4
         0 -1;  # k=5
         1  1;  # k=6
        -1  1;  # k=7
        -1 -1;  # k=8
         1 -1   # k=9
    ]
    c = SMatrix{9, 2, Int}(c_matrix)

    return D2Q9Params(w, c)
end

"""
    SimulationState{T, A3, A2, M}

Container struct holding the entire state of the LBM simulation.

# Architectural Note
This is an **immutable struct** containing references to **mutable arrays**.
This is a high-performance pattern in Julia for scientific computing:
1. **Type Stability:** The compiler knows the exact memory layout of the fields at compile time.
2. **In-Place Mutation:** While the struct pointer is fixed, the contents of the arrays 
   (e.g., `state.rho[i,j]`) are modified in-place during simulation steps, avoiding memory churn.

# Fields
- `f_in::A3`: Input population distributions (Post-Streaming / Pre-Collision).
- `f_out::A3`: Output population distributions (Post-Collision / Pre-Streaming).
- `rho::A2`: Macroscopic density field.
- `u::A2`: Macroscopic velocity field (x-component).
- `v::A2`: Macroscopic velocity field (y-component).
- `mask::M`: Boolean geometry mask (`true` = Solid/Boundary, `false` = Fluid).
- `params::D2Q9Params`: Static physics parameters.
- `tau::T`: Relaxation time constant (related to viscosity).

# Type Parameters
- `T`: Floating-point precision (e.g., `Float64` for accuracy, `Float32` for memory bandwidth).
- `A3`: Type of 3D arrays (Populations).
- `A2`: Type of 2D arrays (Macroscopic moments).
- `M`: Type of the boolean mask (supports CPU `Array` or GPU `CuArray`).
"""
struct SimulationState{
    T<:AbstractFloat, 
    A3<:AbstractArray{T, 3}, 
    A2<:AbstractArray{T, 2},
    M<:AbstractArray{Bool, 2}
}
    # Fields holding lattice populations (3D)
    f_in::A3
    f_out::A3

    # Fields holding macroscopic quantities (2D)
    rho::A2
    u::A2
    v::A2

    # Boundary and physics parameters
    mask::M
    params::D2Q9Params
    tau::T
end

"""
    VorticitySnapshot

Lightweight struct to store simulation snapshots for post-processing/animation.

# Fields
- `t::Int`: The time step index.
- `data::Matrix{Float32}`: The vorticity field. Stored as `Float32` to reduce 
  RAM usage by 50% when storing histories of long simulations.
"""
struct VorticitySnapshot
    t::Int
    data::Matrix{Float32} 
end

"""
    ForceData{T}

Immutable struct to store aerodynamic/hydrodynamic force coefficients.

# Fields
- `Fx::T`: Drag force component (in lattice units).
- `Fy::T`: Lift force component (in lattice units).
- `Cd::T`: Drag coefficient (dimensionless).
- `Cl::T`: Lift coefficient (dimensionless).
"""
struct ForceData{T<:AbstractFloat}
    Fx::T
    Fy::T
    Cd::T
    Cl::T
end