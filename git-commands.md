## 🌩️ Guia de Comandos Git

O Git é um sistema de controle de versão essencial para o desenvolvimento de software, permitindo rastrear alterações, colaborar com equipes e gerenciar o histórico do projeto.

### 1\. Configuração Inicial e Remotos

Antes de enviar ou baixar código, você precisa "iniciar" o Git e conectá-lo a um servidor (como o GitHub).

#### `git init`

**O que faz:** Inicia (cria) um novo repositório Git vazio no seu diretório atual. É o primeiro passo para começar a rastrear um projeto.

```bash
# Cria uma pasta .git oculta no seu diretório
git init
```

#### `git remote add`

**O que faz:** Conecta seu repositório local a um repositório remoto (na internet). Você dá um "apelido" (como `origin`) para uma URL.

```bash
# Sintaxe: git remote add [apelido] [url-do-repositorio]
git remote add origin https://github.com/seu-usuario/seu-projeto.git
```

  * **`remote`**: Subcomando para gerenciar conexões remotas.
  * **`add`**: Ação de adicionar uma nova conexão.
  * **`origin`**: O apelido padrão e mais comum para seu repositório remoto principal.
  * **`[url]`**: O link (HTTPS ou SSH) que você copia do GitHub.

-----

### 2\. O Fluxo de Trabalho Essencial

Estes são os comandos para o ciclo diário de salvar e sincronizar seu trabalho.

#### `git add`

**O que faz:** Prepara (ou "coloca na esteira") suas alterações para serem incluídas no próximo "pacote" (commit).

```bash
# Adiciona todos os arquivos modificados e novos
git add .
```

  * **`-p` (ou `--patch`):** Modo interativo. O Git mostra cada alteração e pergunta se você quer incluí-la (y/n). Ótimo para revisar seu código antes de commitar.
  * **`-A` (ou `--all`):** Adiciona **todas** as alterações (novos, modificados e deletados).

#### `git commit`

**O que faz:** Salva permanentemente as alterações que estão na "Staging Area" no seu histórico local.

```bash
# Abre seu editor de texto para escrever uma mensagem
git commit
```

  * **`-m "Sua mensagem aqui"`:** (A mais usada). Escreve a mensagem diretamente na linha de comando.
    ```bash
    git commit -m "Corrige bug na página de login"
    ```
  * **`-a`:** (Atalho). Automaticamente "adiciona" (add) todos os arquivos já rastreados E faz o "commit". *Nota: Ele não adiciona arquivos novos.*
    ```bash
    git commit -a -m "Atualiza links do rodapé"
    ```
  * **`--amend`:** Modifica o **último** commit. Útil se você esqueceu de adicionar um arquivo ou errou a mensagem.

#### `git push`

**O que faz:** Envia seus commits locais (que você salvou) para o repositório remoto (que você configurou com `git remote add`).

```bash
# Envia a branch 'main' para o remoto 'origin'
git push origin main
```

  * **`-u` (ou `--set-upstream`):** Usado na primeira vez que você envia uma nova branch. Ele "linka" sua branch local à remota. Depois de usar `git push -u origin main` uma vez, você pode simplesmente digitar `git push` nas próximas vezes.

#### `git pull`

**O que faz:** Atualiza sua branch local com as alterações de um repositório remoto. É uma combinação de `git fetch` (buscar) e `git merge` (mesclar).

```bash
# Puxa as alterações da branch 'main' do remoto 'origin'
git pull origin main
```

  * **`--rebase`:** Em vez de criar um "commit de merge", ele puxa as alterações remotas e "reaplica" seus commits locais por cima delas. Mantém um histórico mais limpo e linear.

-----

### 3\. Gerenciamento de Branchs (Ramos)

Branches são essenciais para trabalhar em diferentes funcionalidades sem afetar a linha principal (`main`).

#### `git branch`

**O que faz:** Lista, cria ou deleta branches.

```bash
# Lista todas as branches locais (a ativa é marcada com *)
git branch
```

  * **`git branch nome-da-nova-branch`**: Cria uma nova branch.
  * **`-a` (ou `--all`):** Lista **todas** as branches (locais e remotas).
  * **`-d "nome-da-branch"`:** Deleta uma branch local (com segurança, impede se tiver trabalho não mesclado).
  * **`-D "nome-da-branch"`:** Força a deleção da branch local.

#### `git checkout`

**O que faz:** Muda seu "foco" (HEAD) para outra branch.

```bash
# Muda para uma branch que já existe
git checkout nome-da-branch
```

  * **`-b "nome-da-nova-branch"`:** (O mais usado). **Cria** uma nova branch e imediatamente **muda** para ela.
    ```bash
    git checkout -b minha-nova-feature
    ```
  * **`-` (hífen):** Um atalho que muda você de volta para a **última branch** em que você estava.

#### `git merge`

**O que faz:** Pega as alterações de uma branch e as aplica (mescla) na sua branch atual.

```bash
# 1. Vá para a branch que vai RECEBER as alterações
git checkout main

# 2. Execute o merge para trazer as alterações da outra branch
git merge minha-nova-feature
```

  * **`--no-ff` (No Fast-Forward):** Força o Git a criar um "merge commit" (um commit de junção), mesmo se um "fast-forward" for possível. Isso mantém um registro claro de quando a feature foi integrada.
  * **`--abort`:** Se você tiver conflitos de merge, pode usar isso para cancelar tudo e voltar ao estado anterior.

-----

### ❗ Extra: Solução de Problemas de Sincronização

#### O Problema: "Meu `git push` foi rejeitado\!"

Você tenta dar `git push` e recebe este erro:

```bash
To https://github.com/phelipestoiber/LBM.git
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '...'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

**O que significa:** O repositório remoto (GitHub) tem commits/alterações que você ainda não baixou para o seu PC. O Git não deixa você dar `push` porque isso sobrescreveria o histórico e apagaria o trabalho que está lá.

**A Solução (O Fluxo Correto):**

Você deve **sempre** puxar (pull) as alterações remotas antes de enviar (push) as suas.

1.  **Puxe (Pull) para mesclar as alterações:**

    ```bash
    git pull origin main
    ```

    O Git vai baixar os commits remotos e mesclá-los com os seus.

2.  **(Caso Especial) Se as histórias forem não-relacionadas:**
    Se você (como no nosso exemplo) começou um projeto local e tentou conectá-lo a um projeto remoto que *já tinha arquivos* (como um README), seus históricos são "não-relacionados". Nesse caso, você precisa usar uma flag especial na primeira vez:

    ```bash
    git pull origin main --allow-unrelated-histories
    ```

3.  **Resolva Conflitos (Se houver):**
    Se você e o servidor alteraram a *mesma linha* no *mesmo arquivo*, o Git vai pausar e pedir para você resolver o "conflito". Você deve abrir o arquivo, editar manualmente para deixar a versão correta, e então usar `git add` e `git commit` para finalizar o merge.

4.  **Faça o Push (Agora vai funcionar):**
    Depois que o `pull` (e a resolução de conflitos, se necessária) for concluído, seu repositório local estará sincronizado e à frente do remoto. Agora o push será aceito:

    ```bash
    git push origin main
    ```