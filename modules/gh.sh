MOD_NAME="GitHub CLI"
MOD_CATEGORY="Desarrollo"
MOD_DESC="GitHub desde la terminal"
MOD_DEFAULT=1

MOD_MENU=(
  "gh_login|Iniciar sesión en GitHub"
  "gh_logout|Cerrar sesión"
  "gh_ssh_key|Subir una clave SSH a GitHub"
  "gh_keys|Ver las claves SSH de tu cuenta"
  "gh_test|Probar la conexión SSH con GitHub"
)

mod_is_installed() { pkg_installed gh; }

mod_install() {
  step "Añadiendo repositorio de GitHub CLI" apt_add_repo github-cli \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg https://cli.github.com/packages stable main
  step "Instalando gh" apt_install gh
}

mod_uninstall() {
  step "Eliminando gh" apt_purge gh
  step "Quitando repositorio" apt_remove_repo github-cli
}

_logged() { gh auth status >/dev/null 2>&1; }

mod_status() {
  local user
  if _logged; then
    user=$(gh api user --jq .login 2>/dev/null || echo "?")
    ui_status "Sesión" "$user" ok
    ui_status "Protocolo git" "$(gh config get git_protocol 2>/dev/null || echo https)"
  else
    ui_status "Sesión" "sin iniciar" warn
  fi
}

gh_login() {
  info "Elige GitHub.com, SSH como protocolo y «Login with a web browser»."
  gh auth login
  gh auth setup-git
  ok "Sesión iniciada como $(gh api user --jq .login)"
}

gh_logout() {
  _logged || { info "No hay sesión iniciada"; return 0; }
  gh auth logout
}

gh_ssh_key() {
  local -a keys=()
  local key
  _logged || die "Inicia sesión primero"
  mapfile -t keys < <(compgen -G "$HOME/.ssh/*.pub" || true)
  ((${#keys[@]})) || die "No tienes claves SSH: genéralas en Configurar › SSH server"
  key=$(ui_pick "¿Qué clave subir?" "${keys[@]}") || return 0
  # Puede faltar el permiso admin:public_key en tokens antiguos
  gh ssh-key add "$key" --title "$(hostname)" ||
    { gh auth refresh -h github.com -s admin:public_key && gh ssh-key add "$key" --title "$(hostname)"; }
  ok "Clave subida a GitHub"
}

gh_keys() { _logged || die "Inicia sesión primero"; gh ssh-key list; }

gh_test() {
  local out
  out=$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true)
  if grep -q "successfully authenticated" <<<"$out"; then ok "${out%%!*}!"
  else err "GitHub no acepta tu clave: $out"; return 1
  fi
}
