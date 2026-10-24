MOD_NAME="Ghostty"
MOD_CATEGORY="Terminal"
MOD_DESC="Terminal por defecto con temas de kubu"
MOD_REQUIRED=1
MOD_PRIORITY=12   # antes que fonts, que escribe en ~/.config/ghostty

CONF_DIR="$HOME/.config/ghostty"

mod_is_installed() { pkg_installed ghostty; }

mod_install() {
  step "Instalando ghostty" apt_install ghostty
  mod_configure
}

mod_configure() {
  local desktop
  backup "$CONF_DIR"
  mkdir -p "$CONF_DIR/themes"
  cp "$KUBU_ROOT/configs/ghostty/config" "$CONF_DIR/config"
  # Mantiene tema y fuente si ya estaban elegidos
  [[ -f $CONF_DIR/kubu-theme ]] || echo "theme = kubu" >"$CONF_DIR/kubu-theme"
  [[ -f $CONF_DIR/kubu-font ]] ||
    printf 'font-family = "UbuntuMono Nerd Font"\nfont-size = 16\n' >"$CONF_DIR/kubu-font"
  cp "$KUBU_ROOT/themes/kubu/ghostty" "$CONF_DIR/themes/kubu"
  ghostty_reload
  ok "Configuración en $CONF_DIR"

  desktop=$(basename "$(dpkg -L ghostty | grep -m1 'applications/.*\.desktop$')")
  kde_set kdeglobals General TerminalApplication ghostty
  kde_set kdeglobals General TerminalService "$desktop"
  ok "Ghostty es la terminal por defecto de KDE ($desktop)"
}

mod_uninstall() {
  kde_set kdeglobals General TerminalApplication konsole
  kde_set kdeglobals General TerminalService org.kde.konsole.desktop
  restore "$CONF_DIR"
  step "Eliminando ghostty" apt_purge ghostty
}
