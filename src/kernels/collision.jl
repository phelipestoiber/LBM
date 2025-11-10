# src/NavalLBM/kernels/collision.jl

"""
    calculate_feq!(
        feq_local::AbstractVector{T}, 
        rho::T, 
        u::T, 
        v::T,
        params::D2Q9Params
    ) where {T<:AbstractFloat}

Calculates the D2Q9 equilibrium distribution function (feq) in-place.

This function is marked `@inline` to suggest the compiler to "paste"
this code directly into the calling function (e.g., `collision_bgk!`),
avoiding the overhead of a function call inside the hot loop.

It operates on a pre-allocated buffer `feq_local` (Vector of 9 elements)
for a single lattice node.

# Arguments
- `feq_local`: A pre-allocated buffer (Vector or SVector) to store the result.
- `rho`: Macroscopic density at the node.
- `u`: Macroscopic velocity (x-component) at the node.
- `v`: Macroscopic velocity (y-component) at the node.
- `params`: The D2Q9Params struct containing weights `w` and velocities `c`.

# Source
- Formula: D2Q9 BGK equilibrium distribution function (low Mach number).
- Reference: "A Practical Introduction to the Lattice Boltzmann Method" (A.J. Wagner) 
             ou qualquer livro-texto padrão de LBM.
"""
@inline function calculate_feq!(
    feq_local::AbstractVector{T}, 
    rho::T, 
    u::T, 
    v::T,
    params::D2Q9Params
) where {T<:AbstractFloat}
    
    # Precompute velocity terms for efficiency
    uu = u * u + v * v
    
    # Speed of sound squared (cs^2 = 1/3 in LBM units)
    # We use 3.0 and 1.5 instead of 1.0/cs_sq and 0.5/cs_sq
    
    for k in 1:9
        # Get weight and velocity vector for this direction
        w_k = params.w[k]
        c_k_x = params.c[k, 1]
        c_k_y = params.c[k, 2]
        
        # Calculate (c_k ⋅ u)
        cu = c_k_x * u + c_k_y * v
        
        # Equilibrium distribution formula
        feq_local[k] = w_k * rho * (1.0 + 3.0*cu + 4.5*(cu*cu) - 1.5*uu)
    end
    
    return nothing # Function modifies in-place
end

"""
    collision_bgk!(state::SimulationState{T}) where {T}

Performs the LBM BGK (Bhatnagar-Gross-Krook) collision step.

This is the main computational kernel of the simulation. It iterates
over the entire domain, calculates the equilibrium distribution `feq`
for each node (using the pre-computed `rho`, `u`, `v`), and applies the
BGK collision rule to relax the input populations `f_in` towards `feq`.

The result is written *in-place* to `state.f_out`.

# Arguments
- `state`: The `SimulationState` object.
           - Reads from: `state.f_in`, `state.rho`, `state.u`, `state.v`,
                         `state.tau`, `state.params`.
           - Writes to: `state.f_out`.

# Source
- Formula: BGK Collision Operator
- `f_out = f_in - (1/tau) * (f_in - feq)`
- Reference: "A Practical Introduction to the Lattice Boltzmann Method" (A.J. Wagner)
"""
function collision_bgk!(state::SimulationState{T}) where {T<:AbstractFloat}
    
    # Get domain dimensions and relaxation frequency (omega = 1/tau)
    nx, ny = size(state.rho)
    omega = 1.0 / state.tau

    # -----------------------------------------------------------------
    # CRITICAL PERFORMANCE: Pre-allocate feq buffer ONCE
    # -----------------------------------------------------------------
    # We allocate this temporary buffer *outside* the hot loops (i, j)
    # to avoid allocating memory millions of times per step.
    feq_local = MVector{9, T}(undef)

    # Loop over all fluid nodes
    @inbounds for j in 1:ny
        for i in 1:nx
            # 1. Get local macroscopic values (read from state)
            rho_i = state.rho[i, j]
            u_i = state.u[i, j]
            v_i = state.v[i, j]

            # 2. Calculate equilibrium (uses our validated helper function)
            # This modifies feq_local in-place.
            calculate_feq!(feq_local, rho_i, u_i, v_i, state.params)

            # 3. Apply BGK collision rule (the hot loop)
            # This inner loop (k=1:9) is a perfect target for @simd
            @simd for k in 1:9
                f_in_k = state.f_in[i, j, k]
                
                # f_out = f_in - omega * (f_in - feq)
                f_out_k = f_in_k - omega * (f_in_k - feq_local[k])
                
                state.f_out[i, j, k] = f_out_k
            end
        end
    end

    return nothing # Function modifies in-place
end