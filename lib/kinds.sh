# Tipos declarativos de módulo. Si un módulo define una de estas variables y
# no implementa alguna función mod_*, se usa la implementación por defecto:
#
#   MOD_APT=(paquete ...)        paquetes del repositorio de Ubuntu
#   MOD_FLATPAK=org.app.Id       app de Flathub (instalación de sistema)
#   MOD_NPM=paquete MOD_BIN=bin  CLI de npm instalada en ~/.local
#   MOD_WEBAPP_URL=https://...   web app en modo aplicación
#     MOD_WEBAPP_ICON=nombre     icono de dashboardicons.com (opcional)

kind_apt_is_installed() { local p; for p in "${MOD_APT[@]}"; do pkg_installed "$p" || return 1; done; }
kind_apt_install()      { step "Instalando ${MOD_APT[*]}" apt_install "${MOD_APT[@]}"; }
kind_apt_uninstall()    { step "Eliminando ${MOD_APT[*]}" apt_purge "${MOD_APT[@]}"; }

kind_flatpak_is_installed() { has flatpak && flatpak info "$MOD_FLATPAK" >/dev/null 2>&1; }
kind_flatpak_install() {
  ensure_flatpak
  step "Instalando $MOD_FLATPAK (Flathub)" \
    sudo flatpak install -y --noninteractive flathub "$MOD_FLATPAK"
}
kind_flatpak_uninstall() {
  step "Eliminando $MOD_FLATPAK" sudo flatpak uninstall -y --noninteractive "$MOD_FLATPAK"
  step "Limpiando runtimes sin uso" sudo flatpak uninstall -y --noninteractive --unused
}
kind_flatpak_update() { step "Actualizando $MOD_FLATPAK" sudo flatpak update -y --noninteractive "$MOD_FLATPAK"; }

kind_npm_is_installed() { [[ -x $HOME/.local/bin/$MOD_BIN ]]; }
kind_npm_install()      { ensure_node; step "Instalando $MOD_NPM (npm)" npm install -g --prefix "$HOME/.local" "$MOD_NPM"; }
kind_npm_uninstall()    { step "Eliminando $MOD_NPM" npm uninstall -g --prefix "$HOME/.local" "$MOD_NPM"; }
kind_npm_update()       { step "Actualizando $MOD_NPM" npm install -g --prefix "$HOME/.local" "$MOD_NPM@latest"; }

kind_webapp_is_installed() { [[ -f $(webapp_desktop "$MOD_ID") ]]; }
kind_webapp_install() {
  step "Creando web app $MOD_NAME" webapp_install "$MOD_ID" "$MOD_NAME" "$MOD_WEBAPP_URL" "${MOD_WEBAPP_ICON:-}"
}
kind_webapp_uninstall() { step "Quitando web app $MOD_NAME" webapp_remove "$MOD_ID"; }

kind_apply_defaults() {
  local kind fn
  if   [[ -n ${MOD_APT+x} ]];        then kind=apt
  elif [[ -n ${MOD_FLATPAK:-} ]];    then kind=flatpak
  elif [[ -n ${MOD_NPM:-} ]];        then kind=npm
  elif [[ -n ${MOD_WEBAPP_URL:-} ]]; then kind=webapp
  else return 0
  fi
  for fn in is_installed install uninstall update; do
    declare -F "kind_${kind}_$fn" >/dev/null || continue
    declare -F "mod_$fn" >/dev/null || eval "mod_$fn() { kind_${kind}_$fn; }"
  done
}
