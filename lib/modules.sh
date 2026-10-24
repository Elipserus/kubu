# Descubrimiento y ejecución de módulos (compartido por bin/kubu e install.sh).
#
# modules_info imprime una línea por módulo, separada por tabuladores:
#   id nombre categoría descripción install uninstall configure update instalado obligatorio defecto prioridad
# Léela con:  while IFS=$'\t' read -r id name cat desc i u c up inst req def prio; do ...

run_module() { bash "$KUBU_ROOT/lib/runner.sh" "$@"; }

modules_info() {
  local f id
  for f in "$KUBU_ROOT"/modules/*.sh; do
    id=$(basename "$f" .sh)
    [[ $id == _* ]] && continue
    run_module "$id" info
  done | sort -t$'\t' -k3,3 -k2,2
}

# Ordena ids por MOD_PRIORITY (menor primero) para respetar dependencias
sort_by_priority() {
  local -A want=()
  local id
  for id in "$@"; do want[$id]=1; done
  while IFS=$'\t' read -r id _ _ _ _ _ _ _ _ _ _ prio; do
    [[ -n ${want[$id]:-} ]] && printf '%s\t%s\n' "$prio" "$id"
  done < <(modules_info) | sort -n -k1,1 | cut -f2
}

sudo_keepalive() {
  [[ -n ${KUBU_SUDO_ALIVE:-} ]] && return 0
  KUBU_SUDO_ALIVE=1
  # `sudo -v` pide contraseña aunque haya NOPASSWD si otra regla la exige (verifypw)
  sudo -n true 2>/dev/null || sudo -v || die "Se necesitan permisos de sudo"
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
}

verb() {
  case $1 in
    install) echo "Instalando" ;; uninstall) echo "Desinstalando" ;;
    configure) echo "Configurando" ;; update) echo "Actualizando" ;;
  esac
}

# apply <acción> <id>...: ejecuta la acción en cada módulo y resume los fallos
apply() {
  local action=$1 id failed=()
  shift
  sudo_keepalive
  for id in "$@"; do
    ui_title "$(verb "$action") $id"
    run_module "$id" "$action" || failed+=("$id")
  done
  echo
  if ((${#failed[@]})); then
    err "Fallaron: ${failed[*]}"
    info "Log: $KUBU_LOG"
    return 1
  fi
  ok "Listo"
}
