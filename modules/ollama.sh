MOD_NAME="Ollama"
MOD_CATEGORY="IA"
MOD_DESC="Modelos de IA en local"

MOD_MENU=(
  "ol_list|Ver modelos descargados"
  "ol_pull|Descargar un modelo"
  "ol_run|Chatear con un modelo"
  "ol_rm|Borrar un modelo"
  "ol_ps|Ver modelos cargados en memoria"
  "ol_service|Encender o apagar el servicio"
)

mod_is_installed() { has ollama; }
mod_install() {
  in_vm && warn "En una VM normalmente no hay GPU: Ollama irá por CPU y será lento."
  step "Instalando Ollama" bash -c 'curl -fsSL https://ollama.com/install.sh | sh'
}
mod_update()  { mod_install; }
mod_uninstall() {
  step "Eliminando Ollama" bash -c '
    sudo systemctl disable --now ollama 2>/dev/null || true
    sudo rm -f /etc/systemd/system/ollama.service "$(command -v ollama)"
    sudo rm -rf /usr/local/lib/ollama /usr/share/ollama
    sudo userdel ollama 2>/dev/null || true
    sudo groupdel ollama 2>/dev/null || true
    sudo systemctl daemon-reload'
}

_models() { ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'; }
_need_service() { systemctl is-active ollama >/dev/null 2>&1 || die "El servicio de Ollama está parado: enciéndelo primero"; }

mod_status() {
  ui_service "Servicio" ollama.service
  ui_status "Versión" "$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  systemctl is-active ollama >/dev/null 2>&1 || return 0
  ui_status "Modelos" "$(_models | wc -l)"
  ui_status "Espacio" "$(sudo du -sh /usr/share/ollama/.ollama/models 2>/dev/null | cut -f1 || echo '?')"
  if has nvidia-smi; then ui_status "GPU" "$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)" ok
  else ui_status "GPU" "no detectada (irá por CPU)" warn
  fi
}

ol_list() { _need_service; ollama list; }

ol_pull() {
  local model
  _need_service
  model=$(gum choose --height 10 --header "Modelo (o «Otro» para escribirlo; mira ollama.com/library)" \
    "llama3.2:3b" "qwen3:8b" "gemma3:4b" "mistral:7b" "deepseek-r1:8b" "qwen2.5-coder:7b" "Otro") || return 0
  [[ $model == Otro ]] && model=$(ui_input "Nombre del modelo" "" "phi4:14b")
  [[ -n $model ]] || return 0
  ollama pull "$model"
  ok "$model descargado"
}

ol_run() {
  local model
  _need_service
  model=$(ui_pick "¿Con qué modelo?" $(_models)) || return 0
  info "Escribe /bye para volver a kubu."
  ollama run "$model"
}

ol_rm() {
  local model
  _need_service
  model=$(ui_pick "¿Qué modelo borrar?" $(_models)) || return 0
  ui_confirm "¿Borrar $model?" || return 0
  ollama rm "$model"
}

ol_ps() { _need_service; ollama ps; }

ol_service() {
  if systemctl is-active ollama >/dev/null 2>&1; then
    step "Apagando Ollama" sudo systemctl disable --now ollama
  else
    step "Encendiendo Ollama" sudo systemctl enable --now ollama
  fi
}
