# Atajos globales de KDE: la chuleta de kubu y cómo aplicarlos en caliente.
#
# Se cambian por D-Bus en kglobalaccel (dentro de KWin), así que funcionan al
# momento sin cerrar sesión, y kglobalaccel los guarda en kglobalshortcutsrc.
# Una acción se identifica por: componente · acción · nombre del componente ·
# nombre de la acción (los nombres solo se usan si la acción aún no existe).
#
# Ojo: kglobalaccel solo atiende las teclas de componentes que carga él mismo
# (al arrancar la sesión o al cambiar la base de datos de apps). Una app nueva
# registrada por D-Bus queda asignada pero su tecla no hace nada hasta la
# próxima sesión. Por eso las apps se abren con lanzadores propios
# (kde_launcher_set) que llevan el atajo en X-KDE-Shortcuts.

LAUNCHER_DIR="$HOME/.local/share/applications"

# Chuleta: grupo|teclas|qué hace|k (k = lo pone kubu; el resto es de KDE o de la app)
SHORTCUTS_CHEATSHEET=(
  "Apps|Meta+Intro · Ctrl+Alt+T|Terminal predeterminada (Ghostty)|k"
  "Apps|Meta+B|Navegador por defecto|k"
  "Apps|Meta+C|VS Code (si está instalado)|k"
  "Apps|Meta+E|Archivos (Dolphin)|"
  "Apps|Meta|Menú de aplicaciones|"
  "Apps|Alt+Espacio|Buscar y abrir apps (KRunner)|"
  "Apps|Meta+Esc|Monitor del sistema|"
  "Apps|Meta+V|Historial del portapapeles|"
  "Apps|Meta+.|Emojis|"
  "Apps|Impr · Meta+Shift+S|Captura de pantalla|"
  "Ventanas|Meta+Q · Alt+F4|Cerrar la ventana|k"
  "Ventanas|Meta+F|Pantalla completa|k"
  "Ventanas|Meta+RePág|Maximizar|"
  "Ventanas|Meta+AvPág|Minimizar|"
  "Ventanas|Meta+flechas|Colocar en mitades y cuartos de pantalla|"
  "Ventanas|Meta+arrastrar|Mover (también sin bordes)|"
  "Ventanas|Meta+clic derecho y arrastrar|Redimensionar|"
  "Ventanas|Alt+Tab · Meta+Tab|Cambiar de ventana|"
  "Ventanas|Meta+W|Vista general|"
  "Ventanas|Meta+D|Ver el escritorio|"
  "Ventanas|Meta+Shift+← →|Llevar a otra pantalla|"
  "Escritorios|Meta+Ctrl+← →|Cambiar de escritorio virtual|"
  "Escritorios|Meta+Ctrl+Shift+← →|Llevar la ventana a otro escritorio|"
  "Pestañas|Ctrl+Tab · Ctrl+Shift+Tab|Siguiente / anterior (navegador · Ghostty · Dolphin)|"
  "Pestañas|Ctrl+1…8|Ir a la pestaña N (navegador)|"
  "Pestañas|Alt+1…8|Ir a la pestaña N (Ghostty)|"
  "Pestañas|Ctrl+T · Ctrl+W|Nueva / cerrar pestaña (navegador · Dolphin)|"
  "Pestañas|Ctrl+Shift+T · Ctrl+Shift+W|Nueva / cerrar pestaña (Ghostty)|"
  "Sesión|Meta+L|Bloquear la pantalla|"
)

# Imprime la chuleta agrupada; los atajos que pone kubu llevan ●
shortcuts_cheatsheet() {
  local line group keys desc mine last=""
  for line in "${SHORTCUTS_CHEATSHEET[@]}"; do
    IFS='|' read -r group keys desc mine <<<"$line"
    if [[ $group != "$last" ]]; then
      [[ -n $last ]] && echo
      gum style --bold --foreground $KUBU_ORANGE "  $group"
      last=$group
    fi
    if [[ -n $mine ]]; then
      echo "  $(gum style --foreground $KUBU_BLUE '●') $(gum style --bold "$(pad "$keys" 30)") $desc"
    else
      echo "    $(pad "$keys" 30) $desc"
    fi
  done
  echo
  gum style --faint "  ● = atajo de kubu · Meta es la tecla de Windows"
}

