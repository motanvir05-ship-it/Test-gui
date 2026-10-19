#!/usr/bin/env bash
# MAS > NotRyxen | Pterodactyl Panel & Wings Manager
# Run: sudo bash MAS-NotRyxen.sh
set -o pipefail

# ---------- Theme ----------
if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[91m'; GREEN=$'\033[92m'; YELLOW=$'\033[93m'
  BLUE=$'\033[94m'; MAGENTA=$'\033[95m'; CYAN=$'\033[96m'; WHITE=$'\033[97m'
else
  RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''
fi
PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
PANEL_INSTALLER_URL="https://pterodactyl-installer.se/"

cleanup() { printf '%s' "$RESET"; }
trap cleanup EXIT

line() { printf '%s\n' "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
header() {
  clear 2>/dev/null || true
  printf '\n%s' "$MAGENTA"
  cat <<'ART'
███╗   ███╗ █████╗ ███████╗  >  ███╗   ██╗ ██████╗ ████████╗██████╗ ██╗   ██╗███████╗███╗   ██╗
████╗ ████║██╔══██╗██╔════╝     ████╗  ██║██╔═══██╗╚══██╔══╝██╔══██╗╚██╗ ██╔╝██╔════╝████╗  ██║
██╔████╔██║███████║███████╗     ██╔██╗ ██║██║   ██║   ██║   ██████╔╝ ╚████╔╝ █████╗  ██╔██╗ ██║
██║╚██╔╝██║██╔══██║╚════██║     ██║╚██╗██║██║   ██║   ██║   ██╔══██╗  ╚██╔╝  ██╔══╝  ██║╚██╗██║
██║ ╚═╝ ██║██║  ██║███████║     ██║ ╚████║╚██████╔╝   ██║   ██║  ██║   ██║   ███████╗██║ ╚████║
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝     ╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝
ART
  printf '%s\n' "$RESET"
  printf ' %s%s MAS GUI %s|%s NotRyxen %s\n' "$CYAN" "$BOLD" "$MAGENTA" "$CYAN" "$RESET"
  printf ' %sPterodactyl • Wings • Docker • Cloudflare • System Tools%s\n' "$DIM" "$RESET"
  line
}

pause() { printf '\n%sPress ENTER to continue...%s' "$YELLOW" "$RESET"; read -r _ || true; }
msg() { printf '%b\n' "$*"; }
run_step() {
  local label="$1"; shift
  printf '\n%s⠋ %s%s\n' "$CYAN" "$label" "$RESET"
  "$@"; local rc=$?
  if (( rc == 0 )); then msg "${GREEN}✔ Completed: ${label}${RESET}"; else msg "${RED}✖ Failed (exit ${rc}): ${label}${RESET}"; fi
  return "$rc"
}
need_root() { if (( EUID != 0 )); then msg "${RED}Run as root: sudo bash $0${RESET}"; exit 1; fi; }
confirm_yes() { local prompt="$1" answer; printf '%s [y/N]: ' "$prompt"; read -r answer; [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; }
confirm_code() {
  local label="$1" code answer
  code="$(tr -dc 'A-Z0-9' </dev/urandom | head -c 6)"
  msg "${RED}${BOLD}DANGEROUS ACTION: ${label}${RESET}"
  msg "Type this code to confirm: ${YELLOW}${code}${RESET}"
  printf 'Confirmation: '; read -r answer
  [[ "$answer" == "$code" ]]
}
need_cmd() { command -v "$1" >/dev/null 2>&1; }

show_status() {
  local state
  printf '\n%sSYSTEM STATUS%s\n' "$CYAN" "$RESET"; line
  if need_cmd cloudflared; then state="$(systemctl is-active cloudflared 2>/dev/null || true)"; [[ "$state" == active ]] && state="${GREEN}RUNNING${RESET}" || state="${YELLOW}INSTALLED${RESET}"; printf ' Cloudflare: %b\n' "$state"; else printf ' Cloudflare: %b\n' "${RED}NOT INSTALLED${RESET}"; fi
  [[ -f "$PANEL_DIR/artisan" ]] && printf ' Panel:      %b\n' "${GREEN}INSTALLED${RESET}" || printf ' Panel:      %b\n' "${RED}NOT FOUND${RESET}"
  if need_cmd docker; then state="$(systemctl is-active docker 2>/dev/null || true)"; [[ "$state" == active ]] && state="${GREEN}RUNNING${RESET}" || state="${YELLOW}${state:-unknown}${RESET}"; printf ' Docker:     %b\n' "$state"; else printf ' Docker:     %b\n' "${RED}NOT INSTALLED${RESET}"; fi
  if [[ -x /usr/local/bin/wings ]]; then state="$(systemctl is-active wings 2>/dev/null || true)"; [[ "$state" == active ]] && state="${GREEN}RUNNING${RESET}" || state="${YELLOW}INSTALLED${RESET}"; printf ' Wings:      %b\n' "$state"; else printf ' Wings:      %b\n' "${RED}NOT INSTALLED${RESET}"; fi
  [[ -f /etc/pterodactyl/config.yml ]] && printf ' Wings config: %b\n' "${GREEN}PRESENT${RESET}" || printf ' Wings config: %b\n' "${RED}MISSING${RESET}"
  [[ -d "$PANEL_DIR/.blueprint" ]] && printf ' Blueprint:  %b\n' "${GREEN}DETECTED${RESET}" || printf ' Blueprint:  %b\n' "${DIM}NOT DETECTED${RESET}"
}

install_cloudflared() {
  header; msg "${CYAN}${BOLD}Install Cloudflare Tunnel${RESET}"
  if need_cmd cloudflared && ! confirm_yes "cloudflared is already installed. Download again?"; then return; fi
  command -v apt-get >/dev/null 2>&1 || { msg "${RED}This installer currently supports Debian/Ubuntu (apt).${RESET}"; pause; return; }
  apt-get update && apt-get install -y curl ca-certificates || { msg "${RED}Dependency installation failed.${RESET}"; pause; return; }
  local arch; case "$(uname -m)" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; armv7l) arch=arm;; *) msg "${RED}Unsupported CPU architecture: $(uname -m)${RESET}"; pause; return;; esac
  if curl --fail --location --show-error --progress-bar "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}" -o /usr/local/bin/cloudflared; then
    chmod 0755 /usr/local/bin/cloudflared; ln -sf /usr/local/bin/cloudflared /usr/bin/cloudflared
    msg "${GREEN}✔ Installed: $(cloudflared --version 2>/dev/null | head -n1)${RESET}"
  else msg "${RED}Download failed. Check network and try again.${RESET}"; fi
  pause
}

cloudflare_menu() {
  while true; do
    header; printf '%sCLOUDFLARE%s\n' "$CYAN" "$RESET"
    printf '  %s1)%s Install / update cloudflared\n  %s2)%s Run tunnel in foreground\n  %s3)%s Configure tunnel as systemd service\n  %s4)%s Start service\n  %s5)%s Stop service\n  %s6)%s Restart service\n  %s7)%s View status and recent logs\n  %s0)%s Back\n' "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$RED" "$RESET"
    printf '\nChoice: '; read -r choice
    case "$choice" in
      1) install_cloudflared ;;
      2) if ! need_cmd cloudflared; then msg "${RED}Install cloudflared first.${RESET}"; pause; continue; fi; read -rsp 'Tunnel token: ' token; printf '\n'; [[ -n "$token" ]] || { msg "${RED}Token is required.${RESET}"; pause; continue; }; msg "${YELLOW}Foreground tunnel; press Ctrl+C to stop.${RESET}"; cloudflared tunnel run --protocol http2 --token "$token"; unset token; pause ;;
      3) if ! need_cmd cloudflared; then msg "${RED}Install cloudflared first.${RESET}"; pause; continue; fi; read -rsp 'Tunnel token (input hidden): ' token; printf '\n'; [[ -n "$token" ]] || { msg "${RED}Token is required.${RESET}"; pause; continue; }; umask 077; printf '[Unit]\nDescription=Cloudflare Tunnel\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\nType=simple\nUser=root\nExecStart=/usr/local/bin/cloudflared tunnel run --protocol http2 --token %s\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' "$token" > /etc/systemd/system/cloudflared.service; unset token; systemctl daemon-reload && systemctl enable --now cloudflared; systemctl --no-pager --full status cloudflared; pause ;;
      4) systemctl enable --now cloudflared; systemctl --no-pager status cloudflared; pause ;;
      5) systemctl stop cloudflared; pause ;;
      6) systemctl restart cloudflared; systemctl --no-pager status cloudflared; pause ;;
      7) systemctl --no-pager --full status cloudflared 2>&1 || true; journalctl -u cloudflared -n 30 --no-pager 2>/dev/null || true; pause ;;
      0) return;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;;
    esac
  done
}

