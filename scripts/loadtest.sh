#!/usr/bin/env bash
# Нагрузочный скелет для локального API. Требуется `hey`: go install github.com/rakyll/hey@latest
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:8080}"
echo "BASE_URL=$BASE"

if ! command -v hey >/dev/null 2>&1; then
  echo "Установите hey: go install github.com/rakyll/hey@latest" >&2
  exit 1
fi

echo "--- GET /healthz (прогрев) ---"
hey -n 500 -c 10 "$BASE/healthz"

echo "--- POST /auth/login (ожидаем 401/400 — проверка горячей ручки) ---"
hey -n 200 -c 10 -m POST -T "application/json" \
  -d '{"email":"loadtest@example.com","password":"wrong-password-12345"}' \
  "$BASE/auth/login"

echo "--- GET /items без токена (ожидаем 401) ---"
hey -n 200 -c 10 "$BASE/items"

echo "Готово."
