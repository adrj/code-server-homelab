# VS Code Server para Portainer (Remote SSH)

Este repositório contém templates para subir um servidor SSH (baseado em linuxserver/openssh-server) ou uma imagem customizada que também instala o Docker CLI e opcionalmente o code-server.

Objetivo: permitir que você conecte seu VS Code local via Remote - SSH no servidor em execução dentro do Portainer, e acesse outros serviços no mesmo host/stack (por exemplo, containers, bancos, etc.).

Arquivos:

- `vscode-ssh-stack.yml` : um Compose/Stack para usar no Portainer que sobe `linuxserver/openssh-server` e monta `/var/run/docker.sock` (somente leitura por segurança) para permitir interação com docker.
- `Dockerfile.vscode-server` : Dockerfile opcional para criar uma imagem com Docker CLI, code-server, Supabase CLI, Node.js (npm) e pnpm.
  - Você pode passar `--build-arg SUPABASE_CLI_VERSION=<tag|latest>` ao construir para fixar uma versão do Supabase CLI.

Uso com docker-compose (vários usuários SSH):

Na pasta `portainer/` há um `docker-compose.yml` e um script `init-users.sh` que criam usuários dinamicamente a partir da pasta `portainer/users/`.

Estrutura para criar usuários:

```
portainer/users/
  ├─ alice/
  │   └─ authorized_keys      # chave pública para alice
  ├─ bob/
  │   └─ password             # senha para bob (apenas para testes)
```

Cada subpasta representa um usuário. O script `init-users.sh` criará o usuário com o nome da pasta, adicionará chaves em `/home/<user>/.ssh/authorized_keys` e definirá senha se houver arquivo `password`.

Para subir com compose (constrói a imagem localmente):

```powershell
cd e:\dev-tools\workspace\vscode-server\portainer
docker-compose up -d --build
```

Se você estiver usando um volume externo criado pelo Portainer (por exemplo `code-server`), use um dos comandos abaixo para copiar os arquivos da pasta `portainer/users/` para o volume.

Opção A — usar tar (preserva estrutura):

```powershell
$pwd = (Get-Location).Path
docker run --rm -v code-server:/data -v "${pwd}\portainer\users":/src alpine \
  sh -c "cd /src && tar -cf - . | tar -C /data -xf -"
```

Opção B — copiar com busybox (alternativa):

```powershell
$pwd = (Get-Location).Path
docker run --rm -v code-server:/data -v "${pwd}\portainer\users":/src busybox \
  sh -c "cp -a /src/. /data/"
```

Verifique o conteúdo do volume:

```powershell
docker run --rm -v code-server:/data alpine ls -la /data
```

Nota importante sobre seed automático:

- O `docker-compose.yml` desta pasta está configurado para montar o volume `code-server` como gravável no container. No primeiro start, o container tentará popular o volume com os arquivos `users/` que existem no repositório (copiados para a imagem em `/opt/repo-users`) caso o volume esteja vazio. Isso permite que você atualize as chaves no repositório e, ao fazer redeploy do stack, o container copie as chaves para o volume (apenas quando o volume estiver vazio).
- Se preferir forçar uma atualização a partir do repo para o volume, você pode popular o volume manualmente (com os comandos acima) ou remover os dados do volume e reiniciar o serviço para que o seed ocorra novamente.

A aplicação ficará disponível na porta `2222` do host. Você pode então conectar por SSH:

```powershell
ssh -p 2222 alice@SEU_HOST -i ~/.ssh/id_rsa
ssh -p 2222 bob@SEU_HOST -i ~/.ssh/id_rsa  # se bob tiver chave, ou usar senha se foi configurada
```

Segurança:

- Não commit suas chaves privadas no repositório. A pasta `portainer/users/.gitignore` já bloqueia arquivos por padrão.
- Usar senhas em produção não é recomendado; prefira chaves SSH.
- Se usar Portainer, você pode montar um diretório seguro para `users/` contendo os `authorized_keys`.

