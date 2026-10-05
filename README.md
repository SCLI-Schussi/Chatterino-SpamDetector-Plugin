# 🛡️ Chatterino SpamDetector Plugin (v1.2.7)

Protects Twitch chat from repeated messages with similar text patterns. A lightweight Lua plugin for **Chatterino**.

![Version](https://img.shields.io/badge/Version-1.2.7-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Chatterino](https://img.shields.io/badge/Chatterino-Nightly-orange)
![Language](https://img.shields.io/badge/Language-Lua-000080)

---

## 🚀 Features

- **Similarity detection:** Compares messages using Levenshtein distance and word similarity to identify repeated messages with small variations.
- **Multiple detection criteria:** Looks for repeated similar messages and uses an additional spam score to detect slower spam.
- **Detection thresholds:** Uses a default similarity threshold of **76%** and a score threshold of **80**.
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

The Spam Detector is configured separately for each chat tab. After loading the plugin, activate it in each tab with `/sg on` or `/spamguard on`. Repeat this after restarting Chatterino or reloading the plugin.

| Command | Description |
| --- | --- |
| `/sg on` or `/spamguard on` | Enables the Spam Detector in the current chat tab. |
| `/sg off` or `/spamguard off` | Disables the Spam Detector in the current chat tab. |
| `/sg` or `/spamguard` | Toggles the Spam Detector in the current chat tab. |
| `/sg status` or `/spamguard status` | Shows the status, tracked users, and detection thresholds. |
| `/sg clear` or `/spamguard clear` | Clears the detection history for the current chat tab. |
| `/sg test <text>` or `/spamguard test <text>` | Sends a test message through the detector. |
| `/sg help` or `/spamguard help` | Shows a brief command summary in chat. |

---

## 📦 Creating a release

Maintainers can create a release by updating the version in `info.json`, pushing the change to GitHub, and creating a matching version tag. The version and tag must match, for example `1.2.1` and `v1.2.1`.

```powershell
git tag v1.2.1
git push origin v1.2.1
```

GitHub Actions will automatically create the release with generated release notes and the `SpamDetector.zip` file. The ZIP contains the `SpamDetector` plugin folder and can be extracted directly into `%APPDATA%\Chatterino2\Plugins`.

---

## 👤 Author & License

- **Author:** [SCLI | Schussi](https://github.com/SCLI-Schussi)
- **Repository:** [SCLI-Schussi/SpamDetector](https://github.com/SCLI-Schussi/SpamDetector)
- **License:** This project is licensed under the [MIT License](LICENSE).