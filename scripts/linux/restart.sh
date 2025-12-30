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

# Check for docker-compose or docker compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "  ${RED}❌ Docker Compose não encontrado.${NC}"
    exit 1
fi

# Restart Docker containers (stop then start)
echo ""
echo "[2/3] Reiniciando containers Docker..."
cd docker

# Stop containers (without removing volumes to preserve data)
$COMPOSE_CMD --env-file ../.env down 2>/dev/null

# Start fresh
$COMPOSE_CMD --env-file ../.env up -d
if [ $? -ne 0 ]; then
    echo -e "  ${RED}❌ Falha ao iniciar containers${NC}"
    echo "  Se o problema persistir, execute: ./scripts/linux/reset.sh"
    cd ..
    exit 1
fi
cd ..
echo -e "  ${GREEN}✅ Containers Docker reiniciados${NC}"

# Wait for services
echo ""
echo "[3/3] Aguardando serviços ficarem prontos..."

MAX_WAIT=30
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

# Check PostgreSQL
if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
    echo -e "  ${GREEN}✅ PostgreSQL pronto${NC}"
else
    echo -e "  ${YELLOW}⚠️  PostgreSQL ainda iniciando...${NC}"
fi

# Check Redis
if docker exec ai-server-redis redis-cli ping &> /dev/null; then
    echo -e "  ${GREEN}✅ Redis pronto${NC}"
else
    echo -e "  ${YELLOW}⚠️  Redis ainda iniciando...${NC}"
fi

# Check API
sleep 3
if docker ps --filter "name=ai-server-api" --format "{{.Status}}" | grep -q "Up"; then
    echo -e "  ${GREEN}✅ API rodando${NC}"
else
    echo -e "  ${YELLOW}⚠️  API ainda iniciando (aguarde mais alguns segundos)${NC}"
fi

echo ""
echo "===================================================="
echo " 📋 URLs disponíveis:"
echo "----------------------------------------------------"
echo "  Frontend:   http://localhost:3000"
echo "  Backend:    http://localhost:3001"
echo "  API Docs:   http://localhost:3001/api/docs"
echo "===================================================="
echo ""
echo "Visualizando logs (pressione Ctrl+C para sair)..."
echo ""

cd docker
$COMPOSE_CMD --env-file ../.env logs -f api web
