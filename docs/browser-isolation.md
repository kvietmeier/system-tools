# Isolated browser instances

Launch Chrome or Edge in a **separate profile** so cookies, SSO sessions, and extensions do not bleed into your default browser — useful when you juggle work IdP, customer consoles, and personal accounts on the same laptop.

Same aliases on **macOS (Bash)** and **Windows (PowerShell)**.

## Get the code

Repo: [github.com/kvietmeier/system-tools](https://github.com/kvietmeier/system-tools)

```bash
git clone https://github.com/kvietmeier/system-tools.git
```

| Platform | Source file |
|----------|-------------|
| macOS | [`bash_env/bashrc.d.darwin/03-utility-functions.sh`](https://github.com/kvietmeier/system-tools/blob/main/bash_env/bashrc.d.darwin/03-utility-functions.sh) (aliases in [`20-set-aliases.sh`](https://github.com/kvietmeier/system-tools/blob/main/bash_env/bashrc.d.darwin/20-set-aliases.sh)) |
| Windows | [`powershell/Profile/BrowserFunctions.ps1`](https://github.com/kvietmeier/system-tools/blob/main/powershell/Profile/BrowserFunctions.ps1) |

You can also copy just those files into your own shell/profile setup — you do not need the full env.

| Alias | What it does |
|-------|----------------|
| `pchrome` / `pedge` | Durable **personal** profile — stays on disk, air-gapped from the default browser profile |
| `chrome_isol` / `edge_isol` | **Ephemeral** profile in TEMP — wiped when that browser window exits |

Optional URL for ephemeral launches (defaults to `about:blank`):

```bash
chrome_isol https://console.example.com
edge_isol https://portal.azure.com
```

```powershell
chrome_isol https://console.example.com
edge_isol https://portal.azure.com
```

---

## Why bother

Chromium stores identity in the user-data directory. A second `--user-data-dir` is a second browser: different logins, no shared cookies with your everyday profile. Ephemeral mode is for one-off tests or “I don’t want this session to stick around.”

---

## Quick start

### macOS

Requires the Darwin bash env from this repo (`~/.bashrc.d/` sourcing `03-utility-functions.sh` and aliases from `20-set-aliases.sh`). See the [main README](../README.md).

```bash
pchrome          # personal Chrome
pedge            # personal Edge
chrome_isol      # throwaway Chrome (cleanup on exit)
edge_isol        # throwaway Edge (cleanup on exit)
```

**Profile locations**

| Mode | Path |
|------|------|
| Personal Chrome | `~/.config/personal_chrome_profile` |
| Personal Edge | `~/.config/personal_edge_profile` |
| Ephemeral | `mktemp` under `/var/folders/…` (removed when the process exits) |

Source: [`bash_env/bashrc.d.darwin/03-utility-functions.sh`](../bash_env/bashrc.d.darwin/03-utility-functions.sh)

### Windows

Dot-source or load via the PowerShell profile (`BrowserFunctions.ps1` is listed in `Microsoft.PowerShell_profile.ps1`). See [`powershell/Profile/README.md`](../powershell/Profile/README.md).

```powershell
pchrome
pedge
chrome_isol
edge_isol
```

**Profile locations**

| Mode | Path |
|------|------|
| Personal Chrome | `%LOCALAPPDATA%\personal_chrome_profile` |
| Personal Edge | `%LOCALAPPDATA%\personal_edge_profile` |
| Ephemeral | `%TEMP%\chrome_ephemeral_*` / `edge_ephemeral_*` (removed by a detached waiter when the process exits) |

Source: [`powershell/Profile/BrowserFunctions.ps1`](../powershell/Profile/BrowserFunctions.ps1)

---

## Behavior notes

- Launch is **non-blocking** — your shell returns immediately.
- Ephemeral cleanup runs in the background (Bash subshell + `disown` on macOS; hidden PowerShell waiter on Windows). Close the browser window to delete the temp profile.
- Browsers must already be installed in the usual places (`/Applications/…` on macOS; Program Files / LocalAppData on Windows).
- These are thin wrappers around Chromium’s `--user-data-dir`. They are not a security boundary against malware — just session isolation for day-to-day work.

---

## Minimal copy-paste (no full profile install)

If someone only wants the idea without cloning the whole env, the pattern is:

```bash
# Durable personal profile
open -na "Google Chrome" --args \
  --user-data-dir="$HOME/.config/personal_chrome_profile" \
  --no-first-run

# Throwaway (manual cleanup)
TMP=$(mktemp -d)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --user-data-dir="$TMP" --no-first-run about:blank
# when done: rm -rf "$TMP"
```

```powershell
# Durable personal profile
Start-Process chrome.exe -ArgumentList @(
  "--user-data-dir=$env:LOCALAPPDATA\personal_chrome_profile",
  '--no-first-run'
)
```

Prefer the repo helpers when you already use this environment — they handle paths and ephemeral teardown for you.
