MOD_NAME="Syncthing"
MOD_CATEGORY="Utilidades"
MOD_DESC="Sincroniza carpetas sin nube"
MOD_APT=(syncthing)

MOD_MENU=(
  "st_open|Abrir el panel (en el navegador)"
  "st_service|Encender o apagar Syncthing"
)

PANEL=http://127.0.0.1:8384

mod_install() {
  kind_apt_install
  mod_configure
}

# Servicio de usuario: arranca con tu sesión y sincroniza tus carpetas
mod_configure() {
  step "Arrancando Syncthing con tu sesión" systemctl --user enable --now syncthing.service
  info "Panel: $PANEL"
}

mod_uninstall() {
  systemctl --user disable --now syncthing.service 2>/dev/null || true
  kind_apt_uninstall
}

mod_status() {
  local s boot=""
  s=$(systemctl --user is-active syncthing.service 2>/dev/null || true)
  [[ $(systemctl --user is-enabled syncthing.service 2>/dev/null || true) == enabled ]] &&
    boot="arranca con tu sesión"
  if [[ $s == active ]]; then ui_status "Syncthing" "en marcha" ok "$boot"
  else ui_status "Syncthing" "parado" off "$boot"
  fi
  ui_status "Panel" "$PANEL"
}

st_open() { xdg-open "$PANEL" >/dev/null 2>&1 & ok "Panel abierto en el navegador"; }

st_service() {
  if systemctl --user is-active syncthing.service >/dev/null 2>&1; then
    step "Apagando Syncthing" systemctl --user disable --now syncthing.service
  else
    step "Encendiendo Syncthing" systemctl --user enable --now syncthing.service
  fi
}
