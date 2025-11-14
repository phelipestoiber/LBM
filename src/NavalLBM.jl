# src/NavalLBM.jl

module NavalLBM

# --- External Dependencies ---
using StaticArrays      # For high-performance fixed-size arrays (SVector, SMatrix)
using Plots             # Legacy plotting support
using ProgressMeter     # For simulation progress bars
using BenchmarkTools    # For performance profiling
using CairoMakie        # For high-quality vector graphics and animations
using FFTW              # For spectral analysis (Strouhal number)
using Statistics        # For statistical calculations (mean, etc.)
using Test              # For unit testing
using Interpolations    # For continuous field reconstruction (streamplots)

# --- Internal Modules & Files ---

# 1. Core Data Structures
include("core/types.jl")

# 2. LBM Kernels (The Physics)
include("kernels/collision.jl")
include("kernels/streaming.jl")
include("kernels/boundaries.jl")
include("kernels/macros.jl")

# 3. Solvers & Control Logic
include("core/solver.jl")

# 4. Utilities & Post-Processing
include("utils/initialization.jl")
include("utils/analysis.jl")
include("utils/visualization.jl")

# --- API Exports ---

# Types
export D2Q9Params, SimulationState, VorticitySnapshot

# Initialization
export initialize_state, create_cylinder_mask!, create_cavity_mask!

# Kernels
export calculate_feq!, calculate_macros!, collision_bgk!, streaming!
export apply_bounce_back!, apply_lid_velocity!, apply_zou_he_inlet!, apply_zou_he_outlet!

# Solver
export run_simulation!

# Analysis & Visualization
export calculate_vorticity
export generate_vorticity_gif, save_streamplot, plot_force_history
export calculate_forces, ForceData

end # module NavalLBM
