### Roadmap Discretizado: `NavalLBM`



#### Fase 0: Fundação e Estrutura do Projeto



*Objetivo: Configurar um ambiente de desenvolvimento Julia limpo, versionável e padronizado.*



**0.1. Criação do Ambiente**



**Pseudo-algoritmo:**

1.  Criar a pasta principal `NavalLBM/`.

2.  Inicializar um repositório Git: `git init`.

3.  Criar um arquivo `.gitignore` (padrão Julia, ignorando `Manifest.toml`, `build/`, `*.log`, etc.).

**Validação:** O repositório existe e está "limpo".



**0.2. Estrutura do Pacote Julia**



**Pseudo-algoritmo:**

1.  Dentro da pasta `NavalLBM/`, inicie o REPL do Julia.

2.  Entre no modo `Pkg` (digitando `]`).

3.  Execute `generate NavalLBM` (Isso criará `NavalLBM/NavalLBM/` com `Project.toml` e `src/NavalLBM.jl`).

4.  *Correção de Estrutura:* Mova os arquivos gerados ( `Project.toml`, `src/`) para a pasta raiz `NavalLBM/`. Delete a sub-pasta `NavalLBM/NavalLBM/` vazia.

**Validação:** Você tem um `Project.toml` válido na raiz do projeto.



**0.3. Declaração de Dependências**



**Pseudo-algoritmo:**

1.  No REPL do Julia (na raiz do projeto), entre no modo `Pkg`.

2.  Execute `activate .` (para ativar o ambiente local).

3.  Execute `add StaticArrays, Plots, BenchmarkTools, Images`.

**Validação:** O `Project.toml` agora lista essas dependências. O `Manifest.toml` foi criado.



**0.4. Estrutura de Pastas (Arquitetura)**



**Pseudo-algoritmo:**

1.  Dentro de `NavalLBM/`, crie as pastas:

* `notebooks/` (para exploração e validação).

* `test/` (para testes de unidade formais).

* `data/` (para máscaras de geometria, etc.).

2.  Dentro de `src/`, crie as sub-pastas:

* `core/`

* `kernels/`

* `utils/`

**Validação:** A estrutura de pastas corresponde à arquitetura que definimos.



**0.5. Configuração do Módulo (O "Hub")**



**Pseudo-algoritmo:**

1.  Editar o arquivo `src/NavalLBM.jl`.

2.  Ele deve conter:

    ```

    module NavalLBM



    # Incluir os arquivos de tipos e kernels

    include("core/types.jl")

    include("kernels/collision.jl")

    # ... (outros includes que adicionaremos)



    # Exportar as funções e tipos que queremos usar

    export D2Q9Params, SimulationState

    export initialize_state

    # ... (outros exports que adicionaremos)



    end # module

    ```

**Validação:** No REPL, `using NavalLBM` deve funcionar (embora os `include`s falhem até criarmos os arquivos).



-----



#### Fase 1: Definição dos Tipos de Dados (Contratos)



*Objetivo: Definir os "contêineres" de dados. A estabilidade de tipos (Type Stability) começa aqui.*



**1.1. Arquivo: `src/core/types.jl` - Constantes D2Q9**



**Pseudo-algoritmo:**

1.  Definir `struct D2Q9Params`.

2.  Campos:

* `w::SVector{9, Float64}` (pesos).

* `c::SMatrix{9, 2, Int}` (vetores de velocidade).

3.  Definir um construtor `D2Q9Params()` (função) que preenche e retorna o *struct* com os valores corretos de `w` (4/9, 1/9...) e `c` ([0 0], [1 0]...).

**Validação (em `notebooks/00_validation.ipynb`):**

  * `params = D2Q9Params()`

  **CHECK:** `sum(params.w)` deve ser `1.0` (com tolerância, `isapprox`).

  **CHECK:** `params.c[:, 1]` (vetor `k=0`, coluna-major) deve ser `[0, 0]`.

  **CHECK:** `params.c[:, 2]` (vetor `k=1`) deve ser `[1, 0]`.



**1.2. Arquivo: `src/core/types.jl` - Estado da Simulação**



**Pseudo-algoritmo:**

1.  Definir `struct SimulationState{T<:AbstractFloat}` (paramétrico).

2.  Campos:

* `f_in::Array{T, 3}` (distribuições pós-streaming).

* `f_out::Array{T, 3}` (distribuições pós-colisão).

* `rho::Array{T, 2}` (densidade).

* `u::Array{T, 2}` (velocidade x).

