# Temas: cada carpeta de themes/ tiene un theme.sh con variables y, opcionalmente,
# ficheros propios (ghostty, btop.theme, zellij.kdl, neovim.lua, wallpaper.*).
# THEME_WALLPAPER puede apuntar a un fondo ya instalado en el sistema.
# Solo se tocan las apps que están instaladas.

VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"

theme_current() { cat "$KUBU_STATE/theme" 2>/dev/null || echo kubu; }

theme_list() {
  local d id current
  current=$(theme_current)
  for d in "$KUBU_ROOT"/themes/*/; do
    id=$(basename "$d")
    ( source "$d/theme.sh"
      [[ $id == "$current" ]] && echo "  ● $(pad "$id" 14) $THEME_NAME" || echo "  ○ $(pad "$id" 14) $THEME_NAME" )
  done
}

theme_apply() {
  local id=$1 dir="$KUBU_ROOT/themes/$1" wp
  [[ -f $dir/theme.sh ]] || die "Tema desconocido: $id (mira: kubu theme)"
  # shellcheck source=/dev/null
  source "$dir/theme.sh"

  if [[ -d $HOME/.config/ghostty ]]; then
    if [[ -f $dir/ghostty ]]; then
      mkdir -p "$HOME/.config/ghostty/themes"
      cp "$dir/ghostty" "$HOME/.config/ghostty/themes/$THEME_GHOSTTY"
    fi
    echo "theme = $THEME_GHOSTTY" >"$HOME/.config/ghostty/kubu-theme"
    ghostty_reload
    ok "Ghostty: $THEME_GHOSTTY"
  fi

  if [[ -f $HOME/.config/btop/btop.conf && -f $dir/btop.theme ]]; then
    mkdir -p "$HOME/.config/btop/themes"
    cp "$dir/btop.theme" "$HOME/.config/btop/themes/$id.theme"
    sed -i "s/^color_theme = .*/color_theme = \"$id\"/" "$HOME/.config/btop/btop.conf"
    ok "btop"
  fi

  if [[ -f $HOME/.config/zellij/config.kdl && -f $dir/zellij.kdl ]]; then
    mkdir -p "$HOME/.config/zellij/themes"
    cp "$dir/zellij.kdl" "$HOME/.config/zellij/themes/$id.kdl"
    sed -i "s/^theme \".*\"/theme \"$id\"/" "$HOME/.config/zellij/config.kdl"
    ok "zellij"
  fi

  if [[ -d $HOME/.config/nvim/lua/plugins && -f $dir/neovim.lua ]]; then
    cp "$dir/neovim.lua" "$HOME/.config/nvim/lua/plugins/theme.lua"
    ok "Neovim"
  fi

  if has code && [[ -f $VSCODE_SETTINGS ]]; then
    step "VS Code: $THEME_VSCODE_NAME" code --install-extension "$THEME_VSCODE_EXT" || true
    sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$THEME_VSCODE_NAME\"/" "$VSCODE_SETTINGS"
  fi

  # Las herramientas plasma-apply-* solo hablan con Plasma por D-Bus, pero crean una
  # QGuiApplication: si no pueden conectar con la pantalla (SSH, zellij/tmux con un
  # WAYLAND_DISPLAY heredado...) abortan y Ubuntu muestra "error interno". Con la
  # plataforma offscreen nunca abren ventana y los cambios se aplican igual.
  theme_kde_colors

  theme_panels
  theme_launcher

  # THEME_WALLPAPER (ruta del sistema) o, si no existe, el wallpaper.* del tema
  wp=${THEME_WALLPAPER:-}
  [[ -n $wp && -f $wp ]] || wp=$(compgen -G "$dir/wallpaper.*" | head -1 || true)
  if [[ -n $wp ]] && has plasma-apply-wallpaperimage; then
    mkdir -p "$HOME/.local/share/wallpapers/kubu"
    cp "$wp" "$HOME/.local/share/wallpapers/kubu/$id.${wp##*.}"
    QT_QPA_PLATFORM=offscreen plasma-apply-wallpaperimage "$HOME/.local/share/wallpapers/kubu/$id.${wp##*.}" >>"$KUBU_LOG" 2>&1 &&
      ok "Fondo de escritorio" || warn "No se pudo cambiar el fondo (¿sesión gráfica abierta?)"
    lockscreen_wallpaper "$HOME/.local/share/wallpapers/kubu/$id.${wp##*.}"
  fi

  echo "$id" >"$KUBU_STATE/theme"
  ok "Tema $THEME_NAME aplicado"
}

# Mismo fondo en la pantalla de bloqueo que en el escritorio
lockscreen_wallpaper() {
  has kwriteconfig6 || return 0
  kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image \
    --group General --key Image "file://$1"
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image \
    --group General --key PreviewImage "file://$1"
  ok "Fondo de la pantalla de bloqueo"
}

# Modo de KDE que elige el usuario en Escritorio: dark (por defecto) o light
kde_mode() { cat "$KUBU_STATE/kde-mode" 2>/dev/null || echo dark; }

