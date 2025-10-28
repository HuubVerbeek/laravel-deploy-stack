#!/usr/bin/env bash
set -euo pipefail

exec docker compose \
  --env-file "${1:-env/.env}" \
  -f compose/base.yml \
  -f compose/infra.yml \
  -f compose/app.yml \
  -f compose/workers.yml \
  up -d \
  --scale app="${APP_SCALE:-2}" \
  --scale queue="${QUEUE_SCALE:-2}"
