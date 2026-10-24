MOD_NAME="Escritorio"
MOD_CATEGORY="Sistema"
MOD_DESC="Barra superior · fecha · apps ancladas"
MOD_DEFAULT=1
MOD_PRIORITY=90   # al final: Plasma ya configurado y apps instaladas

PLASMOIDS=(org.kubu.ip org.kubu.spotify org.kubu.sysmon org.kubu.clock)
APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

MOD_MENU=(
  "desk_mode|Modo oscuro o claro"
  "desk_pins|Elegir las apps ancladas en la barra de tareas"
  "desk_bar|Añadir o quitar la barra superior"
  "desk_clock|Añadir o quitar la fecha del escritorio"
  "desk_glow|Activar o quitar el brillo de la ventana activa"
  "desk_restart|Reiniciar Plasma (si algo se queda raro)"
)

mod_is_installed() { [[ -f $KUBU_STATE/desktop ]]; }

mod_install() {
  pkg_installed playerctl || step "Instalando playerctl" apt_install playerctl
  mod_configure
  touch "$KUBU_STATE/desktop"
}

mod_configure() {
  _plasma_running || die "Plasma no está en marcha: ejecútalo desde tu sesión gráfica"
  _glow off
  _install_plasmoids
  _bar_exists && _bar_remove
  _bar_create
  ok "Barra superior creada"
  _clock_exists || { _clock_create; ok "Fecha en el escritorio"; }
}

mod_uninstall() {
  if _plasma_running; then
    _bar_exists && _bar_remove
    _clock_exists && _clock_remove
  fi
  _glow on
  local p
  for p in "${PLASMOIDS[@]}"; do
    kpackagetool6 -t Plasma/Applet -r "$p" >/dev/null 2>&1 || true
  done
  rm -f "$KUBU_STATE/desktop"
  ok "Escritorio restaurado"
}

# --- Plasma -----------------------------------------------------------------------

_install_plasmoids() {
  local p
  for p in "${PLASMOIDS[@]}"; do
    if kpackagetool6 -t Plasma/Applet -s "$p" >/dev/null 2>&1; then
      kpackagetool6 -t Plasma/Applet -u "$KUBU_ROOT/plasmoids/$p" >>"$KUBU_LOG" 2>&1
    else
      kpackagetool6 -t Plasma/Applet -i "$KUBU_ROOT/plasmoids/$p" >>"$KUBU_LOG" 2>&1
    fi
  done
  ok "Widgets de kubu instalados"
}

# La barra superior de kubu es el panel que contiene org.kubu.ip
_bar_exists() {
  [[ $(plasma_js 'print(panels().filter(p => p.widgets("org.kubu.ip").length).length)') != 0 ]]
}

_bar_remove() { plasma_js 'panels().filter(p => p.widgets("org.kubu.ip").length).forEach(p => p.remove())' >/dev/null; }

# IP a la izquierda, Spotify centrado entre dos espaciadores y CPU/RAM a la derecha
_bar_create() {
  plasma_js '
    var p = new Panel("org.kde.panel");
    p.location = "top";
    p.height = 36;
    try { p.floating = false; } catch (e) {}
    p.addWidget("org.kubu.ip");
    p.addWidget("org.kde.plasma.panelspacer");
    p.addWidget("org.kubu.spotify");
    p.addWidget("org.kde.plasma.panelspacer");
    p.addWidget("org.kubu.sysmon");
  ' >/dev/null
  # Transparencia y demás ajustes de barra del tema actual
  source "$KUBU_ROOT/lib/theme.sh"
  theme_panels
}

# --- Fecha en el escritorio (org.kubu.clock en la pantalla principal) -------------

_clock_exists() {
  [[ $(plasma_js 'print(desktops().filter(d => d.widgets("org.kubu.clock").length).length)') != 0 ]]
}

_clock_remove() {
  plasma_js 'desktops().forEach(d => d.widgets("org.kubu.clock").forEach(w => w.remove()))' >/dev/null
}

# Arriba a la izquierda, a 48 px de la barra superior, 1000×200.
# El escritorio ignora la posición de addWidget y solo lee ItemGeometries
# (relativo al área libre de paneles) al arrancar: se escribe y se reinicia Plasma.
_clock_create() {
  plasma_js '
    desktops().filter(d => d.screen == 0).forEach(function (d) {
      var w = d.addWidget("org.kubu.clock");
      var s = screenGeometry(d.screen);
      var entry = "Applet-" + w.id + ":48,48,1000,200,0;";
      d.currentConfigGroup = [];
      ["ItemGeometries-" + s.width + "x" + s.height, "ItemGeometriesHorizontal"].forEach(function (key) {
        var rest = (d.readConfig(key, "") || "").split(";")
          .filter(e => e && e.indexOf("Applet-" + w.id + ":") != 0);
        d.writeConfig(key, rest.map(e => e + ";").join("") + entry);
      });
    });
  ' >/dev/null
  plasma_restart
}

