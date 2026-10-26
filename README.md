<div align="center">

# 🧹 srt-clean

**Free up space on your Mac with one command, without losing anything you need.**

![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## 🚀 Quick start

Open **Terminal**, paste this line and press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh | bash
```

That's it. You don't need to install anything. srt-clean scans your Mac, shows you what it found and how big it is, and asks before it deletes anything:

```
Delete these? (y/n)
```

Type `y` to clean, or `n` to leave everything as it is.

> The first run can take a minute while it scans every app.

### Just want to look?

Add `--dry-run` to see the list without deleting anything:

```bash
curl -fsSL https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh | bash -s -- --dry-run
```

---

## 🧽 What it cleans

srt-clean finds these on its own, for **every app** on your Mac. You don't need to tell it which apps you use.

| What | Where it looks | Examples |
|---|---|---|
| App caches | `~/Library/Caches` | Chrome, Adobe, Spotify, Homebrew, pip |
| Browser and Electron app caches | `Cache`, `Code Cache`, `GPUCache` folders in `~/Library/Application Support` | Chrome, Discord, Slack, VS Code, Teams |
| Video editing render caches | `~/Movies`, Adobe media cache | Premiere Pro, After Effects, Final Cut Pro, DaVinci Resolve |
| Logs and crash reports | `~/Library/Logs` | Every app |
| Developer build files | Xcode `DerivedData`, npm cache | Xcode, Node.js |

All of these are **temporary files**. Apps rebuild them automatically when they need them.

## 🛡️ What it never touches

- Your documents, photos, videos, music and projects
- Passwords, logins, cookies, bookmarks and browser history
- Original media and proxies in Final Cut libraries
- Apple system caches
- The Trash. Empty it yourself when you're ready.

## 🧠 How it stays safe

- **Running apps are skipped.** Before it deletes anything, srt-clean checks which apps are open and which files they're using. It leaves those caches alone, so nothing breaks while you work.
- **It asks first.** You see the full list and the total size before anything is deleted.
- **Big decisions stay yours.** Large apps you haven't opened in 90+ days and leftover installers (`.dmg`, `.pkg`) are **listed only**, never deleted.

## 📋 Example output

```
=== srt-clean: Mac cache cleanup ===
Free space now: 42.3 GB
Scanning... (this can take a moment)

These caches can be removed (58 items, 6.4 GB total). Largest:
     2.1 GB  ~/Library/Caches/Google
     1.3 GB  ~/Library/Application Support/Adobe/Common/Media Cache Files
     812 MB  ~/Movies/CacheClip
  ...

Skipped 12 items because their app is running. Quit those apps and run again to free more.

Delete these? (y/n) y
✓ Done! Freed: 6.4 GB

Not deleted, review these yourself:
  App           5.0 GB  Adobe Media Encoder 2025 (not opened in 214 days)
  Installer     1.2 GB  ~/Downloads/Xcode_16.dmg
```

## 💡 Tips

- **Quit your apps first** (`⌘ + Q`, not just closing the window). srt-clean can then clean their caches too.
- **Run it once a month** or whenever your disk is getting full.
- Caches grow back over time as you use your apps. That's normal.

## 📦 Run it from a file

If you'd rather download it first:

```bash
curl -fsSL -o srt-clean.sh https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh
bash srt-clean.sh
```

## ✅ Requirements

- macOS (tested on macOS 15 Sequoia)
- Nothing to install. It only uses tools that come with every Mac.

## 📄 License

[MIT](LICENSE). Free to use, share and change.
