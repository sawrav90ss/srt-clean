#!/bin/bash
# srt-clean — safe cache cleaner for macOS
# https://github.com/sawrav90ss/srt-clean
#
# Finds cache folders from every app on its own and removes only what apps
# rebuild automatically: caches, logs, render caches, build files.
# Skips caches of apps that are running right now.
# Never touches documents, photos, videos, projects, passwords or logins.
# Large unused apps and leftover installers are only listed, never deleted.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.sh | bash
#   bash srt-clean.sh             # show the list, delete after you type "y"
#   bash srt-clean.sh --dry-run   # only show the list, delete nothing

shopt -s nullglob
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

if [ "$(uname)" != "Darwin" ]; then
  echo "srt-clean only works on macOS."
  exit 1
fi

AS="$HOME/Library/Application Support"
free_kb() { df -k / | awk 'NR==2{print $4}'; }
hr() { awk -v k="$1" 'BEGIN{ if (k >= 1048576) printf "%.1f GB", k/1048576; else printf "%.0f MB", k/1024 }'; }

echo "=== srt-clean: Mac cache cleanup ==="
echo "Free space now: $(hr "$(free_kb)")"
echo "Scanning... (this can take a moment)"

# Files that are open right now. An open file inside a folder means its app is running.
OPEN=$(lsof -u "$(id -u)" -Fn 2>/dev/null | sed -n 's/^n//p' | grep "^$HOME/" | sort -u)
in_use() {
  awk -v p="$1" 'index($0, p) == 1 && (length($0) == length(p) || substr($0, length(p) + 1, 1) == "/") { f = 1; exit }
                 END { exit !f }' <<< "$OPEN"
}

# Names and bundle IDs of running apps (from macOS lsappinfo)
lc() { tr '[:upper:]' '[:lower:]' <<< "$1"; }
APPINFO=$(lsappinfo list 2>/dev/null)
APPS=$(sed -n 's/^ *[0-9]*) "\(.*\)" ASN.*/\1/p' <<< "$APPINFO" | tr '[:upper:]' '[:lower:]')
IDS=$(sed -n 's/.*bundleID="\([^"]*\)".*/\1/p' <<< "$APPINFO" | tr '[:upper:]' '[:lower:]')

# Does this folder belong to a running app? Matches "Application Support/<App>"
# or "Caches/<bundle id>" against running app names and bundle IDs.
app_running_for() {
  local rel c1 c2 b id
  case "$1" in
    "$AS"/*)
      rel="${1#"$AS"/}"; c1="${rel%%/*}"; c2="${rel#*/}"; c2="${c2%%/*}"
      grep -qxF -e "$(lc "$c1")" -e "$(lc "$c1 $c2")" <<< "$APPS" ;;
    "$HOME/Library/Caches"/*)
      b=$(lc "$(basename "$1")")
      while IFS= read -r id; do
        [ -n "$id" ] && case "$b" in "$id"|"$id".*) return 0 ;; esac
      done <<< "$IDS"
      return 1 ;;
    */DerivedData/*) grep -qx "xcode" <<< "$APPS" ;;
    */CacheClip) grep -q "davinci resolve" <<< "$APPS" ;;
    *) return 1 ;;
  esac
}

ITEMS=(); SIZES=(); SKIPPED=()
# add <path> [guard]: skip if its app is running or the guard folder has open files
add() {
  local p="$1" g="${2:-$1}" k
  [ -e "$p" ] || return
  if in_use "$p" || in_use "$g" || app_running_for "$p"; then SKIPPED+=("$p"); return; fi
  k=$(du -sk "$p" 2>/dev/null | cut -f1)
  [ "${k:-0}" -gt 0 ] || return
  ITEMS+=("$p"); SIZES+=("$k")
}