* `v::Array{T, 2}` (velocidade y).

* `mask::Array{Bool, 2}` (máscara de fronteira).

* `params::D2Q9Params` (as constantes).

* `tau::T` (tempo de relaxação).

**Validação:** A simples existência do *struct*. A validação real virá na inicialização.



-----



#### Fase 2: Implementação dos Kernels (O "Motor")



*Objetivo: Implementar cada passo de física (LBM) como uma função *in-place* (`!`) e validá-la **isoladamente**.*



**2.1. Arquivo: `src/kernels/collision.jl` - Equilíbrio (`feq`)**



**Pseudo-algoritmo:**

1.  Definir `function calculate_feq!(feq_local, rho, u, v, params)`.

2.  (Marcar com `@inline` para performance).

3.  Argumentos: `feq_local` (buffer `Vector{Float64}` de 9 posições), `rho`, `u`, `v` (escalares), `params` (o `D2Q9Params`).

4.  *Lógica:*

* `uu = u*u + v*v`

* Loop `k` de 1 a 9:

    * `cu = params.c[1, k] * u + params.c[2, k] * v` (Nota: Julia é coluna-major, então `c` é `(direção, k)`) -\\> *Correção: definimos `c` como 9x2, então o acesso é `params.c[k, 1]` e `params.c[k, 2]`*.

    * `feq_local[k] = params.w[k] * rho * (1.0 + 3.0*cu + 4.5*cu*cu - 1.5*uu)`

    * (Citar fonte da fórmula em comentário).

**Validação (em `notebooks/00_validation.ipynb`):**

  * `params = D2Q9Params()`

  * `feq_buffer = zeros(9)`

  * `calculate_feq!(feq_buffer, 1.0, 0.1, 0.0, params)`

  **CHECK 1 (Massa):** `sum(feq_buffer)` deve ser `1.0`.

  **CHECK 2 (Momentum X):** `sum(feq_buffer .* params.c[:, 1])` deve ser `rho*u` (`0.1`).

  **CHECK 3 (Momentum Y):** `sum(feq_buffer .* params.c[:, 2])` deve ser `rho*v` (`0.0`).

  * *Repetir para `rho=1.2, u=0.0, v=-0.05` e re-validar os 3 CHECKS.*



**2.2. Arquivo: `src/utils/initialization.jl` - Construtor de Estado**



**Pseudo-algoritmo:**

1.  Definir `function initialize_state(nx, ny, tau)`

2.  *Lógica:*

* `params = D2Q9Params()`

* Alocar `f_in`, `f_out`, `rho`, `u`, `v`, `mask` (todos os arrays com os tamanhos corretos, ex: `nx, ny`).

* Alocar `feq_local = zeros(9)` (buffer temporário).

* `rho_init = 1.0`, `u_init = 0.0`, `v_init = 0.0`

* Chamar `calculate_feq!(feq_local, rho_init, u_init, v_init, params)` (a função do passo 2.1).

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx`:

    * `rho[i,j] = rho_init`, `u[i,j] = u_init`, `v[i,j] = v_init`.

    * `mask[i,j] = false`.

    * `f_in[i,j,:] = feq_local` (copiar o buffer).

    * `f_out[i,j,:] = feq_local` (copiar o buffer).

* `Retornar SimulationState(...)` com todos esses campos.

**Validação:**

  * `state = initialize_state(50, 50, 0.6)`

  **CHECK:** `state.rho[10, 10]` deve ser `1.0`.

  **CHECK:** `state.f_in[10, 10, 1]` deve ser `4/9` (o valor de `feq` em repouso para `k=0`, *não* `k=1`. `k=1` é `1/9`.).



**2.3. Arquivo: `src/kernels/macros.jl` - Cálculo de Momentos**



**Pseudo-algoritmo:**

1.  Definir `function calculate_macros!(state)`.

2.  *Lógica:*

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx`:

    * `rho_local = 0.0`, `u_local = 0.0`, `v_local = 0.0`

    * Loop `k` de 1 a 9 (usar `@inbounds` e `@simd` aqui):

        * `f = state.f_in[i,j,k]`

        * `rho_local += f`

        * `u_local += f * state.params.c[k, 1]`

        * `v_local += f * state.params.c[k, 2]`

    * `state.rho[i,j] = rho_local`

    * `state.u[i,j] = u_local / rho_local`

    * `state.v[i,j] = v_local / rho_local`