Passos rápidos (uso com Portainer):

1. Abra Portainer -> Stacks -> Add stack.
2. Cole o conteúdo de `vscode-ssh-stack.yml`.
3. Ajuste a variável `PUBLIC_KEY` no arquivo para sua chave pública SSH (uma linha). Se preferir, você pode subir o arquivo `authorized_keys` no volume `/config` do container via Portainer.
4. Deploy stack.

Conectar do VS Code local (Remote - SSH):

- Instale a extensão Remote - SSH no VS Code local.
- Configure seu arquivo `~/.ssh/config` com algo como:
  Host portainer-vscode
  HostName your.server.ip.or.domain
  Port 2222
  User <seu-usuario-no-container> # normalmente 'abc' ou 'coder' dependendo da imagem
  IdentityFile ~/.ssh/id_rsa

- No VS Code: Command Palette -> Remote-SSH: Connect to Host... -> `portainer-vscode`.

Acesso a serviços locais do Portainer:

- Se o container acessa o socket Docker do host, você pode usar Docker CLI dentro do servidor SSH para listar e conectar a containers.
- Para acessar serviços por hostname entre containers, certifique-se de que o serviço alvo esteja na mesma network do `vscode-ssh` (a stack usa `portainer_network` externa no template). Caso não exista, crie uma network Docker com esse nome ou ajuste o arquivo.

Segurança e recomendações:

- Use chaves SSH e não senhas.
- Não exponha o socket docker com escrita a menos que necessário.
- Restrinja IPs no firewall ou via regras do Portainer/Stack.

Se quiser, eu posso:

- Gerar instruções prontas para criar uma image que rode `code-server` com TLS e autenticação.
- Adaptar o stack para usar Traefik/NGINX reverse proxy para TLS.
- Criar um exemplo de `ssh/config` e comandos Docker para testar a conectividade.

Diga qual opção prefere e seu ambiente (IP público, uso de Traefik, se já tem `portainer_network`).

## Deploy e Atualização

### Deploy Manual Simples

Para fazer deploy local:

```bash
# Clonar o repositório
git clone https://github.com/adrj/code-server-homelab.git
cd code-server-homelab

# Criar volume externo
docker volume create code-server

# Build e run
docker-compose up -d
```

### Rebuild e Deploy (Recomendado)

Para forçar rebuild da imagem quando adicionar novos usuários:

```bash
# Linux/macOS
./rebuild-and-deploy.sh

# Windows
rebuild-and-deploy.bat
```

Este script vai:
1. Parar o container atual
2. Remover imagens existentes
3. Fazer pull das mudanças do repositório
4. Fazer rebuild completo da imagem (no-cache)
5. Subir o container novamente

### Para Portainer

Use o compose específico para Portainer (usa imagem do registry):

```yaml
# Use docker-compose.portainer.yml
# Certifique-se que localhost:5000/code-server:latest existe no registry
```

Para atualizar no Portainer:
1. Faça push das mudanças para o repositório
2. No seu servidor, execute: `./rebuild-and-deploy.sh`
3. A imagem será rebuilded e o container reiniciado automaticamente

O watcher funciona assim:

- roda em um container que tem acesso ao socket Docker (`/var/run/docker.sock`)
- periodicamente clona/puxa o repositório (branch configurada)
- quando detecta novo commit, builda a imagem, faz push para o registry local (ex.: `localhost:5000`) e executa um comando de deploy configurado (ex.: `docker-compose pull && docker-compose up -d`)

Arquivos relevantes:

- `watcher/Dockerfile` - imagem leve baseada em `docker:24-cli` com git
- `watcher/repo-watcher.sh` - script principal
- `watcher/docker-compose.watcher.yml` - compose para subir o watcher no host

Exemplo: subir o watcher no host (assumindo que você está no diretório raiz do repo):

