# wg_manager

WireGuard-Zugänge auf **Freifunk-Franken-Routern** (Layer-3-Firmware) einrichten und verwalten:
von unterwegs ins eigene Netz, nur ins Internet für Gäste, oder beides.

- **Ein Skript** – Tunnel und Geräte per Menü oder Befehl anlegen, sperren, löschen.
- **Nichts nachinstallieren** – nutzt nur, was die Firmware mitbringt (`wg`, `uci`, `nft`, `awk`), auch für den QR-Code.
- **Übersteht Firmware-Updates** – Einstellungen und Schlüssel bleiben erhalten und werden beim Start neu angewendet.

## Installation

Entweder den ganzen Inhalt von [`wg_install.txt`](wg_install.txt) in eine SSH-Sitzung auf dem Router einfügen
(`ssh root@<router>`), oder vom eigenen Rechner aus:

```sh
ssh root@<router> sh < wg_install.txt
```

Danach auf dem Router:

```sh
wg_manager          # Menü
wg_manager hilfe    # alle Befehle
```

Beim ersten Anwenden trägt sich das Skript selbst in `/etc/sysupgrade.conf` und in den Start
(`/etc/rc.local.fff_userconfig`) ein.

**Umstieg von der alten Version** (wg_manager v1 / privwg): `wg_manager migrate` übernimmt Tunnel, Geräte und
Schlüssel. An den Geräten muss nichts geändert werden.

## Begriffe

- **Tunnel** – eine WireGuard-Schnittstelle auf dem Router: eigener Port, eigener Adressbereich, eigene Regeln.
  Zum Beispiel `home` für die Familie und `gast` für Besuch.
- **Gerät** – ein Schlüsselpaar mit fester Adresse in genau einem Tunnel. Die Konfiguration fürs Gerät erzeugt das
  Skript, als Text oder als QR-Code.

### Zugriffsarten je Tunnel

| Zugriff | Gerät erreicht | Internet des Geräts | typisch für |
|---|---|---|---|
| `beides` | gewähltes Netz und Internet | läuft über den Router | eigenes Handy, Laptop |
| `netz` | nur das gewählte Netz | läuft normal am Gerät (Split-Tunnel) | Fernwartung, Familie |
| `internet` | nur Internet, nichts im Haus | läuft über den Router | Gäste |

### Schalter

- **Router-Verwaltung** (`--admin 0|1`) – SSH und Weboberfläche des Routers aus dem Tunnel erreichbar. Standard: aus.
- **Freifunk-Netze** (`--freifunk 0|1`) – 10.50.0.0/16, 10.83.0.0/16 und fd43:5602:29bd::/48 erlaubt, z. B. für den
  Freifunk-DNS. Standard: an, außer bei `internet`.
- **Pre-Shared-Key** – neue Geräte bekommen zusätzlich einen gemeinsamen Schlüssel (abschalten mit `--ohne-psk`).
- **Sperren statt löschen** – gesperrte Geräte bleiben gespeichert. Gelöschte Schlüssel landen in `/etc/wireguard/archiv`.

## Schnellstart

```sh
wg_manager netze                                         # welche Netze hat der Router?
wg_manager tunnel-neu home --netz <netz> --zugriff beides --mtu auto
wg_manager geraet-neu home Handy_Anna
wg_manager qr Handy_Anna                                 # QR-Code für die WireGuard-App
```

In der WireGuard-App: „+“ → „QR-Code scannen“. Für einen Laptop die Konfiguration als Datei holen:

```sh
ssh root@<router> wg_manager zeige Laptop_Anna --raw > laptop.conf
```

## Befehle

| `wg_manager …` | macht |
|---|---|
| *(ohne Angabe)* | Menü |
| `liste` | Tunnel und Geräte mit Status, letztem Kontakt, Datenmenge |
| `netze` | Netze des Routers, in die ein Tunnel führen kann |
| `zeige <gerät> [--raw]` | Gerätekonfiguration als Text |
| `qr <gerät>` | Gerätekonfiguration als QR-Code im Terminal |
| `geraet-neu <tunnel> <name> [--ohne-psk]` | Gerät anlegen |
| `geraet-sperren` / `geraet-entsperren <name>` | Gerät vorübergehend aussperren |
| `geraet-loeschen <name>` | Gerät entfernen, Schlüssel ins Archiv |
| `tunnel-neu <name> [Optionen]` | Tunnel anlegen |
| `tunnel-aendern <name> [Optionen]` | Netz, Zugriff, Verwaltung, DNS, MTU umstellen |
| `tunnel-loeschen <name>` | Tunnel mit allen Geräten entfernen |
| `mtu-messen [ziel]` | Strecke des Routers messen, passende Tunnel-MTU vorschlagen |
| `apply` | alles aus `/etc/config/wgmanager` neu anwenden (reparieren) |
| `migrate [--dns "…"]` | Altbestand (v1/privwg) übernehmen |

