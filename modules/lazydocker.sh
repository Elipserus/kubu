MOD_NAME="lazydocker"
MOD_CATEGORY="Terminal"
MOD_DESC="Interfaz de terminal para Docker"
MOD_DEFAULT=1

mod_is_installed() { [[ -x /usr/local/bin/lazydocker ]]; }

mod_install() {
  local v
  v=$(github_latest jesseduffield/lazydocker)
  step "Instalando lazydocker $v" install_tar_bin \
    "https://github.com/jesseduffield/lazydocker/releases/download/v$v/lazydocker_${v}_Linux_x86_64.tar.gz" lazydocker
}

mod_update()    { mod_install; }
mod_uninstall() { step "Eliminando lazydocker" sudo rm -f /usr/local/bin/lazydocker; }