# --- Brillo de la ventana activa (Oxygen: resplandor · Breeze: contorno) ----------

_glow_on() { [[ $(kreadconfig6 --file oxygenrc --group ActiveShadow --key Enabled --default true) == true ]]; }

_glow() {  # _glow on|off
  if [[ $1 == off ]]; then
    kwriteconfig6 --file oxygenrc --group ActiveShadow --key Enabled false
    kwriteconfig6 --file breezerc --group Common --key OutlineEnabled false
  else
    kwriteconfig6 --file oxygenrc --group ActiveShadow --key Enabled --delete
    kwriteconfig6 --file breezerc --group Common --key OutlineEnabled --delete
  fi
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
}

# --- Apps ancladas ------------------------------------------------------------------

_current_launchers() {
  plasma_js '
    var out = [];
    panels().forEach(function (p) {
      p.widgets().forEach(function (w) {
        if (out.length || (w.type != "org.kde.plasma.icontasks" && w.type != "org.kde.plasma.taskmanager")) return;
        w.currentConfigGroup = ["General"];
        out = w.readConfig("launchers", []);
      });
    });
    print(out.join("\n"));' 2>/dev/null | grep . || true
}

APP_DIRS=("$HOME/.local/share/applications" /var/lib/flatpak/exports/share/applications
          "$HOME/.local/share/flatpak/exports/share/applications" /usr/share/applications)

# _app_installed <fichero.desktop>
_app_installed() { local d; for d in "${APP_DIRS[@]}"; do [[ -f $d/$1 ]] && return 0; done; return 1; }

# Apps típicas, arriba del todo: "<lanzador>\t<nombre>" (solo las que existen)
_typical_apps() {
  local term t
  printf 'preferred://filemanager\t★ Gestor de archivos\n'
  printf 'preferred://browser\t★ Navegador web\n'
  term=$(kreadconfig6 --file kdeglobals --group General --key TerminalService --default org.kde.konsole.desktop)
  _app_installed "$term" && printf 'applications:%s\t★ Terminal\n' "$term"
  for t in "systemsettings.desktop|Ajustes del sistema" "org.kde.discover.desktop|Discover (instalar apps)" \
           "org.kde.plasma-systemmonitor.desktop|Monitor del sistema" "org.kde.kate.desktop|Editor de texto (Kate)" \
           "org.kde.kwrite.desktop|Editor de texto (KWrite)" "org.kde.spectacle.desktop|Capturas de pantalla" \
           "org.kde.kcalc.desktop|Calculadora"; do
    _app_installed "${t%%|*}" && printf 'applications:%s\t★ %s\n' "${t%%|*}" "${t#*|}"
  done
  return 0
}

