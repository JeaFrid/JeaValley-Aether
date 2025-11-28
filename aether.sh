#!/usr/bin/env bash
# JeaValley Aether shell istemcisi (Python gerekmez). Bağımlılıklar: curl, jq
set -euo pipefail

CONFIG_PATH="${JEATUNNEL_CONFIG:-$HOME/.jeatunnel.conf}"
DEFAULT_BASE_URL="${JEATUNNEL_SERVER:-http://127.0.0.1:8000}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Gerekli komut bulunamadı: $1" >&2
    exit 1
  fi
}
require_cmd curl
require_cmd jq

BASE_URL="$DEFAULT_BASE_URL"
TOKEN=""
USER_ID=""
USERNAME=""
PLAN=""
SHARE_URL=""

load_config() {
  if [ -f "$CONFIG_PATH" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_PATH"
  fi
}

save_config() {
  cat >"$CONFIG_PATH" <<EOF
BASE_URL="$BASE_URL"
TOKEN="$TOKEN"
USER_ID="$USER_ID"
USERNAME="$USERNAME"
PLAN="$PLAN"
SHARE_URL="$SHARE_URL"
EOF
}

api_request() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  local url="${BASE_URL%/}${path}"

  local auth_headers=()
  if [ -n "$TOKEN" ]; then
    auth_headers=(-H "Authorization: Bearer $TOKEN")
  fi

  # Curl çıkışından HTTP kodunu ayıkla
  local response
  response=$(curl -s -w "\n%{http_code}" -X "$method" \
    -H "Content-Type: application/json" \
    "${auth_headers[@]}" \
    ${data:+-d "$data"} \
    "$url")
  local http_code="${response##*$'\n'}"
  local body="${response%$'\n'*}"

  if [ "$http_code" -ge 400 ]; then
    local msg
    msg=$(echo "$body" | jq -r '.detail // .error // .status // empty')
    [ -n "$msg" ] || msg="$body"
    echo "Hata [$http_code]: $msg" >&2
    return 1
  fi

  echo "$body"
}

prompt_password() {
  local prompt="$1"
  local pw
  read -rs -p "$prompt" pw
  echo
  printf "%s" "$pw"
}

do_register() {
  local username password plan
  username="${1:-}"
  password="${2:-}"
  plan="${3:-}"
  [ -n "$username" ] || read -rp "Kullanıcı adı: " username
  [ -n "$password" ] || password=$(prompt_password "Şifre: ")
  [ -n "$plan" ] || read -rp "Plan (premium/elite/premium_plus/founder) [premium]: " plan
  plan=${plan:-premium}

  local body
  body=$(api_request POST "/register" "$(jq -n --arg u "$username" --arg p "$password" --arg pl "$plan" '{username:$u,password:$p,plan:$pl}')") || return 1
  TOKEN=$(echo "$body" | jq -r '.token')
  USER_ID=$(echo "$body" | jq -r '.user_id')
  USERNAME=$(echo "$body" | jq -r '.username')
  PLAN=$(echo "$body" | jq -r '.plan')
  SHARE_URL=$(echo "$body" | jq -r '.share_url')
  save_config
  echo "Giriş yapıldı. UID: $USER_ID | Plan: $PLAN"
  echo "Paylaşılacak VPS linki: $SHARE_URL"
}

do_login() {
  local username password
  username="${1:-}"
  password="${2:-}"
  [ -n "$username" ] || read -rp "Kullanıcı adı: " username
  [ -n "$password" ] || password=$(prompt_password "Şifre: ")

  local body
  body=$(api_request POST "/login" "$(jq -n --arg u "$username" --arg p "$password" '{username:$u,password:$p}')" ) || return 1
  TOKEN=$(echo "$body" | jq -r '.token')
  USER_ID=$(echo "$body" | jq -r '.user_id')
  USERNAME=$(echo "$body" | jq -r '.username')
  PLAN=$(echo "$body" | jq -r '.plan')
  SHARE_URL=$(echo "$body" | jq -r '.share_url')
  save_config
  echo "Giriş başarılı. UID: $USER_ID"
  echo "Paylaşılacak VPS linki: $SHARE_URL"
}