# Esquema de colores de KDE del tema (cargado o, si no, el actual) en el modo
# elegido, más su color de acento. THEME_KDE_SCHEME es el oscuro;
# THEME_KDE_SCHEME_LIGHT el claro (BreezeLight si el tema no lo define).
# Van en dos llamadas: con --accent-color y el esquema a la vez, Plasma 6.6 solo
# aplica el acento.
theme_kde_colors() {
  local scheme
  has plasma-apply-colorscheme || return 0
  [[ -n ${THEME_NAME:-} ]] || source "$KUBU_ROOT/themes/$(theme_current)/theme.sh"
  scheme=$THEME_KDE_SCHEME
  [[ $(kde_mode) == light ]] && scheme=${THEME_KDE_SCHEME_LIGHT:-BreezeLight}
  QT_QPA_PLATFORM=offscreen plasma-apply-colorscheme "$scheme" >>"$KUBU_LOG" 2>&1 &&
    QT_QPA_PLATFORM=offscreen plasma-apply-colorscheme --accent-color "$THEME_KDE_ACCENT" >>"$KUBU_LOG" 2>&1 &&
    ok "KDE: $scheme con acento $THEME_KDE_ACCENT" ||
    warn "KDE: no se pudieron aplicar los colores (¿sesión gráfica abierta?)"
}

# Colores del lanzador (fuzzel, Alt+Espacio) del tema cargado o, si no, el actual.
# Marco, prompt y coincidencias con el acento; fondo, texto y selección con
# THEME_LAUNCHER_BG / _FG / _SELECTION (RRGGBBAA) o unos oscuros por defecto.
# Solo si el módulo Escritorio instaló el lanzador.
theme_launcher() {
  local dir=$HOME/.config/fuzzel accent
  [[ -f $dir/fuzzel.ini ]] || return 0
  [[ -n ${THEME_NAME:-} ]] || source "$KUBU_ROOT/themes/$(theme_current)/theme.sh"
  accent=${THEME_KDE_ACCENT#\#}
  printf '%s\n' "[colors]" \
    "background=${THEME_LAUNCHER_BG:-1a1b26f7}" \
    "text=${THEME_LAUNCHER_FG:-c0caf5ff}" \
    "prompt=${accent}ff" \
    "placeholder=565f89ff" \
    "input=e0e6ffff" \
    "match=${accent}ff" \
    "selection=${THEME_LAUNCHER_SELECTION:-${accent}55}" \
    "selection-text=ffffffff" \
    "selection-match=${accent}ff" \
    "border=${accent}ff" >"$dir/kubu-colors.ini"
  ok "Lanzador de apps"
}

# Ajustes de las barras de Plasma del tema (cargado o, si no, el actual):
#   THEME_KDE_PANEL_OPACITY  adaptive · opaque · translucent (todas las barras)
#   THEME_KDE_ICON_SPACING   separación en la barra de tareas: 0 pequeña, 1 normal, 3 grande
# Lo que el tema no define no se toca. También lo usa desktop.sh al crear la barra superior.
theme_panels() {
  [[ -n ${THEME_NAME:-} ]] || source "$KUBU_ROOT/themes/$(theme_current)/theme.sh"
  [[ -n ${THEME_KDE_PANEL_OPACITY:-}${THEME_KDE_ICON_SPACING:-} ]] || return 0
  _plasma_running || return 0

  if [[ -n ${THEME_KDE_ICON_SPACING:-} ]]; then
    plasma_js "
      panels().forEach(function (p) {
        p.widgets().forEach(function (w) {
          if (w.type != 'org.kde.plasma.icontasks' && w.type != 'org.kde.plasma.taskmanager') return;
          w.currentConfigGroup = ['General'];
          w.writeConfig('iconSpacing', $THEME_KDE_ICON_SPACING);
          w.reloadConfig();
        });
      });" >>"$KUBU_LOG" 2>&1 &&
      ok "Barra de tareas: separación entre iconos" ||
      warn "No se pudo cambiar la separación de la barra de tareas"
  fi

  # La API de scripting no cambia la opacidad (Plasma 6.6): se guarda en
  # plasmashellrc, que Plasma solo lee al arrancar, y se reinicia si hace falta.
  if [[ -n ${THEME_KDE_PANEL_OPACITY:-} ]]; then
    local -A level=([adaptive]=0 [opaque]=1 [translucent]=2)
    local want=${level[$THEME_KDE_PANEL_OPACITY]:-} id changed=0
    [[ -n $want ]] || { warn "THEME_KDE_PANEL_OPACITY desconocida: $THEME_KDE_PANEL_OPACITY"; return 0; }
    for id in $(plasma_js 'panels().forEach(p => print(p.id + " "))'); do
      [[ $(kreadconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" \
        --key panelOpacity --default 0) == "$want" ]] && continue
      kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key panelOpacity "$want"
      changed=1
    done
    ((changed)) && plasma_restart
    ok "Barras de Plasma: $THEME_KDE_PANEL_OPACITY"
  fi
}

menu_theme() {
  local d id current choice
  local -A ids=()
  local -a labels=()
  current=$(theme_current)
  for d in "$KUBU_ROOT"/themes/*/; do
    id=$(basename "$d")
    label=$(source "$d/theme.sh"; echo "$THEME_NAME")
    [[ $id == "$current" ]] && label="$label  (actual)"
    ids[$label]=$id
    labels+=("$label")
  done
  ui_header
  choice=$(ui_choose "Elige tu tema" "${labels[@]}" "<< Volver") || return 0
  [[ $choice == "<< Volver" ]] && return 0
  theme_apply "${ids[$choice]}"
  ui_pause
}
