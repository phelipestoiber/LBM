# src/NavalLBM.jl

module NavalLBM

using StaticArrays
using Plots
using ProgressMeter

# Incluir os arquivos de tipos e kernels
include("core/types.jl")
include("kernels/collision.jl")
include("utils/initialization.jl")
include("kernels/macros.jl")
include("kernels/streaming.jl")
include("kernels/boundaries.jl")

# Exportar as funções e tipos que queremos usar
export D2Q9Params, SimulationState, VorticitySnapshot
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
    run_simulation!(state, U_in, max_steps; kwargs...)

Executes the main Lattice Boltzmann Method (LBM) time loop using the 
Stream-and-Collide (SAC) architecture.

# Arguments
- `state`: The mutable `SimulationState` object holding all lattice grids.
- `U_in`: Inflow velocity in lattice units (should be < 0.1 for stability).
- `max_steps`: Total number of time steps to simulate.

# Keyword Arguments
- `snapshot_every`: Interval to save vorticity snapshots (0 to disable).
- `snapshots`: Vector to store the `VorticitySnapshot` structs.
- `probe_location`: Tuple (i, j) for the velocity probe.
- `history_vector`: Vector to store the time-series data of vertical velocity (v).

# Architecture
This function implements the standard splitting of the LBM equation:
1. **Streaming**: Advection of populations to neighboring nodes.
2. **Boundary Conditions**: Application of macroscopic constraints (Bounce-back, Zou-He).
3. **Macroscopic Update**: Calculation of moments (rho, u, v).
4. **Collision**: Relaxation towards equilibrium (BGK operator).
"""
function run_simulation!(
    state::SimulationState{T}, 
    U_in::T, 
    max_steps::Int;
    snapshot_every::Int = 0,
    snapshots::Vector{VorticitySnapshot} = VorticitySnapshot[],
    probe_location::Union{Nothing, Tuple{Int, Int}} = nothing,
    history_vector::Union{Nothing, Vector{T}} = nothing
) where {T<:AbstractFloat}
    
    # Extract domain dimensions
    nx, ny = size(state.rho)
    rho_out = 1.0 # Fixed outlet density for pressure boundary
    
    # --- Setup Probe Logic ---
    # We pre-calculate probe indices to avoid checking 'nothing' inside the hot loop
    do_probe = (probe_location !== nothing) && (history_vector !== nothing)
    px, py = do_probe ? probe_location : (1, 1)

    # --- Main Time Loop ---
    # @showprogress displays a progress bar with minimal overhead (updates every 1s)
    @showprogress 1 "Computing CFD Solution..." for t in 1:max_steps
        
        # --- 1. Streaming Step (Advection) ---
        # Populations f_out propagate to neighbor nodes becoming f_in
        streaming!(state)

        # --- 2. Boundary Conditions (Post-Streaming) ---
        # Apply no-slip condition on solid walls/obstacles
        apply_bounce_back!(state)
        # Apply velocity inlet profile (West boundary)
        apply_zou_he_inlet!(state, U_in)
        # Apply constant pressure/density outlet (East boundary)
        apply_zou_he_outlet!(state, rho_out)

        # --- 3. Macroscopic Moment Calculation ---
        # Compute density (0th moment) and velocity (1st moment) from f_in
        calculate_macros!(state)

        # --- 4. Collision Step (Relaxation) ---
        # Local relaxation of f_in towards equilibrium f_eq (BGK model)
        collision_bgk!(state)

        # --- 5. Data Acquisition (In-Situ) ---
        
        # A. Velocity Probe (High-Frequency Data)
        # Capture vertical velocity for Strouhal analysis (every step)
        if do_probe
            push!(history_vector, state.v[px, py])
        end
        
        # B. Field Snapshots (Low-Frequency Visualization)
        # Capture vorticity field for animation (periodic)
        if snapshot_every > 0 && t % snapshot_every == 0
            # Calculate derived quantity: Vorticity (curl of velocity)
            w = calculate_vorticity(state)
            # Store minimal data (Float32) to conserve memory
            push!(snapshots, VorticitySnapshot(t, Float32.(w)))
        end
    end
    
    println("Simulation completed successfully.")
    return snapshots
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
