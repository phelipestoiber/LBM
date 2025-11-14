# src/NavalLBM/kernels/collision.jl

"""
    calculate_feq!(feq_local, rho, u, v, params)

Calculates the **D2Q9 Equilibrium Distribution Function** (f^{eq}) in-place.

# Performance Note
This function is marked `@inline`. This instructs the compiler to insert the code 
body directly into the calling function (`collision_bgk!`), eliminating function 
call overhead within the innermost hot loop.

# Arguments
- `feq_local`: Pre-allocated buffer (Vector/SVector) to store the 9 results.
- `rho`, `u`, `v`: Macroscopic density and velocity components.
- `params`: D2Q9 parameters struct.

# Physics
Implements the 2nd-order expansion of the Maxwell-Boltzmann distribution 
for low Mach number flows.

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
        
        # Projection of velocity onto lattice direction
        cu = c_k_x * u + c_k_y * v
        
        # Equilibrium expansion
        feq_local[k] = w_k * rho * (1.0 + 3.0*cu + 4.5*(cu*cu) - 1.5*uu)
    end
    
    return nothing # Function modifies in-place
end

"""
    collision_bgk!(state)

Executes the **BGK (Bhatnagar-Gross-Krook)** Collision Step.

This is the primary computational kernel of the LBM. It relaxes the populations
towards thermodynamic equilibrium.

# Algorithm
1. Iterate over every fluid node `(i, j)`.
2. Compute the local equilibrium distribution f^{eq} based on macroscopic `rho`, `u`, `v`.
3. Update populations: f_{out} = f_{in} - frac{1}{tau} (f_{in} - f^{eq}).

# Performance Optimizations
- **Zero Allocation:** A temporary buffer `feq_local` is allocated on the stack once.
- **SIMD:** The inner loop over directions `k` is annotated with `@simd` to enable 
  vectorized CPU instructions (AVX/AVX2).
- **In-Place:** Directly modifies `state.f_out`.

# Source
- Formula: BGK Collision Operator
- `f_out = f_in - (1/tau) * (f_in - feq)`
- Reference: "A Practical Introduction to the Lattice Boltzmann Method" (A.J. Wagner)
"""
function collision_bgk!(state::SimulationState{T}) where {T<:AbstractFloat}
    
    # Get domain dimensions and relaxation frequency (omega = 1/tau)
    nx, ny = size(state.rho)
    omega = 1.0 / state.tau

    Threads.@threads for j in 1:ny
        # -----------------------------------------------------------------
        # CRITICAL PERFORMANCE: Pre-allocate feq buffer ONCE
        # -----------------------------------------------------------------
        # We allocate this temporary buffer *outside* the hot loops (i, j)
        # to avoid allocating memory millions of times per step.
        feq_local = MVector{9, T}(undef)

        # Loop over all fluid nodes
        @fastmath @inbounds for i in 1:nx
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