# Una línea por app instalada y visible en KDE: "<lanzador>\t<nombre>"
# (ojo: corre con set -e y pipefail, así que cada grep que pueda no encontrar nada lleva || true)
_desktop_apps() {
  local dir f name entry
  local -A seen=()
  for dir in "${APP_DIRS[@]}"; do
    [[ -d $dir ]] || continue
    for f in "$dir"/*.desktop; do
      [[ -f $f && -z ${seen[${f##*/}]:-} ]] || continue
      seen[${f##*/}]=1
      # Solo la sección principal: las de acciones ([Desktop Action ...]) tienen otros Name=
      entry=$(awk '/^\[/{main=($0=="[Desktop Entry]")} main' "$f")
      if grep -qE '^(NoDisplay|Hidden)=true' <<<"$entry"; then continue; fi
      grep -q '^Type=Application' <<<"$entry" || continue
      if grep -qE '^NotShowIn=.*KDE' <<<"$entry"; then continue; fi
      if grep -q '^OnlyShowIn=' <<<"$entry" && ! grep -qE '^OnlyShowIn=.*KDE' <<<"$entry"; then continue; fi
      name=$(grep -m1 -E '^Name\[es\]=' <<<"$entry" | cut -d= -f2- || true)
      [[ -n $name ]] || name=$(grep -m1 '^Name=' <<<"$entry" | cut -d= -f2- || true)
      if [[ -n $name ]]; then printf 'applications:%s\t%s\n' "${f##*/}" "${name//,/}"; fi
    done
  done | sort -t$'\t' -k2,2f
}

desk_pins() {
  local line launcher name picked_raw js
  local -A by_label=() label_of=()
  _plasma_running || die "Plasma no está en marcha: ejecútalo desde tu sesión gráfica"
  local -a labels=() current=() preselected=() picked=() chosen=() sel=()
  while IFS=$'\t' read -r launcher name; do
    [[ -n ${label_of[$launcher]:-} ]] && continue   # ya está entre las típicas
    [[ -n ${by_label[$name]:-} ]] && name="$name (${launcher#applications:})"
    by_label[$name]=$launcher
    label_of[$launcher]=$name
    labels+=("$name")
  done < <(_typical_apps; _desktop_apps)

  mapfile -t current < <(_current_launchers)
  for launcher in "${current[@]}"; do
    [[ -n ${label_of[$launcher]:-} ]] && preselected+=("${label_of[$launcher]}")
  done
  ((${#preselected[@]})) && sel=(--selected "$(IFS=,; echo "${preselected[*]}")")

  picked_raw=$(gum choose --no-limit --height 25 "${sel[@]}" \
    --header "Apps ancladas: ★ típicas y luego todas las instaladas (x marca, enter guarda, esc cancela)" "${labels[@]}") || return 0
  [[ -n $picked_raw ]] && mapfile -t picked <<<"$picked_raw"

  # Mantiene el orden actual de las que ya estaban; las nuevas van al final
  for launcher in "${current[@]}"; do
    for line in "${picked[@]}"; do [[ ${by_label[$line]} == "$launcher" ]] && chosen+=("$launcher"); done
  done
  for line in "${picked[@]}"; do
    launcher=${by_label[$line]}
    [[ " ${chosen[*]} " == *" $launcher "* ]] || chosen+=("$launcher")
  done

  js=""
  ((${#chosen[@]})) && js=$(printf '"%s",' "${chosen[@]}")
  plasma_js "
    var launchers = [${js%,}];
    panels().forEach(function (p) {
      p.widgets().forEach(function (w) {
        if (w.type != 'org.kde.plasma.icontasks' && w.type != 'org.kde.plasma.taskmanager') return;
        w.currentConfigGroup = ['General'];
        w.writeConfig('launchers', launchers);
        w.reloadConfig();
      });
    });" >/dev/null
  ok "${#chosen[@]} apps ancladas"
}

desk_bar() {
  if _bar_exists; then
    ui_confirm "¿Quitar la barra superior?" || return 0
    _bar_remove
    ok "Barra superior quitada"
  else
    pkg_installed playerctl || step "Instalando playerctl" apt_install playerctl
    _install_plasmoids
    _bar_create
    ok "Barra superior creada"
  fi
}

desk_clock() {
  _plasma_running || die "Plasma no está en marcha: ejecútalo desde tu sesión gráfica"
  if _clock_exists; then
    _clock_remove
    ok "Fecha quitada del escritorio"
  else
    _install_plasmoids
    _clock_create
    ok "Fecha en el escritorio (agrándala o muévela desde el modo de edición de Plasma)"
  fi
}

# Modo oscuro o claro de KDE: se guarda y se aplica con los colores del tema actual
desk_mode() {
  local choice mode
  source "$KUBU_ROOT/lib/theme.sh"
  choice=$(ui_pick "Modo de KDE (ahora: $([[ $(kde_mode) == light ]] && echo claro || echo oscuro))" \
    "Oscuro" "Claro") || return 0
  mode=dark
  [[ $choice == Claro ]] && mode=light
  echo "$mode" >"$KUBU_STATE/kde-mode"
  theme_kde_colors
}

desk_glow() {
  if _glow_on; then _glow off; ok "Brillo de la ventana activa quitado"
  else _glow on; ok "Brillo de la ventana activa restaurado"
  fi
}

desk_restart() {
  plasma_restart
  ok "Plasma reiniciado"
}

mod_status() {
  local deco n
  deco=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library --default org.kde.breeze)
  ui_status "Decoración" "${deco#org.kde.}"
  ui_status "Modo" "$([[ $(cat "$KUBU_STATE/kde-mode" 2>/dev/null) == light ]] && echo claro || echo oscuro)"
  if _glow_on; then ui_status "Brillo ventana activa" "activado" off
  else ui_status "Brillo ventana activa" "quitado" ok
  fi
  if ! _plasma_running; then ui_status "Plasma" "no accesible" err "abre kubu desde tu sesión"; return 0; fi
  if _bar_exists; then ui_status "Barra superior" "puesta" ok "IP · Spotify · CPU/RAM"
  else ui_status "Barra superior" "sin poner" off
  fi
  if _clock_exists; then ui_status "Fecha en el escritorio" "puesta" ok
  else ui_status "Fecha en el escritorio" "sin poner" off
  fi
  n=$(_current_launchers | grep -c . || true)
  ui_status "Apps ancladas" "$n"
  if pkg_installed playerctl; then ui_status "playerctl" "instalado" ok
  else ui_status "playerctl" "falta" warn "el widget de Spotify lo necesita"
  fi
}
