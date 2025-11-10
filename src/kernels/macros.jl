# src/NavalLBM/kernels/macros.jl

"""
    calculate_macros!(state::SimulationState{T}) where {T}

Calculates macroscopic density (rho) and velocities (u, v) in-place.

This function iterates over the entire lattice, reading the (post-streaming)
populations `state.f_in` and writing the computed macroscopic quantities
into `state.rho`, `state.u`, and `state.v`.

This kernel is essential for updating the macroscopic state before the
collision step.

# Arguments
- `state`: The `SimulationState` object containing all simulation data. 
           `f_in` is read from; `rho`, `u`, `v` are written to.

# Source
- Formula: LBM standard 0th, 1st, and 2nd moments calculation.
- rho = sum_k(f_k)
- rho*u = sum_k(f_k * c_k_x)
- rho*v = sum_k(f_k * c_k_y)
"""
function calculate_macros!(state::SimulationState{T}) where {T<:AbstractFloat}
    
    # Get domain dimensions from one of the arrays
    nx, ny = size(state.rho)
    
    # Loop over all fluid nodes
    @inbounds for j in 1:ny
        for i in 1:nx
            # Initialize local sums
            # (É crucial tipá-los explicitamente como T para performance)
            rho_local::T = 0.0
            u_local::T = 0.0 # This will hold momentum (rho*u)
            v_local::T = 0.0 # This will hold momentum (rho*v)

            # Sum moments over all 9 directions
            # @simd hints the compiler to vectorize this inner loop
            @simd for k in 1:9
                f_k = state.f_in[i, j, k]
                
                # 0th Moment (Density)
                rho_local += f_k
                
                # 1st Moments (Momentum)
                u_local += f_k * state.params.c[k, 1] # f_k * cx
                v_local += f_k * state.params.c[k, 2] # f_k * cy
            end

            # ----------------------------------------------------
            # Write results back to the state arrays
            # ----------------------------------------------------
            state.rho[i, j] = rho_local
            
            # Calculate velocity from momentum: u = (rho*u) / rho
            # (Adicionar 1e-15 para evitar divisão por zero se rho for 0)
            inv_rho_local = 1.0 / (rho_local + 1e-15)
            state.u[i, j] = u_local * inv_rho_local
            state.v[i, j] = v_local * inv_rho_local
        end
    end
    
    return nothing # Function modifies in-place
end