#!/bin/sh
# Baut wg_install.txt aus wg_manager: Text zum Einfügen in eine SSH-Sitzung auf dem Router
# (oder: ssh root@<router> sh < wg_install.txt).
# Wichtig: busybox ash verschluckt beim Einfügen Tabulatoren – das Skript darf keine enthalten.
set -e
cd "$(dirname "$0")"

if grep -q "$(printf '\t')" wg_manager; then
    echo "FEHLER: wg_manager enthält Tabulatoren – beim Einfügen gingen sie verloren." >&2
    exit 1
fi
if grep -qx 'WG_MANAGER_ENDE' wg_manager; then
    echo "FEHLER: wg_manager enthält die Endmarke WG_MANAGER_ENDE." >&2
    exit 1
fi
sh -n wg_manager

version=$(sed -n 's/^#  Version \([0-9.]*\).*/\1/p' wg_manager | head -1)

{
    cat <<KOPF
# =====================================================================
#  wg_manager $version – WireGuard-Zugänge für Freifunk-Franken-Router (Layer 3)
#  Quelle: https://github.com/AlexGutzeit/wg_manager  (GPL-3.0-or-later)
#
#  Installation – eine der beiden Arten:
#    a) Diesen ganzen Text in eine SSH-Sitzung auf dem Router einfügen
#       (ssh root@<router>), oder
#    b) Datei herunterladen und vom eigenen Rechner aus:
#       ssh root@<router> sh < wg_install.txt
#
#  Danach:  wg_manager          Menü
#           wg_manager hilfe    alle Befehle
#
#  Umstieg von der alten Version (wg_manager v1 / privwg):
#           wg_manager migrate  übernimmt Tunnel, Geräte und Schlüssel –
#                               an den Geräten muss nichts geändert werden
#
#  Neu: mehrere Tunnel (Netz+Internet / nur Netz / nur Internet für Gäste),
#  QR-Code direkt im Terminal, MTU je Tunnel (wg_manager mtu-messen),
#  übersteht Firmware-Updates. Nichts muss nachinstalliert werden.
# =====================================================================
cat << 'WG_MANAGER_ENDE' > /usr/sbin/wg_manager
KOPF
    cat wg_manager
    cat <<'FUSS'
WG_MANAGER_ENDE
chmod 755 /usr/sbin/wg_manager
echo "wg_manager installiert. Start: wg_manager   (Hilfe: wg_manager hilfe)"
FUSS
} > wg_install.txt

sh -n wg_install.txt
echo "wg_install.txt gebaut (wg_manager $version, $(wc -c < wg_install.txt) Byte)."
