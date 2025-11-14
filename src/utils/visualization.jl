# src/utils/visualization.jl

"""
    generate_vorticity_gif(snapshots, filename)

Generates a high-performance animated GIF from a list of vorticity snapshots using `CairoMakie`.

This function uses the **Observable** pattern to update plot data efficiently 
without redrawing the entire figure frame-by-frame.

# Arguments
- `snapshots`: Vector of `VorticitySnapshot` containing time `t` and data matrix.
- `filename`: Output path for the GIF (default: "vorticity.gif").

# Returns
- `fig`: The Makie figure object.
"""
function generate_vorticity_gif(snapshots, filename="vorticity.gif")
    if isempty(snapshots)
        @warn "Snapshot list is empty! Cannot generate GIF."
        return
    end

    println("Generating GIF from $(length(snapshots)) frames...")
    
    # --- 1. Setup Observables ---
    # Observables allow us to update data dynamically.
    # We initialize them with the data from the first frame.
    obs_time = Observable(snapshots[1].t)
    obs_vort = Observable(snapshots[1].data)

    # --- 2. Configure Figure and Axis ---
    fig = Figure(size = (800, 300))
    ax = Axis(
        fig[1, 1], 
        title = @lift("Vorticity Field (t = $($obs_time))"), # Dynamic title
        xlabel = "X (Lattice Nodes)", 
        ylabel = "Y (Lattice Nodes)",
        aspect = DataAspect() # Ensures pixels are square (1:1 aspect ratio)
    )

    # --- 3. Plot Heatmap ---
    # We fix the `colorrange` to (-0.02, 0.02). 
    # This is crucial to prevent the GIF from "flashing" or "blowing up" 
    # if a single frame has a numerical spike, and ensures a consistent scale.
    hm = CairoMakie.heatmap!(
        ax, 
        obs_vort, 
        colormap = :balance,       # Blue (negative) -> White (zero) -> Red (positive)
        colorrange = (-0.02, 0.02) # Fixed scale for stability
    )
    Colorbar(fig[1, 2], hm, label="Vorticity magnitude")

    # --- 4. Record Animation ---
    # The `record` function iterates through snapshots and updates the Observables.
    record(fig, filename, snapshots; framerate = 15) do snap
        obs_time[] = snap.t
        obs_vort[] = snap.data
        # Makie automatically triggers a redraw when Observables change.
    end

    println("GIF successfully saved to: $filename")
    return fig
end

"""
    save_streamplot(state, filename; density=1.0, arrow_size=6)

Generates and saves a high-quality vector streamplot of the flow field.

This function uses `Interpolations.jl` to create a continuous velocity field 
from the discrete LBM grid, which is required by Makie's `streamplot` algorithm.

# Arguments
- `state`: The final `SimulationState`.
- `filename`: Output filename (e.g., "streamplot.png" or ".svg").
- `density`: Visual density of the streamlines (default: 1.5).
- `arrow_size`: Size of the flow direction arrows.
"""
function save_streamplot(
    state::SimulationState, 
    filename::String="streamplot.png"; 
    density::Float64=1.5,
    arrow_size::Int=6
)
    println("Generating Streamplot: $filename ...")
    
    nx, ny = size(state.rho)
    # Define ranges as Float32 for compatibility with Makie internals
    x_range = 1f0:Float32(nx)
    y_range = 1f0:Float32(ny)

    # 1. Prepare Data
    # Convert velocity fields to Float32
    u_data = Float32.(state.u)
    v_data = Float32.(state.v)
    
    # 2. Prepare Obstacle Mask
    # We convert the Boolean mask to Float. 
    # `1.0` represents solid (drawn in gray).
    # `NaN` represents fluid (transparent/not drawn).
    mask_float = [m ? 1.0 : NaN for m in state.mask]

    # 3. Create Interpolators
    # Makie's streamplot needs to query velocity at arbitrary (float) coordinates.
    # We use linear interpolation with zero-velocity extrapolation at boundaries.
    u_itp = linear_interpolation((x_range, y_range), u_data, extrapolation_bc=0.0)
    v_itp = linear_interpolation((x_range, y_range), v_data, extrapolation_bc=0.0)

    # Define the vector field function f(x,y) -> Point2f(u,v)
    vel_field(x, y) = Point2f(u_itp(x, y), v_itp(x, y))

    # 4. Plotting
    fig = Figure(size = (nx*3, ny*3)) # Scale figure size to domain aspect ratio
    ax = Axis(
        fig[1, 1], 
        title="Flow Streamlines (Final State)", 
        xlabel="X", ylabel="Y", 
        aspect=DataAspect()
    )

    # Layer 1: Draw the obstacle (Cylinder/Walls)
    CairoMakie.heatmap!(ax, x_range, y_range, mask_float, colormap=[:gray30], colorrange=(0,1))

    # Layer 2: Draw the streamlines
    streamplot!(
        ax, vel_field, x_range, y_range,
        colormap = :viridis, # Color indicates velocity magnitude
        arrow_size = arrow_size,
        density = density,
        linewidth = 1.0
    )

    save(filename, fig)
    println("Image saved successfully.")
    return fig
