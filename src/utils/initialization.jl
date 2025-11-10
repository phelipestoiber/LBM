# src/NavalLBM/utils/initialization.jl

"""
    initialize_state(
        nx::Int, 
        ny::Int, 
        tau::Float64; 
        T::DataType = Float64
    ) -> SimulationState

Allocates and initializes a new `SimulationState` object.

This function performs all the necessary memory allocations for the simulation
grids. It initializes the fluid to a state of rest (u=0, v=0) with a 
uniform density (rho=1.0). The populations `f_in` and `f_out` are
set to the equilibrium distribution corresponding to this rest state.

# Arguments
- `nx::Int`: Domain size in the x-direction.
- `ny::Int`: Domain size in the y-direction.
- `tau::Float64`: Relaxation time.
- `T::DataType = Float64`: The floating-point type for the arrays (e.g., 
                           `Float64` for CPU, `Float32` for GPU/memory saving).

# Returns
- `SimulationState`: A fully initialized struct ready for simulation.
"""
function initialize_state(
    nx::Int, 
    ny::Int, 
    tau::Float64; 
    T::DataType = Float64
)
    # 1. Get D2Q9 parameters
    params = D2Q9Params()

    # 2. Allocate all arrays with type T
    f_in = Array{T, 3}(undef, nx, ny, 9)
    f_out = Array{T, 3}(undef, nx, ny, 9)
    rho = Array{T, 2}(undef, nx, ny)
    u = Array{T, 2}(undef, nx, ny)
    v = Array{T, 2}(undef, nx, ny)
    mask = Array{Bool, 2}(undef, nx, ny)

    # 3. Define initial macroscopic state (rest)
    rho_init = 1.0
    u_init = 0.0
    v_init = 0.0

    # 4. Calculate the equilibrium for the rest state
    # We need a buffer to pass to our kernel
    feq_local = zeros(T, 9)
    calculate_feq!(feq_local, T(rho_init), T(u_init), T(v_init), params)

    # 5. Initialize all grid points to this state
    for j in 1:ny
        for i in 1:nx
            # Set macroscopic values
            rho[i, j] = T(rho_init)
            u[i, j] = T(u_init)
            v[i, j] = T(v_init)
            
            # Initialize mask as fluid (false)
            mask[i, j] = false 

            # Set all 9 populations to the equilibrium value
            for k in 1:9
                f_in[i, j, k] = feq_local[k]
                f_out[i, j, k] = feq_local[k]
            end
        end
    end

    # 6. Construct and return the SimulationState
    # O tipo de Array 'A' é inferido automaticamente
    return SimulationState(
        f_in, f_out, 
        rho, u, v, 
        mask, 
        params, 
        T(tau)
    )
end

"""
    create_cylinder_mask!(
        state::SimulationState, 
        center_x::Int, 
        center_y::Int, 
        radius::Int
    )

Creates a solid circular mask (cylinder) within the domain.

Modifies `state.mask` in-place, setting all nodes `(i, j)` that
fall within the specified radius of the center to `true` (solid).

# Arguments
- `state`: The `SimulationState` object to be modified.
- `center_x`: The x-coordinate (index) of the cylinder's center.
- `center_y`: The y-coordinate (index) of the cylinder's center.
- `radius`: The radius of the cylinder (in grid nodes).
"""
function create_cylinder_mask!(
    state::SimulationState, 
    center_x::Int, 
    center_y::Int, 
    radius::Int
)
    nx, ny = size(state.mask)
    radius_sq = radius^2 # Precompute radius squared
    
    @inbounds for j in 1:ny
        for i in 1:nx
            # Calculate distance squared from center
            dist_sq = (i - center_x)^2 + (j - center_y)^2
            
            if dist_sq <= radius_sq
                state.mask[i, j] = true
            end
        end
    end
    
    return nothing # Function modifies in-place
end