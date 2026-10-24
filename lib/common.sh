# Helpers compartidos por el núcleo y los módulos.

KUBU_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kubu"
KUBU_LOG="$KUBU_STATE/kubu.log"
mkdir -p "$KUBU_STATE"

has() { command -v "$1" >/dev/null 2>&1; }

# Hipervisor si kubu corre en una VM (kvm, oracle, vmware...); vacío en una máquina real
vm_type() { local v; v=$(systemd-detect-virt --vm 2>/dev/null) || true; [[ $v == none ]] || echo "$v"; }
in_vm()   { [[ -n $(vm_type) ]]; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

apt_update() { sudo apt-get update; }

apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_purge() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@"
  sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
}

# Añade un repositorio APT en formato deb822 con su clave (ASCII o binaria).
# apt_add_repo <nombre> <url_clave> <uri> <suites> <componentes> [keyring]
apt_add_repo() {
  local name=$1 key_url=$2 uri=$3 suites=$4 components=$5
  local keyring=${6:-/etc/apt/keyrings/$name.gpg} tmp
  tmp=$(mktemp)
  curl -fsSL "$key_url" -o "$tmp"
  sudo install -d -m 0755 "$(dirname "$keyring")"
  if grep -q "BEGIN PGP" "$tmp"; then
    sudo gpg --dearmor --yes -o "$keyring" "$tmp"
  else
    sudo install -m 0644 "$tmp" "$keyring"
  fi
  rm -f "$tmp"
  sudo tee "/etc/apt/sources.list.d/$name.sources" >/dev/null <<EOF
Types: deb
URIs: $uri
Suites: $suites
Components: $components
Architectures: $(dpkg --print-architecture)
Signed-By: $keyring
EOF
  apt_update
}

# apt_remove_repo <nombre> [keyring]
apt_remove_repo() {
  local name=$1 keyring=${2:-/etc/apt/keyrings/$1.gpg}
  sudo rm -f "/etc/apt/sources.list.d/$name.sources" "$keyring"
}

ensure_gum() {
  has gum && return 0
  if apt-cache show gum >/dev/null 2>&1; then
    apt_install gum
  else
    apt_add_repo charm https://repo.charm.sh/apt/gpg.key https://repo.charm.sh/apt/ "*" "*"
    apt_install gum
  fi
}

ensure_flatpak() {
  has flatpak || step "Instalando flatpak" apt_install flatpak
  step "Configurando Flathub" sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
}

ensure_node() {
  pkg_installed nodejs && pkg_installed npm || step "Instalando nodejs y npm" apt_install nodejs npm
}

# Última versión publicada en GitHub (sin la "v"): github_latest <owner/repo>
github_latest() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -Po '"tag_name": *"v?\K[^"]*'
}

# Instala un binario de un tar.gz: install_tar_bin <url> <binario>
install_tar_bin() {
  local url=$1 bin=$2 tmp
  tmp=$(mktemp -d)
  curl -fsSL "$url" | tar -xz -C "$tmp"
  sudo install "$(find "$tmp" -type f -name "$bin" | head -1)" /usr/local/bin/"$bin"
  rm -rf "$tmp"
}

# Copia de seguridad única antes de que kubu pise un fichero del usuario
backup() {
  local f=$1
  [[ -e $f && ! -e $f.kubu-bak ]] && mv "$f" "$f.kubu-bak"
  return 0
}

# Restaura la copia hecha por backup (o borra el fichero si no la había)
restore() {
  local f=$1
  rm -rf "$f"
  [[ -e $f.kubu-bak ]] && mv "$f.kubu-bak" "$f"
  return 0
}

# Escribe una clave de configuración de KDE: kde_set <fichero> <grupo> <clave> <valor>
kde_set() { has kwriteconfig6 && kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }

# Pide a Ghostty en marcha que recargue su configuración (como ctrl+shift+,).
# Es una sola instancia: sin esto, las ventanas nuevas seguirían con la antigua.
ghostty_reload() { pkill -USR2 -x ghostty 2>/dev/null || true; }

_plasma_running() { qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; }

# plasma_js <script>: ejecuta JavaScript en plasmashell (API de scripting de Plasma)
plasma_js() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

# Reinicia plasmashell y espera a que vuelva a responder (máx. ~15 s)
plasma_restart() {
  local i
  systemctl --user restart plasma-plasmashell.service
  for i in {1..30}; do _plasma_running && return 0; sleep 0.5; done
  warn "Plasma tarda en volver: si algo se ve raro, usa «Reiniciar Plasma»"
}

# Web apps: un .desktop que abre la URL con kubu-webapp (elige navegador al lanzar)
webapp_desktop() { echo "$HOME/.local/share/applications/kubu-$1.desktop"; }

webapp_install() {
  local id=$1 name=$2 url=$3 icon_name=${4:-} domain
  local icon="$HOME/.local/share/icons/kubu/$id.png"
  domain=$(sed -E 's#^https?://([^/]+).*#\1#' <<<"$url")
  mkdir -p "$(dirname "$icon")" "$HOME/.local/share/applications"
  { [[ -n $icon_name ]] &&
      curl -fsSL -o "$icon" "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/$icon_name.png"; } ||
    curl -fsSL -o "$icon" "https://www.google.com/s2/favicons?domain=$domain&sz=256" || true
  cat >"$(webapp_desktop "$id")" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=Web app ($domain)
Exec=$KUBU_ROOT/bin/kubu-webapp $url
Icon=$icon
Terminal=false
Categories=Network;
EOF
  has update-desktop-database && update-desktop-database "$HOME/.local/share/applications" || true
}

webapp_remove() {
  rm -f "$(webapp_desktop "$1")" "$HOME/.local/share/icons/kubu/$1.png"
}