prompt_admin_details() {
  printf '\n%sPanel installer account details%s\n' "$CYAN" "$RESET"
  read -rp 'Lets Encrypt email [admin@example.com]: ' le_email; le_email=${le_email:-admin@example.com}
  read -rp 'Panel admin email [admin@example.com]: ' admin_email; admin_email=${admin_email:-admin@example.com}
  read -rp 'Admin username [admin]: ' admin_user; admin_user=${admin_user:-admin}
  read -rp 'Admin first name [Admin]: ' admin_first; admin_first=${admin_first:-Admin}
  read -rp 'Admin last name [User]: ' admin_last; admin_last=${admin_last:-User}
  read -rsp 'Admin password (leave blank to use installer default): ' admin_pass; printf '\n'
  if [[ -z "$admin_pass" ]]; then msg "${YELLOW}No password entered; installer may prompt or use its own default.${RESET}"; fi
}
run_panel_install() {
  header; msg "${CYAN}${BOLD}Pterodactyl Panel Install${RESET}"
  msg "${YELLOW}This runs the third-party Pterodactyl installer. Review its source before proceeding.${RESET}"
  confirm_yes "Continue and run ${PANEL_INSTALLER_URL}?" || return
  prompt_admin_details
  local answers
  answers=$(mktemp); chmod 600 "$answers"
  # Use a temporary answer file so credentials are not printed to the terminal.
  cat > "$answers" <<ANSWERS
0



Asia/Kolkata
${le_email}
${admin_email}
${admin_user}
${admin_first}
${admin_last}
${admin_pass}

n
y
y
y
y
y
y
y
ANSWERS
  msg "${CYAN}Starting installer. Output below is from the upstream installer.${RESET}"
  if curl --fail --location --silent --show-error "$PANEL_INSTALLER_URL" -o /tmp/mas-pterodactyl-installer.sh; then
    bash /tmp/mas-pterodactyl-installer.sh < "$answers"; local rc=$?
    rm -f "$answers"; unset admin_pass
    (( rc == 0 )) && msg "${GREEN}Installer process finished.${RESET}" || msg "${RED}Installer exited with code ${rc}. Review output above.${RESET}"
  else rm -f "$answers"; unset admin_pass; msg "${RED}Could not download upstream installer.${RESET}"; fi
  pause
}

