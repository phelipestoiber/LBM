## 🌩️ O Fluxo de Trabalho Essencial

Estes são os comandos para o ciclo diário de salvar e sincronizar seu trabalho.

### 1\. `git add`

**O que faz:** Prepara (ou "coloca na esteira") suas alterações para serem incluídas no próximo "pacote" (commit). Ele move as alterações do seu diretório de trabalho para a "Staging Area".

```bash
# Adiciona um arquivo específico
git add nome_do_arquivo.txt

# Adiciona todos os arquivos modificados e novos no diretório atual
git add .
```

#### Opções (Flags) Comuns:

  * **`-p` (ou `--patch`):** Modo interativo. Em vez de adicionar o arquivo inteiro, o Git mostra cada "pedaço" (patch) de alteração e pergunta se você quer incluí-lo (y/n). Isso é excelente para revisar seu próprio código e fazer commits menores e mais limpos.
  * **`-A` (ou `--all`):** Adiciona **todas** as alterações no repositório inteiro (não apenas no diretório atual). Isso inclui arquivos novos, modificados e **arquivos deletados**, o que `git add .` nem sempre faz dependendo da sua versão do Git.
  * **`-u` (ou `--update`):** Adiciona apenas arquivos que já estão sendo rastreados pelo Git (modificados ou deletados). Ele **ignora** arquivos novos (untracked).

-----

### 2\. `git commit`

**O que faz:** Salva permanentemente as alterações que estão na "Staging Area" (as coisas que você usou `git add`) no seu histórico local. Cada commit é um "ponto de salvamento" (snapshot) do seu projeto.

```bash
# Abre seu editor de texto padrão para escrever uma mensagem de commit
git commit
```

#### Opções (Flags) Comuns:

  * **`-m "Sua mensagem aqui"`:** (A flag mais usada). Permite que você escreva a mensagem do commit diretamente na linha de comando, sem abrir o editor de texto.
    ```bash
    git commit -m "Corrige bug na página de login"
    ```
  * **`-a` (ou `--all`):** Um atalho. Ele automaticamente **adiciona (add)** todos os arquivos que já são rastreados (modificados ou deletados) e **faz o commit (commit)** deles em um só comando. *Nota: Ele não adiciona arquivos novos (untracked).*
    ```bash
    # Equivalente a 'git add -u' + 'git commit -m "..."'
    git commit -a -m "Atualiza links do rodapé"
    ```
  * **`--amend`:** Modifica o **último** commit. Se você esqueceu de adicionar um arquivo ou digitou a mensagem errada, você pode usar `git add` no arquivo esquecido e depois rodar `git commit --amend`. Ele "emenda" suas novas alterações ao commit anterior.

-----

### 3\. `git push`

**O que faz:** Envia seus commits locais (que você salvou com `git commit`) para um repositório remoto (como o GitHub ou GitLab), permitindo que outros vejam seu trabalho.

```bash
# Envia a branch 'main' para o remoto 'origin'
git push origin main
```

#### Opções (Flags) Comuns:

  * **`-u` (ou `--set-upstream`):** Usado na primeira vez que você envia uma nova branch. Ele "linka" sua branch local à branch remota. Depois de usar isso uma vez, você pode simplesmente digitar `git push` (sem `origin main`) nas próximas vezes.
    ```bash
    git push -u origin minha-nova-feature
    ```
  * **`-f` (ou `--force`):** **(CUIDADO)** Força o envio. Ele sobrescreve a branch remota com a sua versão local. Isso é destrutivo e pode apagar o histórico de outras pessoas. Geralmente é usado (com cautela) se você usou `git rebase` ou `--amend` em commits que já estavam no remoto.
  * **`--tags`:** Envia todas as suas tags (marcadores de versão, ex: `v1.0`) locais para o remoto, já que o `git push` normal não faz isso.

-----

### 4\. `git pull`

**O que faz:** Atualiza sua branch local com as alterações de um repositório remoto. É, na verdade, uma combinação de dois outros comandos: `git fetch` (que baixa as alterações) e `git merge` (que mescla essas alterações na sua branch atual).