```powershell
cd e:\dev-tools\workspace\vscode-server
docker compose -f watcher/docker-compose.watcher.yml up -d --build
```

Variáveis de ambiente importantes (pode setar via environment variables no compose ou no comando docker):

- `REPO_URL` - URL do repositório git (por padrão o repositório deste projeto)
- `BRANCH` - branch para observar (default: `main`)
- `POLL_INTERVAL` - intervalo em segundos entre checagens (default: 60)
- `IMAGE_NAME` - nome completo da imagem que será construída (ex.: `localhost:5000/code-server`)
- `IMAGE_TAG` - tag da imagem (default: `latest`) — o script usa `IMAGE_TAG` para taggar e empurrar a imagem
- `DEPLOY_CMD` - comando a ser executado no host após push (ex.: `cd /opt/stacks/code-server && docker-compose pull && docker-compose up -d`)

Exemplo de uso recomendado (host local com registry em localhost:5000 e stack em `/opt/stacks/code-server`):

```powershell
docker compose -f watcher/docker-compose.watcher.yml up -d --build \
  -e REPO_URL="https://github.com/adrj/code-server-homelab.git" \
  -e BRANCH=main \
  -e POLL_INTERVAL=30 \
  -e IMAGE_NAME=localhost:5000/code-server \
  -e IMAGE_TAG=latest \
  -e DEPLOY_CMD="cd /opt/stacks/code-server && docker-compose pull && docker-compose up -d --remove-orphans"
```

Observações:

- O watcher precisa executar no host que tem acesso ao registry `localhost:5000` (ou usar o IP do host do registry). Em outras palavras, `localhost` do watcher é o host onde o watcher estiver rodando.
- Se seu repositório for privado e exigir chave SSH, monte a chave em `/root/.ssh/id_rsa` dentro do container (adapte o compose comentado no arquivo).
- O watcher é uma solução simples e leve para ambientes off-line em relação ao GitHub; para ambientes com integração contínua completa, use GitHub Actions + registry acessível.

Fique à vontade para pedir que eu gere um systemd unit ou instruções para rodar o watcher como serviço no host, ou para eu ajustar o comando de deploy para usar API do Portainer em vez de `docker-compose`.

## Deploy local (scripted)

Se quiser um comando único que force remover/buildar e rodar o container `code-server` localmente (útil para testar), use o `docker-compose.deploy.yml` incluído.

1. Para executar no host (PowerShell):

```powershell
cd e:\dev-tools\workspace\vscode-server
docker compose -f docker-compose.deploy.yml up --build
```

O `runner` no compose executa o script `deploy/deploy-and-run.sh`, que:
- remove imagem existente (se houver),
- builda a imagem a partir do contexto do repositório,
- (opcional) faz push para registry se `PUSH_IMAGE=1`,
- remove container antigo chamado `code-server` e inicia o novo.

Adapte variáveis de ambiente no `docker-compose.deploy.yml` conforme necessário (IMAGE_NAME, IMAGE_TAG, VOLUME_NAME, etc.).

## Auto-rebuild no Portainer via Webhook

Para fazer o Portainer rebuildar automaticamente quando o repositório for atualizado:

### 1. Configure webhook na Stack do Portainer:
- No Portainer, vá para a sua stack → Settings
- Habilite "Git-based deployment" se não estiver
- Copie o webhook URL (ex.: `https://seu-portainer.com/api/webhooks/123abc`)

### 2. Configure webhook no GitHub:
- No repositório GitHub → Settings → Webhooks → Add webhook
- Payload URL: cole o webhook URL do Portainer
- Content type: `application/json`
- Events: selecione "Just the push event"
- Active: marcado

### 3. Teste o webhook:
- Faça um commit/push no repositório
- O Portainer deve detectar a mudança e rebuildar a stack automaticamente

Nota: O Portainer deve ter acesso ao repositório (público ou com credenciais configuradas) e o contexto de build deve incluir a pasta `users/` para evitar erros de build.