require_panel() { [[ -f "$PANEL_DIR/artisan" ]] || { msg "${RED}Panel not found at $PANEL_DIR${RESET}"; pause; return 1; }; }
user_create() {
  require_panel || return
  header; msg "${CYAN}Create Panel User${RESET}"
  read -rp 'Email: ' email; read -rp 'Username: ' username; read -rp 'First name: ' first; read -rp 'Last name: ' last
  [[ -n "$email" && -n "$username" && -n "$first" && -n "$last" ]] || { msg "${RED}All fields are required.${RESET}"; pause; return; }
  read -rp 'Make admin? [y/N]: ' admin_ans; local admin=0; [[ "$admin_ans" =~ ^[Yy]$ ]] && admin=1
  read -rsp 'Password (blank = email set-password link): ' pass; printf '\n'
  cd "$PANEL_DIR" || return
  if [[ -n "$pass" ]]; then php artisan p:user:make --email="$email" --username="$username" --name-first="$first" --name-last="$last" --password="$pass" --admin="$admin"; else php artisan p:user:make --email="$email" --username="$username" --name-first="$first" --name-last="$last" --no-password --admin="$admin"; fi
  unset pass; pause
}
user_delete() {
  require_panel || return; header; read -rp 'Username, email, or UUID to delete: ' target; [[ -n "$target" ]] || { pause; return; }
  confirm_code "Delete panel user ${target}" || { msg "${YELLOW}Cancelled.${RESET}"; pause; return; }
  (cd "$PANEL_DIR" && php artisan p:user:delete --user="$target"); pause
}
user_toggle_admin() {
  require_panel || return; header; read -rp 'Username or email: ' target; [[ -n "$target" ]] || { pause; return; }
  # Escape single quotes for a safe PHP string literal.
  local escaped=${target//\\/\\\\}; escaped=${escaped//\'/\\\'}
  (cd "$PANEL_DIR" && php artisan tinker --execute="\$u = \\Pterodactyl\\Models\\User::where('email', '${escaped}')->orWhere('username', '${escaped}')->first(); if (\$u) { \$u->root_admin = !\$u->root_admin; \$u->save(); echo 'Admin status: '.(\$u->root_admin ? 'ADMIN' : 'NOT ADMIN'); } else { echo 'User not found'; }"); pause
}
user_reset_password() {
  require_panel || return; header; read -rp 'Username or email: ' target; read -rsp 'New password: ' pass; printf '\n'; [[ -n "$target" && -n "$pass" ]] || { unset pass; msg "${RED}Both fields are required.${RESET}"; pause; return; }
  # Pass user input as base64 to avoid interpolating quotes into PHP source.
  local target64 pass64; target64=$(printf %s "$target" | base64 -w0); pass64=$(printf %s "$pass" | base64 -w0); unset pass
  (cd "$PANEL_DIR" && php artisan tinker --execute="\$target = base64_decode('${target64}'); \$new = base64_decode('${pass64}'); \$u = \\Pterodactyl\\Models\\User::where('email', \$target)->orWhere('username', \$target)->first(); if (\$u) { \$u->password = \\Illuminate\\Support\\Facades\\Hash::make(\$new); \$u->save(); echo 'Password updated.'; } else { echo 'User not found'; }"); pause
}
users_menu() { while true; do header; printf ' %sUSER MANAGEMENT%s\n  1) Create user\n  2) Delete user\n  3) Toggle admin status\n  4) Reset password\n  0) Back\nChoice: ' "$CYAN" "$RESET"; read -r c; case "$c" in 1) user_create;; 2) user_delete;; 3) user_toggle_admin;; 4) user_reset_password;; 0) return;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;; esac; done; }
panel_menu() { while true; do header; printf ' %sPTERODACTYL PANEL%s\n  1) Install Panel\n  2) User management\n  3) Toggle maintenance mode\n  4) Panel info\n  0) Back\nChoice: ' "$CYAN" "$RESET"; read -r c; case "$c" in 1) run_panel_install;; 2) users_menu;; 3) require_panel || continue; if [[ -f "$PANEL_DIR/storage/framework/down" ]]; then (cd "$PANEL_DIR" && php artisan up); else confirm_yes 'Put the panel into maintenance mode?' && (cd "$PANEL_DIR" && php artisan down); fi; pause;; 4) require_panel && (cd "$PANEL_DIR" && php artisan p:info); pause;; 0) return;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;; esac; done; }

