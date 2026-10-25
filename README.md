# wg_manager

WireGuard für **Freifunk-Franken-Router** (Layer-3-Firmware) – ein einzelnes Shell-Skript, das nichts nachinstalliert
und Firmware-Updates übersteht. Es kann zwei Dinge:

- **Gerätetunnel** – Handy und Laptop kommen von unterwegs ins eigene Netz, nur ins Internet (Gäste) oder beides.
  Die Konfiguration gibt es als Text oder als QR-Code direkt im Terminal.
- **Babel-Verbindungen** – zwei Freifunk-Router koppeln, z. B. einen Router hinter einem LTE-Router ans Freifunk-Netz
  bringen, ohne eigenen Gateway-Server. Die MTU handeln die Router selbst aus.

## Inhalt

1. [Installation](#installation)
2. [Gerätetunnel für Handy und Laptop](#gerätetunnel-für-handy-und-laptop)
3. [Babel-Verbindungen zwischen Routern](#babel-verbindungen-zwischen-routern)
4. [Alle Befehle](#alle-befehle)
5. [Technik](#technik)
6. [Gut zu wissen](#gut-zu-wissen)
7. [Getestet](#getestet) · [Entwicklung](#entwicklung) · [Versionen](#versionen) · [Lizenz](#lizenz)

## Installation

Den ganzen Inhalt von [`wg_install.txt`](wg_install.txt) in eine SSH-Sitzung auf dem Router einfügen
(`ssh root@<router>`) – oder vom eigenen Rechner aus:

```sh
ssh root@<router> sh < wg_install.txt
```

Danach auf dem Router:

```sh
wg_manager          # Menü
wg_manager hilfe    # alle Befehle
```

- **Aktualisieren** geht genauso; Einstellungen und Schlüssel bleiben erhalten.
- Beim ersten Anwenden trägt sich das Skript selbst in `/etc/sysupgrade.conf` und in den Start
  (`/etc/rc.local.fff_userconfig`) ein – nach einem Firmware-Update stellt es sich von selbst wieder her.
- **Umstieg von der alten Version** (wg_manager v1 / privwg): `wg_manager migrate` übernimmt Tunnel, Geräte und
  Schlüssel; an den Geräten muss nichts geändert werden.

## Gerätetunnel für Handy und Laptop

### Schnellstart

```sh
wg_manager netze                                          # welche Netze hat der Router?
wg_manager tunnel-neu home --netz <netz> --zugriff beides --mtu auto
wg_manager geraet-neu home Handy_Anna
wg_manager qr Handy_Anna                                  # QR-Code für die WireGuard-App
```

In der WireGuard-App: „+“ → „QR-Code scannen“. Für einen Laptop die Konfiguration als Datei holen:

```sh
ssh root@<router> wg_manager zeige Laptop_Anna --raw > laptop.conf
```

Im Menü: Punkt 5 (Tunnel anlegen), Punkt 1 (Gerät hinzufügen, danach „Als QR-Code anzeigen?“).

### Tunnel und Geräte

- **Tunnel** – eine WireGuard-Schnittstelle auf dem Router mit eigenem Port, Adressbereich und eigenen Regeln,
  z. B. `home` für die Familie und `gast` für Besuch.
- **Gerät** – ein Schlüsselpaar mit fester Adresse in genau einem Tunnel; erbt dessen Regeln.

Ohne Angabe wählt das Skript: Port ab 51821, Adressbereich 10.10.x.0/24 und fd00:cafe:x::/64, MTU 1280,
DNS = der Router im Tunnel.

### Zugriffsarten

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
- **Sperren statt löschen** – gesperrte Geräte bleiben gespeichert; gelöschte Schlüssel landen in
  `/etc/wireguard/archiv`.

### MTU

Tunnel-MTU = Strecke des Routers ins Internet minus 80 Byte (WireGuard über IPv6). Erlaubt sind 1280–1420.

| Anschluss des Routers | Strecke | Tunnel-MTU |
|---|---|---|
| Freifunk über DSL-Gateway | 1412 | 1332 |
| Richtfunk/Glasfaser direkt am Rechenzentrum | 1500 | 1420 |
| LTE / unbekannt | messen | im Zweifel 1280 (passt immer) |

`wg_manager mtu-messen` misst die Strecke und zeigt, welche Tunnel abweichen; `--mtu auto` übernimmt den gemessenen
Wert. Wird die MTU kleiner, sollten die Geräte ihre Konfiguration neu einlesen.

## Babel-Verbindungen zwischen Routern

Koppelt zwei Freifunk-Router über WireGuard und Babel. Typischer Fall: Ein Freifunk-Router hängt hinter einem
LTE-Router und bekommt über einen Router mit fester Freifunk-Adresse Anschluss ans Freifunk-Netz – ohne eigenen
Gateway-Server. Babel behandelt den Tunnel wie jede andere Verbindung und tauscht darüber die Routen aus.

### Voraussetzungen

- Auf **beiden** Routern läuft wg_manager ab Version 2.3.
- **Router A** (lauscht) ist über seine **feste Freifunk-IPv6** erreichbar (`router_ip6` oder Client-Netz). Die IPv6
  des DSL-/LTE-Anbieters wird bewusst nie benutzt – sie wechselt und ist hinter einer Fritzbox meist gesperrt.
- **Router B** (verbindet sich) hat einen eigenen Internet-Anschluss **mit IPv6** – über ihn läuft der Tunnel zu A.
- Router B hat eine **eigene Freifunk-Identität** (Router-IP, eigene Netze). Ein Router mit den Adressen eines
  anderen Knotens würde dessen Netze ein zweites Mal ankündigen.

### Schnellstart

**Router A** – Menü `b` → `1`, oder:

```sh
wg_manager babel-neu lte1
```

Ausgegeben wird **eine Zeile** zum Kopieren.

**Router B** – Menü `b` → `2`, oder:

```sh
wg_manager babel-einfuegen          # fragt nach der Zeile
```

Zeile einfügen, Namen bestätigen – fertig. Router B wartet bis zu 60 Sekunden auf die Gegenstelle und handelt dann
seine MTU aus. Als Namen schlägt B den Router A vor (`hbl-hoh-chrisb` → `hohchrisb`); ist er vergeben, wird eine
Ziffer angehängt, mit `--name N` lässt sich ein eigener setzen.

### Was in der Zeile steht

```
wgm-babel1 name=lte1 von=hbl-abc-router ep=[2a0b:f4c0:…::17]:51821 rx=16384 pub=… key=… psk=…
```

| Feld | Inhalt |
|---|---|
| `ep` | feste Freifunk-IPv6 und Port von Router A – das Ziel für Router B |
| `rx` | rxcost von Router A; B übernimmt den Wert |
| `pub` | öffentlicher Schlüssel von Router A |
| `key` | **privater Schlüssel von Router B** – die Zeile nur dorthin kopieren |
| `psk` | gemeinsamer Zusatzschlüssel (Pre-Shared-Key) |
| `name`, `von` | Name der Verbindung auf A und Router-Name von A (für den Namensvorschlag) |

Adressen von Router B stehen bewusst nicht darin: Im Tunnel haben beide feste Link-Local-Adressen (`fe80::1` für A,
`fe80::2` für B), die eigenen Freifunk-Netze von B lernt A über Babel, und die Internet-Adresse von B übernimmt A
beim ersten Kontakt von selbst. Erneut anzeigen auf Router A: `wg_manager babel-zeige <name>`.

### MTU aushandeln

Beide Seiten starten mit 1280. Sobald sich die Router gefunden haben (WireGuard verbunden, die Gegenstelle
antwortet), sucht jede Seite für ihre Senderichtung stufenweise die größte MTU zwischen 1280 und 1420 – mit Pings in
voller Paketgröße durch den Tunnel. Wird ein Paket unterwegs zerlegt, gilt die Größe als zu groß. Hin- und Rückweg
können verschieden sein (z. B. bei LTE).

Ein **Wächter** (alle 5 Minuten) handelt neu aus, wenn die Verbindung weg war oder sich die Adresse der Gegenstelle
ändert, und prüft stündlich, ob die MTU noch durchkommt. Von Hand: `wg_manager babel-mtu <name>`.

### rxcost

rxcost sind die Babel-Kosten des Tunnels (1–65535), auf beiden Routern gleich einzustellen.

- **16384** (Standard, wie bei den Firmware-Tunneln) – der Tunnel ist nur Ersatzweg, solange es andere Verbindungen
  gibt. Ist er der einzige Weg (Router hinter LTE), ist der Wert praktisch egal.
- **Kleiner** (z. B. 1024) – Babel bevorzugt den Tunnel.
- Babel addiert die Kosten entlang eines Weges und hält ein Ziel ab 65535 für unerreichbar – hintereinander
  geschaltete Tunnel brauchen kleinere Werte.
- Ändern auf beiden Seiten: `wg_manager babel-aendern <name> --rxcost N` (Menü `b` → `6`). Der Tunnel bleibt stehen,
  nur bird wird neu geladen.

### Mehrere Router A

Ein Router B kann die Zeilen von mehreren Routern A einfügen, z. B. ein LTE-Router mit Verbindungen zu zwei
Freifunk-Routern. Babel sieht dann zwei Nachbarn; fällt einer aus, laufen die Routen nach etwa 15–20 Sekunden über
den anderen. Einen festen Hauptweg bekommt man über verschiedene rxcost (z. B. 16384 und 20000).

### Gerätetunnel auf Router B

Handys und Laptops können sich auch mit Router B verbinden – über dessen feste Freifunk-Adresse, also durch den
Babel-Tunnel (erreichbar, solange mindestens eine Babel-Verbindung steht). Das ist **Tunnel im Tunnel**: Hängt
Router A hinter einem 1412er-Zugang, hat der Babel-Tunnel 1332, ein Gerätetunnel braucht aber mindestens
1280 + 80 = 1360. Die äußeren Pakete des Geräts werden dann zerlegt – das geht, ist aber weniger effizient, und manche
Mobilfunknetze verwerfen zerlegte IPv6-Pakete. Wenn möglich, Geräte direkt mit Router A verbinden.

## Alle Befehle

Ohne Angabe öffnet `wg_manager` das Menü; `wg_manager hilfe` zeigt diese Liste mit Optionen.

**Allgemein**

| `wg_manager …` | macht |
|---|---|
| `liste` | Tunnel, Geräte und Babel-Verbindungen mit Status |
| `netze` | Netze des Routers, in die ein Tunnel führen kann |
| `mtu-messen [ziel]` | Strecke des Routers messen, passende Tunnel-MTU vorschlagen |
| `apply` | alles aus `/etc/config/wgmanager` neu anwenden (reparieren) |
| `migrate [--dns "…"]` | Altbestand (v1/privwg) übernehmen |

**Gerätetunnel**

| `wg_manager …` | macht |
|---|---|
| `tunnel-neu <name> [Optionen]` | Tunnel anlegen |
| `tunnel-aendern <name> [Optionen]` | Netz, Zugriff, Verwaltung, DNS, MTU umstellen |
| `tunnel-loeschen <name>` | Tunnel mit allen Geräten entfernen |
| `geraet-neu <tunnel> <name> [--ohne-psk]` | Gerät anlegen |
| `zeige <gerät> [--raw]` | Gerätekonfiguration als Text |
| `qr <gerät>` | Gerätekonfiguration als QR-Code im Terminal |
| `geraet-sperren` / `geraet-entsperren <name>` | Gerät vorübergehend aussperren |
| `geraet-loeschen <name>` | Gerät entfernen, Schlüssel ins Archiv |

Optionen für `tunnel-neu` / `tunnel-aendern`: `--netz "<netz> …"`, `--zugriff beides|netz|internet`,
`--admin 0|1`, `--freifunk 0|1`, `--dns "…"`, `--mtu N|auto`, bei `tunnel-neu` zusätzlich `--port N`.

**Babel-Verbindungen**

| `wg_manager …` | macht |
|---|---|
| `babel-neu <name> [--port N] [--rxcost N]` | Router A: lauscht, gibt eine Zeile zum Einfügen aus |
| `babel-einfuegen ["<zeile>"] [--name N] [--rxcost N]` | Router B: Zeile von A einfügen, verbindet sich |
| `babel-zeige <name>` | Zeile erneut ausgeben (Router A) |
| `babel-mtu <name>` | MTU jetzt neu aushandeln |
| `babel-aendern <name> --rxcost N` | rxcost nachträglich ändern (Router A und B) |
| `babel-loeschen <name>` | Babel-Verbindung entfernen |
| `babel-pruefen` | Wächter (läuft alle 5 Minuten von selbst) |

## Technik

### Was `apply` erzeugt

Alle Einstellungen stehen in `/etc/config/wgmanager`, die Schlüssel in `/etc/wireguard`. Daraus erzeugt
`wg_manager apply`:

- die Schnittstellen und Gegenstellen in `/etc/config/network` (`wg_<tunnel>` für Gerätetunnel, `bb_<name>` für
  Babel-Verbindungen),
- die Routing-Regeln als uci-Einträge (von netifd verwaltet),
- einen Firewall-Block in `/etc/nftables-fff.conf` (Tabelle `inet wg_manager`, lädt `fff-firewall`),
- je Babel-Verbindung eine Datei in `/etc/bird/fff/babelpeers/` – bird wird erst nach erfolgreicher Prüfung
  (`bird -p`) neu geladen.

Änderungen gehören in `/etc/config/wgmanager` bzw. werden mit den Befehlen gemacht – den erzeugten Teil schreibt
`apply` jedes Mal neu. Beim Start ruft `/etc/rc.local.fff_userconfig` nach 20 Sekunden `wg_manager apply` auf.

### Babel im Detail

- Router B markiert seine Tunnelpakete (`fwmark 0xc8`, wie die Firmware), damit sie über den eigenen Anschluss gehen
  und nicht in den Tunnel selbst. Router A markiert nicht – er antwortet über seine Freifunk-Adresse.
- Router A trägt bis zur ersten Verbindung einen Platzhalter `[::1]:9` als Ziel ein; sonst meldet bird für jedes
  Babel-Hallo einen Fehler und füllt das Systemprotokoll.
- Die MTU-Probe stellt die Schnittstelle je Probe genau auf die geprüfte Größe (WireGuard füllt Pakete auf ein
  Vielfaches von 16 auf, aber nie über die MTU) und zählt, ob der Kernel beim Absenden zerlegt hat
  (`Ip6FragCreates`) – das erkennt auch einen eigenen Uplink-Tunnel mit kleinerer MTU.
- Der Wächter liegt bei micrond der Firmware in `/usr/lib/micron.d/wg_manager` (die Firmware liest kein
  `/etc/crontabs`).

### Eigenheiten der Firmware

- Die Layer-3-Skripte der Firmware löschen jede `wg_`-Schnittstelle ohne eigenen gateway-Eintrag und erzeugen
  `/etc/bird/fff` bei jedem Lauf neu. wg_manager stellt beides beim Start und über den Wächter wieder her; darum
  heißen Babel-Schnittstellen `bb_…`.
- Hat ein Router keinen einzigen Babel-Nachbarn (z. B. nur über wg_manager angebunden), startet bird beim Hochfahren
  nicht: Es findet keine Datei in `babelpeers/`, stürzt ab, und procd gibt auf. wg_manager startet bird dann selbst –
  beim Anwenden und über den Wächter.
- Auf der Beta-Firmware fehlt `birdc`; die Babel-Nachbarn zeigt `birdcl show babel neighbors`.

## Gut zu wissen

- **Erreichbar über IPv6:** Endpunkt ist die feste Freifunk-IPv6 des Routers – nie die wechselnde Adresse des DSL-
  oder LTE-Anbieters. Geräte brauchen unterwegs IPv6, oder man trägt einen eigenen Namen ein:
  `uci set wgmanager.settings.endpoint=<name>; uci commit wgmanager`.
- **Schlüssel schützen:** Gerätekonfiguration, QR-Code und Babel-Zeile enthalten private Schlüssel.
- **QR-Code:** eingebauter Erzeuger in awk (Byte-Modus, Fehlerkorrektur L). Etwa 6 s auf einem EdgeRouter X; das
  Terminal braucht für eine typische Konfiguration etwa 73 × 37 Zeichen.
- **MSS-Begrenzung für alle Verbindungen** (optional): `uci set wgmanager.settings.mss_clamp_all=1240` begrenzt alle
  weitergeleiteten TCP-Verbindungen. Hilft, wenn hinter einer Freifunk-Strecke < 1500 einzelne Seiten nicht laden.
- **Sperre:** Zwei Aufrufe gleichzeitig verhindert eine Sperre; sie wird auch bei Abbruch (Strg-C) freigegeben.
- **Protokoll:** Meldungen des Wächters stehen im Systemprotokoll: `logread | grep wg_manager`.

## Getestet

- Freifunk-Franken-Firmware layer3-20241219 (OpenWrt 23.05.5) auf einem EdgeRouter X, Router hängt über Freifunk
  (Strecke 1412): Tunnel, Geräte, QR-Code, MTU.
- Babel-Verbindung zwischen zwei Routern mit layer3-20250321-beta (OpenWrt 24.10): Router A TL-WR1043ND v2 (Uplink
  über einen Freifunk-WireGuard-Tunnel mit MTU 1412), Router B TL-WDR4900 v1 hinter DSL (Telekom-IPv6). Babel tauscht
  alle Routen aus; beide Seiten handeln 1332 aus (1412 − 80), volle Pakete gehen unzerlegt durch.
- Außerdem: MTU-Suche gegen eine künstliche Engstelle ohne Rückmeldung (1400 → genau 1320); Wächter (Selbstheilung
  nach entfernter bird-Datei, Neuaushandeln nach Adresswechsel, Erkennen einer verschwundenen Gegenstelle); rxcost
  ändern auf beiden Seiten ohne Tunnelabriss und Übernahme über die Zeile; zwei Verbindungen auf einem Router B mit
  automatisch eindeutigen Namen; Löschen ohne Reste.
- **LTE (25.10.2026):** Router B = EdgeRouter X (layer3-20250321-beta) hinter einer LTE-Fritzbox (IPv6 vom
  Mobilfunkanbieter), verbunden mit **zwei Routern A**. Beide Tunnel handeln 1332 aus; Geräte hinter Router B kommen
  über IPv4 (NAT) und IPv6 (eigenes /64) ins Internet, das Netz von B ist im Freifunk-Netz erreichbar. Hauptweg über
  rxcost (16384/20000); fällt er aus, übernimmt der zweite Router A nach rund 23 Sekunden, zurück ging es nach
  4 Sekunden. Laufzeit über LTE 120–150 ms.
- **Noch nicht getestet:** Gerätetunnel (Handy) zu Router B durch den Babel-Tunnel und ein Wechsel der
  LTE-Adresse.

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
  ausgehandelt, rxcost einstellbar und nachträglich änderbar, Namensvorschlag auf Router B, Wächter startet auch
  bird, falls es nicht läuft); Endpunkt nur
  noch feste Freifunk-IPv6, nie die Adresse des WAN-Anschlusses.
- **2.2** (23.10.2026) – MTU je Tunnel einstellbar und messbar (`--mtu`, `mtu-messen`); Einrückung mit Leerzeichen
  (Einfügen in die SSH-Sitzung).
- **2.1** (23.10.2026) – QR-Code im Terminal ohne Zusatzpakete; Sperre wird bei Abbruch freigegeben.
- **2.0** (22.10.2026) – Neubau: mehrere Tunnel, Zugriffsarten, Einstellungen in `/etc/config/wgmanager`,
  übersteht Firmware-Updates, Übernahme des Altbestands.
- **1** (Januar 2026) – erste Fassung (wg_manager + privwg), ein Tunnel.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).
