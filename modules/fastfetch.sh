MOD_NAME="fastfetch"
MOD_CATEGORY="Terminal"
MOD_DESC="Información del sistema"
MOD_DEFAULT=1

CONF="$HOME/.config/fastfetch/config.jsonc"

# fastfetch viene con Kubuntu: kubu gestiona sobre todo su configuración
mod_is_installed() { [[ -f $CONF ]] && pkg_installed fastfetch; }

mod_install() {
  pkg_installed fastfetch || step "Instalando fastfetch" apt_install fastfetch
  mod_configure
}

mod_configure() {
  mkdir -p "$(dirname "$CONF")"
  backup "$CONF"
  cp "$KUBU_ROOT/configs/fastfetch.jsonc" "$CONF"
  ok "fastfetch configurado"
}

mod_uninstall() {
  restore "$CONF"
  ok "Configuración de fastfetch restaurada (el paquete es de Kubuntu y se mantiene)"
}
