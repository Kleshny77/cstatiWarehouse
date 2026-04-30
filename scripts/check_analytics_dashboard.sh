#!/usr/bin/env bash
# Проверка GET /analytics/dashboard на локальном сервере (регистрация временного пользователя + JWT).
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:8080}"
EMAIL="analytics-probe-$(date +%s)@cstati.test"
PASS="${PROBE_PASSWORD:-supersecret123}"

body="$(curl -fsS -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"name\":\"Probe\",\"password\":\"$PASS\"}")"
ACCESS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['access_token'])" "$body")"

orgs="$(curl -fsS "$BASE/organizations" -H "Authorization: Bearer $ACCESS")"
ORG="$(python3 -c "
import json,sys
d=json.loads(sys.argv[1])
for o in d.get('organizations',[]):
    if o.get('is_personal'):
        print(o['id'])
        break
" "$orgs")"

echo "GET $BASE/analytics/dashboard?organization_id=$ORG"
curl -fsS "$BASE/analytics/dashboard?organization_id=$ORG" \
  -H "Authorization: Bearer $ACCESS" \
  -H "Accept: application/json" | python3 -m json.tool
