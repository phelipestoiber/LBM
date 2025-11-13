# src/NavalLBM/kernels/boundaries.jl

using StaticArrays

# -----------------------------------------------------------------
# CONSTANTE DE MAPEAMENTO DE BOUNCE-BACK
# -----------------------------------------------------------------
"""
    const K_OPPOSITE::SVector{9, Int}

A static mapping of each lattice direction `k` to its opposite.
`K_OPPOSITE[k]` gives the index of the direction opposite to `k`.

(1-based indexing)
- k=1 (0,0)  -> k=1 (0,0)
- k=2 (1,0)  -> k=4 (-1,0)
- k=3 (0,1)  -> k=5 (0,-1)
- k=4 (-1,0) -> k=2 (1,0)
- k=5 (0,-1) -> k=3 (0,1)
- k=6 (1,1)  -> k=8 (-1,-1)
- k=7 (-1,1) -> k=9 (1,-1)
- k=8 (-1,-1)-> k=6 (1,1)
- k=9 (1,-1) -> k=7 (-1,1)
"""
const K_OPPOSITE = SVector{9, Int}(1, 4, 5, 2, 3, 8, 9, 6, 7)


"""
    apply_bounce_back!(state::SimulationState{T}) where {T}

Applies the on-grid "bounce-back" boundary condition.

This function must be called *after* the `streaming!` step.
It iterates over the domain. If a node `(i, j)` is marked as
a solid boundary (`state.mask[i, j] == true`), it takes all
populations that just streamed *into* that node (`state.f_in`)
and reflects them.

`f_in[i, j, k] = f_in_temp[ K_OPPOSITE[k] ]`

This simulates a no-slip boundary (u=0, v=0) at the wall.

# Arguments
- `state`: The `SimulationState` object.
           - Reads from: `state.mask`, `state.f_in`.
           - Writes to: `state.f_in`.
"""
function apply_bounce_back!(state::SimulationState{T}) where {T<:AbstractFloat}
    
    nx, ny = size(state.mask)
    
    # Buffer temporário alocado na stack (como em collision_bgk!)
    # para garantir zero alocações.
    f_temp = MVector{9, T}(undef)

    @inbounds for j in 1:ny
        for i in 1:nx
            # Verifica se o nó atual (i, j) é uma parede
            if state.mask[i, j]
                
                # 1. Copia as 9 populações que acabaram
                #    de "pousar" neste nó de parede
                for k in 1:9
                    f_temp[k] = state.f_in[i, j, k]
                end

                # 2. Reflete as populações
                # A nova f_in[k] é a f_temp[oposta de k]
                for k in 1:9
                    state.f_in[i, j, k] = f_temp[ K_OPPOSITE[k] ]
                end
            end
        end
    end

    return nothing # Function modifies in-place
end

"""
    apply_lid_velocity!(
        state::SimulationState{T}, 
        u_lid::T
    ) where {T}

Applies the "Lid" velocity boundary condition (Equilibrium BC)
to the top wall (j=ny).

This function must be called *after* `streaming!` and *after*
`apply_bounce_back!`. It overwrites the populations at the
top boundary `(i, ny)`.

It uses the "Equilibrium Boundary Condition" method:
1. Extrapolate density `rho` from the fluid node below (`j=ny-1`).
2. Calculate `feq` based on this `rho` and the lid velocity `(u_lid, 0)`.
3. Force the populations at `f_in[i, ny, k]` to this `feq`.

# Arguments
- `state`: The `SimulationState` object.
- `u_lid`: The target velocity of the lid (x-component).
"""
function apply_lid_velocity!(
    state::SimulationState{T}, 
    u_lid::T
) where {T<:AbstractFloat}
    
    nx, ny = size(state.rho)
    
    # Buffer alocado na stack (como em collision_bgk!)
    feq_local = MVector{9, T}(undef)
    
    # A velocidade da parede (Lid) é (u_lid, 0.0)
    v_lid = T(0.0)

    # Loop apenas nos nós da tampa (j = ny)
    # Pular os cantos (i=1 e i=nx), pois já são
    # paredes de bounce-back.
    @inbounds for i in 2:(nx-1)
        
        # 1. Extrapolar a densidade do nó fluido abaixo
        rho_wall = state.rho[i, ny - 1]
        
        # 2. Calcular feq para o estado da parede
        calculate_feq!(
            feq_local, 
            rho_wall, 
            u_lid, 
            v_lid, 
            state.params
        )
        
        # 3. Forçar as populações f_in (pós-streaming) 
        #    a este valor de equilíbrio.
        for k in 1:9
            state.f_in[i, ny, k] = feq_local[k]
        end
    end
    
    return nothing # Function modifies in-place
