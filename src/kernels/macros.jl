# src/NavalLBM/kernels/macros.jl

"""
    calculate_macros!(state::SimulationState{T}) where {T<:AbstractFloat}

Calculates macroscopic density (rho) and velocities (u, v) from the 
post-stream populations `state.f_in`.

This function modifies `state.rho`, `state.u`, and `state.v` in-place.
It must be called AFTER streaming and boundary conditions, and BEFORE collision.
"""
function calculate_macros!(state::SimulationState{T}) where {T<:AbstractFloat}
    nx, ny = size(state.rho)

    Threads.@threads for j in 1:ny
        @fastmath @inbounds for i in 1:nx
            # Skip solid boundaries (macros are undefined or 0)
            if state.mask[i, j]
                state.rho[i, j] = 1.0 # Or other reference density
                state.u[i, j] = 0.0
                state.v[i, j] = 0.0
                continue
            end

            # --- 1. Calculate Density (rho) ---
            # Sum of all populations
            rho_local = 0.0
            for k in 1:9
                rho_local += state.f_in[i, j, k]
            end
            state.rho[i, j] = rho_local

            # --- 2. Calculate Velocities (u, v) ---
            # Sum of (c_k * f_k) / rho
            u_local = 0.0
            v_local = 0.0
            if rho_local > 0.0 # Avoid division by zero
                for k in 1:9
                    u_local += state.params.c[k, 1] * state.f_in[i, j, k]
                    v_local += state.params.c[k, 2] * state.f_in[i, j, k]
                end
                state.u[i, j] = u_local / rho_local
                state.v[i, j] = v_local / rho_local
            else
                # Fallback if density is zero
                state.u[i, j] = 0.0
                state.v[i, j] = 0.0
            end
        end
    end
    return nothing
end