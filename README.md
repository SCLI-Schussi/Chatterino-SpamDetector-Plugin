# 🛡️ Chatterino SpamDetector Plugin (v1.2.1)

Spam-Schutz für wiederholte Nachrichten mit ähnlichen Textmustern im Twitch-Chat – als leichtgewichtiges Lua-Plugin für **Chatterino**.

![Version](https://img.shields.io/badge/Version-1.2.0-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Chatterino](https://img.shields.io/badge/Chatterino-Nightly-orange)
![Language](https://img.shields.io/badge/Language-Lua-000080)

---

## 🚀 Features

- **Ähnlichkeitserkennung:** Vergleicht Nachrichten mit Levenshtein-Distanz und Wortähnlichkeit, um wiederholte Nachrichten mit kleinen Abweichungen zu erkennen.
- **Mehrere Erkennungskriterien:** Berücksichtigt wiederholte ähnliche Nachrichten sowie einen zusätzlichen Spam-Score für langsameres Spammen.
- **Schwellenwerte:** Die Erkennung verwendet standardmäßig eine Ähnlichkeitsschwelle von **76 %** und einen Score-Grenzwert von **80**.
- **Steuerung pro Chat:** Der Schutz lässt sich in jedem Chat-Tab einzeln aktivieren und deaktivieren.
- **Chat-Warnungen:** Bei erkanntem Spam erscheint eine hervorgehobene Warnung mit Nutzername und Ähnlichkeitswert.

---

## 📥 Installation

> [!IMPORTANT]
> Das Plugin benötigt **Chatterino Nightly**, da es den neueren Lua-API-Hook `on_message_appended` verwendet.

### 1. Chatterino Nightly installieren

Lade einen aktuellen Chatterino-Nightly-Build von den offiziellen Nightly Builds herunter und entpacke ihn. Die reguläre stabile Version unterstützt den benötigten Plugin-Hook möglicherweise nicht.

### 2. Plugins aktivieren

1. Öffne Chatterino und drücke `Strg + P`, um die Einstellungen zu öffnen.
2. Öffne den Reiter **Plugins** und aktiviere **Enable plugins**.

### 3. Plugin herunterladen und installieren

1. Öffne die [Releases](https://github.com/SCLI-Schussi/SpamDetector/releases) dieses Repositories.
2. Lade unter **Assets** die Datei `SpamDetector.zip` herunter.
3. Drücke `Win + R`, gib den folgenden Pfad ein und bestätige:

   ```text
   %APPDATA%\Chatterino2\Plugins
   ```

4. Entpacke `SpamDetector.zip` in diesen Ordner. Prüfe danach, dass die Dateien direkt im Plugin-Ordner liegen:

   ```text
   %APPDATA%\Chatterino2\Plugins\SpamDetector\
   ├── info.json
   ├── init.lua
   ├── LICENSE
   └── README.md
   ```

   Falls beim Entpacken ein zusätzlicher Unterordner `SpamDetector` entsteht, verschiebe den inneren Plugin-Ordner so, dass `init.lua` direkt unter dem oben gezeigten Pfad liegt.

---

## 🎮 Nutzung & Befehle

Der Spam-Detector wird für jeden Chat-Tab separat eingerichtet. Aktiviere ihn nach dem Laden des Plugins in jedem gewünschten Tab mit `/sg on` oder `/spamguard on`. Nach einem Neustart oder Neuladen des Plugins musst du das für die Tabs erneut ausführen.

| Befehl | Beschreibung |
| --- | --- |
| `/sg on` oder `/spamguard on` | Aktiviert den Spam-Detector im aktuellen Chat-Tab. |
| `/sg off` oder `/spamguard off` | Deaktiviert den Spam-Detector im aktuellen Chat-Tab. |
| `/sg` oder `/spamguard` | Schaltet den Spam-Detector im aktuellen Chat-Tab um. |
| `/sg status` oder `/spamguard status` | Zeigt Status, erkannte Nutzer und Schwellenwerte an. |
| `/sg clear` oder `/spamguard clear` | Setzt den Erkennungs-Cache des aktuellen Chat-Tabs zurück. |
| `/sg test <text>` oder `/spamguard test <text>` | Übergibt einen Testtext an die Erkennung. |
| `/sg help` oder `/spamguard help` | Zeigt eine kurze Befehlsübersicht im Chat an. |

---

## 📦 Release erstellen

Maintainer können ein Release erstellen, indem sie die Versionsnummer in `info.json` aktualisieren, die Änderung nach GitHub pushen und anschließend einen passenden Versions-Tag erstellen. Version und Tag müssen übereinstimmen, zum Beispiel `1.2.1` und `v1.2.1`.

```powershell
git tag v1.2.1
git push origin v1.2.1
```

GitHub Actions erstellt daraufhin automatisch das Release mit generierten Release-Notizen und der Datei `SpamDetector.zip`. Die ZIP-Datei enthält den Plugin-Ordner `SpamDetector` und kann direkt nach `%APPDATA%\Chatterino2\Plugins` entpackt werden.

---

## 👤 Autor & Lizenz

- **Autor:** [SCLI | Schussi](https://github.com/SCLI-Schussi)
- **Repository:** [SCLI-Schussi/SpamDetector](https://github.com/SCLI-Schussi/SpamDetector)
- **Lizenz:** Dieses Projekt steht unter der [MIT License](LICENSE).