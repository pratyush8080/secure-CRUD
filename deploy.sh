#!/usr/bin/env bash
# ================================================================
#  deploy.sh — Single Source of Truth Deployment Script
#  Secure CRUD Multi-Container System
#
#  Usage:
#    chmod +x deploy.sh
#    ./deploy.sh
# ================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'  # No Colour

# ── Banner ────────────────────────────────────────────────────
echo -e "${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║        Secure CRUD — Deployment Script       ║"
echo "  ║    Flask · PostgreSQL · Nginx · Docker       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: Check Prerequisites ──────────────────────────────
echo -e "${CYAN}${BOLD}[1/4] Checking Prerequisites...${NC}"

if ! command -v docker &>/dev/null; then
    echo -e "${RED}[ERROR] Docker is not installed.${NC}"
    echo -e "  → Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "  ${GREEN}✓ Docker found:${NC} $(docker --version)"

# Support both `docker-compose` (v1) and `docker compose` (v2)
if command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
elif docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    echo -e "${RED}[ERROR] Docker Compose is not installed.${NC}"
    echo -e "  → Install: https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "  ${GREEN}✓ Docker Compose found:${NC} $(${COMPOSE} version --short 2>/dev/null || echo 'v2')"

# Check .env file
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "  ${YELLOW}⚠ .env not found — copying from .env.example${NC}"
        cp .env.example .env
        echo -e "  ${RED}[ACTION REQUIRED] Edit .env with your credentials, then re-run this script.${NC}"
        exit 1
    else
        echo -e "${RED}[ERROR] .env file is missing and no .env.example found.${NC}"
        exit 1
    fi
fi
echo -e "  ${GREEN}✓ .env file found${NC}"

echo -e "${GREEN}  Prerequisites satisfied.${NC}\n"

# ── Step 2: Clean State ───────────────────────────────────────
echo -e "${CYAN}${BOLD}[2/4] Cleaning Previous State...${NC}"
$COMPOSE down -v --remove-orphans 2>&1 | sed 's/^/  /'
echo -e "${GREEN}  ✓ Previous containers and volumes removed.${NC}\n"

# ── Step 3: Build & Launch ────────────────────────────────────
echo -e "${CYAN}${BOLD}[3/4] Building Images & Launching Services...${NC}"
$COMPOSE up --build -d 2>&1 | sed 's/^/  /'
echo -e "${GREEN}  ✓ Services launched in detached mode.${NC}\n"

# ── Step 4: Health Check ──────────────────────────────────────
echo -e "${CYAN}${BOLD}[4/4] Waiting for Services to Become Healthy...${NC}"

MAX_WAIT=90
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Count containers still starting or unhealthy
    STARTING=$(docker ps --filter "name=crud_" --format "{{.Status}}" \
               | grep -c "starting" || true)
    UNHEALTHY=$(docker ps --filter "name=crud_" --format "{{.Status}}" \
                | grep -c "unhealthy" || true)

    if [ "$STARTING" -eq 0 ] && [ "$UNHEALTHY" -eq 0 ]; then
        break
    fi

    echo -e "  ${YELLOW}⏳ Still waiting... (${ELAPSED}s / ${MAX_WAIT}s) — ${STARTING} starting, ${UNHEALTHY} unhealthy${NC}"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

# Final status table
echo ""
echo -e "${BLUE}  Container Status:${NC}"
docker ps --filter "name=crud_" \
          --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" \
    | column -t

# Verify Nginx is actually reachable
echo ""
if curl -sf http://localhost/ >/dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}"
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [SUCCESS] Application is live at http://localhost     ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
else
    echo -e "${YELLOW}  [WARN] Nginx did not respond yet — services may need more time.${NC}"
    echo -e "  Try opening ${BOLD}http://localhost${NC} in your browser in a few seconds."
fi