# 1) Every app's cache folder (Apple system caches are left alone)
for p in "$HOME/Library/Caches"/*; do
  case "$(basename "$p")" in com.apple.*|CloudKit|FamilyCircle) continue ;; esac
  add "$p"
done

# 2) Caches of Chrome, Discord, Slack, VS Code and other Chromium/Electron apps,
#    plus Adobe media cache. Found by folder type, not app name. If the folder
#    next to the cache (the app profile) has open files, the app is running.
while IFS= read -r -d '' p; do add "$p" "$(dirname "$p")"; done < <(
  find "$AS" -maxdepth 4 -type d \( -name Cache -o -name "Code Cache" -o -name GPUCache \
    -o -name ShaderCache -o -name GrShaderCache -o -name GraphiteDawnCache -o -name DawnGraphiteCache \
    -o -name DawnWebGPUCache -o -name CachedData -o -name "Media Cache Files" -o -name "Media Cache" \) \
    -not -path "*/Claude/vm_bundles/*" -prune -print0 2>/dev/null)

# 3) Video editor render caches (Final Cut "Render Files", DaVinci "CacheClip").
#    Skipped while the Final Cut library is open.
while IFS= read -r -d '' p; do add "$p" "${p%%.fcpbundle/*}.fcpbundle"; done < <(
  find "$HOME/Movies" -maxdepth 3 \( -name CacheClip -o -path "*.fcpbundle/*/Render Files" \) \
    -prune -print0 2>/dev/null)

# 4) Logs and crash reports, Xcode build files, npm download cache
for p in "$HOME/Library/Logs"/* "$HOME/Library/Developer/Xcode/DerivedData"/* "$HOME/.npm/_cacache"; do add "$p"; done

# --- Show the list ---
total=0
for k in "${SIZES[@]}"; do total=$((total + k)); done
echo
if [ ${#ITEMS[@]} -eq 0 ]; then
  echo "Nothing to clean."
else
  echo "These caches can be removed (${#ITEMS[@]} items, $(hr $total) total). Largest:"
  for i in "${!ITEMS[@]}"; do printf '%s\t%s\n' "${SIZES[$i]}" "${ITEMS[$i]/#$HOME/~}"; done |
    sort -rn | awk -F'\t' '$1 >= 1024' | head -20 | while IFS=$'\t' read -r k p; do printf '  %9s  %s\n' "$(hr "$k")" "$p"; done
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo
  echo "Skipped ${#SKIPPED[@]} items because their app is running. Quit those apps and run again to free more."
fi

# --- Ask before deleting ---
if [ ${#ITEMS[@]} -gt 0 ] && [ $DRY -eq 0 ]; then
  echo
  printf "Delete these? (y/n) "
  # Read the answer from the keyboard, even when the script itself comes from curl.
  # With no keyboard at all, answer "n" so nothing is deleted.
  ans=n
  { read -r ans < /dev/tty; } 2>/dev/null || { [ -t 0 ] && read -r ans; }
  if [[ "$ans" =~ ^[Yy] ]]; then
    before=$(free_kb)
    for p in "${ITEMS[@]}"; do rm -rf "$p" 2>/dev/null; done
    echo "✓ Done! Freed: $(hr $(( $(free_kb) - before )))"
  else
    echo "Nothing deleted."
  fi
elif [ $DRY -eq 1 ]; then
  echo
  echo "(Dry run, nothing deleted)"
fi

# --- Only listed, never deleted: your call ---
echo
echo "Not deleted, review these yourself:"
now=$(date +%s)
for app in /Applications/*.app /Applications/*/*.app; do
  d=$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)
  if [ -z "$d" ] || [ "$d" = "(null)" ]; then
    days=9999
  else
    t=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$d" +%s 2>/dev/null) || continue
    days=$(( (now - t) / 86400 ))
  fi
  [ $days -ge 90 ] || continue
  k=$(du -sk "$app" 2>/dev/null | cut -f1)
  [ "${k:-0}" -ge 204800 ] || continue
  if [ $days -eq 9999 ]; then when="never opened"; else when="not opened in $days days"; fi
  printf '%s\t%s\t%s\n' "$k" "$(basename "$app" .app)" "$when"
done | sort -rn | head -10 | while IFS=$'\t' read -r k n w; do
  printf '  App        %9s  %s (%s)\n' "$(hr "$k")" "$n" "$w"
done
find "$HOME/Downloads" "$HOME/Desktop" -maxdepth 2 \( -iname "*.dmg" -o -iname "*.pkg" -o -iname "*.ipsw" \) -size +20M 2>/dev/null |
  while IFS= read -r f; do printf '%s\t%s\n' "$(du -sk "$f" | cut -f1)" "$f"; done | sort -rn | head -10 |
  while IFS=$'\t' read -r k f; do printf '  Installer  %9s  %s\n' "$(hr "$k")" "${f/#$HOME/~}"; done
echo "  (If you don't need them, move apps and installers to the Trash in Finder.)"
echo
echo "Free space now: $(hr "$(free_kb)")"