**Validação:**

  * `state = initialize_state(...)` (sabemos que `f_in` está em equilíbrio `(1,0,0)`).

  * `calculate_macros!(state)`

  **CHECK:** `state.rho` deve ser `1.0` em todo lugar (`isapprox`).

  **CHECK:** `state.u` e `state.v` devem ser `0.0` em todo lugar (`isapprox`).

  **Validação 2 (Mais Forte):**

* Preencher `state.f_in` com `feq` para `u=0.1` (usando `calculate_feq!`).

* Chamar `calculate_macros!(state)`.

**CHECK:** `state.u` deve ser `0.1` em todo lugar (`isapprox`).



**2.4. Arquivo: `src/kernels/collision.jl` - Colisão BGK**



**Pseudo-algoritmo:**

1.  Definir `function collision_bgk!(state)`.

2.  *Lógica:*

* `omega = 1.0 / state.tau`.

* Alocar `feq_local = zeros(9)` **uma vez**, *fora* dos loops.

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx`:

    * Chamar `calculate_feq!(feq_local, state.rho[i,j], state.u[i,j], state.v[i,j], state.params)`.

    * Loop `k` de 1 a 9 (usar `@inbounds` e `@simd`):

        * `f_in_k = state.f_in[i,j,k]`

        * `state.f_out[i,j,k] = f_in_k - omega * (f_in_k - feq_local[k])`

**Validação (Teste de Relaxamento):**

  * `state = initialize_state(...)`.

  **Perturbar:** `state.f_in[10, 10, :] .+= 0.1 * (rand(9) .- 0.5)` (adicionar ruído).

  * Chamar `calculate_macros!(state)` (para atualizar `rho, u, v` pós-ruído).

  * Chamar `collision_bgk!(state)` (calcula `f_out`).

  **CHECK (Performance):** `@btime collision_bgk!($state)` deve reportar **0 alocações**.

  **CHECK (Físico):** Os momentos de `state.f_out[10, 10, :]` devem ser *idênticos* aos momentos de `state.f_in[10, 10, :]`. (Colisão conserva massa e momentum).



**2.5. Arquivo: `src/kernels/streaming.jl` - Streaming (Pull)**



**Pseudo-algoritmo:**

1.  Definir `function streaming!(state)`.

2.  *Lógica:*

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx` (usar `Threads.@threads` no loop `j` no futuro):

    * Loop `k` de 1 a 9:

        * `cx = state.params.c[k, 1]`

        * `cy = state.params.c[k, 2]`

        * `i_source = i - cx`

        * `j_source = j - cy`

        **Contorno Periódico (Temporário):**

            * `i_source = (i_source - 1 + nx) % nx + 1` (wrap-around correto).

            * `j_source = (j_source - 1 + ny) % ny + 1` (wrap-around correto).

        * `state.f_in[i,j,k] = state.f_out[i_source, j_source, k]` (Pull)

**Validação (Teste do Ponto Quente):**

  * `state = initialize_state(20, 20, ...)` (todos `f` em equilíbrio).

  **Perturbar:** `state.f_out[10, 10, 2] = 2.0` (pulso em `k=1`, ou seja, `c=[1, 0]`. \\*Correção: `k=2` no meu *struct* 1-based é `c=[1,0]`. Usaremos esse).

  * Chamar `streaming!(state)`.

  **CHECK:** O valor de equilíbrio (ex: `1/9`) deve estar em `state.f_in[10, 10, 2]`.

  **CHECK:** O valor `2.0` deve estar em `state.f_in[11, 10, 2]` (o pulso se moveu `[1, 0]`).



-----



#### Fase 3: Geometria e Contornos



*Objetivo: Substituir o contorno periódico por fronteiras sólidas (cilindro) e de entrada/saída.*



**3.1. Arquivo: `src/utils/initialization.jl` - Máscara do Cilindro**



**Pseudo-algoritmo:**

1.  Definir `function create_cylinder_mask!(state, center_x, center_y, radius)`

2.  *Lógica:*

