# src/core/solver.jl

"""
    run_simulation!(state, U_in, max_steps; kwargs...)

Executes the main Lattice Boltzmann Method (LBM) time loop using the 
**Stream-and-Collide (SAC)** architecture.

# Arguments
- `state`: The mutable `SimulationState` object holding all lattice grids.
- `U_in`: Inflow velocity in lattice units (must be small, e.g., < 0.1, to satisfy Ma << 1).
- `max_steps`: Total number of time steps to simulate.

# Keyword Arguments
- `snapshot_every`: Interval to save vorticity snapshots. Set to 0 to disable.
- `snapshots`: Vector to store the `VorticitySnapshot` structs for animation.
- `probe_location`: Tuple `(i, j)` defining the grid node for the velocity probe.
- `history_vector`: Vector to store the time-series data of vertical velocity (`v`).

# Algorithm Overview
This function implements the standard splitting of the LBM equation:
1. **Streaming**: Advection of populations to neighboring nodes.
2. **Boundary Conditions**: Application of macroscopic constraints (Bounce-back, Zou-He) on the *post-streaming* populations.
3. **Macroscopic Update**: Calculation of moments (`rho`, `u`, `v`).
4. **Collision**: Relaxation towards equilibrium (BGK operator).
"""
function run_simulation!(
    state::SimulationState{T}, 
    U_in::T, 
    max_steps::Int;
    snapshot_every::Int = 0,
    snapshots::Vector{VorticitySnapshot} = VorticitySnapshot[],
    probe_location::Union{Nothing, Tuple{Int, Int}} = nothing,
    history_vector::Union{Nothing, Vector{T}} = nothing,
    measure_every::Int = 0,
    force_history::Vector{ForceData{T}} = ForceData{T}[],
    D_char::T = T(1.0)
) where {T<:AbstractFloat}
    
    # Extract domain dimensions
    nx, ny = size(state.rho)
    rho_out = 1.0 # Fixed outlet density for pressure boundary condition
    
    # --- Setup Probe Logic ---
    # Pre-calculate probe indices to avoid checking 'nothing' inside the hot loop.
    # If no probe is provided, we default to (1,1) to avoid errors (but don't record).
    do_probe = (probe_location !== nothing) && (history_vector !== nothing)
    px, py = do_probe ? probe_location : (1, 1)

    sim_aborted = false

    # --- Main Time Loop ---
    # @showprogress uses ProgressMeter.jl to display a bar that updates every 1s.
    # This avoids I/O overhead slowing down the simulation.
    @showprogress 1 "Computing CFD Solution..." for t in 1:max_steps

        # --- 0. SYMMETRY BREAKING (PERTURBATION) ---
        # Introduce a tiny vertical velocity kick to trigger vortex shedding faster.
        if t == 4000
            # Find a point slightly downstream of the cylinder
            p_kick_x = nx ÷ 5 + Int(D_char)
            p_kick_y = ny ÷ 2
            # Only apply kick if the node is FLUID
            if !state.mask[p_kick_x, p_kick_y] && !state.mask[p_kick_x, p_kick_y+1]
                # println("\nApplying perturbation kick at ($p_kick_x, $p_kick_y)...")
                state.v[p_kick_x, p_kick_y]     += 0.1
                state.v[p_kick_x, p_kick_y+1]   -= 0.1
            else
                println("\nWARNING: Perturbation point is inside obstacle! Skipping kick.")
            end
        end
        
        # --- 1. Streaming Step (Advection) ---
        # Populations propagate: f_in(x, t) = f_out(x - c*dt, t - dt)
        streaming!(state)

        # --- 2. Boundary Conditions (Post-Streaming) ---
        # Apply no-slip condition on solid walls/obstacles (Masked regions)
        apply_bounce_back!(state)
        # Apply velocity inlet profile (West boundary)
        apply_zou_he_inlet!(state, U_in)
        # Apply constant pressure/density outlet (East boundary)
        apply_zou_he_outlet!(state, rho_out)

        # --- 3. Macroscopic Moment Calculation ---
        # Compute density (0th moment) and velocity (1st moment) from f_in.
        # These are required for the Equilibrium calculation in the next step.
        calculate_macros!(state)

        # --- 4. Collision Step (Relaxation) ---
        # Local relaxation of f_in towards equilibrium f_eq (BGK model).
        collision_bgk!(state)

        # --- SAFETY CHECK: NaN Detection ---
        # Check center point density every 100 steps to fail fast
        if t % 100 == 0
            if isnan(state.rho[nx÷2, ny÷2]) || state.rho[nx÷2, ny÷2] > 5.0
                println("\n🔥 SIMULATION EXPLODED at step $t Stopping early.")
                sim_aborted = true
                break # Exit loop
            end
        end

        # --- 5. Data Acquisition (In-Situ) ---
        
        # A. Velocity Probe (High-Frequency Data)
        # Capture vertical velocity for Strouhal number analysis (FFT).
        if do_probe
            push!(history_vector, state.v[px, py])
        end

        # B. Force Calculation (Periodic)
        # Calculate aerodynamic forces (Drag/Lift) for time-series analysis.
        if measure_every > 0 && t % measure_every == 0
            forces = calculate_forces(state, U_in, D_char)
            push!(force_history, forces)
        end
        
        # C. Field Snapshots (Low-Frequency Visualization)
        # Capture vorticity field for animation.
        if snapshot_every > 0 && t % snapshot_every == 0
            # Calculate derived physical quantity: Vorticity (curl of velocity)
            w = calculate_vorticity(state)
            # Store data as Float32 to reduce memory footprint by 50%
            push!(snapshots, VorticitySnapshot(t, Float32.(w)))
        end
    end

    if sim_aborted
        println("Simulation aborted due to instability.")
    else
        println("Simulation completed successfully.")
    end

    return (snapshots=snapshots, forces=force_history, probe=history_vector)
end