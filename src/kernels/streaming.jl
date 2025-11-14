# src/NavalLBM/kernels/streaming.jl

"""
    streaming!(state::SimulationState{T}) where {T}

Performs the LBM streaming step (propagation).

This kernel simulates the movement of populations from one node
to the next according to their discrete velocity vector `c_k`.

We use a "pull" scheme, which is generally more cache-friendly
and easier to parallelize. The logic is:
"The new `f_in` at node `(i, j)` for direction `k` is pulled from
the `f_out` at the *source* node `(i_src, j_src)`."

`f_in[i, j, k] = f_out[i_src, j_src, k]`
where `i_src = i - c_k_x` and `j_src = j - c_k_y`.

This function reads from `state.f_out` and writes to `state.f_in`.

# Arguments
- `state`: The `SimulationState` object.
           - Reads from: `state.f_out`, `state.params`.
           - Writes to: `state.f_in`.
"""
function streaming!(state::SimulationState{T}) where {T<:AbstractFloat}

    nx, ny = size(state.rho)
    c = state.params.c # Get reference to velocity vectors

    # Loop over all destination nodes
    # (Note: This loop order is cache-friendly for f_in[i, j, k])
    # (Future optimization: use Threads.@threads for j loop)
    Threads.@threads for j in 1:ny
        @fastmath @inbounds for i in 1:nx
            # Loop over all 9 directions
            @simd for k in 1:9
                # 1. Get the velocity vector c_k
                cx = c[k, 1]
                cy = c[k, 2]

                # 2. Calculate the source node coordinates
                i_src = i - cx
                j_src = j - cy

                # 3. Apply periodic boundary conditions (wrap-around)
                #    (This is temporary; real boundaries will replace this)
                
                # `mod1(x, L)` is the Julia function for 1-based modulo.
                # It wraps `x` into the range `[1, L]`.
                # Ex: mod1(0, 50) -> 50
                # Ex: mod1(51, 50) -> 1
                i_src_periodic = mod1(i_src, nx)
                j_src_periodic = mod1(j_src, ny)

                # 4. Pull the population from the source node
                state.f_in[i, j, k] = state.f_out[i_src_periodic, j_src_periodic, k]
            end
        end
    end

    return nothing # Function modifies in-place
end