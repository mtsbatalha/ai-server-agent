#!/bin/bash

# ============================================
# AI Server Admin - Status Script
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo ""
echo "========================================================================"
echo " 🖥️  AI SERVER ADMIN - STATUS DOS SERVIÇOS"
echo "========================================================================"
echo " Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================"
echo ""

# ============================================
# DOCKER CONTAINERS STATUS
# ============================================
echo -e " ${BOLD}📦 CONTAINERS DOCKER${NC}"
echo "------------------------------------------------------------------------"

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    echo -e "   ${RED}❌ Docker não encontrado no sistema${NC}"
else
    if ! docker info &> /dev/null; then
        echo -e "   ${RED}❌ Docker não está rodando${NC}"
    else
        echo ""
        printf "   %-22s %-16s %-14s %-10s\n" "Container" "Status" "Porta" "Health"
        printf "   %-22s %-16s %-14s %-10s\n" "--------------------" "--------------" "------------" "--------"

        # PostgreSQL Status
        PG_STATUS="${RED}❌ Parado${NC}"
        PG_PORT="-"
        PG_HEALTH="-"

        if docker ps --filter "name=ai-server-postgres" --format "{{.Status}}" 2>/dev/null | grep -q .; then
            PG_STATUS="${GREEN}✅ Rodando${NC}"
            PG_PORT="5432"
            if docker exec ai-server-postgres pg_isready -U postgres &> /dev/null; then
                PG_HEALTH="Healthy"
            else
                PG_HEALTH="Starting"
            fi
        fi

        printf "   %-22s " "PostgreSQL"
        echo -e "$PG_STATUS      $PG_PORT          $PG_HEALTH"

        # Redis Status
        REDIS_STATUS="${RED}❌ Parado${NC}"
        REDIS_PORT="-"
        REDIS_HEALTH="-"

        if docker ps --filter "name=ai-server-redis" --format "{{.Status}}" 2>/dev/null | grep -q .; then
            REDIS_STATUS="${GREEN}✅ Rodando${NC}"
            REDIS_PORT="6379"
            if docker exec ai-server-redis redis-cli ping &> /dev/null; then
                REDIS_HEALTH="Healthy"
            else
                REDIS_HEALTH="Starting"
            fi
        fi

        printf "   %-22s " "Redis"
        echo -e "$REDIS_STATUS      $REDIS_PORT          $REDIS_HEALTH"
    fi
fi

# ============================================
# NODE.JS APPLICATIONS STATUS
# ============================================
echo ""
echo "------------------------------------------------------------------------"
echo -e " ${BOLD}🚀 APLICAÇÕES NODE.JS${NC}"
echo "------------------------------------------------------------------------"
echo ""
printf "   %-22s %-16s %-14s %-10s\n" "Aplicação" "Status" "Porta" "PID"
printf "   %-22s %-16s %-14s %-10s\n" "--------------------" "--------------" "------------" "--------"

# Check Frontend (port 3000)
WEB_STATUS="${RED}❌ Parado${NC}"
WEB_PORT="-"
WEB_PID="-"

WEB_PID_VAL=$(lsof -t -i:3000 2>/dev/null | head -1)
if [ -n "$WEB_PID_VAL" ]; then
    WEB_STATUS="${GREEN}✅ Rodando${NC}"
    WEB_PORT="3000"
    WEB_PID="$WEB_PID_VAL"
fi

printf "   %-22s " "Frontend (Next.js)"
echo -e "$WEB_STATUS      $WEB_PORT          $WEB_PID"

# Check Backend (port 3001)
API_STATUS="${RED}❌ Parado${NC}"
API_PORT="-"
API_PID="-"

API_PID_VAL=$(lsof -t -i:3001 2>/dev/null | head -1)
if [ -n "$API_PID_VAL" ]; then
    API_STATUS="${GREEN}✅ Rodando${NC}"
    API_PORT="3001"
    API_PID="$API_PID_VAL"
fi

printf "   %-22s " "Backend (NestJS)"
echo -e "$API_STATUS      $API_PORT          $API_PID"

# ============================================
# URLS
# ============================================
echo ""
echo "------------------------------------------------------------------------"
echo -e " ${BOLD}🌐 URLs DE ACESSO${NC}"
echo "------------------------------------------------------------------------"
echo ""

if [ -n "$WEB_PID_VAL" ]; then
    echo "   Frontend:     http://localhost:3000"
else
    echo "   Frontend:     [NÃO DISPONÍVEL]"
fi

