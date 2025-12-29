#!/bin/bash

# ============================================
# AI Server Admin - Restart Script
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
echo " 🖥️  AI SERVER ADMIN - REINICIAR SERVIÇOS"
echo "===================================================="
echo ""

# Stop services
echo "[1/3] Parando serviços atuais..."
echo ""

# Kill Node.js processes
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

# Restart Docker containers
echo ""
echo "[2/3] Reiniciando containers Docker..."
cd docker
docker-compose restart
if [ $? -ne 0 ]; then
    echo -e "  ${YELLOW}⚠️  Containers não estavam rodando. Iniciando...${NC}"
    docker-compose up -d
fi
cd ..
echo -e "  ${GREEN}✅ Containers Docker reiniciados${NC}"

# Wait for services
echo ""
echo "[3/3] Aguardando serviços ficarem prontos..."
sleep 3

# Check PostgreSQL
if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
    echo -e "  ${GREEN}✅ PostgreSQL pronto (porta 5432)${NC}"
else
    echo -e "  ${YELLOW}⚠️  PostgreSQL ainda iniciando...${NC}"
fi

# Check Redis
if docker exec ai-server-redis redis-cli ping &> /dev/null; then
    echo -e "  ${GREEN}✅ Redis pronto (porta 6379)${NC}"
else
    echo -e "  ${YELLOW}⚠️  Redis ainda iniciando...${NC}"
fi

# Start development servers
echo ""
echo "Iniciando servidores de desenvolvimento..."
echo ""
echo "  ⏳ Iniciando Frontend (Next.js) e Backend (NestJS)..."
echo "  Pressione Ctrl+C para parar os servidores."
echo ""
echo "===================================================="
echo " 📋 URLs disponíveis após inicialização:"
echo "----------------------------------------------------"
echo "  Frontend:   http://localhost:3000"
echo "  Backend:    http://localhost:3001"
echo "  API Docs:   http://localhost:3001/api/docs"
echo "===================================================="
echo ""

pnpm dev
