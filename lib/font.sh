# Fuentes de programación (Nerd Fonts): se aplican a Ghostty, Konsole, VS Code y
# la fuente monoespaciada de KDE.

# "Nombre en el menú|Familia instalada|Zip de nerd-fonts"
KUBU_FONTS=(
  "Ubuntu Mono|UbuntuMono Nerd Font|UbuntuMono"
  "JetBrains Mono|JetBrainsMono Nerd Font|JetBrainsMono"
  "Cascadia Mono|CaskaydiaMono Nerd Font|CascadiaMono"
  "Fira Mono|FiraMono Nerd Font|FiraMono"
  "Meslo|MesloLGS Nerd Font|Meslo"
)
GHOSTTY_FONT="$HOME/.config/ghostty/kubu-font"
KONSOLE_PROFILE="$HOME/.local/share/konsole/kubu.profile"
FONT_SIZE=16   # tamaño por defecto en Ghostty y Konsole
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"

_font_field() {  # _font_field <nombre> <n>
  local f
  for f in "${KUBU_FONTS[@]}"; do
    [[ ${f%%|*} == "$1" ]] && { cut -d'|' -f"$2" <<<"$f"; return 0; }
  done
  return 1
}

font_list() { local f; for f in "${KUBU_FONTS[@]}"; do echo "  ${f%%|*}"; done; }

font_size() { awk -F' *= *' '/^font-size/{print $2}' "$GHOSTTY_FONT" 2>/dev/null || true; }

# Descarga e instala una Nerd Font si no está ya
font_install() {
  local family=$1 zip=$2 tmp
  fc-list | grep -i "$family" >/dev/null && return 0
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$zip.zip"
  unzip -q "$tmp/font.zip" -d "$tmp/font"
  mkdir -p "$HOME/.local/share/fonts/kubu"
  find "$tmp/font" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} "$HOME/.local/share/fonts/kubu/" \;
  rm -rf "$tmp"
  fc-cache -f >/dev/null
}

_font_write_ghostty() {  # _font_write_ghostty <familia> <tamaño>
  [[ -d $HOME/.config/ghostty ]] || return 0
  printf 'font-family = "%s"\nfont-size = %s\n' "$1" "$2" >"$GHOSTTY_FONT"
  ghostty_reload
}

# Perfil "kubu" de Konsole, predeterminado; conserva el tamaño si ya existía
_font_write_konsole() {  # _font_write_konsole <familia>
  local size
  has kwriteconfig6 || return 0
  size=$(kreadconfig6 --file "$KONSOLE_PROFILE" --group Appearance --key Font 2>/dev/null | cut -d, -f2)
  mkdir -p "$(dirname "$KONSOLE_PROFILE")"
  kwriteconfig6 --file "$KONSOLE_PROFILE" --group General --key Name kubu
  kwriteconfig6 --file "$KONSOLE_PROFILE" --group General --key Parent FALLBACK/
  kwriteconfig6 --file "$KONSOLE_PROFILE" --group Appearance --key Font \
    "$1,${size:-$FONT_SIZE},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  kde_set konsolerc "Desktop Entry" DefaultProfile kubu.profile
}

font_apply() {
  local name=$1 family zip size
  family=$(_font_field "$name" 2) || die "Fuente desconocida: $name (mira: kubu font)"
  zip=$(_font_field "$name" 3)
  size=$(font_size); size=${size:-$FONT_SIZE}

  step "Instalando $family" font_install "$family" "$zip"
  _font_write_ghostty "$family" "$size"
  _font_write_konsole "$family"
  if [[ -f $VSCODE_SETTINGS ]]; then
    sed -i "s/\"editor.fontFamily\": \".*\"/\"editor.fontFamily\": \"$family\"/" "$VSCODE_SETTINGS"
  fi
  kde_set kdeglobals General fixed "$family,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" || true
  echo "$name" >"$KUBU_STATE/font"
  ok "Fuente $name aplicada"
}

font_set_size() {
  local family
  family=$(awk -F' *= *' '/^font-family/{gsub(/"/,"",$2); print $2}' "$GHOSTTY_FONT" 2>/dev/null)
  _font_write_ghostty "${family:-UbuntuMono Nerd Font}" "$1"
  ok "Tamaño de fuente $1 en Ghostty"
}

menu_font() {
  local choice size current
  local -a names=()
  current=$(cat "$KUBU_STATE/font" 2>/dev/null || true)
  for f in "${KUBU_FONTS[@]}"; do names+=("${f%%|*}"); done
  ui_header
  choice=$(ui_choose "Fuente de programación${current:+ (actual: $current)}" \
    "${names[@]}" "> Cambiar tamaño" "<< Volver") || return 0
  case $choice in
    "<< Volver") return 0 ;;
    "> Cambiar tamaño")
      size=$(ui_choose "Tamaño de fuente en Ghostty (actual: $(font_size))" {8..16}) || return 0
      font_set_size "$size" ;;
    *) font_apply "$choice" ;;
  esac
  ui_pause
}
