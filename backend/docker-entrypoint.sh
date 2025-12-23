#!/usr/bin/env bash
set -euo pipefail

# Construit DATABASE_URL à partir des variables + secret file, si pas déjà fourni.
if [ -z "${DATABASE_URL:-}" ]; then
  DB_HOST="${DB_HOST:-db}"
  DB_PORT="${DB_PORT:-5432}"
  DB_NAME="${DB_NAME:-evaluation}"
  DB_USER="${DB_USER:-postgres}"

  if [ -n "${DB_PASSWORD_FILE:-}" ] && [ -f "${DB_PASSWORD_FILE}" ]; then
    DB_PASSWORD="$(cat "${DB_PASSWORD_FILE}")"
  else
    echo "ERROR: DB_PASSWORD_FILE is not set or file not found." >&2
    echo "Expected a Docker secret mounted at /run/secrets/..." >&2
    exit 1
  fi

  export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi

exec "$@"


