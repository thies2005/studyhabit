# Deployment Guide

This guide covers deploying StudyTracker using **Docker Compose** (standalone) and **Coolify** (self-hosted PaaS).

---

## Prerequisites

- A server with Docker and Docker Compose installed (or a Coolify instance)
- A domain name pointing to your server (for HTTPS)
- Git installed on the server

---

## Option 1: Docker Compose (Standalone)

### Step 1: Clone the Repository

```bash
git clone https://github.com/thies2005/studyhabit.git
cd studyhabit
```

### Step 2: Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
# Database
DB_USER=studytracker
DB_PASSWORD=<generate-a-strong-password-here>

# JWT Secrets (generate with: openssl rand -hex 32)
JWT_SECRET=<64-char-random-hex-string>
JWT_REFRESH_SECRET=<different-64-char-random-hex-string>

# Public URLs
API_URL=https://api.yourdomain.com
API_PORT=3001
WEB_PORT=3000
```

**Generating secure secrets:**
```bash
# Generate a strong database password
openssl rand -base64 24

# Generate JWT secrets
openssl rand -hex 32
```

### Step 3: Build and Start

```bash
docker compose up -d --build
```

This starts three services:
| Service | Port | Description |
|---------|------|-------------|
| `db` | 5432 (internal) | PostgreSQL 16 database |
| `api` | 3001 | Express REST API |
| `web` | 3000 | React dashboard (nginx) |

### Step 4: Verify

```bash
# Check all containers are running
docker compose ps

# Check API health
curl http://localhost:3001/api/v1/auth/login

# Check web dashboard
curl -I http://localhost:3000
```

### Step 5: First-Time Database Setup

The API container automatically runs `npx prisma migrate deploy` on startup. The database schema is created from `backend/prisma/schema.prisma`.

If you need to create an initial migration (first deploy):

```bash
docker compose exec api npx prisma migrate dev --name init
```

### Step 6: Reverse Proxy (HTTPS)

For production, put a reverse proxy (Caddy, Nginx, or Traefik) in front:

**Caddy (simplest — auto HTTPS):**

```
study.yourdomain.com {
    reverse_proxy localhost:3000
}

