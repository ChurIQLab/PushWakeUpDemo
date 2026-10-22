#!/usr/bin/env bash
#
# Отправляет VoIP-пуш напрямую в APNs. Firebase VoIP-пуши не отправляет —
# сервер для VoIP всегда ходит в APNs сам, ровно так, как делает этот скрипт.
#
#   ./Scripts/send_voip_push.sh <VoIP-токен> [payload.json]
#
# Нужен ключ APNs (.p8) — тот же, что загружен в Firebase:
#   developer.apple.com → Keys → Apple Push Notifications service (APNs)
# Положить в Scripts/secrets/AuthKey_<KEY_ID>.p8 (папка в .gitignore) — Key ID берётся из имени файла.
#
# Переменные (необязательные):
#   APNS_KEY_FILE   путь к .p8, если он не в Scripts/secrets/
#   APNS_KEY_ID     Key ID, если имя файла не AuthKey_<KEY_ID>.p8
#   APNS_TEAM_ID    Team ID (по умолчанию — DEVELOPMENT_TEAM из проекта)
#   APNS_BUNDLE_ID  bundle ID приложения (по умолчанию com.churiqlab.PushWakeUpDemo)
#   APNS_ENV        sandbox (сборка из Xcode, по умолчанию) или production (TestFlight / App Store)
#   DRY_RUN=1       только показать, что будет отправлено
#
# Использует только то, что есть в macOS: curl, openssl, xxd.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="$SCRIPT_DIR/../PushWakeUpDemo.xcodeproj/project.pbxproj"
VOIP_TOKEN="${1:-}"
PAYLOAD_FILE="${2:-$SCRIPT_DIR/payloads/voip_call.json}"

fail() { echo "❌ $*" >&2; exit 1; }

[[ -n "$VOIP_TOKEN" ]] || fail "Не указан VoIP-токен.
   Использование: $0 <VoIP-токен> [payload.json]
   Токен — на главном экране приложения или в консоли Xcode (строка VOIP_TOKEN=...).
   Это НЕ FCM-токен: VoIP-токен выдаёт PushKit, только на реальном iPhone."
[[ -f "$PAYLOAD_FILE" ]] || fail "Нет файла payload: $PAYLOAD_FILE"

KEY_FILE="${APNS_KEY_FILE:-$(ls "$SCRIPT_DIR"/secrets/AuthKey_*.p8 2>/dev/null | head -1 || true)}"
[[ -n "$KEY_FILE" && -f "$KEY_FILE" ]] || fail "Нет ключа APNs (.p8).
   developer.apple.com → Keys → Apple Push Notifications service (APNs) → Download
   и положить как Scripts/secrets/AuthKey_<KEY_ID>.p8"

KEY_ID="${APNS_KEY_ID:-$(basename "$KEY_FILE" .p8 | sed -n 's/^AuthKey_//p')}"
[[ -n "$KEY_ID" ]] || fail "Не удалось взять Key ID из имени файла. Укажите APNS_KEY_ID=..."

TEAM_ID="${APNS_TEAM_ID:-$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' "$PROJECT_FILE" 2>/dev/null | awk '{print $3}' || true)}"
[[ -n "$TEAM_ID" ]] || fail "Не найден Team ID. Укажите APNS_TEAM_ID=..."

BUNDLE_ID="${APNS_BUNDLE_ID:-com.churiqlab.PushWakeUpDemo}"
case "${APNS_ENV:-sandbox}" in
    sandbox)    HOST="api.sandbox.push.apple.com" ;;
    production) HOST="api.push.apple.com" ;;
    *)          fail "APNS_ENV должен быть sandbox или production" ;;
esac

echo "APNs:    $HOST"
echo "Topic:   $BUNDLE_ID.voip"
echo "Key ID:  $KEY_ID, Team ID: $TEAM_ID"
echo "Payload: $PAYLOAD_FILE"
echo "Токен:   ${VOIP_TOKEN:0:20}…"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo; echo "DRY_RUN=1 — тело запроса:"; cat "$PAYLOAD_FILE"
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# 1. JWT для APNs: ES256, подпись ключом .p8.
#    openssl отдаёт подпись в DER, а JWT нужен «сырой» вид r||s (по 32 байта).
HEADER="$(printf '{"alg":"ES256","kid":"%s"}' "$KEY_ID" | base64url)"
CLAIMS="$(printf '{"iss":"%s","iat":%d}' "$TEAM_ID" "$(date +%s)" | base64url)"
printf '%s' "$HEADER.$CLAIMS" | openssl dgst -sha256 -sign "$KEY_FILE" > "$WORK_DIR/signature.der" \
    || fail "Не удалось подписать JWT ключом $KEY_FILE — это точно ключ APNs (.p8)?"

RAW_SIGNATURE=""
for INTEGER in $(openssl asn1parse -inform DER -in "$WORK_DIR/signature.der" | awk -F: '/INTEGER/ {print $NF}'); do
    INTEGER="$(printf '%064s' "${INTEGER: -64}" | tr ' ' '0')"   # ровно 32 байта
    RAW_SIGNATURE+="$INTEGER"
done
SIGNATURE="$(printf '%s' "$RAW_SIGNATURE" | xxd -r -p | base64url)"
JWT="$HEADER.$CLAIMS.$SIGNATURE"

# 2. Отправка: HTTP/2, topic с суффиксом .voip, push-type voip
HTTP_CODE="$(curl -sS --http2 -o "$WORK_DIR/response.json" -w '%{http_code}' \
    -X POST "https://$HOST/3/device/$VOIP_TOKEN" \
    -H "authorization: bearer $JWT" \
    -H "apns-topic: $BUNDLE_ID.voip" \
    -H "apns-push-type: voip" \
    -H "apns-priority: 10" \
    -H "apns-expiration: 0" \
    --data-binary "@$PAYLOAD_FILE")"

echo
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ APNs принял VoIP-пуш"
    exit 0
fi

RESPONSE="$(cat "$WORK_DIR/response.json")"
echo "❌ APNs ответил $HTTP_CODE: $RESPONSE"
case "$RESPONSE" in
    *BadDeviceToken*)         echo "→ Токен не подходит: это не VoIP-токен или не то окружение (сборка из Xcode — APNS_ENV=sandbox, TestFlight — production)." ;;
    *DeviceTokenNotForTopic*) echo "→ Токен от другого приложения: проверьте APNS_BUNDLE_ID. FCM-токен сюда не подходит." ;;
    *InvalidProviderToken*)   echo "→ Ключ не принят: проверьте Key ID и Team ID, ключ должен быть с включённым APNs." ;;
    *ExpiredProviderToken*)   echo "→ JWT просрочен: проверьте время на Mac." ;;
    *Unregistered*)           echo "→ Токен больше не действует: приложение удалено или переустановлено. Возьмите новый." ;;
    *TopicDisallowed*)        echo "→ Ключ не разрешает этот topic." ;;
esac
exit 1
