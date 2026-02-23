# Secure CRUD — Multi-Container Task Manager

[![CI/CD Pipeline](https://github.com/pratyush8080/secure-CRUD/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/pratyush8080/secure-CRUD/actions/workflows/ci-cd.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/praty1/secure-crud?logo=docker&label=Docker%20Hub)](https://hub.docker.com/r/praty1/secure-crud)
[![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)](https://python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A production-grade, multi-container CRUD application — **Tasks** are managed through a beautiful web UI backed by Flask, PostgreSQL, and Nginx, all wired together with Docker Compose.

🐳 **Docker Hub Image → [`praty1/secure-crud`](https://hub.docker.com/r/praty1/secure-crud)**

---

## 📑 Table of Contents

1. [What This Project Does](#-what-this-project-does)
2. [Architecture Overview](#-architecture-overview)
3. [Project Structure](#-project-structure)
4. [Prerequisites](#-prerequisites)
5. [Quick Start (Recommended)](#-quick-start-recommended)
6. [Manual Setup](#-manual-setup)
7. [API Reference](#-api-reference)
8. [CI/CD Pipeline](#-cicd-pipeline)
9. [Security Design](#-security-design)
10. [Troubleshooting](#-troubleshooting)
11. [Docker Hub](#-docker-hub)

---

## 🎯 What This Project Does

This system lets you **Create, Read, Update, and Delete** tasks through:
- A **beautiful dark-themed web interface** at `http://localhost`
- A **RESTful JSON API** for programmatic access

Data is stored in PostgreSQL and **persists across container restarts and machine reboots** using a Docker named volume.

---

## 🏗 Architecture Overview

```
Browser / API Client
        │
        ▼  Port 80 (only exposed port)
┌───────────────────────────────────────────────────────────┐
│                     Docker Network (crud_network)          │
│                                                           │
│  ┌─────────────┐     ┌─────────────┐     ┌────────────┐  │
│  │    Nginx    │────▶│    Flask    │────▶│ PostgreSQL │  │
│  │  (Proxy)    │     │   (App)     │     │   (DB)     │  │
│  │  Port 80    │     │  Port 5000  │     │  Port 5432 │  │
│  └─────────────┘     └─────────────┘     └────────────┘  │
│   ← Host exposed →   ← Internal only →   ← Internal only →│
└───────────────────────────────────────────────────────────┘
                                                │
                                                ▼
                                     Named Volume: postgres_data
                                     (persists across restarts)
```

| Service  | Image               | Role                        | Host Port |
|----------|---------------------|-----------------------------|-----------|
| `nginx`  | `nginx:alpine`      | Reverse Proxy / Gatekeeper  | **80**    |
| `app`    | `praty1/secure-crud`| Flask CRUD API + Web UI     | None      |
| `db`     | `postgres:15-alpine`| Persistent Data Store       | None      |

---

## 📁 Project Structure

```
secure-CRUD/
├── src/                        # Application source code
│   ├── app.py                  # Flask app — routes, models, DB logic
│   ├── requirements.txt        # Python dependencies
│   └── templates/
│       └── index.html          # Web interface (full CRUD UI)
│
├── nginx/
│   └── nginx.conf              # Reverse proxy configuration
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml           # GitHub Actions CI/CD pipeline
│
├── docker-compose.yml          # Multi-container orchestration
├── Dockerfile                  # App image build instructions
├── deploy.sh                   # One-command deployment script
├── .env.example                # Environment variable template
├── .env                        # Your local secrets (gitignored!)
└── README.md                   # This file
```

---

## 🔧 Prerequisites

Before you begin, make sure the following are installed on your machine:

| Tool | Version | Install Guide |
|------|---------|---------------|
| Docker | 24.0+ | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| Docker Compose | v2.0+ | Bundled with Docker Desktop |
| Git | any | [git-scm.com](https://git-scm.com/) |

**Verify your setup:**
```bash
docker --version         # Docker version 24.x.x
docker compose version   # Docker Compose version v2.x.x
```

---

## ⚡ Quick Start (Recommended)

This is the fastest way to get the app running. The `deploy.sh` script handles **everything**.

### Step 1 — Clone the repository
```bash
git clone https://github.com/pratyush8080/secure-CRUD.git
cd secure-CRUD
```

### Step 2 — Run the deploy script

**On Linux / macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**On Windows (Git Bash or WSL):**
```bash
bash deploy.sh
```

### Step 3 — Open the app
```
http://localhost
```

That's it! 🎉 The script will:
1. ✅ Check if Docker & Docker Compose are installed
2. 🧹 Remove any previous containers and volumes
3. 🔨 Build the Flask image and start all 3 containers
4. ⏳ Wait for all containers to become healthy
5. 🟢 Print `[SUCCESS] Application is live at http://localhost`

---

## 🛠 Manual Setup

If you prefer to run commands step by step:

### Step 1 — Clone & enter directory
```bash
git clone https://github.com/pratyush8080/secure-CRUD.git
cd secure-CRUD
```

### Step 2 — Create your environment file
```bash
cp .env.example .env
```

Edit `.env` and set your preferred database credentials:
```dotenv
POSTGRES_DB=crud_db
POSTGRES_USER=crud_user
POSTGRES_PASSWORD=YourSecurePassword        # ← Change this!
SECRET_KEY=your-random-secret-key           # ← Change this!
```

### Step 3 — Build and start all containers
```bash
docker compose up --build -d
```

### Step 4 — Check container health
```bash
docker compose ps
```

All three containers should show `healthy`:
```
NAME          STATUS
crud_nginx    Up (healthy)
crud_app      Up (healthy)
crud_db       Up (healthy)
```

### Step 5 — Open the app
Navigate to → **[http://localhost](http://localhost)**

### Step 6 — Stop the application
```bash
docker compose down          # Stop containers (data preserved)
docker compose down -v       # Stop + delete all data (fresh start)
```

---

## 🔌 API Reference

The Flask app exposes a REST API under `/api/tasks`.

### Base URL
```
http://localhost/api/tasks
```

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/tasks` | List all tasks |
| `GET` | `/api/tasks/:id` | Get a single task |
| `POST` | `/api/tasks` | Create a new task |
| `PUT` | `/api/tasks/:id` | Update an existing task |
| `DELETE` | `/api/tasks/:id` | Delete a task |
| `GET` | `/health` | Container health check |

### Task Object
```json
{
  "id": 1,
  "title": "Configure Nginx proxy",
  "description": "Set up reverse proxy for the Flask app",
  "status": "completed",
  "created_at": "2025-01-01T10:00:00",
  "updated_at": "2025-01-01T10:30:00"
}
```

### Status Values
| Value | Meaning |
|-------|---------|
| `pending` | Task not started yet |
| `in-progress` | Task is being worked on |
| `completed` | Task is done |

### Example API Calls (curl)

**Create a task:**
```bash
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My Task", "description": "Details here", "status": "pending"}'
```

**Get all tasks:**
```bash
curl http://localhost/api/tasks
```

**Update a task:**
```bash
curl -X PUT http://localhost/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'
```

**Delete a task:**
```bash
curl -X DELETE http://localhost/api/tasks/1
```

---

## 🚀 CI/CD Pipeline

Every push to the `main` branch automatically:

```
Push to main
     │
     ▼
[GitHub Actions]
     │
     ├── 1. Build Docker image
     ├── 2. Tag as :latest + :<commit-sha> + :<short-sha>
     └── 3. Push to Docker Hub → praty1/secure-crud
```

### Setting Up CI/CD for Your Fork

Add these **GitHub Repository Secrets** (`Settings → Secrets → Actions`):

| Secret Name | Value |
|-------------|-------|
| `DOCKERHUB_USERNAME` | `praty1` |
| `DOCKERHUB_TOKEN` | Your Docker Hub Access Token |

> 💡 Create a Docker Hub access token at: `hub.docker.com → Account Settings → Security → Access Tokens`

---

## 🔒 Security Design

| Feature | Implementation |
|---------|---------------|
| Non-root container | `USER appuser` in Dockerfile |
| Slim base image | `python:3.11-slim` (minimal attack surface) |
| No DB port exposed | Only internal Docker network access |
| No App port exposed | Only accessible via Nginx proxy |
| Secrets via env vars | `.env` file, never hardcoded |
| `.env` gitignored | Credentials never in version control |
| Read-only Nginx config | Volume mounted `:ro` |

---

## 🔍 Troubleshooting

### Port 80 already in use
```bash
# Find what's using port 80
netstat -tulnp | grep :80   # Linux
netstat -ano | findstr :80  # Windows

# Change the port in docker-compose.yml
ports:
  - "8080:80"    ← use 8080 instead
```

### Containers won't start — check logs
```bash
docker compose logs app     # Flask app logs
docker compose logs db      # PostgreSQL logs
docker compose logs nginx   # Nginx logs
docker compose logs -f      # Follow all logs live
```

### Database connection errors
The Flask app automatically retries the DB connection 10 times. If it keeps failing:
```bash
docker compose ps           # Check if db container is healthy
docker compose restart app  # Restart the app after DB is ready
```

### Start completely fresh
```bash
docker compose down -v      # Removes containers AND the postgres volume
./deploy.sh                 # Redeploy from scratch
```

### View running containers
```bash
docker ps                          # All running containers
docker inspect crud_app            # Detailed container info
docker exec -it crud_db psql -U crud_user -d crud_db  # Access DB directly
```

---

## 🐳 Docker Hub

The pre-built image is publicly available on Docker Hub:

**→ [hub.docker.com/r/praty1/secure-crud](https://hub.docker.com/r/praty1/secure-crud)**

### Pull and run without cloning:
```bash
# Create a minimal docker-compose.yml or run directly
docker pull praty1/secure-crud:latest
```

### Available Tags
| Tag | Description |
|-----|-------------|
| `latest` | Latest build from main branch |
| `<commit-sha>` | Exact commit snapshot |
| `<short-sha>` | 7-char short commit reference |

---

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">
  Built with 🐍 Flask · 🐘 PostgreSQL · 🌐 Nginx · 🐳 Docker
  <br/>
  <a href="https://hub.docker.com/r/praty1/secure-crud">Docker Hub</a> ·
  <a href="http://localhost">Live App</a>
</div>
