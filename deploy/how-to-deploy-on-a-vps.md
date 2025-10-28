# How to Deploy the Laravel Docker Stack on a VPS

This guide shows **how to get your Laravel application running in production** using the provided Docker stack with **FrankenPHP**, **Traefik**, **PostgreSQL**, **Redis**, and **Watchtower**.

> **Use this when:**
> You need to deploy your Laravel application on a fresh VPS using this repository’s `deploy/` setup.

---

## Prerequisites

* A **VPS** running a recent Linux distribution (e.g., Ubuntu 22.04+ or Debian 12+).
* SSH access as a user with **sudo privileges**.
* The `/deploy` directory copied unto the VPS (e.g., `/home/deploy`).

---

## 🧭 Steps

### 1. Install Docker and Docker Compose

Follow the directions outlined [here](https://docs.docker.com/engine/install/ubuntu/).

Verify installation:

```bash
docker --version
docker compose version
```

---

### 2. Create a GitHub Personal Access Token

1. Go to **GitHub → Settings → Developer Settings → Personal access tokens → Tokens (classic)**
2. Click **“Generate new token (classic)”**.
3. Select:

    * `read:packages`
    * `repo` (if private repository)
4. Copy the token — you’ll need it for Docker authentication.

---

### 3. Log in to Docker Registry

Use your GitHub username and the generated token as password:

```bash
docker login ghcr.io -u <your-github-username>
```

> This allows **Watchtower** to pull private updates from GitHub Container Registry.

---

### 4. Fill in the Docker Environment File

Edit `deploy/env/.env.docker`:

```dotenv
APP_NAME="Project"
APP_IMAGE="ghcr.io/company/project:latest"
APP_DOMAIN="localhost"
LETSENCRYPT_EMAIL="info@example.com"
DOCKER_LOGIN_CREDENTIALS_PATH="/home/username/.docker/config.json" 
```

> All values are **required**.
> Missing any of them will cause Docker Compose to fail during deployment.

---

### 5. Set Strong Secrets

Fill in each file inside `deploy/secrets/`:

```bash
echo "base64:app-key" > deploy/secrets/app_key.txt
echo "secret" > deploy/secrets/db_password.txt
echo "secret" > deploy/secrets/mail_password.txt
echo "secret!" > deploy/secrets/redis_password.txt
```

> Each file should contain **only the secret**, with **no trailing spaces or newlines**.
> These are mounted securely as Docker secrets under `/run/secrets/`.

---

### 6. Deploy the Stack

Navigate to the deployment directory and bring up the full stack:

```bash
cd deploy
bash bin/up.sh
```

This will:

* Build and start **Postgres**, **Redis**, **Traefik**, **FrankenPHP**, and **Watchtower**.
* Automatically request a Let’s Encrypt certificate via Traefik.
* Run Laravel workers and scheduler in the background.

Verify services:

```bash
docker ps
```

Check logs:

```bash
bash bin/logs.sh
```

---

## ✅ Result

If all steps completed successfully:

* Your application is available at `https://<APP_DOMAIN>`.
* SSL certificates are automatically managed by Traefik.
* Watchtower keeps containers updated.
* Laravel queues and schedules are active.

---

## 🧹 Troubleshooting

| Problem                          | Likely Cause                        | Fix                                  |
| -------------------------------- | ----------------------------------- | ------------------------------------ |
| `APP_IMAGE missing in .env file` | `.env.docker` missing required vars | Check and fill all values            |
| SSL not issued                   | Domain not pointing to VPS          | Ensure DNS points to your server IP  |
| Watchtower errors                | Docker login missing                | Re-run `docker login ghcr.io`        |
| Containers unhealthy             | Secrets invalid or missing          | Verify files under `deploy/secrets/` |

---

## 🪶 Summary

You’ve learned **how to deploy the Laravel stack** on a VPS, using:

* Docker for isolation
* Traefik for HTTPS routing
* Watchtower for continuous updates
* and Laravel’s native queue/scheduler workers
