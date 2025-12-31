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

# Clean up conflicting environment variables
if grep -q "^DATABASE_URL" ../.env 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  Removendo DATABASE_URL do .env${NC}"
    sed -i '/^DATABASE_URL/d' ../.env
fi
if grep -q "^REDIS_URL" ../.env 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  Removendo REDIS_URL do .env${NC}"
    sed -i '/^REDIS_URL/d' ../.env
fi

# Clean up old volumes with wrong names
OLD_VOLUMES=("docker_postgres_data" "docker_redis_data")
for vol in "${OLD_VOLUMES[@]}"; do
    if docker volume ls -q | grep -q "^${vol}$"; then
        echo -e "  ${YELLOW}⚠️  Removendo volume antigo: $vol${NC}"
        docker volume rm "$vol" 2>/dev/null || true
    fi
done

# Start fresh
$COMPOSE_CMD --env-file ../.env up -d
if [ $? -ne 0 ]; then
    echo -e "  ${RED}❌ Falha ao iniciar containers${NC}"
    echo "  Se o problema persistir, execute: ./scripts/linux/fix-db.sh"
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
    
    # Sync password from .env to running PostgreSQL
    # This fixes the issue where volume was created with different password
    POSTGRES_PASS=$(grep "^POSTGRES_PASSWORD" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    if [ -n "$POSTGRES_PASS" ]; then
        docker exec ai-server-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASS}';" &>/dev/null
        echo -e "  ${GREEN}✅ Senha do PostgreSQL sincronizada${NC}"
    fi
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
