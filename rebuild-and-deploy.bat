@echo off
echo === Code Server - Rebuild and Deploy ===
echo Data: %date% %time%

REM Parar container se estiver rodando
echo Parando container existente...
docker-compose down 2>nul

REM Remover imagens existentes para forçar rebuild
echo Removendo imagens existentes para forçar rebuild...
docker rmi code-server:local 2>nul
docker rmi localhost:5000/code-server:latest 2>nul

REM Fazer pull das mudanças mais recentes
echo Fazendo pull das mudanças...
git pull origin main

REM Gerar versão baseada no hash dos usuários
for /f "tokens=*" %%i in ('git log -1 --pretty^=format:%%H -- users') do set USERS_VERSION=%%i
echo Versão dos usuários: %USERS_VERSION%

REM Build da imagem com no-cache para garantir rebuild completo
echo Fazendo build da imagem (no-cache)...
set IMAGE_VERSION=%USERS_VERSION%
docker-compose build --no-cache

REM Subir o container
echo Subindo container...
docker-compose up -d

REM Mostrar status
echo Status do container:
docker-compose ps

echo === Deploy concluído! ===
echo SSH disponível em: localhost:2222
pause