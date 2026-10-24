MOD_NAME="SSH server"
MOD_CATEGORY="Sistema"
MOD_DESC="OpenSSH endurecido y gestión de claves"

# 10- para que gane a otros drop-ins (en sshd gana el primer valor leído)
CONF=/etc/ssh/sshd_config.d/10-kubu.conf
SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

MOD_MENU=(
  "ssh_keygen|Generar una clave SSH"
  "ssh_keys|Ver mis claves"
  "ssh_show_pub|Mostrar y copiar una clave pública"
  "ssh_copy_id|Copiar una clave a otro equipo (ssh-copy-id)"
  "ssh_add_host|Guardar un equipo en ~/.ssh/config"
  "ssh_test|Probar la conexión con un equipo"
  "ssh_auth_add|Autorizar una clave para entrar aquí"
  "ssh_auth_remove|Quitar una clave autorizada"
  "ssh_sessions|Ver quién está conectado"
  "ssh_logs|Ver accesos recientes"
  "ssh_toggle|Encender o apagar el servidor"
  "ssh_restart|Reiniciar el servidor"
)

mod_is_installed() { pkg_installed openssh-server; }

mod_install() {
  step "Instalando openssh-server" apt_install openssh-server
  mod_configure
}

_port() { sudo awk '/^Port /{print $2}' "$CONF" 2>/dev/null || true; }

mod_status() {
  local port pw n=0 sessions
  ui_service "Servidor (socket)" ssh.socket
  ui_service "Servidor (servicio)" ssh.service
  port=$(_port)
  ui_status "Puerto" "${port:-22}"
  pw=$(sudo awk '/^PasswordAuthentication /{print $2}' "$CONF" 2>/dev/null || true)
  if [[ $pw == yes ]]; then ui_status "Login con contraseña" "permitido" warn
  elif [[ $pw == no ]]; then ui_status "Login con contraseña" "desactivado" ok "solo con clave"
  else ui_status "Login con contraseña" "por defecto del sistema" warn "usa Configuración básica"
  fi
  [[ -f $AUTH_KEYS ]] && n=$(grep -cE '^(ssh-|ecdsa-|sk-)' "$AUTH_KEYS" || true)
  if ((n)); then ui_status "Claves autorizadas" "$n" ok; else ui_status "Claves autorizadas" "ninguna" warn; fi
  n=$(_my_keys | wc -l)
  if ((n)); then ui_status "Mis claves" "$n" ok; else ui_status "Mis claves" "ninguna" off "genera una abajo"; fi
  sessions=$(who | grep -c '(' || true)
  ui_status "Sesiones remotas" "$sessions" "$( ((sessions)) && echo warn || echo off)" "$( ((sessions)) && echo "hay alguien conectado")"
  ui_status "IP local" "$(hostname -I 2>/dev/null | awk '{print $1}')"
}

mod_configure() {
  local current port password=no
  current=$(_port)
  port=$(ui_input "Puerto SSH" "${current:-22}")
  [[ $port =~ ^[0-9]+$ ]] && (( port > 0 && port < 65536 )) || die "Puerto no válido: $port"

  if [[ ! -s $AUTH_KEYS ]]; then
    warn "No hay claves en ~/.ssh/authorized_keys: si desactivas la contraseña no podrás entrar."
  fi
  ui_confirm "¿Permitir login con contraseña?" && password=yes

  sudo tee "$CONF" >/dev/null <<EOF
# Gestionado por kubu
Port $port
PermitRootLogin no
PasswordAuthentication $password
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
EOF
  ok "Escrito $CONF"

  if ! sudo sshd -t; then
    sudo rm -f "$CONF"
    die "Configuración inválida, revertida"
  fi

  # Ubuntu usa ssh.socket: el puerto se lee de sshd_config vía generador de systemd
  step "Recargando systemd"     sudo systemctl daemon-reload
  step "Activando ssh.socket"   sudo systemctl enable ssh.socket
  step "Reiniciando SSH"        bash -c 'sudo systemctl restart ssh.socket && sudo systemctl try-restart ssh.service'

  if has ufw && sudo ufw status | grep "Status: active" >/dev/null; then
    step "Abriendo puerto $port en ufw" sudo ufw allow "$port/tcp"
  fi
  ok "SSH escuchando en el puerto $port"
}

