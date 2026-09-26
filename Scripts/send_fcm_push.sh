#!/usr/bin/env bash
#
# Отправляет пуш через FCM HTTP v1 — так же, как это делает сервер.
#
#   ./Scripts/send_fcm_push.sh <FCM-токен> [payload.json]
#
# Нужен ключ сервисного аккаунта Firebase (JSON):
#   Firebase Console → Project settings → Service accounts → Generate new private key
# Положить в Scripts/secrets/service-account.json (папка в .gitignore)
# или указать путь: FIREBASE_SERVICE_ACCOUNT=/path/key.json ./Scripts/send_fcm_push.sh ...
#
# DRY_RUN=1 — только показать, что будет отправлено.
#
# Использует только то, что есть в macOS: curl, openssl, plutil.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="${FIREBASE_SERVICE_ACCOUNT:-$SCRIPT_DIR/secrets/service-account.json}"
FCM_TOKEN="${1:-}"
PAYLOAD_FILE="${2:-$SCRIPT_DIR/payloads/fcm_call.json}"

fail() { echo "❌ $*" >&2; exit 1; }

[[ -n "$FCM_TOKEN" ]] || fail "Не указан FCM-токен.
   Использование: $0 <FCM-токен> [payload.json]
   Токен — на главном экране приложения или в консоли Xcode (строка FCM_TOKEN=...)."
[[ -f "$PAYLOAD_FILE" ]] || fail "Нет файла payload: $PAYLOAD_FILE"
[[ -f "$KEY_FILE" ]] || fail "Нет ключа сервисного аккаунта: $KEY_FILE
   Firebase Console → Project settings → Service accounts → Generate new private key
   и сохранить как Scripts/secrets/service-account.json"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

json_value() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# 1. Тело запроса: payload + токен устройства в message.token
BODY_FILE="$WORK_DIR/body.json"
cp "$PAYLOAD_FILE" "$BODY_FILE"
plutil -replace message.token -string "$FCM_TOKEN" "$BODY_FILE" \
    || fail "В $PAYLOAD_FILE нет message.token или это не JSON"

PROJECT_ID="$(json_value "$KEY_FILE" project_id)" || fail "В ключе нет project_id"
CLIENT_EMAIL="$(json_value "$KEY_FILE" client_email)" || fail "В ключе нет client_email"
json_value "$KEY_FILE" private_key > "$WORK_DIR/key.pem" || fail "В ключе нет private_key"

echo "Проект:  $PROJECT_ID"
echo "Payload: $PAYLOAD_FILE"
echo "Токен:   ${FCM_TOKEN:0:20}…"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo; echo "DRY_RUN=1 — тело запроса:"; plutil -convert json -r -o - "$BODY_FILE"
    exit 0
fi

# 2. OAuth-токен Google: подписываем JWT ключом сервисного аккаунта и меняем на access_token
NOW="$(date +%s)"
HEADER="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)"
CLAIMS="$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/firebase.messaging","aud":"https://oauth2.googleapis.com/token","iat":%d,"exp":%d}' \
    "$CLIENT_EMAIL" "$NOW" "$((NOW + 3600))" | base64url)"
SIGNATURE="$(printf '%s' "$HEADER.$CLAIMS" | openssl dgst -sha256 -sign "$WORK_DIR/key.pem" | base64url)"

curl -sS -o "$WORK_DIR/oauth.json" https://oauth2.googleapis.com/token \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    --data-urlencode "assertion=$HEADER.$CLAIMS.$SIGNATURE"
ACCESS_TOKEN="$(json_value "$WORK_DIR/oauth.json" access_token)" \
    || fail "Google не выдал OAuth-токен: $(cat "$WORK_DIR/oauth.json")"

# 3. Отправка
HTTP_CODE="$(curl -sS -o "$WORK_DIR/response.json" -w '%{http_code}' \
    -X POST "https://fcm.googleapis.com/v1/projects/$PROJECT_ID/messages:send" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "@$BODY_FILE")"

echo
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Отправлено: $(json_value "$WORK_DIR/response.json" name)"
    exit 0
fi

echo "❌ FCM ответил $HTTP_CODE:"
cat "$WORK_DIR/response.json"; echo
RESPONSE="$(cat "$WORK_DIR/response.json")"
case "$RESPONSE" in
    *UNREGISTERED*)          echo "→ Токен устарел: приложение удалено или переустановлено. Возьмите новый токен." ;;
    *SENDER_ID_MISMATCH*)    echo "→ Токен от другого Firebase-проекта. GoogleService-Info.plist и ключ должны быть из одного проекта." ;;
    *THIRD_PARTY_AUTH_ERROR*) echo "→ Firebase не смог отправить в APNs: не загружен ключ .p8 (Project settings → Cloud Messaging) или неверный Key ID / Team ID." ;;
    *INVALID_ARGUMENT*)      echo "→ Неверный токен или payload." ;;
esac
exit 1
