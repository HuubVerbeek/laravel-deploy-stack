#!/usr/bin/env bash
set -euo pipefail

docker compose \
  --env-file "${1:-env/.env}" \
  -f compose/base.yml \
  -f compose/infra.yml \
  -f compose/app.yml \
  -f compose/workers.yml \
  down \
  --remove-orphans
