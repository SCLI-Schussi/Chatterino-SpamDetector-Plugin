<<<<<<<<< Temporary merge branch 1
# 🛡️ Chatterino SpamDetector Plugin (v1.5.1)

Protects Twitch chat from repeated messages with similar text patterns. A lightweight Lua plugin for **Chatterino**.

![Version](https://img.shields.io/badge/Version-1.5.1-blue)
=========
# 🛡️ Chatterino SpamDetector Plugin (v1.5.2)

Protects Twitch chat from repeated messages with similar text patterns. A lightweight Lua plugin for **Chatterino**.

![Version](https://img.shields.io/badge/Version-1.5.2-blue)
>>>>>>>>> Temporary merge branch 2
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Chatterino](https://img.shields.io/badge/Chatterino-Nightly-orange)
![Language](https://img.shields.io/badge/Language-Lua-000080)

---

## 🚀 Features

- **Similarity detection:** Compares messages using Levenshtein distance and word similarity to identify repeated messages with small variations.
- **Multiple detection criteria:** Looks for repeated similar messages and uses an additional spam score to detect slower spam.
- **Auto-attaches on startup:** Automatically starts monitoring in all open chat tabs when Chatterino starts.
- **Excludes Moderators, Broadcasters & Bots:** Recognizes moderators (incl. lead mods, staff/admins) and bots purely by their chat badge (Twitch *Chat Bot* badge), so look-alike names can't dodge detection. The broadcaster and your own messages are ignored too. Use `/sg ignore <user>` for bots without a badge. VIPs and subscribers stay monitored.
- **Fresh sessions:** Starts completely fresh every time Chatterino opens without storing chat history across sessions.
- **Per-chat controls:** Enable or disable protection separately in each chat tab.
- **Chat warnings:** Displays a highlighted warning with the user's name and similarity score when spam is detected.

---

## 📥 Installation

> [!IMPORTANT]
> This plugin requires **Chatterino Nightly** because it uses the newer Lua API hook `on_message_appended`.

### 1. Install Chatterino Nightly

Download and extract a recent Chatterino Nightly build. The regular stable version may not support the required plugin hook.

### 2. Enable plugins

1. Open Chatterino and press `Ctrl + P` to open the settings.
2. Open the **Plugins** tab and enable **Enable plugins**.

### 3. Download and install the plugin

1. Open this repository's [Releases](https://github.com/SCLI-Schussi/SpamDetector/releases).
2. Download `SpamDetector.zip` under **Assets**.
3. Press `Win + R`, enter the following path, and confirm:

   ```text
   %APPDATA%\Chatterino2\Plugins
   ```

4. Extract `SpamDetector.zip` into this folder. Make sure the files are directly inside the plugin folder:

   ```text
   %APPDATA%\Chatterino2\Plugins\SpamDetector\
   ├── info.json
   ├── init.lua
   ├── LICENSE
   └── README.md
   ```

   If extraction creates an extra `SpamDetector` subfolder, move the inner plugin folder so that `init.lua` is directly inside the path shown above.

---

## 🎮 Usage & Commands

The plugin auto-attaches silently to all open chat tabs upon startup. You can configure or toggle it at any time using:

| Command | Description |
| --- | --- |
| `/sg` or `/spamguard` | Toggles the Spam Detector in the current chat tab. |
| `/sg on` or `/spamguard on` | Enables the Spam Detector for the current chat tab. |
| `/sg off` or `/spamguard off` | Disables the Spam Detector for the current chat tab. |
| `/sg status` or `/spamguard status` | Shows status, monitored users, flagged spammers, cached mods, and exclusions. |
| `/sg clear` or `/spamguard clear` | Clears the detection history, scores, and mod cache for the current chat tab. |
| `/sg mods on` or `/sg mods off` | Toggles moderator and broadcaster exclusion (default: `on`). |
| `/sg bots on` or `/sg bots off` | Toggles Twitch bot exclusion (default: `on`). |
| `/sg ignore <user>` | Manually adds a user to the ignore list. |
| `/sg unignore <user>` | Removes a user from the ignore list. |
| `/sg test <text>` or `/spamguard test <text>` | Sends a test message through the detector. |
| `/sg help` or `/spamguard help` | Shows a brief command summary in chat. |

---

## 👤 Author & License

- **Author:** [SCLI | Schussi](https://github.com/SCLI-Schussi)
- **Repository:** [SCLI-Schussi/SpamDetector](https://github.com/SCLI-Schussi/SpamDetector)
- **License:** This project is licensed under the [MIT License](LICENSE).
