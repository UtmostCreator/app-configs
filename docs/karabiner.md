
## What your macOS → Windows 10 “muscle memory” mappings do (Karabiner profile)

**Profile name:** `Windows muscle memory (no Ctrl/Cmd swap)`
**Core idea:** keep macOS modifiers as-is, but **translate common Windows shortcuts (Ctrl / Alt / Win)** into the **native macOS equivalents (Cmd / Option / Fn+Ctrl)** — with smart **app-based exceptions** so terminals and IDEs do not break.

---

## 1) Text editing: Windows-style word navigation + selection

Applies **everywhere except terminals** (Terminal / iTerm2 / Warp / WezTerm / Alacritty / Kitty, etc.)
* **Ctrl + ← / →** → **Option + ← / →**
  *(move by word like Windows Ctrl+Arrow)*
* **Ctrl + Shift + ← / →** → **Option + Shift + ← / →**
  *(select by word like Windows)*
✅ Result: text cursor behavior matches Windows in most apps, without harming terminal keybinds.

---

## 2) Browser shortcuts: Windows parity across Chrome/Brave/Edge + Firefox/Safari


### Private/Incognito window

* **Ctrl + Shift + N** → **Cmd + Shift + N**
  *(Incognito/Private window for Chrome/Brave/Edge + Firefox/Safari)*

### Chromium “Windows parity pack” (Chrome/Brave/Edge)

* **Ctrl + J** → **Cmd + Shift + J** *(Downloads)*
* **Ctrl + H** → **Cmd + Y** *(History in Chromium)*
* **Ctrl + Shift + Delete** (both backspace + forward delete variants) → **Cmd + Shift + Delete** *(Clear browsing data)*
* **Zoom controls**
  * **Ctrl + =** → **Cmd + Shift + =** *(Zoom in)*
  * **Ctrl + -** → **Cmd + -** *(Zoom out; multiple variants covered incl. keypad minus)*
  * **Ctrl + 0** → **Cmd + 0** *(Reset zoom)*

### Cross-browser “Windows browser pack” (Chrome/Brave/Edge/Firefox/Safari)

* **Ctrl + T** → **Cmd + T** *(New tab)*
* **Ctrl + Shift + T** → **Cmd + Shift + T** *(Reopen closed tab)*
* **Ctrl + W** → **Cmd + W** *(Close tab/window)*
* **Ctrl + Tab** → **Cmd + Option + →** *(Next tab)*
* **Ctrl + Shift + Tab** → **Cmd + Option + ←** *(Previous tab)*
* **Ctrl + R** → **Cmd + R** *(Refresh)*
* **Ctrl + Shift + R** → **Cmd + Shift + R** *(Hard reload equivalent)*
* **Alt + ← / →** → **Cmd + [ / ]** *(Back/Forward in history)*

### Devtools + Address bar

* **Ctrl + Shift + C** → **Cmd + Option + C** *(Inspect element)*
* **Alt + D** → **Cmd + L** *(Focus address bar)*
* **Ctrl + L** → **Cmd + L** *(Focus address bar)*
✅ Result: browsers behave *extremely* close to Windows muscle memory.

---

## 3) Microsoft Teams: one-key mute toggle

Only in Teams:
* **Option + A** → **Cmd + Shift + M** *(Mute / Unmute)*

---

## 4) Laptop keys: Home/End/Delete/Insert like Windows keyboards

System-wide:
* **Fn + ←** → **Home**
* **Fn + →** → **End**
* **Fn + Backspace** → **Delete Forward**
* **Fn + I** → **Insert**
✅ Result: laptop layout feels like a PC keyboard.

---

## 5) App switching: Alt+Tab like Windows

System-wide:
* **Alt + Tab** → **Cmd + Tab**
* **Alt + Shift + Tab** → **Cmd + Shift + Tab**
✅ Result: Windows-style task switching works naturally on macOS.

---

## 6) Window snapping / tiling: Win+Arrow like Windows 10

You treat **Right Command** as **Windows (Win)** key.
* **Right Cmd + Arrow** → **Fn + Ctrl + Arrow** *(macOS tiling / stage manager window move behavior)*
* **Right Cmd + Shift + Arrow** → **Fn + Ctrl + Shift + Arrow** *(shift-modified variant)*
✅ Result: “Win+Arrow snapping” muscle memory is recreated via macOS window tiling shortcuts.

---

## 7) Close behavior: Alt+F4 like Windows

System-wide:
* **Alt + F4** → **Cmd + W** *(Close window/tab)*
* **Alt + Shift + F4** → **Cmd + Q** *(Quit app)*
✅ Result: classic Windows close/quit behavior is restored.

---

## 8) Classic Windows clipboard style: Insert/Delete combinations

