## Bash Environment Setup (WSL/Linux + macOS/Darwin)

Personal Bash environment for WSL, Linux, and macOS (Apple Silicon) DevOps workstations: modular configs, aliases, and cloud/Terraform helpers.

* Primary shell is **Bash** (Homebrew bash recommended on macOS).
* Platform modules: `bashrc.d.linux/` and `bashrc.d.darwin/`.
* Cloud providers: AWS, GCP, Azure — plus Terraform lab helpers.
* Light/dark terminal color schemes; `ssh/config` templates for lab use.
* Prompt tag shows where the host is running:

  ```shell
  user@host [WSL] :~$
  user@host [GCP] :~$
  user@host [Local] :~$
  ```

**Lab VM drop-in:** `server_bashrc_files/bashrc_lab_server.sh` — lean `~/.bashrc` (cloud-tagged prompt, vi mode, shared history, common aliases) without the full laptop stack.

```shell
# On the VM:
cp bashrc_lab_server.sh ~/.bashrc && source ~/.bashrc
```

### Lima boxes

| Kind | Examples | Lifecycle |
|------|----------|-----------|
| Durable Linux labs | `aws-env`, `gcp-env` | Keep; bootstrap once; reuse for cloud work |
| Ephemeral macOS bare-node | `MacOS01`, `MacOS_Clean` | **Use once, then wipe** |

```shell
./bash_env/lima/wipe_macos_ephemeral.sh          # MacOS01 + MacOS_Clean
./bash_env/lima/wipe_macos_ephemeral.sh --all-macos
```

**Durable Linux lab-demo boxes** (minimal comfort, not the Mac day-to-day stack):

1. `install_lab_base_universal.sh` — vim, git, python3/pip, asciinema, tree, jq, tmux, etc.
2. `bashrc_lab_server.sh` — lean interactive shell only
3. Optional: `install_cloud_sdks_universal.sh` when a demo needs AWS/GCP/Azure/TF
4. Do **not** run full `rehydrate_repo.sh` / `bashrc.d.*` into Lima unless you want the laptop suite
5. iTerm2 Dynamic Profiles: `iterm2/lima-vms.json` → `~/Library/Application Support/iTerm2/DynamicProfiles/`

```shell
cp bash_env/iterm2/lima-vms.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/lima-vms.json

./install_lab_base_universal.sh --verbose \
  --dotfiles ./common \
  --configure-git
```

---
### Sharing with colleagues who use zsh (porting notes)
---

This stack is **Bash-first**. Do not source `bashrc.d.*` wholesale from `~/.zshrc`.

**Safe to reuse with light edits:**

* `10`–`14` GCP / AWS / Azure / Terraform helpers
* Most of `03` utility functions and `20` aliases
* Private secrets / maps from `~/.bash_environment.sh` — exports are fine; associative arrays need a small syntax tweak

**Must rewrite for zsh** (shell integration):

| Bash piece | Why it fails in zsh | zsh direction |
|------------|---------------------|---------------|
| Loader (`.bash_profile` → `~/.bashrc.d/*`) | Different startup files | `~/.zshrc` + `for f in ~/.zshrc.d/*; do source "$f"; done` |
| `02-terminal-settings.sh` | `shopt`, `bind`, `PROMPT_COMMAND`, bash `PS1` | `setopt`, `bindkey`, `precmd`, `%n %m %~` |
| Bash completion | `bash_completion.sh` | `compinit` |
| `shopt -s nullglob` | No `shopt` | `setopt nullglob` or `(N)` |
| `declare -gA MAP=(...)` | Bash declare flags | `typeset -gA MAP=(...)` |
| `"${!MAP[@]}"` | Bash keys expansion | `"${(k)MAP[@]}"` |

Suggested: keep Bash modules as source of truth for cloud functions; thin `~/.zshrc` that sources helpers only (skip `02` / bash completion); zsh-native prompt/history.

---
### How it works — WARNING: can overwrite your existing environment
---

1. **`git_setup.sh` / `git_clone.sh`**: Bootstrap Git and clone repos on a new machine.
2. **`git_sync.sh`**: Pull a list of local repos (road-trip laptop update).
3. **`update_repo.sh`**: Copy `~/.bashrc.d` → `bashrc.d.darwin/` or `bashrc.d.linux/`. Pass **`--all`** to also sync `common/` (scrubs secrets from `bash_environment`, personal info from `gitconfig`).
4. **`rehydrate_repo.sh`**: Deploy repo files into a new home directory after clone.
5. **`install_cloud_sdks_universal.sh`**: Install AWS CLI, Azure CLI, gcloud, OCI CLI, Terraform, Asciinema (plus `wslu` on WSL).

---
### Files
---

```text
bash_env/
│
├─ common/               # Shared dotfiles (bashrc, aliases, vimrc, tmux, gitconfig templates)
├─ install_*.sh          # Lab base + cloud SDK bootstrap
├─ update_repo.sh        # Sync ~/.bashrc.d → bashrc.d.{darwin|linux}; --all for common/
├─ rehydrate_repo.sh     # Deploy configs to a new machine
│
├─ server_bashrc_files/  # Drop-in ~/.bashrc for cloud/lab VMs
├─ ssh/                  # SSH client config templates
├─ lima/                 # Ephemeral macOS wipe helpers
├─ iterm2/               # Dynamic profile JSON for Lima labs
│
├─ bashrc.d.linux/       # Modular scripts for WSL/Linux
└─ bashrc.d.darwin/      # Modular scripts for macOS
   ├─ 01-set-env_variables.sh
   ├─ 02-terminal-settings.sh
   ├─ 03-utility-functions.sh
   ├─ 04-terminal-multiplexers.sh
   ├─ 10–14 cloud / Terraform helpers
   ├─ 15-iterm-session-log-functions.sh
   └─ 20-set-aliases.sh
```

```text
Terminal → ~/.bashrc → sources ~/.bashrc.d/*.sh
         → AWS / GCP / Azure / Terraform helpers + aliases
```
