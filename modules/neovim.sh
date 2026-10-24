MOD_NAME="Neovim"
MOD_CATEGORY="Terminal"
MOD_DESC="Editor de terminal con LazyVim"
MOD_DEFAULT=1
MOD_PRIORITY=30

NVIM_DIRS=("$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim")

mod_is_installed() { pkg_installed neovim; }

mod_install() {
  step "Instalando neovim luarocks" apt_install neovim luarocks
  if apt-cache show tree-sitter-cli >/dev/null 2>&1; then
    step "Instalando tree-sitter-cli" apt_install tree-sitter-cli
  fi
  mod_configure
}

# Solo crea la configuración si nunca se ha usado Neovim (como omakub)
mod_configure() {
  local cfg="$HOME/.config/nvim" theme
  if [[ -d $cfg ]]; then
    info "Ya existe $cfg: no se toca"
    return 0
  fi
  theme=$(cat "$KUBU_STATE/theme" 2>/dev/null || echo kubu)
  step "Descargando LazyVim" git clone -q --depth 1 https://github.com/LazyVim/starter "$cfg"
  rm -rf "$cfg/.git"
  mkdir -p "$cfg/plugin/after"
  cp "$KUBU_ROOT/configs/neovim/transparency.lua" "$cfg/plugin/after/"
  cp "$KUBU_ROOT/configs/neovim/snacks-animated-scrolling-off.lua" "$cfg/lua/plugins/"
  cp "$KUBU_ROOT/configs/neovim/lazyvim.json" "$cfg/"
  cp "$KUBU_ROOT/themes/$theme/neovim.lua" "$cfg/lua/plugins/theme.lua"
  echo "vim.opt.relativenumber = false" >>"$cfg/lua/config/options.lua"
  ok "LazyVim listo: los plugins se descargan al abrir nvim la primera vez"
}

mod_uninstall() {
  local cfg="$HOME/.config/nvim"
  if [[ -d $cfg ]]; then
    mv "$cfg" "$cfg.kubu-bak-$(date +%Y%m%d%H%M%S)"
    info "Configuración movida a $cfg.kubu-bak-*"
  fi
  rm -rf "${NVIM_DIRS[@]}"
  step "Eliminando neovim" apt_purge neovim luarocks
}
