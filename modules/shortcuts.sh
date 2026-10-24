MOD_NAME="Atajos de kubu"
MOD_CATEGORY="Sistema"
MOD_DESC="Atajos de teclado para apps y ventanas"
MOD_DEFAULT=1
MOD_PRIORITY=95   # después de instalar las apps a las que apuntan

source "$KUBU_ROOT/lib/shortcuts.sh"

MOD_MENU=(
  "sc_list|Ver la chuleta de atajos"
)

mod_is_installed() { [[ -f $KUBU_STATE/shortcuts.orig ]]; }

mod_install() {
  has jq || step "Instalando jq" apt_install jq
  mod_configure
}

_desktop_path() {
  local dir
  for dir in "$HOME/.local/share/applications" /var/lib/flatpak/exports/share/applications /usr/share/applications; do
    [[ -f $dir/$1 ]] && { echo "$dir/$1"; return 0; }
  done
  return 1
}

# Desktop de una app instalada (el primero que exista), vacío si no hay
_desktop_of() {
  local d
  for d in "$@"; do _desktop_path "$d" >/dev/null && { echo "$d"; return 0; }; done
  return 0
}

# Nombre visible de una app (Name= de su .desktop) para la configuración de KDE
_app_name() {
  local f name=""
  f=$(_desktop_path "$1") && name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
  echo "${name:-${1%.desktop}}"
}

_set() {  # _set <qué> <comp> <acción> <nombre comp> <nombre acción> <tecla>...
  local what=$1
  shift
  if kde_shortcut_set "$@"; then ok "$what: ${*:5}"
  else warn "$what: no se pudo asignar ${*:5}"
  fi
}

_launcher() {  # _launcher <qué> <id> <nombre> <icono> <tecla>...
  local what=$1
  shift
  if kde_launcher_set "$@"; then ok "$what: ${*:4}"
  else warn "$what: no se pudo asignar ${*:4}"
  fi
}

mod_configure() {
  kglobalaccel_running || die "No hay sesión de KDE accesible: ejecútalo desde tu sesión gráfica"

  # Apps: lanzadores propios (ver lib/shortcuts.sh); abren las predeterminadas
  _launcher "Terminal" terminal "Terminal (kubu)" utilities-terminal Meta+Intro Ctrl+Alt+T
  _launcher "Navegador" browser "Navegador (kubu)" internet-web-browser Meta+B
  # Alt+Espacio: lanzador de apps; KRunner se queda con Alt+F2
  _launcher "Lanzador de apps" launcher "Lanzador de apps (kubu)" system-search Alt+Espacio
  if [[ -n $(_desktop_of com.microsoft.VSCode.desktop code.desktop) ]]; then
    _launcher "VS Code" editor "VS Code (kubu)" accessories-text-editor Meta+C
  fi
  # Acciones de KWin: ya están cargadas, se cambian directamente
  _set "Cerrar ventana" kwin "Window Close" KWin "Cerrar la ventana" Alt+F4 Meta+Q
  _set "Pantalla completa" kwin "Window Fullscreen" KWin "Pantalla completa" Meta+F
  # En el asistente la chuleta sale al final de todo (install.sh)
  [[ -n ${KUBU_FIRST_RUN:-} ]] || { echo; shortcuts_cheatsheet; }
}

mod_uninstall() {
  kglobalaccel_running || die "No hay sesión de KDE accesible: ejecútalo desde tu sesión gráfica"
  kde_shortcuts_restore
  ok "Atajos devueltos a como estaban antes de kubu"
}

mod_status() {
  local n
  n=$(grep -c . "$KUBU_STATE/shortcuts.orig" 2>/dev/null || true)
  ui_status "Atajos de kubu" "aplicados" ok "${n:-0} acciones de KDE tocadas (se restauran al desinstalar)"
  ui_status "Meta+Intro abre" "$(_app_name "$(kreadconfig6 --file kdeglobals --group General \
    --key TerminalService --default org.kde.konsole.desktop)")"
  ui_status "Meta+B abre" "$(_app_name "$(xdg-settings get default-web-browser 2>/dev/null)")"
}

sc_list() { shortcuts_cheatsheet | ui_view "Atajos (q para salir)"; }
