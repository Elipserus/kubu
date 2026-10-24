MOD_NAME="Bases de datos"
MOD_CATEGORY="Desarrollo"
MOD_DESC="PostgreSQL · MySQL · Redis en Docker"
MOD_PRIORITY=60

# contenedor|etiqueta|argumentos de docker run|cliente dentro del contenedor|cadena de conexión
DBS=(
  "postgres|PostgreSQL|-p 127.0.0.1:5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17|psql -U postgres|postgres://postgres@localhost:5432/postgres"
  "mysql|MySQL|-p 127.0.0.1:3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=true mysql:8.4|mysql -uroot|mysql://root@localhost:3306"
  "redis|Redis|-p 127.0.0.1:6379:6379 redis:8|redis-cli|redis://localhost:6379"
)

MOD_MENU=(
  "db_toggle|Arrancar o parar una base de datos"
  "db_console|Abrir la consola de una base de datos"
  "db_urls|Ver cadenas de conexión"
  "db_logs|Ver logs"
  "db_remove|Borrar una base de datos"
)

# docker sin sudo si ya tienes el grupo (tras volver a iniciar sesión); si no, con sudo
_dk() { if docker info >/dev/null 2>&1; then docker "$@"; else _dk "$@"; fi; }
_containers() { _dk ps -a --format '{{.Names}}' 2>/dev/null; }
_state() { _dk inspect -f '{{.State.Status}}' "kubu-$1" 2>/dev/null || echo "no creada"; }

# Al listar las apps no se puede pedir contraseña: sin grupo docker ni sudo en caché,
# vale la marca que deja mod_configure al crear alguna base de datos.
mod_is_installed() {
  has docker || return 1
  local names
  if names=$(docker ps -a --format '{{.Names}}' 2>/dev/null) ||
     names=$(sudo -n docker ps -a --format '{{.Names}}' 2>/dev/null); then
    grep -qxE 'kubu-(postgres|mysql|redis)' <<<"$names"
  else
    [[ -f $KUBU_STATE/databases ]]
  fi
}

mod_install() {
  has docker || die "Necesita Docker: instálalo antes desde Aplicaciones"
  mod_configure
}

mod_status() {
  local d name label state
  for d in "${DBS[@]}"; do
    IFS='|' read -r name label _ <<<"$d"
    state=$(_state "$name")
    case $state in
      running)     ui_status "$label" "en marcha" ok ;;
      "no creada") ui_status "$label" "no creada" off ;;
      *)           ui_status "$label" "$state" warn ;;
    esac
  done
}

mod_configure() {
  local wanted d name label args
  if [[ -n ${KUBU_FIRST_RUN:-} ]]; then
    wanted=${KUBU_DATABASES:-}
  else
    wanted=$(gum choose --no-limit --height 5 --header "Bases de datos a crear (x marca, enter acepta)" \
      PostgreSQL MySQL Redis | paste -sd' ' || true)
  fi
  for d in "${DBS[@]}"; do
    IFS='|' read -r name label args _ <<<"$d"
    [[ " $wanted " == *" $label "* ]] || continue
    if _containers | grep -x "kubu-$name" >/dev/null; then
      info "$label ya existe (kubu-$name)"
    else
      # shellcheck disable=SC2086
      step "$label en Docker" _dk run -d --restart unless-stopped --name "kubu-$name" $args
    fi
  done
  _containers | grep -qxE 'kubu-(postgres|mysql|redis)' && touch "$KUBU_STATE/databases"
  return 0
}

mod_uninstall() {
  local d name
  for d in "${DBS[@]}"; do
    name="kubu-${d%%|*}"
    if _containers | grep -x "$name" >/dev/null; then
      step "Eliminando $name" _dk rm -f "$name"
    fi
  done
  rm -f "$KUBU_STATE/databases"
}

# _pick_db <cabecera> [running]: imprime la línea de DBS elegida (solo las creadas)
_pick_db() {
  local d name label state
  local -A lines=()
  local -a labels=()
  for d in "${DBS[@]}"; do
    IFS='|' read -r name label _ <<<"$d"
    state=$(_state "$name")
    [[ $state == "no creada" ]] && continue
    [[ ${2:-} == running && $state != running ]] && continue
    lines[$label]=$d
    labels+=("$label")
  done
  ((${#labels[@]})) || die "No hay bases de datos${2:+ en marcha}: créalas con Configuración básica"
  label=$(ui_pick "$1" "${labels[@]}")
  echo "${lines[$label]}"
}

db_toggle() {
  local line name label
  line=$(_pick_db "¿Cuál?")
  IFS='|' read -r name label _ <<<"$line"
  if [[ $(_state "$name") == running ]]; then
    step "Parando $label" _dk stop "kubu-$name"
  else
    step "Arrancando $label" _dk start "kubu-$name"
  fi
}

db_console() {
  local line name label client
  line=$(_pick_db "¿Qué consola?" running)
  IFS='|' read -r name label _ client _ <<<"$line"
  info "Sal con \\q, exit o ctrl+d para volver a kubu."
  # shellcheck disable=SC2086
  _dk exec -it "kubu-$name" $client
}

db_urls() {
  local d name label url
  for d in "${DBS[@]}"; do
    IFS='|' read -r name label _ _ url <<<"$d"
    [[ $(_state "$name") == "no creada" ]] && continue
    ui_status "$label" "$url" "$([[ $(_state "$name") == running ]] && echo ok || echo off)"
  done
  info "  Solo accesibles desde este equipo (127.0.0.1) y sin contraseña."
}

db_logs() {
  local line name label
  line=$(_pick_db "¿Logs de cuál?")
  IFS='|' read -r name label _ <<<"$line"
  _dk logs --tail 500 "kubu-$name" 2>&1 | ui_view "Logs de $label (q para salir)"
}

db_remove() {
  local line name label
  line=$(_pick_db "¿Cuál quieres borrar?")
  IFS='|' read -r name label _ <<<"$line"
  ui_confirm "¿Borrar $label y TODOS sus datos?" || return 0
  step "Borrando $label" _dk rm -f "kubu-$name"
}
