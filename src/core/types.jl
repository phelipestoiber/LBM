# src/NavalLBM/core/types.jl

"""
    D2Q9Params

Struct to hold the D2Q9 lattice parameters (weights `w` and velocity vectors `c`).

We use StaticArrays (`SVector`, `SMatrix`) because these parameters are small, 
constant, and known at compile time. This allows the Julia compiler to 
aggressively optimize calculations that use them (e.g., loop unrolling in 
the `calculate_feq!` kernel), dramatically improving performance over 
standard `Vector` or `Matrix`.

Fields:
- `w::SVector{9, Float64}`: Lattice weights.
- `c::SMatrix{9, 2, Int}`: Lattice velocity vectors (e_ia). 
                           Stored as 9 rows, 2 columns [cx, cy].
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
    # k=1 -> (i=0) [rest]
    # k=2-5 -> (i=1-4) [axis-aligned]
    # k=6-9 -> (i=5-8) [diagonal]
    w = SVector{9, Float64}(
        4/9,  # k=1 (i=0)
        1/9,  # k=2 (i=1)
        1/9,  # k=3 (i=2)
        1/9,  # k=4 (i=3)
        1/9,  # k=5 (i=4)
        1/36, # k=6 (i=5)
        1/36, # k=7 (i=6)
        1/36, # k=8 (i=7)
        1/36  # k=9 (i=8)
    )
    
    # D2Q9 velocity vectors (c_i)
    # We define this as a 9x2 SMatrix.
    # Access: c[k, 1] -> cx, c[k, 2] -> cy
    c_matrix = [
         0  0;  # k=1 (i=0)
         1  0;  # k=2 (i=1)
         0  1;  # k=3 (i=2)
        -1  0;  # k=4 (i=3)
         0 -1;  # k=5 (i=4)
         1  1;  # k=6 (i=5)
        -1  1;  # k=7 (i=6)
        -1 -1;  # k=8 (i=7)
         1 -1   # k=9 (i=8)
    ]
    c = SMatrix{9, 2, Int}(c_matrix)

    return D2Q9Params(w, c)
end

"""
    SimulationState{T, A3, A2, M}

Struct to hold the entire state of the LBM simulation.

This is an immutable `struct` that holds *references* to mutable arrays.
This is a standard high-performance Julia pattern: the *structure* of the
state (which arrays it points to) cannot change, but the *content* of the 
arrays (e.g., `state.rho[i,j] = ...`) can and will be modified in-place.

This design ensures Type Stability, as the compiler always knows the
exact types of the fields.

Fields:
- `f_in::A3{T, 3}`: Input population distributions (post-streaming).
- `f_out::A3{T, 3}`: Output population distributions (post-collision).
- `rho::A{2T, 2}`: Macroscopic density.
- `u::A2{T, 2}`: Macroscopic velocity (x-component).
- `v::A2{T, 2}`: Macroscopic velocity (y-component).
- `mask::M`: Boolean mask for boundary nodes (true = boundary/solid).
- `params::D2Q9Params`: Static D2Q9 parameters (weights and velocities).
- `tau::T`: Relaxation time.

Type Parameters:
- `T<:AbstractFloat`: The floating-point type (e.g., Float64, Float32).
- `A3<:AbstractArray{T, 3}`: Type for 3D arrays (f_in, f_out).
- `A2<:AbstractArray{T, 2}`: The type of the 2D arrays (rho, u, v).
- `M<:AbstractArray{Bool, 2}`: The type of the mask (allows for `Array` or `CuArray`).
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

    # Inner constructor for validation (opcional, mas boa prática)
    # Por enquanto, deixaremos o construtor padrão.
end