end

"""
    plot_force_history(force_history, measure_interval, filename; dt=1.0)

Generates a diagnostic plot of Aerodynamic Coefficients (Cd and Cl) over time.

This function creates a dual-axis plot:
1. **Top:** Drag Coefficient (Cd). Includes the mean value over the last 50% of steps.
2. **Bottom:** Lift Coefficient (Cl). Shows the oscillation amplitude.

# Arguments
- `force_history`: Vector of `ForceData` structs.
- `measure_interval`: Integer, how often forces were measured (e.g., every 10 steps).
- `filename`: Output filename (e.g., "forces_history.png").
"""
function plot_force_history(
    force_history::Vector{ForceData{T}}, 
    measure_interval::Int, 
    filename::String="forces_history.png"
) where {T}
    
    if isempty(force_history)
        @warn "Force history is empty. Cannot plot."
        return
    end

    println("Generating Force History Plot: $filename ...")

    # 1. Extract Data
    # Create a time vector corresponding to simulation steps
    steps = (1:length(force_history)) .* measure_interval
    
    cd_data = [f.Cd for f in force_history]
    cl_data = [f.Cl for f in force_history]

    # 2. Calculate Statistics (Steady State Estimate)
    # We analyze the last 50% of the simulation to avoid initial transients
    n_samples = length(cd_data)
    steady_start = div(n_samples, 2)
    
    cd_mean = mean(cd_data[steady_start:end])
    cl_amp = (maximum(cl_data[steady_start:end]) - minimum(cl_data[steady_start:end])) / 2.0

    # 3. Setup Figure (Dual Plot)
    fig = Figure(size = (800, 600))
    
    # --- Subplot 1: Drag Coefficient (Cd) ---
    ax_cd = Axis(
        fig[1, 1],
        title = "Drag Coefficient (Cd)",
        ylabel = "Cd",
        xlabel = "Time Steps"
    )
    
    lines!(ax_cd, steps, cd_data, color = :blue, label = "Cd Signal")
    hlines!(ax_cd, [cd_mean], color = :orange, linestyle = :dash, label = "Mean (Last 50%)")
    
    # Add text annotation for the mean value
    text!(
        ax_cd, 
        steps[1], cd_mean, 
        text = "Mean Cd ≈ $(round(cd_mean, digits=4))", 
        align = (:left, :bottom),
        fontsize = 12
    )
    axislegend(ax_cd, position = :rt)

    # --- Subplot 2: Lift Coefficient (Cl) ---
    ax_cl = Axis(
        fig[2, 1],
        title = "Lift Coefficient (Cl)",
        ylabel = "Cl",
        xlabel = "Time Steps"
    )
    
    lines!(ax_cl, steps, cl_data, color = :red, label = "Cl Signal")
    hlines!(ax_cl, [0.0], color = :black, linewidth = 0.5) # Zero line reference
    
    # Annotation for amplitude
    text!(
        ax_cl, 
        steps[1], maximum(cl_data)*0.8, 
        text = "Amplitude ≈ ±$(round(cl_amp, digits=4))", 
        align = (:left, :top),
        fontsize = 12
    )

    # 4. Save
    save(filename, fig)
    println("Plot saved successfully.")
    return fig
end