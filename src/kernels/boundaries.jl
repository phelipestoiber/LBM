# src/NavalLBM/kernels/boundaries.jl

using StaticArrays

# -----------------------------------------------------------------
# BOUNCE-BACK MAPPING CONSTANT
# -----------------------------------------------------------------
"""
    const K_OPPOSITE::SVector{9, Int}

A static lookup table mapping each lattice direction `k` to its opposite.
Used for the Bounce-Back boundary condition.

# Mapping (1-based index):
- k=1 (Rest) -> k=1 (Rest)
- k=2 (E)    -> k=4 (W)
- k=3 (N)    -> k=5 (S)
- ... and so on.
"""
const K_OPPOSITE = SVector{9, Int}(1, 4, 5, 2, 3, 8, 9, 6, 7)


"""
    apply_bounce_back!(state::SimulationState{T}) where {T}

Applies the **Half-Way Bounce-Back** boundary condition for no-slip walls.

This kernel enforces zero velocity (`u=0, v=0`) at solid boundaries defined by `state.mask`.
It reflects populations hitting a wall back in the direction they came from.

# Execution Order
Must be called **after** `streaming!` and **before** `collision!`.

# Algorithm
For every node `(i, j)` where `mask == true`:
1. Read the incoming populations `f_in` (which just arrived from neighbors).
2. Reflect them: `f_in_new[k] = f_in_old[opposite(k)]`.

# Performance
Uses a stack-allocated `MVector` (`f_temp`) to perform the swap without
allocating heap memory.
"""
function apply_bounce_back!(state::SimulationState{T}) where {T<:AbstractFloat}
    
    nx, ny = size(state.mask)
    
    # Stack-allocated temporary buffer for swapping directions.
    # Zero GC overhead.
    f_temp = MVector{9, T}(undef)

    @fastmath @inbounds for j in 1:ny
        for i in 1:nx
            # Check if the current node is a solid wall
            if state.mask[i, j]
                
                # 1. Load the populations that just streamed into the wall
                for k in 1:9
                    f_temp[k] = state.f_in[i, j, k]
                end

                # 2. Reflect populations back to where they came from
                for k in 1:9
                    state.f_in[i, j, k] = f_temp[ K_OPPOSITE[k] ]
                end
            end
        end
    end
    return nothing # Function modifies in-place
end

"""
    apply_lid_velocity!(state, u_lid)

Applies the **Moving Lid** boundary condition (Top Wall, j=ny).

# Physics
Simulates a moving wall with velocity `(u_lid, 0)`. It uses an **Equilibrium BC** approach:
1. Density (`rho`) is extrapolated from the fluid node directly below (`ny-1`).
2. Equilibrium distributions (`feq`) are calculated using this extrapolated density and the prescribed wall velocity.
3. The populations at the boundary are forced to this equilibrium state.

# Arguments
- `state`: The `SimulationState` object.
- `u_lid`: The prescribed velocity of the lid in lattice units.
"""
function apply_lid_velocity!(
    state::SimulationState{T}, 
    u_lid::T
) where {T<:AbstractFloat}
    
    nx, ny = size(state.rho)
    
    # Stack-allocated buffer for equilibrium calculation
    feq_local = MVector{9, T}(undef)
    
    # Wall velocity vector
    v_lid = T(0.0)

    # Iterate over the top lid (excluding corners handled by bounce-back)
    @fastmath @inbounds for i in 2:(nx-1)
        
        # 1. Extrapolate density from the fluid domain
        rho_wall = state.rho[i, ny - 1]
        
        # 2. Calculate equilibrium for the wall state
        calculate_feq!(
            feq_local, 
            rho_wall, 
            u_lid, 
            v_lid, 
            state.params
        )
        
        # 3. Overwrite populations with equilibrium values
        for k in 1:9
            state.f_in[i, ny, k] = feq_local[k]
        end
    end
    return nothing # Function modifies in-place
end

"""
    apply_zou_he_inlet!(state, u_in)

Applies the **Zou-He Velocity Inlet** boundary condition (West Wall, i=1).

# Physics
Prescribes a fixed velocity `(u_in, 0)` while solving for the unknown density `rho`
and the unknown populations that are streaming into the domain from the boundary.

# Source
Zou, Q., & He, X. (1997). "On pressure and velocity boundary conditions for the lattice Boltzmann BGK model." *Physics of Fluids*.
"""
function apply_zou_he_inlet!(
    state::SimulationState{T}, 
    u_in::T
) where {T<:AbstractFloat}
    
    _, ny = size(state.rho)
    feq_local = MVector{9, T}(undef)

    @inbounds for j in 2:ny-1 # Iterate inlet nodes (skip corners)
        # 1. Prescribe macroscopic velocity
        state.u[1, j] = u_in
        state.v[1, j] = 0.0

        # 2. Calculate unknown density from known populations
        # Knowns: f[1,3,5] (transverse) and f[4,7,8] (streaming from fluid interior)
        f = @view state.f_in[1, j, :]
        
        rho_local = (f[1] + f[3] + f[5] + 2 * (f[4] + f[7] + f[8])) / (1.0 - u_in)
        
        # Numerical stability check
        if rho_local <= 0.0 
             rho_local = 1.0
        end
        state.rho[1, j] = rho_local

        # 3. Calculate equilibrium with the resolved rho and u
        calculate_feq!(feq_local, rho_local, u_in, 0.0, state.params)
        
        # 4. Reconstruct missing non-equilibrium parts for incoming populations (k=2, 6, 9)
        f[2] = feq_local[2] + feq_local[4] - f[4]
        f[6] = feq_local[6] + feq_local[8] - f[8]
        f[9] = feq_local[9] + feq_local[7] - f[7]
    end
    return nothing
end

"""
    apply_zou_he_outlet!(state, rho_out)

Applies the **Zou-He Pressure/Density Outlet** boundary condition (East Wall, i=nx).

# Physics
Prescribes a fixed density `rho_out` (simulating constant pressure). 
Velocity is extrapolated from the interior assuming a zero-gradient condition (`∂u/∂x = 0`).

# Source
Zou, Q., & He, X. (1997). "On pressure and velocity boundary conditions for the lattice Boltzmann BGK model." *Physics of Fluids*.
"""
function apply_zou_he_outlet!(
    state::SimulationState{T}, 
    rho_out::T
) where {T<:AbstractFloat}
    
    nx, ny = size(state.rho)
    feq_local = MVector{9, T}(undef)

    @fastmath @inbounds for j in 2:ny-1 # Iterate outlet nodes (skip corners)
        # 1. Prescribe density
        state.rho[nx, j] = rho_out
        
        # 2. Extrapolate velocity (Zero-Gradient approximation)
        u_local = state.u[nx-1, j]
        v_local = state.v[nx-1, j]
        state.u[nx, j] = u_local
        state.v[nx, j] = v_local
        
        f = @view state.f_in[nx, j, :] # Get view of f_in at this node
        
        # 3. Calculate equilibrium with prescribed rho and extrapolated u
        calculate_feq!(feq_local, rho_out, u_local, v_local, state.params)
        
        # 4. Reconstruct missing non-equilibrium parts (k=4, 7, 8)
        f[4] = feq_local[4] + feq_local[2] - f[2]
        f[7] = feq_local[7] + feq_local[9] - f[9]
        f[8] = feq_local[8] + feq_local[6] - f[6]
    end
    return nothing
end