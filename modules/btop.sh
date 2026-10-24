MOD_NAME="btop"
MOD_CATEGORY="Terminal"
MOD_DESC="Monitor de recursos con el tema de kubu"
MOD_DEFAULT=1
MOD_APT=(btop)

CONF="$HOME/.config/btop"

mod_install() { kind_apt_install; mod_configure; }

mod_configure() {
  local theme
  theme=$(cat "$KUBU_STATE/theme" 2>/dev/null || echo kubu)
  mkdir -p "$CONF/themes"
  backup "$CONF/btop.conf"
  cp "$KUBU_ROOT/configs/btop.conf" "$CONF/btop.conf"
  cp "$KUBU_ROOT/themes/$theme/btop.theme" "$CONF/themes/$theme.theme"
  sed -i "s/^color_theme = .*/color_theme = \"$theme\"/" "$CONF/btop.conf"
  ok "btop configurado con el tema $theme"
}

mod_uninstall() {
  kind_apt_uninstall
  restore "$CONF/btop.conf"
  rm -rf "$CONF/themes"
}
