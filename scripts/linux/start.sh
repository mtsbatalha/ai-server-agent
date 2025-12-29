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

# Start Docker containers
echo "[1/2] Iniciando containers Docker..."
cd docker
docker-compose up -d
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

# Start the development servers
echo ""
echo "[2/2] Iniciando servidores de desenvolvimento..."
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
