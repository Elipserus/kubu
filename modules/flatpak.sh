MOD_NAME="Flatpak"
MOD_CATEGORY="Utilidades"
MOD_DESC="Flatpak + Flathub integrado en Discover"
MOD_PRIORITY=25
MOD_DEFAULT=1
MOD_APT=(flatpak plasma-discover-backend-flatpak)

mod_install() { kind_apt_install; ensure_flatpak; }
