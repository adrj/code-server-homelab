#!/bin/bash

echo "=== Code Server - Rebuild and Deploy ==="
echo "Data: $(date)"

# Parar container se estiver rodando
echo "Parando container existente..."
docker-compose down 2>/dev/null || true

# Remover imagens existentes para forçar rebuild
echo "Removendo imagens existentes para forçar rebuild..."
docker rmi code-server:local 2>/dev/null || true
docker rmi localhost:5000/code-server:latest 2>/dev/null || true

# Fazer pull das mudanças mais recentes
echo "Fazendo pull das mudanças..."
git pull origin main

# Gerar versão baseada no hash dos usuários
USERS_VERSION=$(git log -1 --pretty=format:%H -- users)
echo "Versão dos usuários: $USERS_VERSION"

# Build da imagem com no-cache para garantir rebuild completo
echo "Fazendo build da imagem (no-cache)..."
IMAGE_VERSION=$USERS_VERSION docker-compose build --no-cache

# Subir o container
echo "Subindo container..."
docker-compose up -d

# Mostrar status
echo "Status do container:"
docker-compose ps

echo "=== Deploy concluído! ==="
echo "SSH disponível em: localhost:2222"