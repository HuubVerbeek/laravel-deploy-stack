#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1) Load secrets from *_FILE (securely read Docker secrets)
# ---------------------------------------------------------------------------
# This allows Docker secrets to override sensitive environment variables
# without exposing them in docker inspect output.
# Each *_FILE variable should point to a file containing the secret value.
###############################################################################
for var in APP_KEY DB_PASSWORD REDIS_PASSWORD MAIL_PASSWORD; do
  fileVar="${var}_FILE"
  if [[ -n "${!fileVar-}" && -f "${!fileVar}" ]]; then
    # Trim possible CR/LF at the end (avoids Redis “WRONGPASS” issues)
    export "$var"="$(tr -d '\r\n' < "${!fileVar}")"
  fi
done

: "${APP_KEY:?APP_KEY is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"

###############################################################################
# 2) Laravel pre-boot setup (idempotent runtime tasks)
# ---------------------------------------------------------------------------
# Clear any stale cache from build time, then rebuild optimized caches.
# These commands make Laravel faster and ensure the runtime environment
# reflects actual Docker secrets and env vars (which may differ from build-time).
###############################################################################

# Ensure Laravel is accessible before running commands
if [ -f /app/artisan ]; then
  php artisan config:clear || true
  php artisan cache:clear || true
  php artisan route:clear || true
  php artisan view:clear || true
  php artisan event:clear || true

  # Rebuild caches for production performance
  php artisan config:cache --no-ansi --quiet || true
  php artisan route:cache --no-ansi --quiet || true
  php artisan view:cache --no-ansi --quiet || true
  php artisan event:cache --no-ansi --quiet || true
else
  echo "  Artisan not found. Skipping Laravel optimization."
fi

###############################################################################
# 3) Run database migrations (isolated and safe for parallel containers)
# ---------------------------------------------------------------------------
# In containerized deployments, multiple instances may start simultaneously.
# Using the --isolated flag ensures each migration runs in its own transaction
# and avoids race conditions between parallel containers.
###############################################################################
if [ -f /app/artisan ]; then
  php artisan migrate --force --isolated || true
else
  echo "  Artisan not found. Skipping migrations."
fi

###############################################################################
# 4) Start the FrankenPHP server
# ---------------------------------------------------------------------------
# The base image’s docker-php-entrypoint is already patched to run
# `frankenphp run`. Here we directly call FrankenPHP with the default
# Caddyfile adapter. Replace the config path if your project overrides it.
###############################################################################
exec frankenphp run --config /etc/frankenphp/Caddyfile --adapter caddyfile
