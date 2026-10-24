MOD_NAME="Git"
MOD_CATEGORY="Desarrollo"
MOD_DESC="Tu identidad y alias útiles"
MOD_REQUIRED=1
MOD_PRIORITY=5

mod_is_installed() { pkg_installed git; }

mod_install() {
  step "Instalando git" apt_install git
  mod_configure
}

mod_configure() {
  local name=${KUBU_USER_NAME:-} email=${KUBU_USER_EMAIL:-}
  [[ -n $name ]]  || name=$(ui_input "Nombre para los commits" "$(git config --global user.name || true)")
  [[ -n $email ]] || email=$(ui_input "Email para los commits" "$(git config --global user.email || true)")
  [[ -n $name ]]  && git config --global user.name "$name"
  [[ -n $email ]] && git config --global user.email "$email"
  git config --global init.defaultBranch main
  git config --global pull.rebase true
  git config --global push.autoSetupRemote true
  git config --global core.editor nvim
  git config --global alias.co checkout
  git config --global alias.br branch
  git config --global alias.ci commit
  git config --global alias.st status
  ok "Git configurado${name:+ para $name <$email>}"
}

MOD_MENU=(
  "git_show|Ver la configuración global"
  "git_signing|Firmar los commits con tu clave SSH"
  "git_unsigning|Dejar de firmar los commits"
)

mod_status() {
  local name email key
  name=$(git config --global user.name || true)
  email=$(git config --global user.email || true)
  if [[ -n $name ]]; then ui_status "Identidad" "$name <$email>" ok; else ui_status "Identidad" "sin configurar" warn; fi
  ui_status "Rama por defecto" "$(git config --global init.defaultBranch || echo master)"
  key=$(git config --global user.signingkey || true)
  if [[ $(git config --global commit.gpgsign || true) == true ]]; then ui_status "Firma de commits" "activada" ok "${key/#$HOME/\~}"
  else ui_status "Firma de commits" "desactivada" off
  fi
}

git_show() { git config --global --list | ui_view "~/.gitconfig (q para salir)"; }

git_signing() {
  local -a keys=()
  local key
  mapfile -t keys < <(compgen -G "$HOME/.ssh/*.pub" || true)
  ((${#keys[@]})) || die "No tienes claves SSH: genéralas en Configurar › SSH server"
  key=$(ui_pick "¿Con qué clave firmar?" "${keys[@]}") || return 0
  git config --global gpg.format ssh
  git config --global user.signingkey "$key"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  # Para que `git log --show-signature` reconozca tus propias firmas
  mkdir -p "$HOME/.config/git"
  echo "$(git config --global user.email) $(cat "$key")" >"$HOME/.config/git/allowed_signers"
  git config --global gpg.ssh.allowedSignersFile "$HOME/.config/git/allowed_signers"
  ok "Los commits se firmarán con $(basename "$key")"
  if has gh && gh auth status >/dev/null 2>&1 && ui_confirm "¿Subirla a GitHub como clave de firma (verified)?"; then
    gh ssh-key add "$key" --type signing --title "$(hostname) (firma)" ||
      { gh auth refresh -h github.com -s admin:ssh_signing_key &&
        gh ssh-key add "$key" --type signing --title "$(hostname) (firma)"; }
  fi
}

git_unsigning() {
  git config --global --unset commit.gpgsign || true
  git config --global --unset tag.gpgsign || true
  ok "Los commits ya no se firman"
}