if [ -n "$API_PID_VAL" ]; then
    echo "   Backend API:  http://localhost:3001"
    echo "   API Docs:     http://localhost:3001/api/docs"
else
    echo "   Backend API:  [NÃO DISPONÍVEL]"
    echo "   API Docs:     [NÃO DISPONÍVEL]"
fi

# ============================================
# ENVIRONMENT CONFIGURATION
# ============================================
echo ""
echo "------------------------------------------------------------------------"
echo -e " ${BOLD}⚙️  CONFIGURAÇÃO DO AMBIENTE${NC}"
echo "------------------------------------------------------------------------"
echo ""

if [ -f ".env" ]; then
    echo -e "   Arquivo .env:   ${GREEN}✅ Configurado${NC}"
    
    # Check AI Provider configured
    AI_CONFIGURED=""
    
    if grep -q "OPENAI_API_KEY" .env && ! grep -q "sk-your\|your-" .env; then
        AI_CONFIGURED="OpenAI"
    fi
    
    if grep -q "GEMINI_API_KEY" .env && ! grep "GEMINI_API_KEY" .env | grep -q "your-"; then
        [ -n "$AI_CONFIGURED" ] && AI_CONFIGURED="$AI_CONFIGURED/"
        AI_CONFIGURED="${AI_CONFIGURED}Gemini"
    fi
    
    if grep -q "GROQ_API_KEY" .env && ! grep "GROQ_API_KEY" .env | grep -q "your-"; then
        [ -n "$AI_CONFIGURED" ] && AI_CONFIGURED="$AI_CONFIGURED/"
        AI_CONFIGURED="${AI_CONFIGURED}Groq"
    fi
    
    [ -z "$AI_CONFIGURED" ] && AI_CONFIGURED="Nenhum configurado"
    
    echo "   AI Provider:    $AI_CONFIGURED"
else
    echo -e "   Arquivo .env:   ${RED}❌ Não encontrado${NC}"
    echo "   Execute install.sh para configurar"
fi

# ============================================
# RECENT LOGS (Docker)
# ============================================
echo ""
echo "------------------------------------------------------------------------"
echo -e " ${BOLD}📜 LOGS RECENTES DOS CONTAINERS${NC}"
echo "------------------------------------------------------------------------"

if docker ps --filter "name=ai-server-postgres" --format "{{.Status}}" 2>/dev/null | grep -q .; then
    echo ""
    echo "   [PostgreSQL - Últimas 3 linhas]"
    docker logs ai-server-postgres --tail 3 2>&1 | sed 's/^/   /'
fi

if docker ps --filter "name=ai-server-redis" --format "{{.Status}}" 2>/dev/null | grep -q .; then
    echo ""
    echo "   [Redis - Últimas 3 linhas]"
    docker logs ai-server-redis --tail 3 2>&1 | sed 's/^/   /'
fi

# ============================================
# DISK USAGE
# ============================================
echo ""
echo "------------------------------------------------------------------------"
echo -e " ${BOLD}💾 USO DE DISCO (Docker)${NC}"
echo "------------------------------------------------------------------------"
echo ""
docker system df 2>/dev/null | sed 's/^/   /'

# ============================================
# SUMMARY
# ============================================
echo ""
echo "========================================================================"
echo -e " ${BOLD}📊 RESUMO${NC}"
echo "========================================================================"

TOTAL_SERVICES=4
RUNNING_SERVICES=0

docker ps --filter "name=ai-server-postgres" --format "{{.Status}}" 2>/dev/null | grep -q . && ((RUNNING_SERVICES++))
docker ps --filter "name=ai-server-redis" --format "{{.Status}}" 2>/dev/null | grep -q . && ((RUNNING_SERVICES++))
[ -n "$WEB_PID_VAL" ] && ((RUNNING_SERVICES++))
[ -n "$API_PID_VAL" ] && ((RUNNING_SERVICES++))

echo ""
if [ $RUNNING_SERVICES -eq $TOTAL_SERVICES ]; then
    echo -e "   ${GREEN}✅ Todos os serviços estão rodando ($RUNNING_SERVICES/$TOTAL_SERVICES)${NC}"
elif [ $RUNNING_SERVICES -eq 0 ]; then
    echo -e "   ${RED}❌ Nenhum serviço está rodando ($RUNNING_SERVICES/$TOTAL_SERVICES)${NC}"
    echo "   Execute start.sh para iniciar"
else
    echo -e "   ${YELLOW}⚠️  Alguns serviços estão parados ($RUNNING_SERVICES/$TOTAL_SERVICES)${NC}"
fi

echo ""
echo "========================================================================"
echo ""
