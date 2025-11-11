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