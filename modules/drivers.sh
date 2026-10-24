MOD_NAME="Drivers"
MOD_CATEGORY="Sistema"
MOD_DEFAULT=1
MOD_PRIORITY=8   # antes que las apps: el reinicio del final del asistente ya lo carga

# Drivers privativos recomendados para este hardware (NVIDIA, algunos Wi-Fi...),
# los mismos que ofrece «Controladores adicionales». Sin ninguno (máquinas
# virtuales, gráficas Intel/AMD) no se define nada: el módulo no aparece.
# ubuntu-drivers tarda: el resultado se guarda y se repite si cambia el hardware.
_recommended() {
  local cache=$KUBU_STATE/drivers.cache key
  has ubuntu-drivers || return 0
  key=$(lspci -n 2>/dev/null | md5sum | cut -d' ' -f1)
  if [[ $(head -1 "$cache" 2>/dev/null) != "$key" ]]; then
    { echo "$key"; ubuntu-drivers devices 2>/dev/null | awk '/non-free.*recommended/ {print $3}'; } >"$cache"
  fi
  tail -n +2 "$cache"
}

mapfile -t DRIVERS < <(_recommended)
((${#DRIVERS[@]})) || return 0

MOD_DESC="Recomendados: ${DRIVERS[*]}"

mod_is_installed() { local p; for p in "${DRIVERS[@]}"; do pkg_installed "$p" || return 1; done; }

mod_install() {
  if has mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    info "Secure Boot activado: Ubuntu usa módulos ya firmados cuando existen."
  fi
  step "Instalando ${DRIVERS[*]}" sudo DEBIAN_FRONTEND=noninteractive ubuntu-drivers install
  warn "Reinicia para cargar los drivers nuevos."
}

mod_uninstall() {
  step "Eliminando ${DRIVERS[*]}" apt_purge "${DRIVERS[@]}"
  warn "Reinicia para volver a los drivers libres."
}

mod_status() {
  local d
  for d in "${DRIVERS[@]}"; do
    if pkg_installed "$d"; then ui_status "$d" "instalado" ok
    else ui_status "$d" "sin instalar" off
    fi
  done
  if has nvidia-smi; then
    ui_status "GPU" "$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)" ok
  fi
}
