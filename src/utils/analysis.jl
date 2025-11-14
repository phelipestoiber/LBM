# src/core/analysis.jl

"""
    calculate_vorticity(state::SimulationState{T}) where {T}

Calculates the vertical component of the vorticity field (ω_z) from the velocity field.

The vorticity is defined as the curl of the velocity:
`ω_z = ∂v/∂x - ∂u/∂y`

This implementation uses a **2nd-order central difference scheme** for interior nodes:
`∂f/∂x ≈ (f(x+1) - f(x-1)) / 2`

# Arguments
- `state`: The current `SimulationState`.

# Returns
- `vort`: A 2D Matrix containing the local vorticity values.
"""
function calculate_vorticity(state::SimulationState{T}) where {T}
    nx, ny = size(state.rho)
    u = state.u
    v = state.v
    vort = zeros(T, nx, ny)

    # Iterate over interior nodes (skipping boundaries to avoid index errors)
    Threads.@threads for j in 2:ny-1
        @inbounds for i in 2:nx-1
            dv_dx = (v[i+1, j] - v[i-1, j]) / 2.0
            du_dy = (u[i, j+1] - u[i, j-1]) / 2.0
            vort[i, j] = dv_dx - du_dy
        end
    end
    return vort
end

# """
#     calculate_forces(state, U_char, D_char, rho_ref=1.0)

# Calculates the forces (Fx, Fy) and dimensionless coefficients (Cd, Cl) acting on 
# solid obstacles using the **Momentum Exchange Method**.

# # Physics
# The force is calculated by summing the momentum transfer of all fluid particles 
# that hit a solid boundary during a time step. 
# Formula: `F = sum(2 * f_in_k * c_k)` for all directions `k` pointing to a wall.

# # Arguments
# - `state`: The current `SimulationState`.
# - `U_char`: Characteristic velocity (e.g., Inlet velocity) for normalization.
# - `D_char`: Characteristic length (e.g., Cylinder diameter) for normalization.
# - `rho_ref`: Reference density (default: 1.0).

# # Returns
# - `ForceData`: Struct containing Fx, Fy, Cd, Cl.
# """
# function calculate_forces(
#     state::SimulationState{T}, 
#     U_char::T, 
#     D_char::T,
#     rho_ref::T=1.0
# ) where {T<:AbstractFloat}
    
#     nx, ny = size(state.mask)
#     c = state.params.c
    
#     Fx = zero(T)
#     Fy = zero(T)

#     # Iterate over the entire domain (Single-threaded for safety/precision)
#     @inbounds for j in 1:ny
#         for i in 1:nx
#             # We look for FLUID nodes that are neighbors of SOLID nodes
#             if !state.mask[i, j]
                
#                 # Check all 9 directions
#                 for k in 1:9
#                     # Neighbor coordinates
#                     xn = i + c[k, 1]
#                     yn = j + c[k, 2]
                    
#                     # Boundary checks
#                     if xn >= 1 && xn <= nx && yn >= 1 && yn <= ny
                        
#                         # If the neighbor is SOLID (Obstacle), a bounce-back occurred
#                         if state.mask[xn, yn]
#                             # Momentum Exchange:
#                             # The particle `k` went towards the wall and returned.
#                             # Momentum change = 2 * mass * velocity
#                             # Force contribution = 2 * f_in[i, j, k]
                            
#                             f_val = state.f_out[i, j, k]
#                             momentum = 2.0 * f_val
                            
#                             # Project force onto the lattice direction vector c[k]
#                             Fx += momentum * c[k, 1]
#                             Fy += momentum * c[k, 2]
#                         end
#                     end
#                 end
#             end
#         end
#     end
    
#     # Calculate Dimensionless Coefficients
#     # Dynamic Pressure q = 0.5 * rho * U^2
#     # Force = Coefficient * q * Area (Area = D_char in 2D)
#     denominator = 0.5 * rho_ref * (U_char^2) * D_char
    
#     Cd = Fx / denominator
#     Cl = Fy / denominator
    
#     return ForceData(Fx, Fy, Cd, Cl)
# end

"""
    calculate_forces(state, U_char, D_char, rho_ref=1.0)

Calculates aerodynamic forces (Fx, Fy) acting ONLY on the obstacle inside the channel.
Includes a spatial filter to ignore the top/bottom channel walls.
"""
function calculate_forces(
    state::SimulationState{T}, 
    U_char::T, 
    D_char::T,
    rho_ref::T=1.0
) where {T<:AbstractFloat}
    
    nx, ny = size(state.mask)
    c = state.params.c
    
    Fx = zero(T)
    Fy = zero(T)
    
    # Debug counters
    cylinder_nodes = 0

    @inbounds for j in 2:ny-1 # Skip checking boundary lines j=1 and j=ny entirely
        for i in 1:nx
            # If current node is FLUID
            if !state.mask[i, j]
                for k in 1:9
                    xn = i + c[k, 1]
                    yn = j + c[k, 2]
                    
                    # Bounds check
                    if xn >= 1 && xn <= nx && yn >= 1 && yn <= ny
                        
                        # If neighbor is SOLID
                        if state.mask[xn, yn]
                            
                            # --- SPATIAL FILTER ---
                            # We only want force on the Cylinder, not the channel walls.
                            # Since we iterate j from 2 to ny-1, we just need to ensure
                            # the SOLID neighbor isn't part of the top/bottom walls.
                            is_channel_wall = (yn == 1 || yn == ny)
                            
                            if !is_channel_wall
                                # Momentum Exchange (using f_out for outgoing particle)
                                f_val = state.f_out[i, j, k]
                                momentum = 2.0 * f_val
                                
                                Fx += momentum * c[k, 1]
                                Fy += momentum * c[k, 2]
                                
                                cylinder_nodes += 1
                            end
                        end
                    end
                end
            end
        end
    end
    
    # Calculation of Coefficients
    # Force = Cd * 0.5 * rho * U^2 * D
    denom = 0.5 * rho_ref * (U_char^2) * D_char
    
    Cd = Fx / denom
    Cl = Fy / denom

    # # Debugging (apenas se Cd for absurdo)
    # if abs(Cd) > 10.0
    #     println("DEBUG FORCE: Fx=$Fx, denom=$denom, D=$D_char, Nodes=$cylinder_nodes")
    # end
    
    return ForceData(Fx, Fy, Cd, Cl)
end