end

"""
    apply_zou_he_inlet!(
        state::SimulationState{T}, 
        u_in::T
    ) where {T<:AbstractFloat}

Applies the Zou-He velocity boundary condition at the inlet (left wall, i=1).

Assumes a prescribed velocity (u_in, 0) and an unknown density, which is
calculated from the known populations.

This function modifies `state.rho`, `state.u`, `state.v`, and `state.f_in`
at the boundary `i=1`.
It must be called *after* streaming and *before* collision.

# Source
- Zou, Q., & He, X. (1997). "On pressure and velocity boundary conditions
  for the lattice Boltzmann BGK model." Physics of Fluids.
"""
function apply_zou_he_inlet!(
    state::SimulationState{T}, 
    u_in::T
) where {T<:AbstractFloat}
    
    _, ny = size(state.rho)
    feq_local = MVector{9, T}(undef)

    @inbounds for j in 2:ny-1 # Iterate inlet nodes (skip corners)
        # 1. Prescribe velocity, v=0
        state.u[1, j] = u_in
        state.v[1, j] = 0.0

        # 2. Calculate rho from known (streamed) populations
        # f[1,3,5] (parallel) and f[4,7,8] (from fluid) are known
        f = @view state.f_in[1, j, :] # Get view of f_in at this node
        
        rho_local = (f[1] + f[3] + f[5] + 2 * (f[4] + f[7] + f[8])) / (1.0 - u_in)
        
        if rho_local <= 0.0 # Safety check
             rho_local = 1.0
        end
        state.rho[1, j] = rho_local

        # 3. Calculate feq with known u,v,rho
        calculate_feq!(feq_local, rho_local, u_in, 0.0, state.params)
        
        # 4. Reconstruct unknown populations (k=2, 6, 9)
        f[2] = feq_local[2] + feq_local[4] - f[4]
        f[6] = feq_local[6] + feq_local[8] - f[8]
        f[9] = feq_local[9] + feq_local[7] - f[7]
    end
    return nothing
end

"""
    apply_zou_he_outlet!(
        state::SimulationState{T}, 
        rho_out::T
    ) where {T<:AbstractFloat}

Applies the Zou-He pressure/density boundary condition at the outlet (right wall, i=nx).

Assumes a prescribed density `rho_out` (e.g., 1.0) and extrapolates
velocity (u, v) from the adjacent fluid node (zero-gradient).

This function modifies `state.rho`, `state.u`, `state.v`, and `state.f_in`
at the boundary `i=nx`.
It must be called *after* streaming and *before* collision.

# Source
- Zou, Q., & He, X. (1997). "On pressure and velocity boundary conditions
  for the lattice Boltzmann BGK model." Physics of Fluids.
"""
function apply_zou_he_outlet!(
    state::SimulationState{T}, 
    rho_out::T
) where {T<:AbstractFloat}
    
    nx, ny = size(state.rho)
    feq_local = MVector{9, T}(undef)

    @inbounds for j in 2:ny-1 # Iterate outlet nodes (skip corners)
        # 1. Prescribe density
        state.rho[nx, j] = rho_out
        
        # 2. Extrapolate velocity (zero-gradient)
        u_local = state.u[nx-1, j]
        v_local = state.v[nx-1, j]
        state.u[nx, j] = u_local
        state.v[nx, j] = v_local
        
        f = @view state.f_in[nx, j, :] # Get view of f_in at this node
        
        # 3. Calculate feq with prescribed rho and extrapolated u,v
        calculate_feq!(feq_local, rho_out, u_local, v_local, state.params)
        
        # 4. Reconstruct unknown populations (k=4, 7, 8)
        f[4] = feq_local[4] + feq_local[2] - f[2]
        f[7] = feq_local[7] + feq_local[9] - f[9]
        f[8] = feq_local[8] + feq_local[6] - f[6]
    end
    return nothing
end