wings_install() {
  header; msg "${RED}${BOLD}Wings + Docker installer${RESET}"
  msg "This can change Docker packages. It will NOT automatically delete /var/lib/docker or existing container data."
  confirm_yes 'Install Docker from the official Docker repository and Wings binary?' || return
  . /etc/os-release
  [[ "${ID:-}" == ubuntu || "${ID_LIKE:-}" == *debian* || "${ID:-}" == debian ]] || { msg "${RED}Supported on Ubuntu/Debian only.${RESET}"; pause; return; }
  apt-get update && apt-get install -y ca-certificates curl gnupg openssl || { pause; return; }
  install -m 0755 -d /etc/apt/keyrings
  curl --fail --location --silent --show-error https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc || { msg "${RED}Docker GPG download failed.${RESET}"; pause; return; }
  gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc && chmod a+r /etc/apt/keyrings/docker.gpg || { pause; return; }
  local codename; codename="${VERSION_CODENAME:-$(. /etc/os-release; echo "$VERSION_CODENAME")}"; local distro=ubuntu; [[ "${ID:-}" == debian ]] && distro=debian
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/%s %s stable\n' "$(dpkg --print-architecture)" "$distro" "$codename" > /etc/apt/sources.list.d/docker.list
  apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { msg "${RED}Docker install failed.${RESET}"; pause; return; }
  systemctl enable --now docker || { pause; return; }
  mkdir -p /etc/pterodactyl
  local arch; case "$(uname -m)" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; *) msg "${RED}Unsupported Wings architecture: $(uname -m)${RESET}"; pause; return;; esac
  curl --fail --location --show-error --progress-bar "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${arch}" -o /usr/local/bin/wings && chmod 0755 /usr/local/bin/wings || { msg "${RED}Wings download failed.${RESET}"; pause; return; }
  msg "${GREEN}✔ Docker and Wings installed. Configure Wings using the Panel's node configuration.${RESET}"; pause
}
wings_config() {
  header; msg "${CYAN}Wings Config Setup${RESET}"
  msg "Use the values from Panel → Admin → Nodes → your node → Configuration. Keep these credentials private."
  read -rp 'UUID: ' uuid; read -rp 'Token ID: ' token_id; read -rsp 'Token: ' token; printf '\n'; read -rp 'Panel URL (https://...): ' remote
  [[ -n "$uuid" && -n "$token_id" && -n "$token" && "$remote" =~ ^https?:// ]] || { unset token; msg "${RED}UUID, token ID, token and valid Panel URL are required.${RESET}"; pause; return; }
  mkdir -p /etc/pterodactyl
  if [[ -f /etc/pterodactyl/config.yml ]]; then cp -a /etc/pterodactyl/config.yml "/etc/pterodactyl/config.yml.bak.$(date +%Y%m%d%H%M%S)"; fi
  msg "${YELLOW}This writes a basic config template. For production, prefer the exact generated config from your Panel, including its TLS settings.${RESET}"
  cat > /etc/pterodactyl/config.yml <<CONFIG
# Basic template only. Prefer the exact configuration generated by your Panel.
debug: false
uuid: "$uuid"
token_id: "$token_id"
token: "$token"
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    cert: /etc/letsencrypt/live/REPLACE_WITH_NODE_DOMAIN/fullchain.pem
    key: /etc/letsencrypt/live/REPLACE_WITH_NODE_DOMAIN/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: "$remote"
docker:
  network:
    name: pterodactyl_nw
    interfaces:
      v4:
        subnet: 10.240.0.0/16
        gateway: 10.240.0.1
CONFIG
  unset token
  cat > /etc/systemd/system/wings.service <<'SERVICE'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
SERVICE
  chmod 0600 /etc/pterodactyl/config.yml; systemctl daemon-reload
  msg "${GREEN}Wings service created. Review /etc/pterodactyl/config.yml and replace TLS placeholders before starting.${RESET}"; pause
}
wings_menu() { while true; do header; printf ' %sWINGS & DOCKER%s\n  1) Install/update Docker + Wings (preserves Docker data)\n  2) Configure Wings service (basic template)\n  3) Start Wings service\n  4) Stop Wings service\n  5) Restart Wings service\n  6) Status and recent logs\n  0) Back\nChoice: ' "$CYAN" "$RESET"; read -r c; case "$c" in 1) wings_install;; 2) wings_config;; 3) systemctl enable --now wings; systemctl --no-pager status wings; pause;; 4) systemctl stop wings; pause;; 5) systemctl restart wings; systemctl --no-pager status wings; pause;; 6) systemctl --no-pager --full status wings 2>&1 || true; journalctl -u wings -n 40 --no-pager 2>/dev/null || true; pause;; 0) return;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;; esac; done; }