mod_uninstall() {
  step "Quitando configuración" sudo rm -f "$CONF"
  step "Eliminando openssh-server" apt_purge openssh-server
}

# --- Claves propias -------------------------------------------------------------

_my_keys() { compgen -G "$SSH_DIR/*.pub" || true; }

# _pick_key <cabecera>: elige una clave pública propia y la imprime
_pick_key() {
  local -a keys=()
  mapfile -t keys < <(_my_keys)
  ((${#keys[@]})) || die "No tienes claves: genera una primero"
  if ((${#keys[@]} == 1)); then echo "${keys[0]}"; return 0; fi
  ui_pick "$1" "${keys[@]}"
}

ssh_keygen() {
  local name comment file
  mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
  name=$(ui_input "Nombre del fichero de la clave" "id_ed25519")
  [[ -n $name && $name != */* ]] || die "Nombre no válido"
  file="$SSH_DIR/$name"
  if [[ -e $file ]]; then
    ui_confirm "$file ya existe. ¿Sobrescribirla? (perderás la clave actual)" || return 0
    rm -f "$file" "$file.pub"
  fi
  comment=$(ui_input "Comentario" "$(git config --global user.email 2>/dev/null || echo "$USER@$(hostname)")")
  info "Se te pedirá una frase de paso (enter dos veces para dejarla vacía)."
  ssh-keygen -t ed25519 -a 100 -C "$comment" -f "$file"
  ok "Clave creada: $file.pub"
  if has gh && gh auth status >/dev/null 2>&1 && ui_confirm "¿Subirla también a tu cuenta de GitHub?"; then
    gh ssh-key add "$file.pub" --title "$(hostname)" && ok "Clave añadida a GitHub"
  fi
}

ssh_keys() {
  local k
  if [[ -z $(_my_keys) ]]; then info "No tienes claves en $SSH_DIR"; return 0; fi
  for k in $(_my_keys); do
    echo "  $(gum style --foreground $KUBU_BLUE "$(basename "$k" .pub)")"
    ssh-keygen -lf "$k" | awk '{printf "    %s %s  %s\n", $1, $NF, $2}'
  done
}

ssh_show_pub() {
  local key
  key=$(_pick_key "¿Qué clave?")
  echo
  cat "$key"
  echo
  if clip_copy <"$key"; then ok "Copiada al portapapeles"; fi
}

# Lee usuario@host y puerto; los imprime separados por espacio
_ask_target() {
  local target port
  target=$(ui_input "Equipo destino (usuario@ip o alias de ~/.ssh/config)" "" "$USER@192.168.1.10")
  [[ -n $target ]] || die "Destino vacío"
  port=$(ui_input "Puerto" "22")
  [[ $port =~ ^[0-9]+$ ]] || die "Puerto no válido: $port"
  echo "$target $port"
}

ssh_copy_id() {
  local key dest target port
  key=$(_pick_key "¿Qué clave quieres copiar?")
  dest=$(_ask_target); read -r target port <<<"$dest"
  info "Se pedirá la contraseña de $target una última vez."
  ssh-copy-id -i "$key" -p "$port" "$target"
  ok "Ya puedes entrar con: ssh -p $port $target"
}

ssh_add_host() {
  local alias host user port key="" cfg="$SSH_DIR/config"
  alias=$(ui_input "Alias (el nombre corto que usarás: ssh <alias>)" "" "servidor")
  [[ $alias =~ ^[A-Za-z0-9._-]+$ ]] || die "Alias no válido"
  if [[ -f $cfg ]] && grep -qE "^Host[[:space:]]+$alias\$" "$cfg"; then die "Ya existe el alias $alias en $cfg"; fi
  host=$(ui_input "IP o dominio" "" "192.168.1.10")
  user=$(ui_input "Usuario" "$USER")
  port=$(ui_input "Puerto" "22")
  [[ -n $(_my_keys) ]] && key=$(_pick_key "Clave para este equipo")
  mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
  {
    if [[ -s $cfg ]]; then echo; fi
    echo "Host $alias"
    echo "  HostName $host"
    echo "  User $user"
    if [[ $port != 22 ]]; then echo "  Port $port"; fi
    if [[ -n $key ]]; then echo "  IdentityFile ${key%.pub}"; echo "  IdentitiesOnly yes"; fi
  } >>"$cfg"
  chmod 600 "$cfg"
  ok "Guardado: ahora puedes usar  ssh $alias"
}

ssh_test() {
  local dest target port
  dest=$(_ask_target); read -r target port <<<"$dest"
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$target" true 2>/dev/null; then
    ok "Conexión correcta con clave a $target"
  elif ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$target" true 2>&1 | grep -q "Permission denied"; then
    warn "$target responde pero no acepta tu clave: usa «Copiar una clave a otro equipo»"
  else
    err "No se puede conectar con $target:$port"
    return 1
  fi
}

# --- Claves autorizadas (quién puede entrar aquí) --------------------------------

ssh_auth_add() {
  local key
  info "Pega la clave pública (empieza por ssh-ed25519, ssh-rsa...)"
  key=$(gum input --width 0 --prompt "› " --placeholder "")
  [[ -n $key ]] || return 0
  ssh-keygen -lf /dev/stdin <<<"$key" >/dev/null 2>&1 || die "Eso no parece una clave pública válida"
  mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
  touch "$AUTH_KEYS" && chmod 600 "$AUTH_KEYS"
  if grep -qxF "$key" "$AUTH_KEYS"; then info "Esa clave ya estaba autorizada"; return 0; fi
  echo "$key" >>"$AUTH_KEYS"
  ok "Clave autorizada: $(ssh-keygen -lf /dev/stdin <<<"$key" | awk '{print $NF, $2}')"
}

ssh_auth_remove() {
  local -a lines=() labels=()
  local l choice i
  [[ -s $AUTH_KEYS ]] || { info "No hay claves autorizadas"; return 0; }
  mapfile -t lines < <(grep -E '^(ssh-|ecdsa-|sk-)' "$AUTH_KEYS")
  for l in "${lines[@]}"; do
    labels+=("$(ssh-keygen -lf /dev/stdin <<<"$l" | awk '{print $NF, $2}') $(awk '{print $3}' <<<"$l")")
  done
  choice=$(ui_pick "¿Qué clave quieres quitar?" "${labels[@]}") || return 0
  for i in "${!labels[@]}"; do
    [[ ${labels[i]} == "$choice" ]] || continue
    ui_confirm "¿Quitar $choice? Quien la use no podrá entrar." || return 0
    cp "$AUTH_KEYS" "$AUTH_KEYS.kubu-prev"
    grep -vxF "${lines[i]}" "$AUTH_KEYS.kubu-prev" >"$AUTH_KEYS" || true
    ok "Quitada (copia anterior en $AUTH_KEYS.kubu-prev)"
  done
}

# --- Servicio ---------------------------------------------------------------------

ssh_sessions() {
  local port
  port=$(_port); port=${port:-22}
  ui_title "Usuarios conectados"
  who | grep '(' || info "  Nadie conectado por SSH"
  ui_title "Conexiones TCP al puerto $port"
  ss -tn state established "( sport = :$port )" | tail -n +2 | awk '{print "  " $NF}' | grep . ||
    info "  Ninguna"
}

ssh_logs() {
  sudo journalctl -u ssh.service -u ssh.socket -n 300 --no-pager -o short-iso |
    grep -E "Accepted|Failed|Invalid user|Disconnected|session opened" |
    ui_view "Accesos SSH recientes (q para salir)"
}

ssh_toggle() {
  if systemctl is-active ssh.socket >/dev/null 2>&1 || systemctl is-active ssh.service >/dev/null 2>&1; then
    ui_confirm "El servidor está encendido. ¿Apagarlo? (no se podrá entrar por SSH)" || return 0
    step "Apagando SSH" sudo systemctl disable --now ssh.socket ssh.service
  else
    step "Encendiendo SSH" sudo systemctl enable --now ssh.socket
  fi
}

ssh_restart() {
  step "Comprobando configuración" sudo sshd -t
  step "Reiniciando SSH" bash -c 'sudo systemctl restart ssh.socket && sudo systemctl try-restart ssh.service'
}
