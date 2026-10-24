MOD_NAME="Bitwarden"
MOD_CATEGORY="Utilidades"
MOD_DESC="Contraseñas y autocompletado en Brave"
MOD_FLATPAK=com.bitwarden.desktop

MOD_MENU=(
  "bw_brave|Usar Bitwarden como gestor de contraseñas de Brave (activar o quitar)"
)

# Política de empresa de Brave (solo el Brave de apt la lee): instala la extensión
# de Bitwarden y apaga el gestor de contraseñas y las tarjetas de Brave, para que
# el autocompletado sea solo de Bitwarden. Brave lo indica con «Gestionado por tu
# organización». Se aplica al reiniciar Brave.
BW_EXTENSION=nngceckbapebfimnlniiiahkandclblb
BRAVE_POLICY=/etc/brave/policies/managed/kubu-bitwarden.json

mod_uninstall() {
  _bw_brave_off
  kind_flatpak_uninstall
}

_bw_brave_on()  { [[ -f $BRAVE_POLICY ]]; }

_bw_brave_off() {
  _bw_brave_on || return 0
  step "Devolviendo a Brave su gestor de contraseñas" sudo rm -f "$BRAVE_POLICY"
}

mod_status() {
  if ! pkg_installed brave-browser; then
    ui_status "Brave" "no instalado (instálalo desde Aplicaciones)" off
  elif _bw_brave_on; then
    ui_status "En Brave" "gestor de contraseñas" ok "extensión instalada · gestor de Brave apagado"
  else
    ui_status "En Brave" "sin activar" off "usa la opción de abajo"
  fi
}

bw_brave() {
  if _bw_brave_on; then
    ui_confirm "¿Quitar Bitwarden de Brave y volver a su gestor de contraseñas?" || return 0
    _bw_brave_off
    ok "Hecho. Reinicia Brave para aplicarlo (la extensión puedes quitarla tú)."
    return 0
  fi
  pkg_installed brave-browser || die "Este ajuste es para el Brave de kubu (apt): instálalo desde Aplicaciones"
  sudo install -d -m 0755 "$(dirname "$BRAVE_POLICY")"
  sudo tee "$BRAVE_POLICY" >/dev/null <<EOF
{
  "ExtensionSettings": {
    "$BW_EXTENSION": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  },
  "PasswordManagerEnabled": false,
  "AutofillCreditCardEnabled": false
}
EOF
  ok "Bitwarden será el gestor de contraseñas de Brave"
  info "Reinicia Brave: se instala la extensión. Inicia sesión en ella y activa"
  info "el autocompletado en sus ajustes (Autocompletar › al cargar la página)."
}
