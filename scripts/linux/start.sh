#!/bin/bash

# ============================================
# AI Server Admin - Start Script
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
echo " 🖥️  AI SERVER ADMIN - INICIAR SERVIÇOS"
echo "===================================================="
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "  ${RED}❌ Arquivo .env não encontrado!${NC}"
    echo "  Execute install.sh primeiro."
    exit 1
fi

# Check for docker-compose or docker compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "  ${RED}❌ Docker Compose não encontrado.${NC}"
    exit 1
fi

# Start Docker containers
echo "[1/2] Iniciando containers Docker..."
cd docker
$COMPOSE_CMD up -d
if [ $? -ne 0 ]; then
    echo -e "  ${RED}❌ Falha ao iniciar containers Docker${NC}"
    echo "  Verifique se o Docker está rodando."
    cd ..
    exit 1
fi
cd ..
echo -e "  ${GREEN}✅ Containers Docker iniciados${NC}"

# Wait for services to be ready
echo ""
echo "Aguardando serviços ficarem prontos..."
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
$COMPOSE_CMD logs -f api web
