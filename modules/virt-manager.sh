MOD_NAME="Virt Manager"
MOD_CATEGORY="Sistema"
MOD_DESC="KVM/QEMU + libvirt + virt-manager"

PACKAGES=(virt-manager libvirt-daemon-system qemu-system-x86 qemu-utils ovmf swtpm)
GROUPS_=(libvirt kvm)

MOD_MENU=(
  "vm_list|Ver máquinas virtuales"
  "vm_action|Arrancar · apagar · forzar apagado de una VM"
  "vm_open|Abrir virt-manager"
  "vm_service|Encender o apagar libvirtd"
)

mod_is_installed() { pkg_installed virt-manager; }

mod_install() {
  if ! grep -Eq 'vmx|svm' /proc/cpuinfo; then
    if in_vm; then
      warn "Estás en una VM sin virtualización anidada: actívala en el anfitrión o las VMs irán muy lentas."
    else
      warn "La CPU no expone VT-x/AMD-V: actívalo en la BIOS/UEFI o las VMs irán muy lentas."
    fi
  fi
  step "Instalando ${PACKAGES[*]}" apt_install "${PACKAGES[@]}"
  mod_configure
}

mod_configure() {
  local g
  step "Habilitando libvirtd" sudo systemctl enable --now libvirtd
  for g in "${GROUPS_[@]}"; do
    step "Añadiendo $USER al grupo $g" sudo usermod -aG "$g" "$USER"
  done
  step "Arrancando la red 'default'" bash -c \
    'sudo virsh -c qemu:///system net-autostart default &&
     { sudo virsh -c qemu:///system net-start default 2>/dev/null || true; }'
  warn "Cierra sesión y vuelve a entrar para que los grupos tengan efecto."
}

mod_uninstall() {
  step "Eliminando paquetes" apt_purge "${PACKAGES[@]}"
}

vsh() { sudo virsh -c qemu:///system "$@"; }

mod_status() {
  local running total
  ui_service "libvirtd" libvirtd.service
  if grep -Eq 'vmx|svm' /proc/cpuinfo; then ui_status "Virtualización CPU" "activada" ok
  elif in_vm; then ui_status "Virtualización CPU" "sin virtualización anidada en el anfitrión" err
  else ui_status "Virtualización CPU" "desactivada en la BIOS/UEFI" err
  fi
  if id -nG "$USER" | grep -qw libvirt; then ui_status "Grupo libvirt" "sí" ok
  else ui_status "Grupo libvirt" "no (usa Configuración básica)" warn
  fi
  systemctl is-active libvirtd >/dev/null 2>&1 || return 0
  running=$(vsh list --name | grep -c . || true)
  total=$(vsh list --all --name | grep -c . || true)
  ui_status "Máquinas" "$running en marcha de $total" "$( ((running)) && echo ok || echo off)"
  if vsh net-info default 2>/dev/null | grep -qE '^Active:\s+yes'; then ui_status "Red default" "activa" ok
  else ui_status "Red default" "inactiva" warn
  fi
}

vm_list() { vsh list --all; }

vm_action() {
  local -a vms=()
  local vm state action
  mapfile -t vms < <(vsh list --all --name | grep .)
  vm=$(ui_pick "¿Qué máquina?" "${vms[@]}") || return 0
  state=$(vsh domstate "$vm")
  if [[ $state == running ]]; then
    action=$(ui_pick "$vm está encendida" "Apagar" "Reiniciar" "Forzar apagado") || return 0
  else
    action=$(ui_pick "$vm está $state" "Arrancar") || return 0
  fi
  case $action in
    Arrancar)         step "Arrancando $vm" vsh start "$vm" ;;
    Apagar)           step "Apagando $vm" vsh shutdown "$vm" ;;
    Reiniciar)        step "Reiniciando $vm" vsh reboot "$vm" ;;
    "Forzar apagado") ui_confirm "¿Forzar el apagado de $vm? Es como quitarle el enchufe." || return 0
                      step "Forzando apagado de $vm" vsh destroy "$vm" ;;
  esac
}

vm_open() { (setsid virt-manager >/dev/null 2>&1 &); ok "virt-manager abierto"; }

vm_service() {
  if systemctl is-active libvirtd >/dev/null 2>&1; then
    step "Apagando libvirtd" sudo systemctl stop libvirtd
  else
    step "Encendiendo libvirtd" sudo systemctl start libvirtd
  fi
}
