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

1) Abra Portainer -> Stacks -> Add stack.
2) Cole o conteúdo de `vscode-ssh-stack.yml`.
3) Ajuste a variável `PUBLIC_KEY` no arquivo para sua chave pública SSH (uma linha). Se preferir, você pode subir o arquivo `authorized_keys` no volume `/config` do container via Portainer.
4) Deploy stack.

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
