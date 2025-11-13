"""
    generate_vorticity_gif(snapshots, filename)

Gera um GIF animado a partir da lista de snapshots usando CairoMakie.
"""
function generate_vorticity_gif(snapshots, filename="vorticity.gif")
    if isempty(snapshots)
        @warn "Lista de snapshots vazia!"
        return
    end

    println("Gerando GIF a partir de $(length(snapshots)) frames...")

    # Extrair dimensões
    nx, ny = size(snapshots[1].data)
    
    # Criar Observables (Dados que mudam dinamicamente)
    # Começamos com o primeiro frame
    obs_time = Observable(snapshots[1].t)
    obs_vort = Observable(snapshots[1].data)

    # Configurar Figura
    fig = Figure(size = (800, 300))
    ax = Axis(
        fig[1, 1], 
        title = @lift("Vorticity Field (t = $($obs_time))"), # Título dinâmico
        xlabel = "X", ylabel = "Y",
        aspect = DataAspect()
    )

    # Configurar Heatmap
    # Note: Usamos transpose (rot90 ou permutedims) se necessário para alinhar eixos
    # Makie plota matrizes [x,y], então geralmente está ok sem transpor, 
    # mas visualmente depende de como calculamos.
    hm = CairoMakie.heatmap!(
        ax, 
        obs_vort, 
        colormap = :balance, # Azul -> Branco -> Vermelho
        colorrange = (-0.02, 0.02) # Fixar a escala para não piscar
    )
    Colorbar(fig[1, 2], hm, label="Vorticity")

    # Loop de Gravação (Record)
    record(fig, filename, snapshots; framerate = 15) do snap
        # Atualizamos os Observables com os dados do snapshot atual
        obs_time[] = snap.t
        obs_vort[] = snap.data
        # O Makie atualiza o plot automaticamente aqui
    end

    println("GIF salvo: $filename")
    return fig
end

# --- Gerar o GIF ---
generate_vorticity_gif(snapshots_vorticity, "von_karman_vorticity.gif")






println("Gerando Streamplot de Alta Qualidade...")

# --- 1. Preparação dos Dados ---
# Makie prefere Float32 para visualização
x_range = 1f0:Float32(NX_SIM)
y_range = 1f0:Float32(NY_SIM)

u_data = Float32.(state_sim.u)
v_data = Float32.(state_sim.v)

# Preparar Máscara para Visualização (1.0 = Sólido, NaN = Transparente)
# Isso permite desenhar o cilindro em cinza sobre o fundo branco
mask_float = [m ? 1.0 : NaN for m in state_sim.mask]

# --- 2. Criar Interpoladores ---
# Define que u_data[i, j] está em x_range[i], y_range[j]
u_itp = linear_interpolation((x_range, y_range), u_data, extrapolation_bc=0.0)
v_itp = linear_interpolation((x_range, y_range), v_data, extrapolation_bc=0.0)

# Função de campo vetorial que o streamplot consome
function vel_field(x, y)
    return Point2f(u_itp(x, y), v_itp(x, y))
end

# --- 3. Configurar Figura ---
# Tamanho mais largo (800x300) pois o canal é comprido (300x100)
fig = Figure(size = (900, 350)) 

ax = Axis(
    fig[1, 1], 
    title="Von Karman Vortex Street (Re=$RE_SIM, t=Final)",
    xlabel="X (Lattice Nodes)",
    ylabel="Y (Lattice Nodes)",
    aspect=DataAspect() # Mantém a proporção correta 1:1 dos pixels
)

# --- 4. Desenhar o Cilindro/Paredes ---
# Usamos heatmap para desenhar a máscara sólida em cinza escuro
CairoMakie.heatmap!(
    ax, 
    x_range, y_range, mask_float, 
    colormap=[:gray30], 
    colorrange=(0,1)
)

# --- 5. Desenhar as Linhas de Corrente (Streamplot) ---
streamplot!(
    ax,
    vel_field,
    x_range,
    y_range,
    colormap = :viridis, # Cor baseada na magnitude da velocidade
    arrow_size = 6,
    density = 1.5,       # Aumente para mais linhas, diminua para menos
    linewidth = 1.0
)

# --- 6. Salvar e Exibir ---
save("von_karman_final.png", fig)
save("von_karman_final.svg", fig)

println("Plot salvo como 'von_karman_final.png'")
fig # Exibir no notebook