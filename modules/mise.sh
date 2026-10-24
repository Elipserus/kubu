MOD_NAME="mise"
MOD_CATEGORY="Desarrollo"
MOD_DESC="Versiones de lenguajes de programación"
MOD_DEFAULT=1
MOD_PRIORITY=40

LANGUAGES=("Node.js" "Python" "Go" "Ruby" "Rust" "Java" "PHP" "Elixir")

mod_is_installed() { pkg_installed mise; }

mod_install() {
  step "Añadiendo repositorio de mise" apt_add_repo mise \
    https://mise.jdx.dev/gpg-key.pub https://mise.jdx.dev/deb stable main
  step "Instalando mise" apt_install mise
  mod_configure
}

# Lenguajes: los del asistente (KUBU_LANGUAGES) o preguntando
mod_configure() {
  local langs lang
  if [[ -n ${KUBU_FIRST_RUN:-} ]]; then
    langs=${KUBU_LANGUAGES:-}
  else
    langs=$(gum choose --no-limit --height 10 --header "Lenguajes a instalar con mise" \
      "${LANGUAGES[@]}" | paste -sd' ' || true)
  fi
  if [[ -z $langs ]]; then
    info "Sin lenguajes que instalar"
    return 0
  fi

  for lang in $langs; do
    case $lang in
      Node.js) step "Node.js LTS" mise use --global node@lts ;;
      Python)  step "Python"      mise use --global python@latest ;;
      Go)      step "Go"          mise use --global go@latest ;;
      Java)    step "Java"        mise use --global java@latest ;;
      Ruby)
        step "Dependencias de Ruby" apt_install build-essential libssl-dev libyaml-dev \
          zlib1g-dev libffi-dev libreadline-dev libgmp-dev
        step "Ruby" mise use --global ruby@latest
        ;;
      Rust)
        step "Rust (rustup)" bash -c 'curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
        ;;
      PHP)
        step "PHP y extensiones" apt_install php-cli php-curl php-intl php-mbstring \
          php-pgsql php-mysql php-sqlite3 php-xml php-zip
        ;;
      Elixir)
        step "Erlang" mise use --global erlang@latest
        step "Elixir" mise use --global elixir@latest
        ;;
    esac
  done
}

mod_update() {
  step "Actualizando mise" bash -c 'sudo apt-get install -y --only-upgrade mise && mise upgrade'
}

mod_uninstall() {
  step "Eliminando mise" apt_purge mise
  step "Quitando repositorio" apt_remove_repo mise
  rm -rf "$HOME/.local/share/mise" "$HOME/.config/mise" "$HOME/.cache/mise"
}