system_spec() {
  header; printf '%sLIVE SYSTEM SPECIFICATIONS%s\n' "$CYAN" "$RESET"; line
  printf ' OS:       %s\n' "$(. /etc/os-release; echo "${PRETTY_NAME:-Unknown}")"
  printf ' Kernel:   %s\n' "$(uname -r)"; printf ' CPU:      %s\n' "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' || echo Unknown)"
  printf ' Cores:    %s\n' "$(nproc 2>/dev/null || echo Unknown)"
  awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf " RAM:      %.2f GiB total • %.2f GiB available • %.2f GiB used\n",t/1048576,a/1048576,(t-a)/1048576}' /proc/meminfo
  df -h / | awk 'NR==2 {printf " Disk:     %s total • %s used • %s available (%s used)\n",$2,$3,$4,$5}'
  printf ' Uptime:   '; uptime -p 2>/dev/null || cat /proc/uptime
  if need_cmd nvidia-smi; then printf ' GPU:      '; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true; else printf ' GPU:      Not detected / NVIDIA tools unavailable\n'; fi
  pause
}
system_update() { header; msg "${YELLOW}System package upgrade may restart services or install kernel updates.${RESET}"; confirm_yes 'Run apt update and apt upgrade?' || return; apt-get update && apt-get upgrade -y; pause; }
installed_apps() { header; show_status; pause; }
service_logs() { local svc="$1"; header; systemctl --no-pager --full status "$svc" 2>&1 || true; printf '\n%sRecent logs%s\n' "$CYAN" "$RESET"; journalctl -u "$svc" -n 50 --no-pager 2>/dev/null || true; pause; }
uninstall_menu() {
  while true; do header; msg "${RED}${BOLD}UNINSTALL — READ CAREFULLY${RESET}"; msg "Removing software can cause downtime. Docker removal/data deletion is intentionally not automated here."; printf '  1) Remove Wings service and binary only\n  2) Remove Cloudflare service and binary\n  3) Remove Blueprint files/CLI\n  4) Remove Pterodactyl Panel files (DANGEROUS)\n  0) Back\nChoice: '; read -r c
    case "$c" in
      1) confirm_code 'Remove Wings service and binary (does not delete Docker data)' && { systemctl disable --now wings 2>/dev/null || true; rm -f /etc/systemd/system/wings.service /usr/local/bin/wings; systemctl daemon-reload; msg "${GREEN}Wings service/binary removed. /etc/pterodactyl config was preserved.${RESET}"; }; pause;;
      2) confirm_code 'Remove Cloudflare tunnel service and binary' && { systemctl disable --now cloudflared 2>/dev/null || true; rm -f /etc/systemd/system/cloudflared.service /usr/local/bin/cloudflared /usr/bin/cloudflared; systemctl daemon-reload; msg "${GREEN}Cloudflare binary/service removed.${RESET}"; }; pause;;
      3) confirm_code 'Remove Blueprint directory and CLI' && { rm -rf "$PANEL_DIR/.blueprint"; rm -f "$PANEL_DIR/blueprint.sh" /usr/local/bin/blueprint; msg "${GREEN}Blueprint files removed.${RESET}"; }; pause;;
      4) confirm_code "DELETE PANEL FILES at $PANEL_DIR (make a backup first)" && { if [[ -d "$PANEL_DIR" ]]; then mv "$PANEL_DIR" "${PANEL_DIR}.removed.$(date +%Y%m%d%H%M%S)"; msg "${GREEN}Panel directory moved to a timestamped backup instead of permanently deleting it.${RESET}"; else msg "${YELLOW}Panel directory not found.${RESET}"; fi; }; pause;;
      0) return;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;;
    esac
  done
}
blueprint_menu() {
  header; msg "${CYAN}${BOLD}BLUEPRINT / THEMES${RESET}"
  msg "For safety, this version does not auto-download third-party theme bundles or run unknown installer scripts as root."
  msg "Use the official Blueprint documentation and verify each extension's source and compatibility with your Panel version."
  pause
}
credits() { header; msg "${CYAN}${BOLD}CREDITS${RESET}"; printf '\n MAS > NotRyxen UI refresh\n Pterodactyl Panel and Wings are third-party projects.\n Cloudflare Tunnel is provided by Cloudflare.\n Follow official project documentation and licenses.\n'; pause; }
main_menu() {
  header; show_status; line
  printf '\n  %s1)%s System Update\n  %s2)%s Cloudflare Tunnel\n  %s3)%s Pterodactyl Panel Setup\n  %s4)%s Wings + Docker Setup\n  %s5)%s System Specifications\n  %s6)%s Blueprint / Themes guidance\n  %s7)%s Installed Apps / Status\n  %s8)%s Credits\n  %s9)%s Uninstall / Cleanup\n  %s0)%s Exit\n\nChoice: ' "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$CYAN" "$RESET" "$RED" "$RESET"; read -r choice
  case "$choice" in 1) system_update;; 2) cloudflare_menu;; 3) panel_menu;; 4) wings_menu;; 5) system_spec;; 6) blueprint_menu;; 7) installed_apps;; 8) credits;; 9) uninstall_menu;; 0) exit 0;; *) msg "${RED}Invalid option.${RESET}"; sleep 1;; esac
}

need_root
while true; do main_menu; done
