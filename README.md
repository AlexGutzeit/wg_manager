# wg_manager

WireGuard-Zugänge auf **Freifunk-Franken-Routern** (Layer-3-Firmware) einrichten und verwalten:
von unterwegs ins eigene Netz, nur ins Internet für Gäste, oder beides.

- **Ein Skript** – Tunnel und Geräte per Menü oder Befehl anlegen, sperren, löschen.
- **Nichts nachinstallieren** – nutzt nur, was die Firmware mitbringt (`wg`, `uci`, `nft`, `awk`), auch für den QR-Code.
- **Übersteht Firmware-Updates** – Einstellungen und Schlüssel bleiben erhalten und werden beim Start neu angewendet.
- **Babel-Verbindungen** – zwei Freifunk-Router über WireGuard und Babel koppeln, z. B. einen Router hinter einem
  LTE-Router ins Freifunk-Netz bringen, ohne eigenen Gateway-Server. Siehe [Babel-Verbindungen](#babel-verbindungen-router--router).

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
| `babel-neu <name> [--port N] [--rxcost N]` | Babel-Verbindung, Seite A: lauscht, gibt eine Zeile zum Einfügen aus |
| `babel-einfuegen ["<zeile>"] [--name N]` | Babel-Verbindung, Seite B: Zeile von A einfügen, verbindet sich |
| `babel-zeige <name>` | Zeile erneut ausgeben (Seite A) |
| `babel-mtu <name>` | MTU jetzt neu aushandeln |
| `babel-aendern <name> --rxcost N` | Babel-Kosten nachträglich ändern (Seite A und B) |
| `babel-loeschen <name>` | Babel-Verbindung entfernen |
| `babel-pruefen` | Wächter (läuft alle 5 min von selbst) |
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

## Babel-Verbindungen (Router ↔ Router)

Koppelt zwei Freifunk-Router über WireGuard und Babel. Beispiel: Ein Freifunk-Router hängt hinter einem
LTE-Router und bekommt über einen Router mit fester Freifunk-Adresse Anschluss ans Freifunk-Netz – ohne eigenen
Gateway-Server. Auf beiden Routern muss wg_manager (ab 2.3) installiert sein.

**Seite A** (lauscht, hat eine feste Freifunk-IPv6 aus `router_ip6` oder dem Client-Netz):

```sh
wg_manager babel-neu lte1
```

Ausgegeben wird **eine Zeile**, etwa `wgm-babel1 name=lte1 von=<router-a> ep=[2a0b:…]:51821 rx=16384 pub=… key=… psk=…`.

**Seite B** (verbindet sich, z. B. hinter LTE) – Zeile einfügen:

```sh
wg_manager babel-einfuegen          # fragt nach der Zeile
```

Im Menü: `b` → `1` (konfigurieren) bzw. `b` → `2` (einfügen). Danach steht der Tunnel, Babel tauscht die Routen aus.
Als Namen schlägt Seite B den Router A vor (`hbl-hoh-chrisb` → `hohchrisb`); ist er schon vergeben, wird eine
Ziffer angehängt. Mit `--name N` lässt sich ein eigener Name setzen.

**Mehrere Verbindungen:** Ein Router B kann Zeilen von mehreren Routern A einfügen, z. B. ein LTE-Router mit
Verbindungen zu zwei Freifunk-Routern. Babel sieht dann zwei Nachbarn; fällt einer aus, laufen die Routen nach
etwa 15–20 Sekunden über den anderen. Einen festen Hauptweg bekommt man über verschiedene rxcost (z. B. 16384 und
20000).

**Gerätetunnel auf Router B:** Handys und Laptops können sich auch mit Router B verbinden – über dessen feste
Freifunk-Adresse, also durch den Babel-Tunnel (erreichbar, solange mindestens eine Babel-Verbindung steht). Das ist
Tunnel im Tunnel: Hängt Router A hinter einem 1412er-Zugang, hat der Babel-Tunnel 1332, ein Gerätetunnel braucht
aber mindestens 1280 + 80 = 1360. Die äußeren Pakete des Geräts werden dann zerlegt – das geht, ist aber weniger
effizient, und manche Mobilfunknetze verwerfen zerlegte IPv6-Pakete. Wenn möglich, Geräte direkt mit Router A
verbinden.

**MTU aushandeln:** Beide Seiten starten mit 1280. Sobald sich die Router gefunden haben (WireGuard verbunden, die
Gegenstelle antwortet), sucht jede Seite für ihre Senderichtung stufenweise die größte MTU zwischen 1280 und 1420:
Pings in voller Paketgröße an die Gegenstelle durch den Tunnel, wobei geprüft wird, dass unterwegs nichts zerlegt
wurde. Hin- und Rückweg können verschieden sein (z. B. bei LTE). Ein Wächter (alle 5 Minuten) handelt neu aus, wenn
die Verbindung weg war oder sich die Adresse der Gegenstelle ändert, und prüft stündlich, ob die MTU noch passt.
Von Hand: `wg_manager babel-mtu <name>`.

**rxcost (Babel-Kosten des Tunnels, 1–65535):** Standard 16384 wie bei den Firmware-Tunneln – der Tunnel ist dann nur
Ersatzweg, solange es andere Verbindungen gibt. Ist er der einzige Weg (Router hinter LTE), ist der Wert praktisch
egal. Kleinere Werte (z. B. 1024) lassen Babel den Tunnel bevorzugen. Babel addiert die Kosten entlang eines Weges und
hält ein Ziel ab 65535 für unerreichbar – hintereinander geschaltete Tunnel brauchen kleinere Werte.

- Beim Anlegen: `--rxcost N` bzw. im Menü abgefragt. Die Zeile von A trägt deren Wert (`rx=`) mit, B übernimmt ihn,
  solange beim Einfügen nichts anderes angegeben wird.
- Nachträglich auf beiden Seiten: `wg_manager babel-aendern <name> --rxcost N` (Menü `b` → `6`). Der Tunnel bleibt
  stehen, nur bird wird neu geladen. rxcost gilt für die Empfangsrichtung – auf beiden Routern gleich einstellen.

**Voraussetzungen**

- Seite A ist über ihre feste Freifunk-IPv6 erreichbar. Die IPv6 des DSL-/LTE-Anbieters wird bewusst nie benutzt
  (wechselt, ist hinter einer Fritzbox meist gesperrt).
- Seite B hat einen eigenen Internet-Anschluss **mit IPv6** (WAN) – über ihn läuft der Tunnel zu A.
- Seite B hat eine **eigene Freifunk-Identität** (Router-IP, eigene Netze). Ein Router mit den Adressen eines anderen
  Knotens würde dessen Netze ein zweites Mal ankündigen.
- Die Zeile enthält den privaten Schlüssel von B – nur dorthin kopieren. Erneut anzeigen: `wg_manager babel-zeige <name>`.

**Technik**

- Schnittstelle `bb_<name>` (nicht `wg_…`: die Layer-3-Skripte der Firmware löschen `wg_`-Schnittstellen ohne
  eigenen gateway-Eintrag), Link-Local `fe80::1` (A) und `fe80::2` (B) plus die Router-IP.
- Babel: eine Datei je Verbindung in `/etc/bird/fff/babelpeers/`; bird wird erst nach erfolgreicher Prüfung
  (`bird -p`) neu geladen.
- B markiert seine Tunnelpakete (`fwmark 0xc8`, wie die Firmware), damit sie über den eigenen Anschluss gehen und
  nicht in den Tunnel selbst. A markiert nicht – er antwortet über seine Freifunk-Adresse.
- A trägt bis zur ersten Verbindung einen Platzhalter `[::1]:9` als Ziel ein; sonst meldet bird für jedes
  Babel-Hallo einen Fehler und füllt das Systemprotokoll.
- Der Wächter liegt bei micrond der Firmware in `/usr/lib/micron.d/wg_manager` und stellt auch Schnittstellen und
  bird-Dateien wieder her, die ein Layer-3-Lauf der Firmware entfernt hat.

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

- Freifunk-Franken-Firmware layer3-20241219 (OpenWrt 23.05.5) auf einem EdgeRouter X, Router hängt über Freifunk
  (Strecke 1412): Tunnel, Geräte, QR-Code, MTU.
- Babel-Verbindung zwischen zwei Routern mit layer3-20250321-beta (OpenWrt 24.10): Seite A TL-WR1043ND v2
  (Uplink über einen Freifunk-WireGuard-Tunnel mit MTU 1412), Seite B TL-WDR4900 v1 hinter DSL (Telekom-IPv6).
  Babel tauscht alle Routen aus; beide Seiten handeln 1332 aus (1412 − 80), volle Pakete gehen unzerlegt durch.
  Außerdem: MTU-Suche gegen eine künstliche Engstelle ohne Rückmeldung (1400 → genau 1320), Wächter
  (Selbstheilung nach entfernter bird-Datei, Neuaushandeln nach Adresswechsel, Erkennen einer verschwundenen
  Gegenstelle), rxcost ändern auf beiden Seiten ohne Tunnelabriss, Übernahme von rxcost über die Zeile, zwei
  Verbindungen auf einem Router B mit automatisch eindeutigen Namen, Löschen ohne Reste. Ein echter LTE-Anschluss
  und zwei verschiedene Router A für einen Router B sind noch nicht getestet.

Rückmeldungen von anderen Routern und Anschlüssen (LTE, Richtfunk) sind willkommen.

## Entwicklung

`wg_install.txt` wird aus `wg_manager` gebaut:

```sh
./make-install.sh
```

Das Skript darf **keine Tabulatoren** enthalten: busybox ash verschluckt sie beim Einfügen in die SSH-Sitzung.
Eingerückt wird mit vier Leerzeichen.

## Versionen

- **2.3** (25.10.2026) – Babel-Verbindungen zwischen Freifunk-Routern (`babel-neu`, `babel-einfuegen`, MTU wird
  ausgehandelt, rxcost einstellbar und nachträglich änderbar, Wächter); Endpunkt nur noch feste Freifunk-IPv6, nie
  die Adresse des WAN-Anschlusses.
- **2.2** (23.10.2026) – MTU je Tunnel einstellbar und messbar (`--mtu`, `mtu-messen`); Einrückung mit Leerzeichen
  (Einfügen in die SSH-Sitzung).
- **2.1** (23.10.2026) – QR-Code im Terminal ohne Zusatzpakete; Sperre wird bei Abbruch freigegeben.
- **2.0** (22.10.2026) – Neubau: mehrere Tunnel, Zugriffsarten, Einstellungen in `/etc/config/wgmanager`,
  übersteht Firmware-Updates, Übernahme des Altbestands.
- **1** (Januar 2026) – erste Fassung (wg_manager + privwg), ein Tunnel.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).
