# Capa de interfaz sobre gum. Paleta kubu: naranja + azul.

KUBU_ORANGE=208      # #ff8700
KUBU_ORANGE_SOFT=215
KUBU_BLUE=33         # #0087ff
KUBU_BLUE_SOFT=75
KUBU_OK=42
KUBU_ERR=196

export GUM_CHOOSE_CURSOR_FOREGROUND=$KUBU_ORANGE
export GUM_CHOOSE_SELECTED_FOREGROUND=$KUBU_BLUE_SOFT
export GUM_CHOOSE_HEADER_FOREGROUND=$KUBU_BLUE
export GUM_CHOOSE_CURSOR_PREFIX="○ "
export GUM_CHOOSE_SELECTED_PREFIX="● "
export GUM_CHOOSE_UNSELECTED_PREFIX="○ "
export GUM_INPUT_CURSOR_FOREGROUND=$KUBU_ORANGE
export GUM_INPUT_PROMPT_FOREGROUND=$KUBU_ORANGE
export GUM_INPUT_HEADER_FOREGROUND=$KUBU_BLUE
export GUM_CONFIRM_PROMPT_FOREGROUND=$KUBU_BLUE
export GUM_CONFIRM_SELECTED_BACKGROUND=$KUBU_ORANGE
export GUM_CONFIRM_SELECTED_FOREGROUND=0
export GUM_SPIN_SPINNER_FOREGROUND=$KUBU_ORANGE
# Paginador (Manual, vistas): búsqueda en azul y naranja en vez del rosa de gum
export GUM_PAGER_MATCH_FOREGROUND=$KUBU_BLUE
export GUM_PAGER_MATCH_HIGH_FOREGROUND=0
export GUM_PAGER_MATCH_HIGH_BACKGROUND=$KUBU_ORANGE
# Manual: tema de kubu para gum format (secciones azules, código naranja)
export GUM_FORMAT_THEME="$KUBU_ROOT/configs/gum-format.json"

KUBU_ASCII=' ____  __.     ___.
|    |/ _|__ _\_ |__  __ __
|      < |  |  \ __ \|  |  \
|    |  \|  |  / \_\ \  |  /
|____|__ \____/|___  /____/
        \/         \/'

# Logo en degradado naranja → azul, una línea por color
ui_logo() {
  local colors=(202 208 214 75 39 33) i=0 line
  echo
  while IFS= read -r line; do
    printf '  \033[38;5;%sm%s\033[0m\n' "${colors[i % ${#colors[@]}]}" "$line"
    ((i++)) || true
  done <<<"$KUBU_ASCII"
}

ui_header() {
  clear
  ui_logo
  echo
  echo "  $(gum style --foreground $KUBU_BLUE "Kubuntu a tu manera") $(gum style --faint "· v$(cat "$KUBU_ROOT/version" 2>/dev/null || echo dev)")"
  echo
}

