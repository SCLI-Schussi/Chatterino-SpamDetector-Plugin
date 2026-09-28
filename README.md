# 🛡️ Chatterino SpamDetector Plugin (v1.2.0)

Spam-Schutz für wiederholte Nachrichten mit ähnlichen Textmustern im Twitch-Chat – als leichtgewichtiges Lua-Plugin für **Chatterino**.

![Version](https://img.shields.io/badge/Version-1.2.0-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Chatterino](https://img.shields.io/badge/Chatterino-Nightly-orange)
![Language](https://img.shields.io/badge/Language-Lua-000080)

---

## 🚀 Features

- **Mustererkennung (Levenshtein-Algorithmus):** Erkennt nicht nur identische Nachrichten, sondern auch Spams mit leicht geänderten Satzzeichen, Leerzeichen oder Groß-/Kleinschreibung.
- **Einstellbarer Schwellenwert:** Warnt automatisch ab einer Ähnlichkeit von **75 %**.
- **Flexible Steuerung:** Das Plugin startet standardmäßig im deaktivierten Zustand. Es kann pro Chat-Tab mit Befehlen (`/sg on` / `/sg off`) flexibel an- und ausgeschaltet werden.
- **System-Warnungen:** Gibt bei erkanntem Spam direkt im Chat eine hervorgehobene Warnmeldung inklusive Prozentwert der Übereinstimmung aus.

---

## 📥 Installation

> [!IMPORTANT]
> Dieses Plugin benötigt zwingend **Chatterino Nightly**, da es neuere Lua-API-Hooks (`on_message_appended`) verwendet.

1. **Chatterino Nightly nutzen:**
   - Lade dir die neueste `chatterino-windows-x86-64-Qt-*.zip` von den offiziellen Chatterino Nightly Builds herunter und entpacke sie.

2. **Plugins aktivieren:**
   - Öffne Chatterino und drücke `Strg + P` (Einstellungen).
   - Gehe zum Reiter **Plugins** und setze ein Häkchen bei **Enable plugins**.

3. **Plugin-Ordner einrichten:**
   - Drücke `Win + R`, gib folgenden Pfad ein und drücke Enter:
     ```text
     %APPDATA%\Chatterino2\Plugins
     ```
   - Erstelle dort einen Ordner namens `SpamDetector` und platziere die Projektdateien darin:
     ```text
     %APPDATA%\Chatterino2\Plugins\SpamDetector\
     ├── info.json
     ├── init.lua
     ├── LICENSE
     └── README.md
     ```

---

## 🎮 Nutzung & Befehle

Beim Starten oder Neuladen von Chatterino ist der Spam-Detector zunächst **deaktiviert**. Du kannst den Schutz in jedem Chat-Tab einzeln steuern:

| Befehl | Beschreibung |
| :--- | :--- |
| `/sg on` oder `/spamguard on` | Aktiviert den Spam-Detector für den aktuellen Chat (`🛡️ Spam-Detector aktiviert!`) |
| `/sg off` oder `/spamguard off` | Deaktiviert den Spam-Detector für den aktuellen Chat (`🛡️ Spam-Detector deaktiviert!`) |
| `/sg` oder `/spamguard` | Zeigt den aktuellen Status des Spam-Detectors an |

---

## 👤 Autor & Lizenz

- **Autor:** [SCLI | Schussi](https://github.com/SCLI-Schussi)
- **Repository:** [SCLI-Schussi/SpamDetector](https://github.com/SCLI-Schussi/SpamDetector)
- **Lizenz:** Dieses Projekt steht unter der [MIT License](LICENSE).