api.study.yourdomain.com {
    reverse_proxy localhost:3001
}
```

**Nginx:**

```nginx
server {
    listen 443 ssl http2;
    server_name study.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 443 ssl http2;
    server_name api.study.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Useful Commands

```bash
# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f api
docker compose logs -f db
docker compose logs -f web

# Restart a service
docker compose restart api

# Rebuild after code changes
docker compose up -d --build

# Stop everything
docker compose down

# Stop and remove volumes (DELETES ALL DATA)
docker compose down -v

# Database backup
docker compose exec db pg_dump -U studytracker studytracker > backup_$(date +%Y%m%d).sql

# Database restore
cat backup.sql | docker compose exec -T db psql -U studytracker studytracker
```

---

## Option 2: Coolify Deployment

Coolify is a self-hosted PaaS alternative to Heroku. These instructions assume you have a running Coolify instance.

### Step 1: Add the Repository

1. Log in to your Coolify dashboard
2. Click **"Add New Resource"** → **"Public Repository"** (or Private if you've set up SSH keys)
3. Enter the repository URL: `https://github.com/thies2005/studyhabit.git`
4. Select branch: `master`
5. Click **Save**

### Step 2: Configure as Docker Compose Stack

1. In the resource settings, set **Build Type** to **Docker Compose**
2. Coolify will detect the `docker-compose.yml` at the repository root
3. The stack defines 3 services: `db`, `api`, `web`

### Step 3: Set Environment Variables

In Coolify's **Environment Variables** section for the stack, add all variables from `.env.example`:

| Variable | Value | Notes |
|----------|-------|-------|
| `DB_USER` | `studytracker` | Database username |
| `DB_PASSWORD` | *(strong password)* | Generate with `openssl rand -base64 24` |
| `JWT_SECRET` | *(64-char hex)* | Generate with `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET` | *(64-char hex)* | Different from JWT_SECRET |
| `API_URL` | `https://your-coolify-domain.com/api` | Public API URL |
| `API_PORT` | `3001` | Internal port (don't expose publicly) |
| `WEB_PORT` | `3000` | Internal port (Coolify handles routing) |

### Step 4: Configure Domains

For each service in the stack, configure the domain in Coolify:

**Web service (dashboard):**
- Domain: `study.yourdomain.com`
- Coolify auto-generates SSL via Let's Encrypt (Traefik/Let's Encrypt)

**API service:**
- Domain: `api.study.yourdomain.com`
- Coolify auto-generates SSL

**Database:**
- No domain needed (internal only)

### Step 5: Persistent Volumes

The `docker-compose.yml` includes a named volume `pgdata` for PostgreSQL. Coolify handles this automatically — your data persists across deployments.

### Step 6: Deploy

1. Click **"Deploy"** in Coolify
2. Coolify will:
   - Pull the latest code from GitHub
   - Build all 3 Docker images (multi-stage builds)
   - Start the services in order (db → api → web)
   - Run `npx prisma migrate deploy` on the API container
   - Set up HTTPS automatically via Traefik

### Step 7: Configure Web Dashboard API URL

After deployment, the web dashboard needs to know where the API is. The `VITE_API_URL` environment variable in the `web` service should point to your API domain:

```
VITE_API_URL=https://api.study.yourdomain.com
```

Set this in Coolify's environment variables for the `web` service.

### Step 8: Create an Admin Account

After the API is running, create an account through the web dashboard:

1. Open `https://study.yourdomain.com`
2. Click **Register**
3. Fill in email and password
4. You're now logged in and can start using the dashboard

### Step 9: Connect the Flutter App (Optional)

To connect the mobile app to your server:

1. Open the app → Settings → "Connect to Server" (Phase 2 card — currently disabled by default)
2. Enter your API URL: `https://api.study.yourdomain.com`
3. Login with the same credentials
4. The app will sync data to the server

> **Note:** Server sync is currently a stub. The app works fully offline by default.

### Monitoring & Updates

**View logs in Coolify:**
- Go to your stack → select service → click **"Logs"**

**Update to latest version:**
- Go to your stack → click **"Update"** → Coolify pulls latest code and rebuilds

**Automatic deployments:**
- Enable **"Auto-Update"** in Coolify to deploy on every push to `master`

**Health checks:**
- The `db` service has a built-in healthcheck: `pg_isready`
- The `api` service depends on `db` being healthy before starting

---

## Database Management

### Run Migrations Manually

```bash
# Via Docker
docker compose exec api npx prisma migrate deploy

# Via Coolify exec
# Use Coolify's "Execute Command" feature on the api service
npx prisma migrate deploy
```

### Create a New Migration

```bash
# Via Docker
docker compose exec api npx prisma migrate dev --name description_of_change

# Or locally
cd backend
npx prisma migrate dev --name description_of_change
```

### Reset Database (DANGER)

```bash
# WARNING: This deletes ALL data
docker compose exec api npx prisma migrate reset
```

### Access Database Directly

```bash
docker compose exec db psql -U studytracker studytracker
```

---

## Troubleshooting

### API won't start

```bash
# Check logs
docker compose logs api

# Common issues:
# 1. Database not ready yet — wait for db healthcheck
# 2. Missing environment variables — check .env
# 3. Migration failed — check prisma migrate status
docker compose exec api npx prisma migrate status
```

### Web shows blank page

```bash
# Check web container logs
docker compose logs web

# Verify nginx config exists
docker compose exec web cat /etc/nginx/conf.d/default.conf
```

### Database connection errors

```bash
# Verify database is running
docker compose ps db

# Check database health
docker compose exec db pg_isready

# Check connection string
docker compose exec api env | grep DATABASE_URL
```

### SSL/Certificate Issues in Coolify

1. Ensure your domain DNS records point to your Coolify server
2. Coolify uses Traefik + Let's Encrypt — certificates are auto-generated
3. If certificate fails, check Traefik logs in Coolify
4. DNS propagation can take up to 48 hours

### Port Conflicts

If ports 3000 or 3001 are already in use:

```bash
# Change ports in .env
API_PORT=3002
WEB_PORT=3001
```

---

## Security Checklist

- [ ] Change all default passwords in `.env`
- [ ] Use strong random JWT secrets (64+ chars)
- [ ] Enable HTTPS (Coolify does this automatically)
- [ ] Don't expose PostgreSQL port (5432) publicly
- [ ] Set up automated database backups
- [ ] Restrict API access to your web dashboard domain (CORS)
- [ ] Review `backend/src/config.ts` for allowed origins
- [ ] Rotate JWT secrets periodically
- [ ] Keep Docker images updated (`docker compose pull && docker compose up -d`)

---

## Backup & Restore

### Backup

```bash
# Database backup
docker compose exec db pg_dump -U studytracker studytracker > backup_$(date +%Y%m%d_%H%M%S).sql

# Full backup (database + volumes)
docker compose stop
tar -czf studytracker_backup_$(date +%Y%m%d).tar.gz .env pgdata/
docker compose start
```

### Restore

```bash
# Restore database from SQL dump
cat backup.sql | docker compose exec -T db psql -U studytracker studytracker

# Restore full backup
docker compose down
tar -xzf studytracker_backup_20240101.tar.gz
docker compose up -d
```

### Automated Backups (Cron)

```bash
# Add to crontab (crontab -e)
# Daily backup at 3 AM
0 3 * * * cd /path/to/studyhabit && docker compose exec -T db pg_dump -U studytracker studytracker > /backups/studytracker_$(date +\%Y\%m\%d).sql
```