do_run() {
  if [ -z "$TOKEN" ]; then
    echo "Önce giriş yapmalısın." >&2
    exit 1
  fi
  local port="${1:-}"
  [ -n "$port" ] || read -rp "Tünellenecek port: " port
  local body
  body=$(api_request POST "/tunnel/start" "$(jq -n --argjson port "$port" '{port:$port}')" ) || return 1
  echo "Tünel durum: $(echo "$body" | jq -r '.status') | Port: $(echo "$body" | jq -r '.port')"
  local link
  link=$(echo "$body" | jq -r '.share_url')
  [ -n "$link" ] && echo "Paylaşılacak VPS linki: $link"
}

do_stop() {
  if [ -z "$TOKEN" ]; then
    echo "Önce giriş yapmalısın." >&2
    exit 1
  fi
  local body
  body=$(api_request POST "/tunnel/stop" "{}") || return 1
  echo "Tünel durduruldu. Toplam istek: $(echo "$body" | jq -r '.request_count')"
}

do_status() {
  if [ -z "$TOKEN" ]; then
    echo "Önce giriş yapmalısın." >&2
    exit 1
  fi
  local body
  body=$(api_request GET "/tunnel/status") || return 1
  echo "Durum: $(echo "$body" | jq -r '.status') | Port: $(echo "$body" | jq -r '.port')"
  echo "İstek sayısı: $(echo "$body" | jq -r '.request_count') | Plan: $(echo "$body" | jq -r '.plan')"
  local err
  err=$(echo "$body" | jq -r '.last_error // empty')
  [ -n "$err" ] && echo "Son hata: $err"
  local link
  link=$(echo "$body" | jq -r '.share_url // empty')
  [ -n "$link" ] && echo "Paylaşılacak VPS linki: $link"
}

do_whoami() {
  if [ -z "$USER_ID" ]; then
    echo "Kayıtlı oturum yok."
    return
  fi
  echo "Kullanıcı: $USERNAME | UID: $USER_ID | Plan: $PLAN"
  [ -n "$SHARE_URL" ] && echo "Paylaşılacak VPS linki: $SHARE_URL"
  echo "Sunucu: $BASE_URL"
}

do_config() {
  local server="${1:-}"
  if [ -n "$server" ]; then
    BASE_URL="$server"
    save_config
    echo "Sunucu adresi kaydedildi: $BASE_URL"
  else
    echo "Şu anki sunucu: $BASE_URL"
  fi
}

interactive_menu() {
  while true; do
    cat <<'MENU'
JeaTunnel Menü
 1) Kayıt ol
 2) Giriş yap
 3) Tünel başlat
 4) Tünel durdur
 5) Durumu göster
 6) Oturum bilgisi
 0) Çık
MENU
    read -rp "Seçim: " choice
    case "$choice" in
      1) do_register ;;
      2) do_login ;;
      3) do_run ;;
      4) do_stop ;;
      5) do_status ;;
      6) do_whoami ;;
      0) exit 0 ;;
      *) echo "Geçersiz seçim." ;;
    esac
  done
}

usage() {
  cat <<EOF
Kullanım: $0 <komut> [argümanlar]
Komutlar:
  register [--username u --password p --plan pl]
  login [--username u --password p]
  run [port]
  stop
  status
  whoami
  config [--server URL]
EOF
}

main() {
  load_config
  # Defaults yoksa config üret
  [ -f "$CONFIG_PATH" ] || save_config

  local cmd="${1:-}"
  if [ -z "$cmd" ]; then
    interactive_menu
    exit 0
  fi
  shift || true

  case "$cmd" in
    register)
      local user pass plan
      while [ $# -gt 0 ]; do
        case "$1" in
          --username) user="$2"; shift 2 ;;
          --password) pass="$2"; shift 2 ;;
          --plan) plan="$2"; shift 2 ;;
          *) break ;;
        esac
      done
      do_register "$user" "$pass" "$plan"
      ;;
    login)
      local user pass
      while [ $# -gt 0 ]; do
        case "$1" in
          --username) user="$2"; shift 2 ;;
          --password) pass="$2"; shift 2 ;;
          *) break ;;
        esac
      done
      do_login "$user" "$pass"
      ;;
    run)
      do_run "${1:-}"
      ;;
    stop)
      do_stop
      ;;
    status)
      do_status
      ;;
    whoami)
      do_whoami
      ;;
    config)
      local server=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --server) server="$2"; shift 2 ;;
          *) break ;;
        esac
      done
      do_config "$server"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
