# Guia de Troubleshooting - Code Server

## Erros Comuns e Soluções

### 1. Erro no Builder Container

**Sintomas:**
- Builder falha ao executar
- "Permission denied" no Docker socket
- "Cannot connect to Docker daemon"

**Soluções:**
```bash
# Verificar se Docker socket está acessível
ls -la /var/run/docker.sock

# No Portainer, certificar que o volume está correto:
# /var/run/docker.sock:/var/run/docker.sock
```

### 2. Registry não acessível (localhost:5000)

**Sintomas:**
- "connection refused" ao fazer push
- "no route to host localhost:5000"

**Soluções:**
```bash
# Verificar se registry está rodando
curl http://localhost:5000/v2/_catalog

# Verificar IP do host do registry
docker network ls
```

### 3. Volume code-server não existe

**Sintomas:**
- "volume code-server not found"

**Solução:**
```bash
docker volume create code-server
```

### 4. Git clone fails

**Sintomas:**
- "Permission denied (publickey)"
- "Could not resolve hostname"

**Verificações:**
- Internet disponível no container
- Repositório público acessível

### 5. Code-server não inicia

**Sintomas:**
- Container fica reiniciando
- "Image not found"

**Verificações:**
- Builder completou com sucesso
- Imagem foi enviada para registry
- Registry acessível do Portainer

## Comandos para Debug

### Ver logs do builder:
```bash
docker logs code-server-builder
```

### Ver logs do code-server:
```bash
docker logs code-server
```

### Verificar status dos volumes:
```bash
docker volume ls
docker volume inspect code-server
```

### Verificar imagens no registry:
```bash
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/code-server/tags/list
```