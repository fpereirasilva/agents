#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Uso:
  BASE_URL="https://seu-app.vercel.app" \
  ADMIN_EMAIL="admin@dominio.com" \
  ADMIN_PASSWORD="senha" \
  ./engineering/scripts/kesherapp-auth-smoke.sh

Variáveis opcionais:
  LOGIN_PATH=/api/auth/login
  ADMIN_PATH=/api/admin/me
USAGE
  exit 0
fi

: "${BASE_URL:?Defina BASE_URL, ex.: https://seu-app.vercel.app}"
: "${ADMIN_EMAIL:?Defina ADMIN_EMAIL}"
: "${ADMIN_PASSWORD:?Defina ADMIN_PASSWORD}"

LOGIN_PATH="${LOGIN_PATH:-/api/auth/login}"
ADMIN_PATH="${ADMIN_PATH:-/api/admin/me}"

LOGIN_URL="${BASE_URL%/}${LOGIN_PATH}"
ADMIN_URL="${BASE_URL%/}${ADMIN_PATH}"

printf "[1/3] Testando endpoint de login: %s\n" "$LOGIN_URL"

LOGIN_TMP="$(mktemp)"
LOGIN_CODE=$(curl -sS -o "$LOGIN_TMP" -w "%{http_code}" -X POST "$LOGIN_URL" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}")

printf "HTTP login: %s\n" "$LOGIN_CODE"

if [[ "$LOGIN_CODE" != "200" ]]; then
  echo "Falha no login. Resposta:"
  cat "$LOGIN_TMP"
  rm -f "$LOGIN_TMP"
  exit 1
fi

TOKEN=$(python3 - <<'PY' "$LOGIN_TMP"
import json,sys
p=sys.argv[1]
with open(p,'r',encoding='utf-8') as f:
    data=json.load(f)
for key in ("token","accessToken","access_token"):
    if key in data and isinstance(data[key],str) and data[key].strip():
        print(data[key].strip())
        sys.exit(0)
print("")
PY
)
rm -f "$LOGIN_TMP"

if [[ -z "$TOKEN" ]]; then
  echo "Login retornou 200, mas não foi encontrado token em token/accessToken/access_token."
  exit 1
fi

printf "[2/3] Token recebido com sucesso.\n"
printf "[3/3] Testando rota admin: %s\n" "$ADMIN_URL"

ADMIN_TMP="$(mktemp)"
ADMIN_CODE=$(curl -sS -o "$ADMIN_TMP" -w "%{http_code}" -X GET "$ADMIN_URL" \
  -H "Authorization: Bearer ${TOKEN}")

printf "HTTP admin: %s\n" "$ADMIN_CODE"

if [[ "$ADMIN_CODE" != "200" ]]; then
  echo "Falha ao acessar rota admin. Resposta:"
  cat "$ADMIN_TMP"
  rm -f "$ADMIN_TMP"
  exit 1
fi

echo "Sucesso: autenticação e acesso admin estão funcionais."
rm -f "$ADMIN_TMP"