```bash
# Puxa as alterações da branch 'main' do remoto 'origin'
git pull origin main
```

#### Opções (Flags) Comuns:

  * **`--rebase`:** Esta é uma alternativa muito popular ao merge. Em vez de criar um "merge commit" (um commit de "junção"), ele pega os seus commits locais que ainda não estão no remoto, **coloca-os de lado**, puxa as alterações do remoto e, em seguida, **re-aplica** os seus commits um por um "em cima" das alterações baixadas. Isso mantém o histórico linear e mais limpo.
  * **`--ff-only` (Fast-Forward Only):** Só permite o pull se ele puder ser feito com um "fast-forward" (ou seja, se você não tiver nenhum commit local que o remoto não tenha). Se houver divergência, o pull falhará, forçando você a decidir se quer fazer um merge ou rebase.
  * **`--prune`:** "Limpa" referências a branches remotas que já foram deletadas no servidor, mas que seu Git local ainda acha que existem.

-----

## 🌳 Gerenciamento de Branchs (Ramos)

Branches são essenciais para trabalhar em diferentes funcionalidades ou correções de bugs sem afetar a linha principal de desenvolvimento (`main`).

### 1\. `git branch`

**O que faz:** Lista, cria ou deleta branches.

```bash
# Lista todas as branches locais (a ativa é marcada com *)
git branch

# Cria uma nova branch
git branch nome-da-nova-branch
```

#### Opções (Flags) Comuns:

  * **`-a` (ou `--all`):** Lista **todas** as branches (locais e remotas).
  * **`-d "nome-da-branch"` (ou `--delete`):** Deleta uma branch local. O Git **não** deixará você fazer isso se a branch tiver trabalho que ainda não foi mesclado (merge) em outra branch.
  * **`-D "nome-da-branch"`:** (Delete forçado). Deleta a branch local **mesmo que** ela tenha trabalho não mesclado.
  * **`-m "novo-nome"` (ou `--move`):** Renomeia a branch atual.

-----

### 2\. `git checkout`

**O que faz:** Muda seu "foco" (HEAD) para outra branch ou commit.

```bash
# Muda para uma branch que já existe
git checkout nome-da-branch

# Descarta alterações em um arquivo, voltando ao estado do último commit
git checkout -- nome_do_arquivo.txt
```

#### Opções (Flags) Comuns:

  * **`-b "nome-da-nova-branch"`:** Um atalho fundamental. Ele **cria** uma nova branch (como `git branch nome-da-nova-branch`) e imediatamente **muda** para ela (como `git checkout nome-da-nova-branch`) em um só passo.
    ```bash
    git checkout -b minha-nova-feature
    ```
  * **`-` (hífen):** Um atalho útil que muda você de volta para a **última branch** em que você estava (similar ao comando `cd -` no terminal).

-----

### 3\. `git merge`

**O que faz:** Pega as alterações de uma branch e as aplica (mescla) na sua branch atual.

```bash
# 1. Primeiro, vá para a branch que vai RECEBER as alterações
git checkout main

# 2. Execute o merge para trazer as alterações da outra branch
git merge minha-nova-feature
```

#### Opções (Flags) Comuns:

  * **`--no-ff` (No Fast-Forward):** Por padrão, se a branch `main` não tiver nenhuma alteração nova desde que você criou a `minha-nova-feature`, o Git fará um "fast-forward", simplesmente movendo o ponteiro da `main` para frente. Usar `--no-ff` **força** o Git a criar um "merge commit" (um commit de junção). Isso é útil para manter um registro claro de quando uma feature foi integrada, preservando a topologia da branch.
  * **`--ff-only` (Fast-Forward Only):** O oposto. Só permite o merge se ele puder ser feito com *fast-forward*. Se não for possível (ou seja, se a `main` tiver novos commits), o merge falhará.
  * **`--abort`:** Se você estiver no meio de um merge e encontrar **conflitos** que não sabe resolver, você pode usar `git merge --abort` para cancelar tudo e voltar ao estado de antes do merge.