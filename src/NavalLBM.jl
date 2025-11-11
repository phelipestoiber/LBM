# src/NavalLBM.jl

module NavalLBM

using StaticArrays

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

end # module NavalLBM
