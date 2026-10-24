MOD_NAME="yazi"
MOD_CATEGORY="Terminal"
MOD_DESC="Gestor de ficheros de terminal (y)"

PREVIEWS=(ffmpegthumbnailer poppler-utils 7zip jq)

mod_is_installed() { [[ -x /usr/local/bin/yazi ]]; }

mod_install() {
  local v tmp dir
  v=$(github_latest sxyazi/yazi)
  dir="yazi-$(uname -m)-unknown-linux-gnu"
  tmp=$(mktemp -d)
  step "Descargando yazi $v" curl -fsSLo "$tmp/yazi.zip" \
    "https://github.com/sxyazi/yazi/releases/download/v$v/$dir.zip"
  step "Instalando yazi y ya" bash -c \
    "unzip -q '$tmp/yazi.zip' -d '$tmp' && sudo install '$tmp/$dir/yazi' '$tmp/$dir/ya' /usr/local/bin/"
  rm -rf "$tmp"
  step "Instalando vistas previas (vídeo · PDF · comprimidos · JSON)" apt_install "${PREVIEWS[@]}"
  info "Ábrelo con y: al salir, la terminal se queda en la carpeta donde estabas."
}

mod_update()    { mod_install; }
mod_uninstall() { step "Eliminando yazi" sudo rm -f /usr/local/bin/yazi /usr/local/bin/ya; }