System-wide:
* **Ctrl + Insert** → **Cmd + C** *(Copy)*
* **Shift + Insert** → **Cmd + V** *(Paste)*
* **Shift + Delete** (both delete keys) → **Cmd + X** *(Cut)*
✅ Result: older Windows clipboard muscle memory works again.

---

## 9) Windows word-delete behavior (safe-mode)

Applies **everywhere EXCEPT**:
* VS Code
* JetBrains IDEs
* terminals
Mappings:
* **Ctrl + Backspace** → **Option + Backspace** *(delete previous word)*
* **Ctrl + Delete** → **Option + Delete Forward** *(delete next word)*
✅ Result: word deletion matches Windows, while preserving IDE/terminal semantics.

---

## 10) Home/End selection rules (Windows-like selection ergonomics)

System-wide:
* **Home** → **Cmd + ←** *(line start)*
* **End** → **Cmd + →** *(line end)*
Selection:
* **Shift + Home** → **Cmd + Shift + ←** *(select to line start)*
* **Shift + End** → **Cmd + Shift + →** *(select to line end)*
Document selection:
* **Ctrl + Shift + Home** → **Cmd + Shift + ↑** *(select to start of document)*
* **Ctrl + Shift + End** → **Cmd + Shift + ↓** *(select to end of document)*
Also supports **Fn+Arrow variants** for laptop consistency.
✅ Result: Windows-style selection logic is recreated cleanly.

---

## 11) “Ctrl shortcuts behave like Windows” (but excluded from IDEs/terminals)

Applies **everywhere except** VS Code / JetBrains / terminals.
Windows-style **Ctrl+…** becomes macOS **Cmd+…**:
* Ctrl+A/C/X/V (Select all / Copy / Cut / Paste)
* Ctrl+Z / Ctrl+Shift+Z (Undo / Redo)
* Ctrl+Y → Cmd+Shift+Z *(Windows redo behavior mapped to macOS redo)*
* Ctrl+S / Ctrl+Shift+S (Save / Save As)
* Ctrl+F (Find)
* Ctrl+P (Print in many apps / command-p semantics)
* Ctrl+O (Open)
* Ctrl+N (New)
* Ctrl+T (New tab/document)
* Ctrl+W (Close)
✅ Result: most apps feel like Windows, while developer tools keep their native shortcuts.

---

## 12) Finder becomes Windows File Explorer

Only in Finder:
* **F2** → **Enter** *(Rename)*
* **Delete** → **Cmd + Backspace** *(Move to Trash)*
* **Shift + Delete** → **Cmd + Option + Backspace** *(Delete immediately)*
* **Alt + Enter** → **Cmd + I** *(Properties → Get Info)*
* **Alt + ← / →** → **Cmd + [ / ]** *(Back/Forward)*
* **Alt + ↑** → **Cmd + ↑** *(Go up a folder)*
✅ Result: Finder navigation mirrors Windows Explorer behavior closely.

---

## 13) VS Code: Win+Space → Quick Open

Only in VS Code + JetBrains:
* **Right Cmd (Win) + Space** → **Cmd + P** *(Quick Open)*
✅ Result: matches the “launcher / quick open” habit tied to the Windows key.

---

## 14) Right Command = your “Windows key” macro layer

You use **Right Command** as **Win** and mapped key Windows actions:
* **Win + E** → open Finder
* **Win + I** → open System Settings
* **Win + L** → **Ctrl + Cmd + Q** *(Lock screen)*
* **Win + D** → **F11** *(Show desktop)*
* **Win + Shift + S** → **Cmd + Shift + 4** *(Area screenshot)*
* **Win + Tab** → **Ctrl + ↑** *(Mission Control / task view equivalent)*
* **Win + Shift + Tab** → **Ctrl + ↓** *(App Exposé equivalent)*
* **Win + Ctrl + ← / →** → **Ctrl + ← / →** *(Switch spaces)*
* **Win + .** → **Ctrl + Cmd + Space** *(Emoji picker)*
* **Ctrl + Shift + Esc** → open Activity Monitor
* **Win + R** → **Cmd + Space** *(Spotlight as “Run…”)*
✅ Result: macOS gains a Windows-like “Win-key command layer”.

---

## Summary: what you achieved

* **Windows editing ergonomics:** word movement, word delete, Home/End logic.
* **Windows browser parity:** tabs, history, downloads, devtools, address bar, zoom.
* **Windows window management:** Alt+Tab, Win+Arrow snapping, Alt+F4 semantics.
* **Explorer parity:** rename/delete/properties/back-forward/up-folder in Finder.
* **Developer safety:** terminals + IDEs are explicitly excluded where it matters.
If you want, I can generate a **clean cheat-sheet** (one screen) from this config: “Windows shortcut → macOS action → where it applies”.
