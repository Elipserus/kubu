MOD_NAME="Docker"
MOD_CATEGORY="Desarrollo"
MOD_DESC="Docker Engine + compose + buildx"
MOD_DEFAULT=1
MOD_PRIORITY=50
MOD_APT=(docker.io docker-compose-v2 docker-buildx)

MOD_MENU=(
  "dk_containers|Ver contenedores"
  "dk_container_action|Arrancar · parar · reiniciar un contenedor"
  "dk_logs|Ver logs de un contenedor"
  "dk_shell|Abrir una shell dentro de un contenedor"
  "dk_disk|Espacio usado"
  "dk_prune|Limpiar lo que no se usa"
  "dk_service|Encender o apagar Docker"
)

mod_install() {
  kind_apt_install
  mod_configure
}

mod_configure() {
  # Logs limitados para que no llenen el disco (como omakub)
  echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"}}' |
    sudo tee /etc/docker/daemon.json >/dev/null
  ok "Logs de contenedores limitados a 5 × 10 MB"
  step "Reiniciando docker" sudo systemctl restart docker
  if id -nG "$USER" | grep -qw docker; then
    ok "$USER ya está en el grupo docker"
  else
    step "Añadiendo $USER al grupo docker" sudo usermod -aG docker "$USER"
    warn "Cierra sesión y vuelve a entrar para usar docker sin sudo."
  fi
}

mod_uninstall() {
  kind_apt_uninstall
  sudo rm -f /etc/docker/daemon.json
}

# docker sin sudo si el usuario ya tiene permisos; si no, con sudo
dk() { if docker info >/dev/null 2>&1; then docker "$@"; else sudo docker "$@"; fi; }

mod_status() {
  local running total images
  ui_service "Docker" docker.service
  if ! systemctl is-active docker >/dev/null 2>&1; then return 0; fi
  ui_status "Versión" "$(dk version --format '{{.Server.Version}}' 2>/dev/null)"
  running=$(dk ps -q | wc -l); total=$(dk ps -aq | wc -l); images=$(dk images -q | sort -u | wc -l)
  ui_status "Contenedores" "$running en marcha de $total" "$( ((running)) && echo ok || echo off)"
  ui_status "Imágenes" "$images"
  if id -nG "$USER" | grep -qw docker; then
    docker info >/dev/null 2>&1 && ui_status "Sin sudo" "sí" ok || ui_status "Sin sudo" "tras cerrar sesión" warn
  else
    ui_status "Sin sudo" "no (usa Configuración básica)" warn
  fi
}

# _pick_container <cabecera> [all]: imprime el nombre del contenedor elegido
_pick_container() {
  local -a names=()
  if [[ ${2:-} == all ]]; then mapfile -t names < <(dk ps -a --format '{{.Names}}')
  else mapfile -t names < <(dk ps --format '{{.Names}}')
  fi
  ((${#names[@]})) || die "No hay contenedores$([[ ${2:-} == all ]] || echo " en marcha")"
  ui_pick "$1" "${names[@]}"
}

dk_containers() {
  dk ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' |
    ui_view "Contenedores (q para salir)"
}

dk_container_action() {
  local c state action
  c=$(_pick_container "¿Qué contenedor?" all)
  state=$(dk inspect -f '{{.State.Status}}' "$c")
  if [[ $state == running ]]; then
    action=$(ui_pick "$c está en marcha" "Parar" "Reiniciar" "Borrar") || return 0
  else
    action=$(ui_pick "$c está $state" "Arrancar" "Borrar") || return 0
  fi
  case $action in
    Arrancar)  step "Arrancando $c" dk start "$c" ;;
    Parar)     step "Parando $c" dk stop "$c" ;;
    Reiniciar) step "Reiniciando $c" dk restart "$c" ;;
    Borrar)    ui_confirm "¿Borrar $c? Se pierden los datos que no estén en volúmenes." || return 0
               step "Borrando $c" dk rm -f "$c" ;;
  esac
}

dk_logs() {
  local c
  c=$(_pick_container "¿Logs de qué contenedor?" all)
  dk logs --tail 500 "$c" 2>&1 | ui_view "Logs de $c (q para salir)"
}

dk_shell() {
  local c
  c=$(_pick_container "¿En qué contenedor?")
  info "Escribe exit para volver a kubu."
  dk exec -it "$c" bash 2>/dev/null || dk exec -it "$c" sh
}

dk_disk() { dk system df; }

dk_prune() {
  dk system df
  echo
  ui_confirm "¿Borrar contenedores parados, imágenes sin usar, redes y caché de build? (los volúmenes se conservan)" ||
    return 0
  step "Limpiando" dk system prune -af
  dk system df
}

dk_service() {
  if systemctl is-active docker >/dev/null 2>&1; then
    ui_confirm "Docker está encendido. ¿Apagarlo? (se paran todos los contenedores)" || return 0
    step "Apagando Docker" sudo systemctl stop docker.service docker.socket
  else
    step "Encendiendo Docker" sudo systemctl start docker.socket docker.service
  fi
}
