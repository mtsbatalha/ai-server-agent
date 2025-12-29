#!/bin/bash

# ============================================
# AI Server Admin - Stop Script
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo ""
echo "===================================================="
echo " 🖥️  AI SERVER ADMIN - PARAR SERVIÇOS"
echo "===================================================="
echo ""

# Kill Node.js processes for this project
echo "[1/2] Parando servidores Node.js..."

# Find and kill processes on ports 3000 and 3001
WEB_PID=$(lsof -t -i:3000 2>/dev/null)
if [ -n "$WEB_PID" ]; then
    echo "  Parando processo na porta 3000 (PID: $WEB_PID)"
    kill -9 $WEB_PID 2>/dev/null
fi

API_PID=$(lsof -t -i:3001 2>/dev/null)
if [ -n "$API_PID" ]; then
    echo "  Parando processo na porta 3001 (PID: $API_PID)"
    kill -9 $API_PID 2>/dev/null
fi

echo -e "  ${GREEN}✅ Servidores Node.js parados${NC}"

# Stop Docker containers
echo ""
echo "[2/2] Parando containers Docker..."
cd docker
docker-compose stop
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ Containers Docker parados${NC}"
else
    echo -e "  ${YELLOW}⚠️  Nenhum container para parar ou erro ao parar${NC}"
fi
cd ..

echo ""
echo "===================================================="
echo -e " ${GREEN}✅ TODOS OS SERVIÇOS FORAM PARADOS${NC}"
echo "===================================================="
echo ""
echo " Para remover completamente os containers, execute:"
echo "   cd docker && docker-compose down"
echo ""
