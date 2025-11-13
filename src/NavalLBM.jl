# src/NavalLBM.jl

module NavalLBM

using StaticArrays
using Plots

# Incluir os arquivos de tipos e kernels
include("core/types.jl")
include("kernels/collision.jl")
include("utils/initialization.jl")
include("kernels/macros.jl")
include("kernels/streaming.jl")
include("kernels/boundaries.jl")

# Exportar as funções e tipos que queremos usar
export D2Q9Params, SimulationState
export calculate_feq!
export initialize_state
export create_cylinder_mask!
export create_cavity_mask!
export calculate_macros!
export collision_bgk!
export streaming!
export apply_bounce_back!
export apply_lid_velocity!
export apply_zou_he_inlet!
export apply_zou_he_outlet!
export calculate_vorticity
export run_simulation!

"""
    run_simulation!(
        state::SimulationState{T}, 
        U_in::T, 
        max_steps::Int
    ) where {T<:AbstractFloat}

Main time loop for the Von Karman cylinder simulation.

Implements the "Stream-and-Collide" (SAC) algorithm order:
1. Streaming (f_out -> f_in)
2. Boundary Conditions (on f_in)
    - Bounce-back (walls/cylinder)
    - Zou-He Inlet (left)
    - Zou-He Outlet (right)
3. Calculate Macros (rho, u, v from f_in)
4. Collision (f_in -> f_out)
"""
function run_simulation!(
    state::SimulationState{T}, 
    U_in::T, 
    max_steps::Int;
    # plot_every::Int = 0,
    # plots_list::Vector = [], # Para armazenar plots para animação
    probe_location::Union{Nothing, Tuple{Int, Int}} = nothing,
    history_vector::Union{Nothing, Vector{T}} = nothing
) where {T<:AbstractFloat}
    
    nx, ny = size(state.rho)
    rho_out = 1.0 # Prescribed outlet density

    # --- Pre-allocate probe coordinates if provided ---
    # (Doing this check outside the loop is a micro-optimization)
    do_probe = (probe_location !== nothing) && (history_vector !== nothing)
    if do_probe
        px, py = probe_location
    end

    for t in 1:max_steps
        # --- 1. Streaming Step ---
        # Populations move from f_out (post-collision) to f_in (post-stream)
        streaming!(state)

        # --- 2. Boundary Conditions Step (on f_in) ---
        # 2a. Solid walls (Top/Bottom/Cylinder)
        apply_bounce_back!(state)
        
        # 2b. Velocity Inlet (Zou-He)
        apply_zou_he_inlet!(state, U_in)
        
        # 2c. Pressure Outlet (Zou-He)
        apply_zou_he_outlet!(state, rho_out)

        # --- 3. Macroscopic Step ---
        # Calculate rho, u, v from the corrected f_in lattice
        calculate_macros!(state)

        # --- 4. Collision Step ---
        # Collide populations from f_in into f_out
        collision_bgk!(state)

        # --- 5. Data Probing ---
        # (This must be *after* calculate_macros!)
        if do_probe
            # Record the vertical velocity (v) at the probe point
            push!(history_vector, state.v[px, py])
        end

        # # --- 6. Visualization (Optional) ---
        # if plot_every > 0 && t % plot_every == 0
        #     println("Simulation step: $t / $max_steps")
            
        #     # Calculate vorticity for plotting
        #     vort = calculate_vorticity(state)
            
        #     # Create heatmap (transpose ' for correct Plots.jl layout)
        #     p = heatmap(
        #         vort', 
        #         aspect_ratio=:equal, 
        #         c=:balance, 
        #         clim=(-0.02, 0.02),
        #         title="Vorticity (t=$t)"
        #     )
        #     push!(plots_list, p)
        # end
    end
    println("Simulation finished.")
    # return plots_list
end

"""
    calculate_vorticity(state::SimulationState{T}) where {T}

Helper function to calculate the vorticity field (ω_z) from velocities.
ω_z = ∂v/∂x - ∂u/∂y
Uses 2nd-order central differences.
"""
function calculate_vorticity(state::SimulationState{T}) where {T}
    nx, ny = size(state.rho)
    u = state.u
    v = state.v
    vort = zeros(T, nx, ny)

    @inbounds for j in 2:ny-1
        for i in 2:nx-1
            dv_dx = (v[i+1, j] - v[i-1, j]) / 2.0
            du_dy = (u[i, j+1] - u[i, j-1]) / 2.0
            vort[i, j] = dv_dx - du_dy
        end
    end
    return vort
end

end # module NavalLBM
