MOD_NAME="Python"
MOD_CATEGORY="Desarrollo"
MOD_DESC="Python 3 con venv pip pipx y uv"

# python3 lo usa el propio sistema: nunca se desinstala, solo los extras
PACKAGES=(python3 python3-venv python3-pip python3-dev pipx)
EXTRAS=(python3-venv python3-pip python3-dev pipx)

mod_is_installed() { pkg_installed pipx && pkg_installed python3-venv; }

mod_install() {
  step "Instalando ${PACKAGES[*]}" apt_install "${PACKAGES[@]}"
  mod_configure
}

mod_configure() {
  step "Añadiendo ~/.local/bin al PATH" pipx ensurepath
  if ! has uv && ! [[ -x $HOME/.local/bin/uv ]]; then
    if ui_confirm "¿Instalar también uv (gestor rápido de proyectos Python)?"; then
      step "Instalando uv con pipx" pipx install uv
    fi
  fi
  ok "$(python3 --version)"
}

mod_uninstall() {
  if [[ -x $HOME/.local/bin/uv ]]; then
    step "Quitando uv" pipx uninstall uv
  fi
  step "Eliminando ${EXTRAS[*]}" apt_purge "${EXTRAS[@]}"
  info "python3 se mantiene: lo necesita el sistema."
}
