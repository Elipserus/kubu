MOD_NAME="Brave"
MOD_CATEGORY="Internet"
MOD_DESC="Navegador Brave (repo oficial)"
MOD_DEFAULT=1

KEYRING=/usr/share/keyrings/brave-browser-archive-keyring.gpg
SOURCES=/etc/apt/sources.list.d/brave-browser-release.sources
BASE=https://brave-browser-apt-release.s3.brave.com

mod_is_installed() { pkg_installed brave-browser; }

mod_install() {
  step "Descargando clave del repositorio" sudo curl -fsSLo "$KEYRING" "$BASE/brave-browser-archive-keyring.gpg"
  step "Añadiendo repositorio"             sudo curl -fsSLo "$SOURCES" "$BASE/brave-browser.sources"
  step "Actualizando índices"              apt_update
  step "Instalando brave-browser"          apt_install brave-browser
}

mod_uninstall() {
  step "Eliminando brave-browser" apt_purge brave-browser
  step "Quitando repositorio"     sudo rm -f "$SOURCES" "$KEYRING"
}
