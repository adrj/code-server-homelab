#!/bin/bash

echo "=== Code Server - Build and Deploy Script ==="
echo "Este script executa o builder primeiro, depois o code-server"
echo

# Função para executar builder
run_builder() {
    echo ">>> Executando builder..."
    docker-compose -f docker-compose.sequential.yml up builder
    
    # Verificar se o build foi bem-sucedido
    BUILD_STATUS=$(docker run --rm -v code-server-homelab_builder-status:/status alpine cat /status/build-status 2>/dev/null || echo "FAILED")
    
    if [ "$BUILD_STATUS" = "SUCCESS" ]; then
        echo "✅ Builder executado com sucesso!"
        VERSION=$(docker run --rm -v code-server-homelab_builder-status:/status alpine cat /status/version 2>/dev/null || echo "unknown")
        echo "📦 Versão da imagem: $VERSION"
        return 0
    else
        echo "❌ Builder falhou!"
        return 1
    fi
}

# Função para executar code-server
run_code_server() {
    echo ">>> Executando code-server..."
    docker-compose -f docker-compose.sequential.yml up -d code-server
    
    echo "✅ Code Server iniciado!"
    echo "🔗 SSH disponível em: localhost:2222"
}

# Execução principal
echo "Parando containers existentes..."
docker-compose -f docker-compose.sequential.yml down 2>/dev/null

echo
if run_builder; then
    echo
    run_code_server
    echo
    echo "🎉 Deploy concluído com sucesso!"
    echo
    echo "Status dos containers:"
    docker-compose -f docker-compose.sequential.yml ps
else
    echo
    echo "💥 Deploy falhou no builder!"
    exit 1
fi