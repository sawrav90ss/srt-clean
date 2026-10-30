<div align="center">

# 🧹 srt-clean

**Free up space on your Mac or Windows PC with one command, without losing anything you need.**

![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=windows11&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</div>

---

## 🚀 Quick start

### 🍎 Mac

Open **Terminal**, paste this line and press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh | bash
```

### 🪟 Windows

Open **PowerShell** (press the Windows key, type `PowerShell`, press Enter), paste this line and press **Enter**:

```powershell
irm https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.ps1 | iex
```

> **Tip:** right-click PowerShell and choose **Run as administrator** to also clean Windows temp files and Windows Update leftovers.

That's it. You don't need to install anything. srt-clean scans your computer, shows you what it found and how big it is, and asks before it deletes anything:

```
Delete these? (y/n)
```

Type `y` to clean, or `n` to leave everything as it is.

> The first run can take a minute while it scans every app.

### Just want to look?

See the list without deleting anything:

```bash
# Mac
curl -fsSL https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh | bash -s -- --dry-run
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.ps1))) -DryRun
```

---

## 🧽 What it cleans

srt-clean finds these on its own, for **every app** on your computer. You don't need to tell it which apps you use.

### 🍎 Mac

| What | Where it looks | Examples |
|---|---|---|
| App caches | `~/Library/Caches` | Chrome, Adobe, Spotify, Homebrew, pip |
| Browser and Electron app caches | `Cache`, `Code Cache`, `GPUCache` folders in `~/Library/Application Support` | Chrome, Discord, Slack, VS Code, Teams |
| Video editing render caches | `~/Movies`, Adobe media cache | Premiere Pro, After Effects, Final Cut Pro, DaVinci Resolve |
| Logs and crash reports | `~/Library/Logs` | Every app |
| Developer build files | Xcode `DerivedData`, npm cache | Xcode, Node.js |

### 🪟 Windows

| What | Where it looks | Examples |
|---|---|---|
| Temp files older than a day | `%TEMP%` | Installers, apps, Windows |
| Browser and app caches | `Cache`, `Code Cache`, `GPUCache`, `cache2` folders in `AppData` | Chrome, Edge, Firefox, Discord, Slack, VS Code |
| Graphics shader caches | `DXCache`, `GLCache`, `D3DSCache` | NVIDIA, AMD, DirectX games |
| Video editing caches | Adobe media cache, `CacheClip` | Premiere Pro, After Effects, DaVinci Resolve |
| Crash dumps and error reports | `CrashDumps`, `WER` | Every app |
| Developer caches | npm, pip, yarn | Node.js, Python |
| **As administrator:** system leftovers | `Windows\Temp`, Windows Update downloads, Delivery Optimization | Windows |

All of these are **temporary files**. Apps rebuild them automatically when they need them.

## 🛡️ What it never touches

- Your documents, photos, videos, music and projects
- Passwords, logins, cookies, bookmarks and browser history
- Original media and proxies in Final Cut libraries
- Apple system caches
- The Trash on Mac and the Recycle Bin on Windows. Empty them yourself when you're ready.

## 🧠 How it stays safe

- **Running apps are skipped.** Before it deletes anything, srt-clean checks which apps are open. It leaves their caches alone, so nothing breaks while you work.
- **Double check on Windows.** Right before deleting a folder, srt-clean tries to rename it. Windows refuses that while any program is using a file inside, and srt-clean then leaves the folder alone.
- **It asks first.** You see the full list and the total size before anything is deleted.
- **Big decisions stay yours.** Large apps, leftover installers (`.dmg`, `.pkg`, `.exe`, `.msi`, `.iso`), the Recycle Bin and `Windows.old` are **listed only**, never deleted.

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

- **Quit your apps first** (`⌘ + Q` on Mac; on Windows, also quit apps from the system tray). srt-clean can then clean their caches too.
- **Run it once a month** or whenever your disk is getting full.
- Caches grow back over time as you use your apps. That's normal.

## 📦 Run it from a file

If you'd rather download it first:

```bash
# Mac
curl -fsSL -o srt-clean.sh https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh
bash srt-clean.sh
```

```powershell
# Windows
irm https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.ps1 -OutFile srt-clean.ps1
powershell -ExecutionPolicy Bypass -File .\srt-clean.ps1
```

## ✅ Requirements

- **Mac:** macOS (tested on macOS 15 Sequoia)
- **Windows:** Windows 10 or 11 with the built-in PowerShell
- Nothing to install. It only uses tools that come with your computer.

## 📄 License

[MIT](LICENSE). Free to use, share and change.