# --- kglobalaccel ------------------------------------------------------------------

_kga() { busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel "$@"; }
_kga_json() { busctl --user --json=short call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel "$@"; }

kglobalaccel_running() { _kga allMainComponents >/dev/null 2>&1; }

# Código Qt de una combinación: key_code Meta+Shift+Intro → entero
key_code() {
  local part code=0
  local -A mods=([Meta]=0x10000000 [Shift]=0x02000000 [Ctrl]=0x04000000 [Alt]=0x08000000)
  local -A keys=([Intro]=0x01000004 [Return]=0x01000004 [Esc]=0x01000000 [Tab]=0x01000001
    [Espacio]=0x20 [Space]=0x20 [Impr]=0x01000009 [Print]=0x01000009 [RePág]=0x01000016
    [AvPág]=0x01000017 [Left]=0x01000012 [Up]=0x01000013 [Right]=0x01000014 [Down]=0x01000015)
  IFS='+' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    if [[ -n ${mods[$part]:-} ]]; then code=$((code | mods[$part]))
    elif [[ -n ${keys[$part]:-} ]]; then code=$((code | keys[$part]))
    elif [[ $part =~ ^F([0-9]{1,2})$ ]]; then code=$((code | (0x01000030 + BASH_REMATCH[1] - 1)))
    elif [[ ${#part} == 1 ]]; then code=$((code | $(printf '%d' "'${part^^}")))
    else return 1
    fi
  done
  echo "$code"
}

# Teclas actuales de una acción (códigos separados por espacios)
_kga_keys() { _kga_json shortcut as 4 "$1" "$2" "" "" | jq -r '.data[0] | map(tostring) | join(" ")'; }

# _kga_set <comp> <acción> <nombre comp> <nombre acción> [código...]
_kga_set() {
  local action_id=("$1" "$2" "$3" "$4")
  shift 4
  _kga setForeignShortcut asai 4 "${action_id[@]}" $# "$@" >/dev/null
}

# Guarda (una sola vez) cómo estaba una acción antes de que kubu la toque
_kga_remember() {
  local file="$KUBU_STATE/shortcuts.orig"
  grep -qF -- "$1"$'\t'"$2"$'\t' "$file" 2>/dev/null && return 0
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(_kga_keys "$1" "$2")" >>"$file"
}

# Códigos de varias teclas (uno por línea); falla si alguna no se conoce
_key_codes() {
  local k
  for k in "$@"; do key_code "$k" || { err "Tecla desconocida: $k"; return 1; }; done
}

# kde_key_free <comp> <acción> <código>...: si otra acción usa alguna de esas
# teclas, se le quita solo esa (kglobalaccel rechaza en silencio una tecla ocupada)
kde_key_free() {
  local comp=$1 act=$2 c x hcomp hact hcompName hactName hkeys
  local -a keep
  shift 2
  for c in "$@"; do
    while IFS=$'\t' read -r hcomp hact hcompName hactName hkeys; do
      [[ $hcomp == "$comp" && $hact == "$act" ]] && continue
      _kga_remember "$hcomp" "$hact" "$hcompName" "$hactName"
      keep=()
      for x in $hkeys; do [[ $x == "$c" ]] || keep+=("$x"); done
      _kga_set "$hcomp" "$hact" "$hcompName" "$hactName" "${keep[@]}"
    done < <(_kga_json getGlobalShortcutsByKey i "$c" |
      jq -r '.data[0][] | [.[2], .[0], .[3], .[1], (.[6] | map(tostring) | join(" "))] | @tsv')
  done
}

# kde_shortcut_set <comp> <acción> <nombre comp> <nombre acción> <tecla>...
# Para acciones que kglobalaccel ya tiene cargadas (KWin, Plasma...): las teclas
# sustituyen a las que tuviera la acción.
kde_shortcut_set() {
  local comp=$1 act=$2 compName=$3 actName=$4
  local -a codes
  shift 4
  mapfile -t codes < <(_key_codes "$@") && ((${#codes[@]} == $#)) || return 1

  _kga doRegister as 4 "$comp" "$act" "$compName" "$actName" >/dev/null
  _kga_remember "$comp" "$act" "$compName" "$actName"
  kde_key_free "$comp" "$act" "${codes[@]}"
  _kga_set "$comp" "$act" "$compName" "$actName" "${codes[@]}"
  [[ $(_kga_keys "$comp" "$act") == "${codes[*]}" ]]
}

# kde_launcher_set <id> <nombre> <icono> <tecla>...
# Lanzador oculto kubu-shortcut-<id>.desktop que ejecuta `kubu-launch <id>`, con
# el atajo en X-KDE-Shortcuts. kglobalaccel lo carga solo al reconstruir la base
# de datos de apps, y así su tecla funciona al momento.
kde_launcher_set() {
  local id=$1 name=$2 icon=$3 i
  local comp="kubu-shortcut-$id.desktop"
  local -a codes
  shift 3
  mapfile -t codes < <(_key_codes "$@") && ((${#codes[@]} == $#)) || return 1

  kde_key_free "$comp" _launch "${codes[@]}"
  mkdir -p "$LAUNCHER_DIR"
  cat >"$LAUNCHER_DIR/$comp" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=Atajo de kubu
Exec=$KUBU_ROOT/bin/kubu-launch $id
Icon=$icon
NoDisplay=true
X-KDE-Shortcuts=$(IFS=,; key_portable "$*")
EOF
  kbuildsycoca6 >/dev/null 2>&1 || true

  # kglobalaccel lo recoge al poco; si ya lo conocía con otras teclas, se corrigen
  for i in {1..20}; do
    [[ $(_kga_keys "$comp" _launch 2>/dev/null) == "${codes[*]}" ]] && return 0
    if ((i == 10)); then _kga_set "$comp" _launch "$name" "$name" "${codes[@]}" 2>/dev/null || true; fi
    sleep 0.5
  done
  return 1
}

# Teclas en el formato de los .desktop (en inglés): Meta+Intro → Meta+Return
key_portable() {
  sed -e 's/Intro/Return/g; s/Espacio/Space/g; s/RePág/PgUp/g; s/AvPág/PgDown/g; s/Impr/Print/g' <<<"$1"
}

# Quita los lanzadores de kubu y sus teclas
kde_launchers_remove() {
  local f comp
  for f in "$LAUNCHER_DIR"/kubu-shortcut-*.desktop; do
    [[ -f $f ]] || continue
    comp=$(basename "$f")
    _kga_set "$comp" _launch "" "" || true
    rm -f "$f"
  done
  kbuildsycoca6 >/dev/null 2>&1 || true
}

# Devuelve todas las acciones tocadas a como estaban. Primero se vacían todas
# para que ninguna tecla esté ocupada al devolverlas.
kde_shortcuts_restore() {
  local file="$KUBU_STATE/shortcuts.orig" comp act compName actName keys
  kde_launchers_remove
  [[ -f $file ]] || return 0
  while IFS=$'\t' read -r comp act compName actName keys; do
    _kga_set "$comp" "$act" "$compName" "$actName"
  done <"$file"
  while IFS=$'\t' read -r comp act compName actName keys; do
    # shellcheck disable=SC2086
    _kga_set "$comp" "$act" "$compName" "$actName" $keys
  done <"$file"
  rm -f "$file"
}
