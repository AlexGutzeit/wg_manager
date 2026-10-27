# wg_manager

WireGuard für **Freifunk-Franken-Router** (Layer-3-Firmware) – ein einzelnes Shell-Skript, das nichts nachinstalliert
und Firmware-Updates übersteht. Es kann drei Dinge:

- **Gerätetunnel** – Handy und Laptop kommen von unterwegs ins eigene Netz, nur ins Internet (Gäste) oder beides.
  Die Konfiguration gibt es als Text oder als QR-Code direkt im Terminal.
- **Babel-Verbindungen** – zwei Freifunk-Router koppeln, z. B. einen Router hinter einem LTE-Router ans Freifunk-Netz
  bringen, ohne eigenen Gateway-Server. Die MTU handeln die Router selbst aus.
- **Netzverbindungen** – ein Netz eines anderen Freifunk-Routers aus dem eigenen Netz erreichen, z. B. den Drucker
  hinter dessen Fritzbox aus dem eigenen Heimnetz. Haben beide Netze denselben Adressbereich (bei Fritzboxen die
  Regel), gilt automatisch ein Ersatznetz.

**Anleitung mit Bildschirmfotos zu jedem Schritt:** [docs/wg_manager-anleitung.pdf](docs/wg_manager-anleitung.pdf)
(46 Seiten, Schritt für Schritt im Menü – Installation, Gerätetunnel samt aller Änderungsmöglichkeiten, Babel- und
Netzverbindungen, Werkzeuge; Befehle für die Kommandozeile im Anhang).

## Inhalt

