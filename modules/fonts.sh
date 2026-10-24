MOD_NAME="Fuentes"
MOD_CATEGORY="Terminal"
MOD_DESC="Nerd Fonts Ubuntu Mono y Cascadia Mono"
MOD_REQUIRED=1
MOD_PRIORITY=15

source "$KUBU_ROOT/lib/font.sh"

mod_is_installed() { fc-list 2>/dev/null | grep -i "UbuntuMono Nerd Font" >/dev/null; }

mod_install() {
  pkg_installed fontconfig || step "Instalando fontconfig" apt_install fontconfig unzip
  step "Instalando CaskaydiaMono Nerd Font" font_install "CaskaydiaMono Nerd Font" CascadiaMono
  font_apply "Ubuntu Mono"
}

mod_uninstall() {
  step "Eliminando Nerd Fonts de kubu" bash -c 'rm -rf "$HOME/.local/share/fonts/kubu" && fc-cache -f'
  rm -f "$KUBU_STATE/font"
}
