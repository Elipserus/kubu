MOD_NAME="Zellij"
MOD_CATEGORY="Terminal"
MOD_DESC="Paneles y sesiones en la terminal"
MOD_DEFAULT=1

URL=https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
CONF="$HOME/.config/zellij"

mod_is_installed() { [[ -x /usr/local/bin/zellij ]]; }

mod_install() {
  step "Instalando zellij" install_tar_bin "$URL" zellij
  mod_configure
}

mod_configure() {
  local theme
  theme=$(cat "$KUBU_STATE/theme" 2>/dev/null || echo kubu)
  mkdir -p "$CONF/themes"
  [[ -f $CONF/config.kdl ]] || cp "$KUBU_ROOT/configs/zellij.kdl" "$CONF/config.kdl"
  cp "$KUBU_ROOT/themes/$theme/zellij.kdl" "$CONF/themes/$theme.kdl"
  sed -i "s/^theme \".*\"/theme \"$theme\"/" "$CONF/config.kdl"
  ok "Zellij configurado con el tema $theme"
}

mod_update() { step "Actualizando zellij" install_tar_bin "$URL" zellij; }

mod_uninstall() {
  step "Eliminando zellij" sudo rm -f /usr/local/bin/zellij
  rm -rf "$CONF"
}