1. [Installation](#installation) · [Das Menü](#das-menü)
2. [Gerätetunnel für Handy und Laptop](#gerätetunnel-für-handy-und-laptop)
3. [Babel-Verbindungen zwischen Routern](#babel-verbindungen-zwischen-routern)
4. [Netzverbindungen zwischen Netzen](#netzverbindungen-zwischen-netzen)
5. [Alle Befehle](#alle-befehle)
6. [Technik](#technik)
7. [Gut zu wissen](#gut-zu-wissen)
8. [Getestet](#getestet) · [Entwicklung](#entwicklung) · [Versionen](#versionen) · [Lizenz](#lizenz)

## Installation

Den ganzen Inhalt von [`wg_install.txt`](wg_install.txt) in eine SSH-Sitzung auf dem Router einfügen
(`ssh root@<router>`) – oder vom eigenen Rechner aus:

```sh
ssh root@<router> sh < wg_install.txt
```

Danach auf dem Router:

```sh
wg_manager          # Menü (Pfeiltasten, Enter, Esc)
wg_manager hilfe    # alle Befehle für die Kommandozeile
```

- **Aktualisieren** geht genauso; Einstellungen und Schlüssel bleiben erhalten.
- Beim ersten Anwenden trägt sich das Skript selbst in `/etc/sysupgrade.conf` und in den Start
  (`/etc/rc.local.fff_userconfig`) ein – nach einem Firmware-Update stellt es sich von selbst wieder her.
- **Umstieg von der alten Version** (wg_manager v1 / privwg): `wg_manager migrate` übernimmt Tunnel, Geräte und
  Schlüssel; an den Geräten muss nichts geändert werden.

## Das Menü

`wg_manager` ohne Angabe öffnet ein Menü, das ganz ohne Befehle auskommt:

| Taste | macht |
|---|---|
| ↑ ↓ | Eintrag wählen – unter der Liste steht, was er bewirkt |
| Enter | öffnen bzw. ausführen |
| Esc | eine Ebene zurück (im Hauptmenü: beenden) |
| Leertaste | Häkchen setzen/entfernen (Auswahl der Netze) |
| 1–9 | Eintrag direkt wählen |
| q | beenden |

Aufgebaut ist es nach dem, was man verwaltet:

- **Gerätetunnel** → Tunnel → Geräte → Gerät: QR-Code, Konfiguration als Text, sperren/entsperren, löschen.
  Im Tunnel selbst stehen alle Einstellungen mit ihrem aktuellen Wert (Netz, Zugriff, Router-Verwaltung,
  Freifunk-Netze, DNS, MTU) – Enter ändert sie. „+ Neuen Tunnel anlegen“ und „+ Gerät hinzufügen“ führen Schritt
  für Schritt durch alles Nötige; die MTU wird dabei gemessen.
- **Babel-Verbindungen** und **Netzverbindungen**: anlegen (Seite A, die Zeile erscheint zum Kopieren), Zeile
  einfügen (Seite B, Einfügen mit Strg+Umschalt+V oder Rechtsklick), ansehen, ändern, löschen. Beim Einfügen einer
  Netzverbindung erklärt das Menü ein nötiges Ersatznetz und fragt nach.
- **Werkzeuge**: Netze anzeigen, MTU messen, alles neu anwenden, Wächter, Protokoll, Befehlsübersicht.

Löschen fragt immer nach; vorausgewählt ist „Abbrechen“. Das Menü braucht nichts außer der busybox-Shell der
Firmware. Ohne Terminal (z. B. per Pipe) und mit `wg_manager menue-einfach` gibt es das frühere Zahlenmenü. Alles,
was das Menü kann, gibt es weiterhin als Befehl – die folgenden Abschnitte nennen beides.

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

Im Menü: Gerätetunnel → „+ Neuen Tunnel anlegen“, danach „+ Gerät hinzufügen“ und „QR-Code anzeigen“.

### Tunnel und Geräte

- **Tunnel** – eine WireGuard-Schnittstelle auf dem Router mit eigenem Port, Adressbereich und eigenen Regeln,
  z. B. `home` für die Familie und `gast` für Besuch.
- **Gerät** – ein Schlüsselpaar mit fester Adresse in genau einem Tunnel; erbt dessen Regeln.

Ohne Angabe wählt das Skript: Port ab 51821, Adressbereich 10.10.x.0/24 und fd00:cafe:x::/64, MTU 1280,
DNS = der Router im Tunnel.

### Netze

Ein Tunnel führt nur in Netze, in denen Endgeräte stehen – das zeigt `wg_manager netze`:

- die **Client-Netze** der Firmware (bei der Beta heißen sie `cfgXXXXXX`),
- das **WAN** (`wan`), z. B. das Netz der Fritzbox, an der der Router hängt – nur IPv4, weil sich die IPv6 des
  Anbieters ändert.

Babel-, Mesh- und Tunnelschnittstellen lehnt wg_manager mit Begründung ab, auch solche, die es nicht kennt.

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

**Router A** – Menü: Babel-Verbindungen → „+ Neue Verbindung – dieser Router lauscht“, oder:

```sh
wg_manager babel-neu lte1
```

Ausgegeben wird **eine Zeile** zum Kopieren.

**Router B** – Menü: Babel-Verbindungen → „+ Zeile vom anderen Router einfügen“, oder:

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
- Ändern auf beiden Seiten: `wg_manager babel-aendern <name> --rxcost N` (Menü: Babel-Verbindungen → Verbindung → „rxcost ändern“). Der Tunnel bleibt stehen,
  nur bird wird neu geladen.

### Mehrere Router A

Ein Router B kann die Zeilen von mehreren Routern A einfügen, z. B. ein LTE-Router mit Verbindungen zu zwei
Freifunk-Routern. Babel sieht dann zwei Nachbarn; fällt einer aus, laufen die Routen nach etwa 15–20 Sekunden über
den anderen. Einen festen Hauptweg bekommt man über verschiedene rxcost (z. B. 16384 und 20000).

### Gerätetunnel auf Router B

Handys und Laptops können sich auch mit Router B verbinden – über dessen feste Freifunk-Adresse, also durch den
Babel-Tunnel (erreichbar, solange mindestens eine Babel-Verbindung steht). Das ist **Tunnel im Tunnel**: Hängt
Router A hinter einem 1412er-Zugang, hat der Babel-Tunnel 1332, ein Gerätetunnel braucht aber mindestens
1280 + 80 = 1360. Die äußeren Pakete des Geräts werden dann zerlegt – das geht, ist aber weniger effizient, und bei
schlechtem Mobilfunk kostet jedes verlorene Bruchstück ein ganzes Paket. Getestet: funktioniert, bei schwachem LTE
aber spürbar langsam. Wenn möglich, Geräte direkt mit Router A verbinden – ins Netz hinter Router B kommen sie von
dort über Babel ohnehin.

## Netzverbindungen zwischen Netzen

Macht ein Netz von **Router A** für Geräte im Netz von **Router B** erreichbar. Typischer Fall: Router A hängt mit
seinem WAN an einer Fritzbox, dahinter steht ein Drucker; Router B ist der eigene Router mit dem Heimnetz. Innerhalb
von Freifunk ist ohnehin alles verbunden – an das Netz hinter einem Router kommt man aber nur mit Tunnel, Routing und
Adressübersetzung.

- **Nur in eine Richtung:** Geräte im Netz von B erreichen das Netz von A, nicht umgekehrt. Router A lässt aus dem
  Tunnel nur das freigegebene Netz zu – nicht sein Internet, nicht das Freifunk-Netz, nicht sich selbst.
- **Nur das Netz von A** geht in den Tunnel; Heimnetz, Freifunk und Internet laufen auf Router B wie bisher.
- **Niemand muss eine Route eintragen:** Router B schickt alles mit seiner Tunneladresse, Router A mit seiner
  eigenen Adresse im freigegebenen Netz (NAT) – der Drucker antwortet einfach seinem Router.
- Nur IPv4.

### Schnellstart

**Router A** – Menü: Netzverbindungen → „+ Netz dieses Routers freigeben“, oder:

```sh
wg_manager netz-neu drucker --netz wan      # WAN freigeben (ohne --netz: WAN)
```

**Router B** – Menü: Netzverbindungen → „+ Zeile vom anderen Router einfügen“, oder:

```sh
wg_manager netz-einfuegen                   # fragt nach der Zeile
```

### Gleiche Netze: das Ersatznetz

Fast jede Fritzbox verteilt 192.168.178.0/24 – das Netz von A ist dann oft auch auf B in Gebrauch. Router B prüft
die Zeile gegen **alle** seine Netze (Client-Netze, WAN, Tunnel, Freifunk), nicht nur gegen den DHCP-Bereich.

- **Keine Überschneidung:** Router B erreicht das Netz von A unter dessen echten Adressen.
- **Überschneidung:** Router B nimmt das **Ersatznetz**, das Router A beim Anlegen zufällig aus 10.201.0.0/16 wählt
  und 1:1 abbildet – die letzte Zahl bleibt gleich: aus Sicht von B ist `10.201.7.25` der Drucker `192.168.178.25`.
  Im Menü fragt Router B vorher nach; mit `--ohne-ersatz` lehnt er stattdessen ab.
- Ist auch das Ersatznetz auf B belegt, lehnt B ab; auf A dann mit `--ersatz <netz>` ein anderes wählen.

**Drucker über das Ersatznetz:** Die automatische Suche (mDNS/Bonjour) geht nicht über geroutete Netze – den Drucker
einmal von Hand einrichten. Manche Drucker nehmen über HTTP/IPP nur Anfragen an ihre eigene Adresse oder ihren Namen
an (Schutz vor DNS-Rebinding) und antworten auf die Ersatzadresse mit „400 Bad Request“. Dann entweder
**Raw/JetDirect** (`socket://10.201.7.25:9100`) nehmen oder den Namen des Druckers im DNS von Router B auf die
Ersatzadresse zeigen lassen und den Drucker über diesen Namen einrichten.

### Was in der Zeile steht

```
wgm-netz1 name=drucker von=hbl-abc-router ep=[2a0b:f4c0:…::4]:51822 netz=192.168.178.0/24 ersatz=10.201.7.0/24 tr=169.254.93.80 pub=… key=… psk=…
```

| Feld | Inhalt |
|---|---|
| `ep` | feste Freifunk-IPv6 und Port von Router A |
| `netz`, `ersatz` | freigegebenes Netz von A und sein Ersatznetz |
| `tr` | Tunneladressen (/30 aus 169.254.0.0/16; A = .1, B = .2) – verlassen den Tunnel nie |
| `key` | **privater Schlüssel von Router B** – die Zeile nur dorthin kopieren |
| `pub`, `psk`, `name`, `von` | wie bei Babel-Verbindungen |

## Alle Befehle

Ohne Angabe öffnet `wg_manager` das Menü; `wg_manager hilfe` zeigt diese Liste mit Optionen.

**Allgemein**

| `wg_manager …` | macht |
|---|---|
| `liste` | Tunnel, Geräte, Babel- und Netzverbindungen mit Status |
| `netze` | Netze des Routers, in die ein Tunnel führen kann (Client-Netze und WAN) |
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

**Netzverbindungen**

| `wg_manager …` | macht |
|---|---|
| `netz-neu <name> [--netz wan\|<netz>] [--ersatz <netz>] [--port N]` | Router A: gibt ein Netz frei, gibt eine Zeile aus |
| `netz-einfuegen ["<zeile>"] [--name N] [--netz "<netz> …"] [--ohne-ersatz]` | Router B: Zeile einfügen, prüft auf gleiche Netze, verbindet sich |
| `netz-zeige <name>` | Zeile erneut ausgeben (Router A) |
| `netz-loeschen <name>` | Netzverbindung entfernen |

`--netz` auf Router B: aus welchen eigenen Netzen man das Netz von A erreichen darf (ohne Angabe: alle Client-Netze).

## Technik

### Was `apply` erzeugt

Alle Einstellungen stehen in `/etc/config/wgmanager`, die Schlüssel in `/etc/wireguard`. Daraus erzeugt
`wg_manager apply`:

- die Schnittstellen und Gegenstellen in `/etc/config/network` (`wg_<tunnel>` für Gerätetunnel, `bb_<name>` für
  Babel-Verbindungen, `nv_<name>` für Netzverbindungen),
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

### Netzverbindungen im Detail

- Router A: Regel „aus `nv_<name>` → Tabelle des freigegebenen Netzes“ (WAN: `main`, Client-Netz: Freifunk-Tabelle),
  Ersatznetz per `dnat ip prefix to` auf das echte Netz, Absender beim Verlassen ins freigegebene Netz per
  `masquerade`. Die Firmware sperrt jede Weiterleitung ins WAN (`oifname <wan> reject`) – wg_manager setzt davor eine
  Freigabe nur für `nv_<name>` → WAN.
- Router B: Route für das Netz von A (bzw. das Ersatznetz) über `nv_<name>` in `main` plus Regel mit Priorität 10,
  damit es nicht über die Freifunk-Tabelle läuft; Antworten aus dem Tunnel über die Freifunk-Tabelle.
- Beide Seiten: neue Verbindungen nur von B nach A, Zugriff auf den Router selbst über den Tunnel gesperrt (nur Ping
  auf die Tunneladresse ist erlaubt, zum Prüfen).
- Die Tunnelpakete von B laufen über Freifunk zur festen Freifunk-IPv6 von A – Router B braucht keinen eigenen
  Internet-Anschluss.

### Eigenheiten der Firmware

- Die Layer-3-Skripte der Firmware löschen jede `wg_`-Schnittstelle ohne eigenen gateway-Eintrag und erzeugen
  `/etc/bird/fff` bei jedem Lauf neu. wg_manager stellt beides beim Start und über den Wächter wieder her; darum
  heißen Babel-Schnittstellen `bb_…`.
- Hat ein Router keinen einzigen Babel-Nachbarn (z. B. nur über wg_manager angebunden), legt die Firmware den Ordner
  `babelpeers/` gar nicht an. bird 2.16.1 (Beta) bricht dann beim Hochfahren ab („Unable to match pattern …: No such
  file or directory“), und procd gibt auf. Ein leerer Ordner stört nicht, und bird 2.15.1 (20241219) ist nicht
  betroffen. wg_manager startet bird in diesem Fall selbst – beim Anwenden und über den Wächter.
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
  4 Sekunden. Laufzeit über LTE 120–150 ms. Neue LTE-Adresse (Fritzbox „Neu verbinden“): beide Tunnel stehen nach
  rund einer Minute wieder, die Router A übernehmen die neue Adresse, ihre Wächter handeln die MTU beim nächsten
  Lauf neu aus. Echter Neustart von Router B: Babel-Nachbarn nach 76 Sekunden.
- **Gerätetunnel zu Router B (Tunnel im Tunnel, 25.10.2026):** Handy über Mobilfunk mit Router B hinter LTE
  verbunden – funktioniert. Wie erwartet werden die Pakete zerlegt (Router B setzt sie zusammen bzw. zerlegt seine
  Antworten selbst). Bei schlechtem LTE-Empfang am Router (Laufzeit 450–1100 ms) war es spürbar langsam, und
  einzelne Pakete gingen verloren, weil ein Bruchstück fehlte. Bei mittelgutem Empfang lief es gut.

- **Netzverbindung und WAN als Netz (27.10.2026):** Router A TL-WDR4900 v1 (layer3-20250321-beta) gibt sein WAN
  (Fritzbox-Netz 192.168.178.0/24) frei, Router B EdgeRouter X (layer3-20241219) hat im Heimnetz denselben Bereich –
  B erkennt das und nimmt das Ersatznetz. Aus dem Heimnetz: Ping, Weboberfläche, IPP (631) und Raw-Druck (9100) des
  Druckers erreichbar; IPP nimmt der Drucker nur unter seinem eigenen Namen an (siehe oben). Gegenproben: kein
  Zugriff auf die Router über den Tunnel (Zähler der Sperren steigen), kein Weg von A ins Heimnetz, kein Internet über
  A, aus dem Freifunk-Netz nicht erreichbar; ein Router mit eigenem 192.168.178.0/24 lehnt mit `--ohne-ersatz` ab und
  hinterlässt nichts. Gerätetunnel mit Netz `wan`: Testgerät erreicht Drucker und Fritzbox hinter Router A.

Rückmeldungen von anderen Routern und Anschlüssen (LTE, Richtfunk) sind willkommen.

## Entwicklung

`wg_install.txt` wird aus `wg_manager` gebaut:

```sh
./make-install.sh
```

Das Skript darf **keine Tabulatoren** enthalten: busybox ash verschluckt sie beim Einfügen in die SSH-Sitzung.
Eingerückt wird mit vier Leerzeichen.

## Versionen

- **2.5** (27.10.2026) – Menü mit Pfeiltasten, Enter und Esc für alle Funktionen: Assistenten zum Anlegen,
  Einstellungen mit aktuellem Wert, Netzauswahl per Häkchen, Sicherheitsabfrage beim Löschen; ohne Zusatzprogramme.
  Das Zahlenmenü bleibt als `menue-einfach`, alle Befehle bleiben unverändert.
- **2.4** (27.10.2026) – Netzverbindungen zwischen Netzen (`netz-neu`, `netz-einfuegen`, Überschneidungsprüfung gegen
  alle Netze des Routers, Ersatznetz mit 1:1-Abbildung, nur in eine Richtung); Gerätetunnel nur noch in Client-Netze
  und das WAN (neu wählbar), Babel-/Mesh-/Tunnelschnittstellen werden abgelehnt.
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
