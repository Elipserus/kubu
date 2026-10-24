MOD_NAME="Tailscale"
MOD_CATEGORY="Internet"
MOD_DESC="Red privada entre tus equipos"

MOD_MENU=(
  "ts_up|Conectar (la primera vez abre el inicio de sesión)"
  "ts_down|Desconectar"
  "ts_peers|Ver los equipos de tu red"
  "ts_service|Encender o apagar tailscaled"
)

mod_is_installed() { pkg_installed tailscale; }

mod_install() {
  local codename
  codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
  step "Añadiendo repositorio de Tailscale" apt_add_repo tailscale \
    "https://pkgs.tailscale.com/stable/ubuntu/$codename.noarmor.gpg" \
    https://pkgs.tailscale.com/stable/ubuntu "$codename" main
  step "Instalando tailscale" apt_install tailscale
  mod_configure
}

mod_configure() {
  step "Habilitando tailscaled" sudo systemctl enable --now tailscaled
  # Operador: tailscale up/down/status sin sudo
  step "Permitiendo a $USER usar Tailscale sin sudo" sudo tailscale set --operator="$USER" ||
    warn "No se pudo hacer a $USER operador: kubu usará sudo"
  info "Para unirte a tu red: Configurar › Tailscale › Conectar"
}

mod_uninstall() {
  sudo tailscale down 2>/dev/null || true
  step "Eliminando tailscale" apt_purge tailscale
  step "Quitando repositorio" apt_remove_repo tailscale
}

# tailscale sin sudo si somos operador; si no, con sudo
ts() {
  if tailscale debug prefs 2>/dev/null | grep -q "\"OperatorUser\": \"$USER\""; then tailscale "$@"
  else sudo tailscale "$@"
  fi
}

_ts_state() { ts status --json 2>/dev/null | grep -oP '"BackendState":\s*"\K[^"]+' || true; }

mod_status() {
  local state
  ui_service "tailscaled" tailscaled.service
  systemctl is-active tailscaled >/dev/null 2>&1 || return 0
  state=$(_ts_state)
  case $state in
    Running)    ui_status "Conexión" "conectado" ok
                ui_status "Mi IP" "$(ts ip -4 2>/dev/null | head -1)" ;;
    NeedsLogin) ui_status "Conexión" "sin iniciar sesión" warn "usa Conectar" ;;
    *)          ui_status "Conexión" "desconectado" off ;;
  esac
}

ts_up() {
  info "Si es la primera vez, abre en el navegador el enlace que aparece."
  ts up
  ok "Conectado a Tailscale: $(ts ip -4 2>/dev/null | head -1)"
}

ts_down()  { step "Desconectando" ts down; }
ts_peers() { ts status | ui_view "Equipos de tu red Tailscale (q para salir)"; }

ts_service() {
  if systemctl is-active tailscaled >/dev/null 2>&1; then
    step "Apagando tailscaled" sudo systemctl stop tailscaled
  else
    step "Encendiendo tailscaled" sudo systemctl start tailscaled
  fi
}
