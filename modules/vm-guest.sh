MOD_NAME="Herramientas VM"
MOD_CATEGORY="Sistema"
MOD_DESC="Integración si kubu corre en una VM"
MOD_REQUIRED=1
MOD_PRIORITY=5

# Paquetes, servicio y carpetas compartidas según el hipervisor.
# En una máquina real (o un hipervisor sin soporte) no se define ninguna
# función: el módulo no aparece ni en el asistente ni en el menú.
VIRT=$(vm_type)
case $VIRT in
  kvm|qemu)  PACKAGES=(qemu-guest-agent spice-vdagent)
             SERVICE=qemu-guest-agent.service ;;
  oracle)    PACKAGES=(virtualbox-guest-utils virtualbox-guest-x11)
             SERVICE=virtualbox-guest-utils.service SHARED=/media ;;
  vmware)    PACKAGES=(open-vm-tools open-vm-tools-desktop)
             SERVICE=open-vm-tools.service SHARED=/mnt/hgfs ;;
  microsoft) PACKAGES=(linux-cloud-tools-virtual)
             SERVICE=hv-kvp-daemon.service ;;
  *)         PACKAGES=() ;;
esac

# Se monta al entrar en /mnt/hgfs (automount): con las carpetas compartidas
# desactivadas en VMware, un montaje al arrancar fallaría en cada inicio.
HGFS_FSTAB="vmhgfs-fuse /mnt/hgfs fuse defaults,allow_other,nofail,x-systemd.automount 0 0"

((${#PACKAGES[@]})) || return 0

MOD_MENU=("vg_shared|Ver carpetas compartidas")

mod_is_installed() { local p; for p in "${PACKAGES[@]}"; do pkg_installed "$p" || return 1; done; }

mod_install() {
  # Los paquetes de VirtualBox están en multiverse
  if [[ $VIRT == oracle ]] && ! apt-cache show virtualbox-guest-utils >/dev/null 2>&1; then
    step "Activando el repositorio multiverse" sudo add-apt-repository -y multiverse
  fi
  step "Instalando ${PACKAGES[*]}" apt_install "${PACKAGES[@]}"
  mod_configure
}

mod_configure() {
  case $VIRT in
    oracle)
      step "Añadiendo $USER al grupo vboxsf" sudo usermod -aG vboxsf "$USER"
      warn "Cierra sesión y vuelve a entrar para acceder a las carpetas compartidas."
      ;;
    vmware)
      # Solo si VMware comparte alguna carpeta; si no, el montaje fallaría al entrar
      if [[ -z $(vmware-hgfsclient 2>/dev/null) ]]; then
        info "Sin carpetas compartidas en VMware. Actívalas en la configuración de la VM"
        info "y vuelve aquí: Configurar › Herramientas VM › Configuración básica."
        return 0
      fi
      # Las VMware Tools actuales (Ubuntu 26.04) montan /mnt/hgfs solas al activar
      # una carpeta compartida: un montaje propio chocaría con el suyo.
      if grep -q '^vmhgfs-fuse /mnt/hgfs ' /etc/fstab && mountpoint -q /mnt/hgfs; then
        step "Quitando el montaje de kubu (lo hace VMware)" bash -c \
          "sudo sed -i '\#^vmhgfs-fuse /mnt/hgfs #d' /etc/fstab && sudo systemctl daemon-reload"
      fi
      if mountpoint -q /mnt/hgfs; then
        ok "Carpetas compartidas en /mnt/hgfs (las monta VMware)"
        return 0
      fi
      # VMware Tools antiguas: montaje propio al entrar en la carpeta
      grep -qxF "$HGFS_FSTAB" /etc/fstab ||
        step "Carpetas compartidas en /mnt/hgfs (se montan al entrar)" bash -c \
          "sudo mkdir -p /mnt/hgfs && sudo sed -i '\#^vmhgfs-fuse /mnt/hgfs #d' /etc/fstab &&
           echo '$HGFS_FSTAB' | sudo tee -a /etc/fstab >/dev/null &&
           sudo systemctl daemon-reload && sudo systemctl start mnt-hgfs.automount"
      ;;
  esac
  return 0
}

mod_uninstall() {
  if [[ $VIRT == vmware ]] && grep -q '^vmhgfs-fuse /mnt/hgfs ' /etc/fstab; then
    sudo systemctl stop mnt-hgfs.automount mnt-hgfs.mount 2>/dev/null || true
    step "Quitando /mnt/hgfs de fstab" sudo sed -i "\#^vmhgfs-fuse /mnt/hgfs #d" /etc/fstab
    sudo systemctl daemon-reload
  fi
  step "Eliminando ${PACKAGES[*]}" apt_purge "${PACKAGES[@]}"
}

_shares() {
  case $VIRT in
    oracle) find /media -maxdepth 1 -name 'sf_*' 2>/dev/null ;;
    vmware) mountpoint -q /mnt/hgfs && find /mnt/hgfs -mindepth 1 -maxdepth 1 2>/dev/null ;;
  esac
  return 0
}

mod_status() {
  ui_status "Hipervisor" "$VIRT" ok
  ui_service "Servicio" "$SERVICE"
  if [[ $VIRT == oracle ]]; then
    if id -nG "$USER" | grep -qw vboxsf; then ui_status "Grupo vboxsf" "sí" ok
    else ui_status "Grupo vboxsf" "no (usa Configuración básica)" warn
    fi
  fi
  [[ -n ${SHARED:-} ]] && ui_status "Carpetas compartidas" "$(_shares | grep -c . || true)"
  return 0
}

vg_shared() {
  [[ -n ${SHARED:-} ]] || { info "Este hipervisor no usa carpetas compartidas de kubu."; return 0; }
  if [[ -n $(_shares) ]]; then _shares
  else info "No hay carpetas compartidas: añádelas en la configuración de la VM."
  fi
}
