#!/bin/bash

# ============================================
# AI Server Admin - Reset Script (FULL CLEANUP)
# ============================================
# WARNING: This script will DELETE ALL DATA including database!
# Use this only for fresh installations or when you need to start over.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo ""
echo "===================================================="
echo -e " ${RED}⚠️  AI SERVER ADMIN - RESET COMPLETO${NC}"
echo "===================================================="
echo ""
echo -e "${YELLOW}ATENÇÃO: Este script irá:${NC}"
echo "  - Parar TODOS os containers"
echo "  - REMOVER todos os volumes (banco de dados, cache)"
echo "  - Recriar tudo do zero"
echo ""

# Confirmation
read -p "Tem certeza que deseja continuar? (digite 'sim' para confirmar): " CONFIRM
if [ "$CONFIRM" != "sim" ]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""

# Check for docker compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "  ${RED}❌ Docker Compose não encontrado.${NC}"
    exit 1
fi

# Kill any rogue local processes
echo "[1/5] Parando processos locais..."
for PORT in 3000 3001 3003 3004; do
    PID=$(lsof -t -i:$PORT 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "  Parando processo na porta $PORT (PID: $PID)"
        kill -9 $PID 2>/dev/null
    fi
done
echo -e "  ${GREEN}✅ Processos locais parados${NC}"

# Stop and remove containers + volumes
echo ""
echo "[2/5] Parando e removendo containers e volumes..."
cd docker
$COMPOSE_CMD --env-file ../.env down -v --remove-orphans
cd ..
echo -e "  ${GREEN}✅ Containers e volumes removidos${NC}"

# Remove any orphan volumes
echo ""
echo "[3/5] Limpando volumes órfãos..."
docker volume prune -f 2>/dev/null
echo -e "  ${GREEN}✅ Volumes órfãos removidos${NC}"

# Start fresh
echo ""
echo "[4/5] Iniciando containers do zero..."
cd docker
$COMPOSE_CMD --env-file ../.env up -d
if [ $? -ne 0 ]; then
    echo -e "  ${RED}❌ Falha ao iniciar containers${NC}"
    cd ..
    exit 1
fi
cd ..
echo -e "  ${GREEN}✅ Containers iniciados${NC}"

# Wait for services
echo ""
echo "[5/5] Aguardando serviços ficarem prontos..."
echo "  (Isso pode levar até 60 segundos na primeira vez)"

MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    echo -n "."
done
echo ""

if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
    echo -e "  ${GREEN}✅ PostgreSQL pronto${NC}"
else
    echo -e "  ${YELLOW}⚠️  PostgreSQL ainda iniciando...${NC}"
fi

if docker exec ai-server-redis redis-cli ping &> /dev/null; then
    echo -e "  ${GREEN}✅ Redis pronto${NC}"
else
    echo -e "  ${YELLOW}⚠️  Redis ainda iniciando...${NC}"
fi

# Check API
sleep 5
if docker ps --filter "name=ai-server-api" --format "{{.Status}}" | grep -q "Up"; then
    echo -e "  ${GREEN}✅ API rodando${NC}"
else
    echo -e "  ${YELLOW}⚠️  API ainda iniciando (verifique logs)${NC}"
fi

echo ""
echo "===================================================="
echo -e " ${GREEN}✅ RESET COMPLETO!${NC}"
echo "===================================================="
echo ""
echo " Aguarde alguns segundos para os serviços"
echo " ficarem totalmente prontos."
echo ""
echo " URLs disponíveis:"
echo "  Frontend:   http://localhost:3000"
echo "  Backend:    http://localhost:3001"
echo "  API Docs:   http://localhost:3001/api/docs"
echo ""
echo " Para ver os logs em tempo real:"
echo "   cd docker && docker compose --env-file ../.env logs -f"
echo ""