* `radius_sq = radius^2`

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx`:

    * Se `(i - center_x)^2 + (j - center_y)^2 <= radius_sq`:

        * `state.mask[i,j] = true`

**Validação:**

  * `state = initialize_state(...)`

  * `create_cylinder_mask!(state, 50, 50, 10)`

  **CHECK:** `heatmap(state.mask)` (em `Plots.jl`) deve mostrar um círculo sólido.



**3.2. Arquivo: `src/kernels/boundaries.jl` - Bounce-Back**



**Pseudo-algoritmo:**

1.  Definir `const k_opposite = [1, 4, 5, 2, 3, 8, 9, 6, 7]` (mapeamento estático 1-based).

2.  Definir `function apply_bounce_back!(state)`.

3.  (Esta função é chamada *após* o `streaming!`).

4.  *Lógica:*

* Alocar `f_temp = zeros(9)` (buffer).

* Loop `j` de 1 a `ny`, Loop `i` de 1 a `nx`:

    * Se `state.mask[i,j] == true`:

        * Copiar `state.f_in[i,j,:]` para `f_temp` (populações que "entraram" na parede).

        * Loop `k` de 1 a 9:

            * `state.f_in[i,j,k] = f_temp[k_opposite[k]]` (refletir).

**Validação:**

  * Usar o "Teste do Ponto Quente" (2.5), mas agora com uma `mask` em `[11, 10]`.

  **CHECK:** O pulso `2.0` que bateu na parede em `[11, 10, 2]` deve ser refletido e aparecer em `state.f_in[11, 10, 4]` (direção oposta `k=4`).



**3.3. Arquivo: `src/kernels/boundaries.jl` - Contorno de Entrada/Saída**



**Pseudo-algoritmo (Inlet - Zou-He):**

1.  Definir `function apply_velocity_inlet!(state, u_inlet)` (em `i=1`).

2.  *Lógica:* Para `j` de 1 a `ny` (em `i=1`):

* Calcular `rho` a partir das populações conhecidas (que chegam do interior).

* Usar `rho` e `u_inlet` para calcular as populações desconhecidas (que saem da parede `i=1`).

**Pseudo-algoritmo (Outlet - Pressão):**

1.  Definir `function apply_pressure_outlet!(state, rho_outlet)` (em `i=nx`).

2.  *Lógica:* Similar ao Zou-He, mas forçando `rho=rho_outlet` e extrapolando `u`.

**Validação:** *Extremamente difícil de validar isoladamente.* A validação será na simulação completa (Fase 4).



-----



#### Fase 4: Simulação Completa (Lid-Driven Cavity)



*Objetivo: Montar todos os kernels e validar o *engine* LBM em um caso de teste clássico.*



**4.1. Arquivo: `notebooks/01_lid_driven_cavity.ipynb`**

**Pseudo-algoritmo (Loop Principal):**

1.  `state = initialize_state(100, 100, 0.54)`

2.  Definir `mask` para as 4 paredes. `create_wall_mask!(state)`

3.  `u_lid = 0.1`

4.  `Loop t de 1 a max_steps:`

* `calculate_macros!(state)`

* `collision_bgk!(state)`

* `streaming!(state)`

* `apply_bounce_back!(state)` (em `state.mask`).

* `apply_lid_velocity!(state, u_lid)` (BC especial para a tampa `j=ny`).

* `Se t % 100 == 0:`

    * Visualizar `state.u` e `state.v` (com `heatmap` ou `streamplot`).

**Validação:**

  **CHECK 1 (Estabilidade):** A simulação não deve divergir (sem `NaN`s).

  **CHECK 2 (Físico):** O *plot* deve mostrar um vórtice primário se formando no canto superior direito e migrando para o centro.

  **CHECK 3 (Performance):** O *loop* (sem o plot) deve ter **zero alocações** (`@btime`).



-----



#### Fase 5: Simulação do Cilindro (Benchmark)



*Objetivo: Adaptar a simulação da Fase 4 para o benchmark do cilindro.*



**5.1. Arquivo: `notebooks/02_cylinder_benchmark.ipynb`**

**Pseudo-algoritmo (Loop Principal):**

1.  `state = initialize_state(400, 200, 0.58)`

2.  `create_cylinder_mask!(state, 100, 100, 20)` (o obstáculo).

3.  `u_inlet = 0.1`

4.  `Loop t de 1 a max_steps:`

* `calculate_macros!(state)`

* `collision_bgk!(state)`

* `streaming!(state)`

* `apply_bounce_back!(state)` (no cilindro `state.mask`).

* `apply_velocity_inlet!(state, u_inlet)` (em `i=1`).

* `apply_pressure_outlet!(state, 1.0)` (em `i=nx`).

* `Se t % 100 == 0:`

    * Visualizar `state.u` e `state.v`.

**Validação:**

  **CHECK 1 (Físico):** A esteira de von Kármán (vórtices alternados) deve aparecer atrás do cilindro.

  **CHECK 2 (Performance):** Zero alocações no loop.

