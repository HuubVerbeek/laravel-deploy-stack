# Laravel Docker Stack (FrankenPHP + Traefik + Redis + Postgres)

A modular, production-ready Docker setup for running Laravel applications using **FrankenPHP** behind **Traefik**, with **Redis**, **PostgreSQL**, and **Watchtower** for automated updates.

---

## 📁 Directory Structure

```
deploy/
├── compose/
│   ├── base.yml        # Core services: Postgres, Redis, networks, secrets, volumes
│   ├── infra.yml       # Infrastructure: Traefik reverse proxy + Watchtower
│   ├── app.yml         # Main HTTP app (FrankenPHP)
│   └── workers.yml     # Background jobs: queue workers + scheduler
├── env/
│   ├── .env.app        # Container environment for Laravel
│   ├── .env.docker     # Global environment overrides
├── secrets/
│   ├── app_key.txt
│   ├── db_password.txt
│   ├── mail_password.txt
│   └── redis_password.txt
├── config/
│   └── Caddyfile       # FrankenPHP web server configuration
├── bin/
│   ├── up.sh           # Start full stack
│   ├── down.sh         # Stop and remove stack
│   └── logs.sh         # Tail logs for all containers
├── entrypoint.sh       # Laravel bootstrap script
├── README.md        

.github/
├── compose/
│   ├── build.yml       # GitHub action to build the Laravel app
 
Dockerfile              # Image definition for the Laravel app
```

---

## 🚀 Overview

This stack is designed for **reproducible, multi-service Laravel deployments**, combining:

* **FrankenPHP** – modern PHP runtime with HTTP server built-in.
* **Traefik** – edge router handling HTTPS (Let’s Encrypt) and load balancing.
* **PostgreSQL** – main database.
* **Redis** – caching and queue backend.
* **Watchtower** – automatic rolling image updates.
* **Workers** – queue processor and scheduler containers.

---

## ⚙️ Configuration

### Environment Files

* `env/.env.app` → main environment for the Laravel application container (`app`, `queue`, `scheduler`).
* `env/.env` → defines Docker-level configuration used by all Compose files.

### Secrets

Stored as Docker secrets (never committed):

```
secrets/
├── app_key.txt
├── db_password.txt
├── mail_password.txt
└── redis_password.txt
```

Each service references them under `/run/secrets/<name>`.

---

## 🧩 Compose Files

### 1. `base.yml` — Core Infrastructure

Defines networks, volumes, and secrets.
Includes:

* `postgres` (with healthcheck)
* `redis` (with password required)



---

### 2. `infra.yml` — Reverse Proxy and Maintenance

Sets up **Traefik** and **Watchtower**:

* Traefik handles HTTPS (ACME/Let’s Encrypt) and routes.
* Watchtower watches all containers with the label `com.centurylinklabs.watchtower.enable=true` for auto-updates.



---

### 3. `app.yml` — Main Application (FrankenPHP)

Defines:

* `app` service with load balancing, health checks, and Traefik routing.
* HTTPS termination via Traefik using the `web` and `backend` networks.

Environment variables and secrets injected securely for Laravel:

* `APP_KEY_FILE`, `DB_PASSWORD_FILE`, etc.



---

### 4. `workers.yml` — Queue and Scheduler

Two lightweight containers:

* **`queue`** → runs `php artisan queue:work redis`
* **`scheduler`** → runs `php artisan schedule:work`
  Both depend on `postgres` and `redis` and include independent health checks.



---

## 🧱 Networks & Volumes

| Type    | Name          | Purpose                                 |
| ------- | ------------- | --------------------------------------- |
| Network | `web`         | Public HTTP/HTTPS traffic (Traefik)     |
| Network | `backend`     | Internal communication between services |
| Volume  | `pgdata`      | PostgreSQL data                         |
| Volume  | `letsencrypt` | ACME cert storage for Traefik           |

---

## 🧰 Operational Scripts (`bin/`)

| Script    | Description                                 |
| --------- | ------------------------------------------- |
| `up.sh`   | Starts all services using all compose files |
| `down.sh` | Stops and removes all running containers    |
| `logs.sh` | Follows logs from all containers            |

Example:

```bash
./bin/up.sh          # start stack
./bin/logs.sh app    # tail app logs
./bin/down.sh        # stop stack
```

**Note:** run the scripts from the `deploy` directory

---

## 🧑‍💻 Usage

### 1. Build and Start

```bash
cd deploy
./deploy/up.sh
```

This composes `base.yml`, `infra.yml`, `app.yml`, and `workers.yml`.

### 2. Check Services

```bash
docker ps
docker compose -f compose/base.yml ps
```

### 3. Logs

```bash
./deploy/logs.sh
```

### 4. Stop and Remove

```bash
./deploy/down.sh
```

---

## 🔒 Security Notes

* Use production-ready `.env` and `secrets/` files (never commit them).
* Use strong, random passwords for all secrets.

---

## 🩺 Healthchecks

All major services define `healthcheck` commands:

* **Postgres:** `pg_isready`
* **Redis:** internal auth test
* **App:** `curl -fsS http://localhost/health`
* **Queue/Scheduler:** `php artisan about`


---

## 🧾 License & Attribution

Private repository.
Created and maintained by our team for internal Laravel projects.
Includes third-party open-source components (Traefik, Redis, Postgres, Watchtower) under their respective licenses.

