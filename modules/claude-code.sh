MOD_NAME="Claude Code"
MOD_CATEGORY="IA"
MOD_DESC="Agente de programación de Anthropic"
MOD_DEFAULT=1

mod_is_installed() { [[ -x $HOME/.local/bin/claude ]]; }
mod_install()   { step "Instalando Claude Code" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; }
mod_uninstall() { step "Eliminando Claude Code" rm -rf "$HOME/.local/bin/claude" "$HOME/.local/share/claude"; }
