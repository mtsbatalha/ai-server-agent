#!/bin/bash

# ============================================
# AI Server Admin - Install Script
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd "$PROJECT_DIR"

echo ""
echo "===================================================="
echo " 🖥️  AI SERVER ADMIN - INSTALAÇÃO"
echo "===================================================="
echo ""

# Check Node.js
echo -e "[1/6] Verificando Node.js..."
if ! command -v node &> /dev/null; then
    echo -e "  ${YELLOW}⚠️  Node.js não encontrado!${NC}"
    echo ""
    read -p "  Deseja instalar o Node.js 20 automaticamente? (s/n): " INSTALL_NODE
    if [[ "$INSTALL_NODE" =~ ^[Ss]$ ]]; then
        echo "  Instalando Node.js 20..."
        
        # Detect package manager and install
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
            dnf install -y nodejs
        elif command -v yum &> /dev/null; then
            # CentOS/older RHEL
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
            yum install -y nodejs
        else
            echo -e "  ${RED}❌ Gerenciador de pacotes não suportado.${NC}"
            echo "  Por favor, instale o Node.js 18+ manualmente de: https://nodejs.org"
            exit 1
        fi
        
        if ! command -v node &> /dev/null; then
            echo -e "  ${RED}❌ Falha ao instalar Node.js${NC}"
            exit 1
        fi
    else
        echo "  Por favor, instale o Node.js 18+ de: https://nodejs.org"
        exit 1
    fi
fi
NODE_VERSION=$(node -v)
echo -e "  ${GREEN}✅ Node.js encontrado: $NODE_VERSION${NC}"

# Check pnpm
echo ""
echo -e "[2/6] Verificando pnpm..."
if ! command -v pnpm &> /dev/null; then
    echo -e "  ${YELLOW}⚠️  pnpm não encontrado. Instalando...${NC}"
    npm install -g pnpm
fi
PNPM_VERSION=$(pnpm -v)
echo -e "  ${GREEN}✅ pnpm encontrado: v$PNPM_VERSION${NC}"

# Check Docker
echo ""
echo -e "[3/6] Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo -e "  ${RED}❌ Docker não encontrado!${NC}"
    echo "  Por favor, instale o Docker de: https://docker.com"
    exit 1
fi
if ! docker info &> /dev/null; then
    echo -e "  ${YELLOW}⚠️  Docker não está rodando! Por favor, inicie o Docker.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✅ Docker encontrado e rodando${NC}"

# Install dependencies
echo ""
echo -e "[4/6] Instalando dependências..."
pnpm install
echo -e "  ${GREEN}✅ Dependências instaladas${NC}"

# Configure .env
echo ""
echo -e "[5/6] Configurando ambiente..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "  ${GREEN}✅ Arquivo .env criado a partir de .env.example${NC}"
        echo -e "  ${YELLOW}⚠️  IMPORTANTE: Edite o arquivo .env com suas configurações!${NC}"
    else
        echo -e "  ${RED}❌ Arquivo .env.example não encontrado!${NC}"
        exit 1
    fi
else
    echo -e "  ${GREEN}✅ Arquivo .env já existe${NC}"
fi

# Start Docker containers
echo ""
echo -e "[6/6] Iniciando containers Docker..."
cd docker
docker-compose up -d
cd ..
echo -e "  ${GREEN}✅ Containers Docker iniciados${NC}"

# Wait for PostgreSQL
echo ""
echo "Aguardando PostgreSQL ficar pronto..."
counter=0
while ! docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; do
    counter=$((counter + 1))
    if [ $counter -ge 30 ]; then
        echo -e "  ${RED}❌ Timeout aguardando PostgreSQL${NC}"
        exit 1
    fi
    sleep 1
done
echo -e "  ${GREEN}✅ PostgreSQL pronto!${NC}"

# Configure Prisma
echo ""
echo "Configurando banco de dados..."
pnpm db:generate || echo -e "  ${YELLOW}⚠️  Aviso: Falha ao gerar cliente Prisma${NC}"
pnpm db:push || echo -e "  ${YELLOW}⚠️  Aviso: Falha ao sincronizar schema do banco${NC}"
echo -e "  ${GREEN}✅ Banco de dados configurado${NC}"

echo ""
echo "===================================================="
echo -e " ${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo "===================================================="
echo ""
echo " Próximos passos:"
echo "   1. Edite o arquivo .env com suas chaves de API"
echo "   2. Execute ./scripts/linux/start.sh para iniciar o projeto"
echo ""
echo " URLs:"
echo "   - Frontend: http://localhost:3000"
echo "   - Backend API: http://localhost:3001"
echo "   - API Docs: http://localhost:3001/api/docs"
echo ""
