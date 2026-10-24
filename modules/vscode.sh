MOD_NAME="VS Code"
MOD_CATEGORY="Desarrollo"
MOD_DESC="Editor de Microsoft con ajustes de kubu"
MOD_DEFAULT=1

# Mismas rutas que usa el paquete code, para no duplicar el repositorio
KEYRING=/usr/share/keyrings/microsoft.gpg
SETTINGS="$HOME/.config/Code/User/settings.json"

mod_is_installed() { pkg_installed code; }

mod_install() {
  step "Evitando que code añada su propio repo" bash -c \
    'echo "code code/add-microsoft-repo boolean false" | sudo debconf-set-selections'
  step "Añadiendo repositorio de Microsoft" apt_add_repo vscode \
    https://packages.microsoft.com/keys/microsoft.asc https://packages.microsoft.com/repos/code stable main "$KEYRING"
  step "Instalando code" apt_install code
  mod_configure
}

mod_configure() {
  local theme font
  theme=$(cat "$KUBU_STATE/theme" 2>/dev/null || echo kubu)
  mkdir -p "$(dirname "$SETTINGS")"
  backup "$SETTINGS"
  cp "$KUBU_ROOT/configs/vscode.json" "$SETTINGS"
  # shellcheck source=/dev/null
  source "$KUBU_ROOT/themes/$theme/theme.sh"
  step "Instalando tema $THEME_VSCODE_NAME" code --install-extension "$THEME_VSCODE_EXT"
  sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$THEME_VSCODE_NAME\"/" "$SETTINGS"
  font=$(awk -F' *= *' '/^font-family/{gsub(/"/,"",$2); print $2}' "$HOME/.config/ghostty/kubu-font" 2>/dev/null || true)
  [[ -n $font ]] && sed -i "s/\"editor.fontFamily\": \".*\"/\"editor.fontFamily\": \"$font\"/" "$SETTINGS"
  ok "VS Code configurado"
}

mod_uninstall() {
  step "Eliminando code" apt_purge code
  step "Quitando repositorio" apt_remove_repo vscode "$KEYRING"
  restore "$SETTINGS"
}
