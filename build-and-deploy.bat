@echo off
echo === Code Server - Build and Deploy Script ===
echo Este script executa o builder primeiro, depois o code-server
echo.

echo Parando containers existentes...
docker-compose -f docker-compose.sequential.yml down 2>nul

echo.
echo ^>^>^> Executando builder...
docker-compose -f docker-compose.sequential.yml up builder

REM Verificar se o build foi bem-sucedido
for /f "tokens=*" %%i in ('docker run --rm -v code-server-homelab_builder-status:/status alpine cat /status/build-status 2^>nul') do set BUILD_STATUS=%%i
if "%BUILD_STATUS%"=="" set BUILD_STATUS=FAILED

if "%BUILD_STATUS%"=="SUCCESS" (
    echo ✅ Builder executado com sucesso!
    
    for /f "tokens=*" %%i in ('docker run --rm -v code-server-homelab_builder-status:/status alpine cat /status/version 2^>nul') do set VERSION=%%i
    echo 📦 Versão da imagem: %VERSION%
    
    echo.
    echo ^>^>^> Executando code-server...
    docker-compose -f docker-compose.sequential.yml up -d code-server
    
    echo ✅ Code Server iniciado!
    echo 🔗 SSH disponível em: localhost:2222
    echo.
    echo 🎉 Deploy concluído com sucesso!
    echo.
    echo Status dos containers:
    docker-compose -f docker-compose.sequential.yml ps
) else (
    echo ❌ Builder falhou!
    echo 💥 Deploy falhou no builder!
    pause
    exit /b 1
)

pause