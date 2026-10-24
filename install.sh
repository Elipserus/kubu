#!/usr/bin/env bash
# Primera ejecución de kubu: preguntas, instalación completa y tema.
# Normalmente lo lanza boot.sh; también vale `bash install.sh` desde un clon.
set -Eeuo pipefail

KUBU_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export KUBU_ROOT

trap 'echo; echo "La instalación de kubu falló. Puedes reintentarla con: bash $KUBU_ROOT/install.sh"' ERR

if [[ $EUID -eq 0 ]]; then
  echo "Ejecuta kubu como tu usuario normal (usará sudo cuando lo necesite)." >&2
  exit 1
fi

. /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != "26.04" ]]; then
  echo "Aviso: kubu está pensado para Kubuntu 26.04 (detectado: ${PRETTY_NAME:-desconocido})." >&2
fi

source "$KUBU_ROOT/lib/common.sh"

echo "==> Preparando dependencias..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget git gpg ca-certificates unzip >/dev/null
ensure_gum >/dev/null

source "$KUBU_ROOT/lib/ui.sh"
source "$KUBU_ROOT/lib/modules.sh"

mkdir -p "$HOME/.local/bin"
ln -sf "$KUBU_ROOT/bin/kubu" "$HOME/.local/bin/kubu"

ui_header
gum style --foreground $KUBU_BLUE "  Prepárate para elegir unas cuantas cosas..."
echo

# --- 1. Aplicaciones opcionales (las obligatorias se instalan siempre)
declare -A ids=()
labels=() preselected=() required=()
while IFS=$'\t' read -r id name cat desc i u c up inst req def prio; do
  [[ $i == 1 && $id != databases ]] || continue   # databases tiene su propia pregunta
  if [[ $req == 1 ]]; then required+=("$id"); continue; fi
  label="$(pad "$cat" 15) $(pad "$name" 16) ${desc//,/}"
  ids[$label]=$id
  labels+=("$label")
  [[ $def == 1 ]] && preselected+=("$label")
done < <(modules_info)

sel_args=()
((${#preselected[@]})) && sel_args=(--selected "$(IFS=,; echo "${preselected[*]}")")
picked=$(gum choose --no-limit --height 25 "${sel_args[@]}" \
  --header "Aplicaciones (x marca/desmarca, enter continúa)" "${labels[@]}") || true

selected=()
while IFS= read -r label; do
  [[ -n $label ]] && selected+=("${ids[$label]}")
done <<<"$picked"

# --- 2. Lenguajes (mise) y bases de datos (Docker)
export KUBU_LANGUAGES KUBU_DATABASES
KUBU_LANGUAGES=$(gum choose --no-limit --height 10 --selected "Node.js,Python" \
  --header "Lenguajes de programación (con mise)" \
  "Node.js" "Python" "Go" "Ruby" "Rust" "Java" "PHP" "Elixir" | paste -sd' ' || true)
KUBU_DATABASES=$(gum choose --no-limit --height 5 \
  --header "Bases de datos (en Docker, solo en localhost)" \
  "PostgreSQL" "MySQL" "Redis" | paste -sd' ' || true)
[[ -n $KUBU_DATABASES ]] && selected+=(databases docker)

# --- 3. Identidad para git
export KUBU_USER_NAME KUBU_USER_EMAIL
KUBU_USER_NAME=$(ui_input "Tu nombre (para git)" "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)")
KUBU_USER_EMAIL=$(ui_input "Tu email (para git)" "" "tu@email.com")

# --- 4. Instalación desatendida
export KUBU_FIRST_RUN=1
mapfile -t order < <(sort_by_priority "${required[@]}" "${selected[@]}")

ui_header
gum style --foreground $KUBU_ORANGE "  Instalando ${#order[@]} módulos. Esto puede tardar un buen rato."
gum style --faint "  Detalles en $KUBU_LOG"

virt=$(vm_type)
if [[ -n $virt && " ${order[*]} " != *" vm-guest "* ]]; then
  warn "Máquina virtual ($virt) sin herramientas de invitado conocidas: se omiten."
fi

failed=0
apply install "${order[@]}" || failed=1

ui_title "Aplicando el tema kubu"
"$KUBU_ROOT/bin/kubu" theme kubu || failed=1

date +%s >"$KUBU_STATE/installed_at"

if [[ -f $KUBU_STATE/shortcuts.orig ]]; then
  source "$KUBU_ROOT/lib/shortcuts.sh"
  ui_title "Tus atajos de teclado (los verás siempre con: kubu atajos)"
  shortcuts_cheatsheet
fi

echo
if ((failed)); then
  warn "Algunos módulos fallaron. Revisa el log y reinténtalos desde el menú: kubu"
else
  gum style --foreground $KUBU_OK --bold "  ¡kubu instalado!"
fi
info "A partir de ahora, abre el menú con: kubu"
echo
ui_confirm "¿Reiniciar ahora para aplicar todo (grupos, terminal por defecto, tema)?" && sudo reboot || true