# pad <texto> <ancho>: rellena por caracteres (printf %-Ns cuenta bytes y descuadra las tildes)
pad() { local s=$1; printf '%s%*s' "$s" $(( $2 > ${#s} ? $2 - ${#s} : 0 )) ''; }

ui_title() { echo; gum style --bold --foreground $KUBU_ORANGE "  $*"; }
info()     { gum style --faint "  $*"; }
ok()       { echo "  $(gum style --foreground $KUBU_OK '✓') $*"; }
warn()     { echo "  $(gum style --foreground $KUBU_ORANGE '!') $*"; }
err()      { echo "  $(gum style --foreground $KUBU_ERR '✗') $*" >&2; }
die()      { err "$*"; exit 1; }

# gum 0.17 revienta al pintar un placeholder no vacío: la pista va en el título
ui_input()   { gum input --prompt "› " --header "$1${3:+ (p. ej. $3)}" --value "${2:-}" --placeholder ""; }
ui_confirm() { gum confirm --affirmative "Sí" --negative "No" "$@"; }
ui_choose()  { local header=$1; shift; gum choose --height 20 --header "$header" "$@"; }
ui_pause()   { echo; gum style --faint "  Pulsa una tecla para continuar..."; read -rsn1 _ || true; }

# --- Submenús de configuración (mod_status / MOD_MENU) ---------------------------

# ui_status <etiqueta> <valor> [estado] [nota]: línea de estado coloreada
#   ok (verde) · warn (naranja) · err (rojo) · off (gris, ○) · sin estado: dato (azul)
ui_status() {
  local dot='●' color=$KUBU_BLUE_SOFT value=$2
  case ${3:-} in
    ok)   color=$KUBU_OK ;;
    warn) color=$KUBU_ORANGE ;;
    err)  color=$KUBU_ERR ;;
    off)  color=244 dot='○' ;;
  esac
  [[ -n ${3:-} ]] && value="\033[38;5;${color}m$2\033[0m"
  printf '  \033[38;5;%sm%s\033[0m \033[38;5;%sm%s\033[0m %b%b\n' \
    "$color" "$dot" "$KUBU_BLUE" "$(pad "$1" 22)" "$value" "${4:+  \033[2m$4\033[0m}"
}

# ui_service <etiqueta> <unidad systemd>
ui_service() {
  local s boot=""
  s=$(systemctl is-active "$2" 2>/dev/null || true)
  [[ $(systemctl is-enabled "$2" 2>/dev/null || true) == enabled ]] && boot="arranca con el sistema"
  case $s in
    active)     ui_status "$1" "en marcha" ok "$boot" ;;
    failed)     ui_status "$1" "con errores" err "mira los logs" ;;
    activating) ui_status "$1" "arrancando" warn ;;
    *)          ui_status "$1" "parado" off "$boot" ;;
  esac
}

# ui_section <título>: encabezado de un panel de configuración
ui_section() {
  printf '  \033[1;38;5;%sm▌ %s\033[0m\n' "$KUBU_BLUE" "$1"
  [[ -n ${2:-} ]] && printf '  \033[2m  %s\033[0m\n' "$2"
  return 0
}

# ui_view <título> < texto: muestra una salida larga en el paginador
ui_view() { { gum style --bold --foreground $KUBU_BLUE "  ▌ $1"; echo; cat; } | gum pager; }

# ui_pick <cabecera> <opción>...: elige una; falla si no hay opciones o se cancela
ui_pick() {
  local header=$1; shift
  (($#)) || { warn "No hay nada que elegir."; return 1; }
  gum choose --height 15 --header "$header" "$@"
}

# Copia la entrada estándar al portapapeles si hay forma de hacerlo
clip_copy() {
  if has wl-copy && [[ -n ${WAYLAND_DISPLAY:-} ]]; then wl-copy
  elif has xclip; then xclip -selection clipboard
  else cat >/dev/null; return 1
  fi
}

# step <título> <comando...>
# Ejecuta un comando no interactivo, enviando su salida al log.
# Para pasos que piden datos al usuario, no uses step.
step() {
  local title=$1 rc
  shift
  printf '  %s %s' "$(gum style --foreground $KUBU_BLUE '…')" "$title"
  printf '\n### %s — %s\n' "$(date '+%F %T')" "$title" >>"$KUBU_LOG"
  set +e
  ( set -e; "$@" ) >>"$KUBU_LOG" 2>&1
  rc=$?
  set -e
  if (( rc == 0 )); then
    printf '\r\033[K  %s %s\n' "$(gum style --foreground $KUBU_OK '✓')" "$title"
  else
    printf '\r\033[K  %s %s\n' "$(gum style --foreground $KUBU_ERR '✗')" "$title"
    tail -n 15 "$KUBU_LOG" | gum style --faint --margin "0 4"
    info "Log completo: $KUBU_LOG"
    return "$rc"
  fi
}