Optionen für `tunnel-neu` / `tunnel-aendern`: `--netz "<netz> …"`, `--zugriff beides|netz|internet`,
`--admin 0|1`, `--freifunk 0|1`, `--dns "…"`, `--mtu N|auto`, bei `tunnel-neu` zusätzlich `--port N`.

Ohne Angabe wählt das Skript: Port ab 51821, Adressbereich 10.10.x.0/24 und fd00:cafe:x::/64, MTU 1280,
DNS = der Router im Tunnel.

## MTU

Tunnel-MTU = Strecke des Routers ins Internet minus 80 Byte (WireGuard über IPv6).

| Anschluss des Routers | Strecke | Tunnel-MTU |
|---|---|---|
| Freifunk über DSL-Gateway | 1412 | 1332 |
| Richtfunk/Glasfaser direkt am Rechenzentrum | 1500 | 1420 |
| LTE / unbekannt | messen | im Zweifel 1280 (passt immer) |

`wg_manager mtu-messen` misst die Strecke und zeigt, welche Tunnel abweichen; `--mtu auto` übernimmt den gemessenen
Wert. Erlaubt sind 1280–1420. Wird die MTU kleiner, sollten die Geräte ihre Konfiguration neu einlesen.

## Was im Hintergrund passiert

Alle Einstellungen stehen in `/etc/config/wgmanager`, die Schlüssel in `/etc/wireguard`. Daraus erzeugt
`wg_manager apply`:

- die Schnittstellen `wg_<tunnel>` und die Geräte in `/etc/config/network`,
- die Routing-Regeln als uci-Einträge (von netifd verwaltet),
- einen Firewall-Block in `/etc/nftables-fff.conf` (Tabelle `inet wg_manager`, lädt `fff-firewall`).

Änderungen gehören in `/etc/config/wgmanager` bzw. werden mit den Befehlen gemacht – den erzeugten Teil schreibt
`apply` jedes Mal neu. Beim Start ruft `/etc/rc.local.fff_userconfig` nach 20 Sekunden `wg_manager apply` auf; so
stellt sich nach einem Firmware-Update alles von selbst wieder her.

## Gut zu wissen

- **Erreichbar über IPv6:** Endpunkt ist die öffentliche IPv6-Adresse des Routers. Das Gerät braucht unterwegs IPv6 –
  oder man trägt einen eigenen Namen ein: `uci set wgmanager.settings.endpoint=<name>; uci commit wgmanager`.
- **Schlüssel schützen:** Konfiguration und QR-Code enthalten den privaten Schlüssel des Geräts.
- **QR-Code:** eingebauter Erzeuger in awk (Byte-Modus, Fehlerkorrektur L). Etwa 6 s auf einem EdgeRouter X; das
  Terminal braucht für eine typische Konfiguration etwa 73 × 37 Zeichen.
- **MSS-Begrenzung für alle Verbindungen** (optional): `uci set wgmanager.settings.mss_clamp_all=1240` begrenzt alle
  weitergeleiteten TCP-Verbindungen. Hilft, wenn hinter einer Freifunk-Strecke < 1500 einzelne Seiten nicht laden.
- Zwei Aufrufe gleichzeitig verhindert eine Sperre; sie wird auch bei Abbruch (Strg-C) freigegeben.

## Getestet

Freifunk-Franken-Firmware layer3-20241219 (OpenWrt 23.05.5) auf einem EdgeRouter X, Router hängt über Freifunk
(Strecke 1412). Rückmeldungen von anderen Routern und Anschlüssen (LTE, Richtfunk) sind willkommen.

## Entwicklung

`wg_install.txt` wird aus `wg_manager` gebaut:

```sh
./make-install.sh
```

Das Skript darf **keine Tabulatoren** enthalten: busybox ash verschluckt sie beim Einfügen in die SSH-Sitzung.
Eingerückt wird mit vier Leerzeichen.

## Versionen

- **2.2** (23.10.2026) – MTU je Tunnel einstellbar und messbar (`--mtu`, `mtu-messen`); Einrückung mit Leerzeichen
  (Einfügen in die SSH-Sitzung).
- **2.1** (23.10.2026) – QR-Code im Terminal ohne Zusatzpakete; Sperre wird bei Abbruch freigegeben.
- **2.0** (22.10.2026) – Neubau: mehrere Tunnel, Zugriffsarten, Einstellungen in `/etc/config/wgmanager`,
  übersteht Firmware-Updates, Übernahme des Altbestands.
- **1** (Januar 2026) – erste Fassung (wg_manager + privwg), ein Tunnel.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).
