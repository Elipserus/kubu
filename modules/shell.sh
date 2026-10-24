MOD_NAME="Shell"
MOD_CATEGORY="Terminal"
MOD_DESC="Bash con alias y el prompt de kubu"
MOD_REQUIRED=1
MOD_PRIORITY=10

PACKAGES=(bash-completion eza zoxide fzf bat fd-find ripgrep plocate wget unzip)

mod_is_installed() { grep -q "kubu/defaults/bash/rc\|defaults/bash/rc" "$HOME/.bashrc" 2>/dev/null; }

mod_install() {
  step "Instalando ${PACKAGES[*]}" apt_install "${PACKAGES[@]}"
  backup "$HOME/.bashrc"
  backup "$HOME/.inputrc"
  cat >"$HOME/.bashrc" <<RC
# Generado por kubu (tu .bashrc anterior está en ~/.bashrc.kubu-bak)
export KUBU_PATH="$KUBU_ROOT"
source "\$KUBU_PATH/defaults/bash/rc"

# Añade aquí tus propios ajustes
RC
  echo "\$include $KUBU_ROOT/defaults/bash/inputrc" >"$HOME/.inputrc"
  ok "~/.bashrc e ~/.inputrc configurados (copias en *.kubu-bak)"
}

mod_uninstall() {
  restore "$HOME/.bashrc"
  restore "$HOME/.inputrc"
  [[ -f $HOME/.bashrc ]] || cp /etc/skel/.bashrc "$HOME/.bashrc"
  ok "Restaurados ~/.bashrc e ~/.inputrc"
  step "Eliminando eza zoxide fzf bat fd-find ripgrep plocate" apt_purge eza zoxide fzf bat fd-find ripgrep plocate
}
