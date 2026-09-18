## Bash Environment Setup (WSL/Linux + macOS/Darwin)

This repository contains a personal Bash environment setup for WSL, Linux, and macOS (Apple Silicon) DevOps workstations. It includes custom Bash configurations, aliases, functions, and other development utilities to streamline cloud and infrastructure workflows.

* Primary shell is **Bash** (including on macOS — Homebrew bash is recommended).
* Platform-specific modules live under `bashrc.d.linux/` and `bashrc.d.darwin/`.
* Modular numbered scripts make it easy to extend and maintain functions.
* Works with cloud providers (AWS, GCP, Azure) and Terraform / VASTCloud workflows.
* Includes light and dark terminal color schemes.
* Has settings for `ssh/config` for lab use and proxy tunneling.
* Prompt tag identifies where the host is running:

  ```shell
  karlv@ghostcanyon [WSL] :~$
  karlv@devops01 [GCP] :~$
  karlv@macbook [Local] :~$
  ```

The file in **server_bashrc_files** is a standalone drop-in `~/.bashrc` for a new cloud/lab VM. It sets a cloud-tagged prompt (e.g. `user@host [GCP]:~`), vi editing, shared history, and common aliases — without the full laptop `bashrc.d` stack.

```shell
# On the VM:
cp bashrc_lab_server.sh ~/.bashrc && source ~/.bashrc
```

**Lima boxes — two different roles:**

| Kind | Examples | Lifecycle |
|------|----------|-----------|
| Durable Linux labs | `aws-env`, `gcp-env`, `vcdev-env` | Keep; bootstrap once; reuse for cloud / vcdev work |
| Ephemeral macOS bare-node | `MacOS01`, `MacOS_Clean` | **Use once, then wipe** — bare macOS node tests only |

Do **not** put vastcloud/git lab setup on the MacOS* VMs; wipe when done:

```shell
./bash_env/lima/wipe_macos_ephemeral.sh          # MacOS01 + MacOS_Clean
./bash_env/lima/wipe_macos_ephemeral.sh --all-macos
```

**Durable Linux lab-demo boxes** (minimal comfort, not the Mac day-to-day stack):

1. `install_lab_base_universal.sh` — vim, git, python3/pip, asciinema, tree, jq, tmux, etc.
2. `bashrc_lab_server.sh` — lean interactive shell only
3. Optional: `install_cloud_sdks_universal.sh` when a demo needs AWS/GCP/Azure/TF
4. Do **not** run full `rehydrate_repo.sh` / `bashrc.d.*` into Lima unless you intentionally want the laptop suite
5. iTerm2 Dynamic Profiles: `iterm2/lima-vms.json` → `~/Library/Application Support/iTerm2/DynamicProfiles/`

```shell
cp bash_env/iterm2/lima-vms.json \
  ~/Library/Application\ Support/iTerm2/DynamicProfiles/lima-vms.json
# Durable: Lima aws-env / gcp-env / vcdev-env
# Ephemeral: Lima MacOS* bare-node (wipe after use)
```

```shell
./install_lab_base_universal.sh --verbose \
  --dotfiles ./common \
  --configure-git   # or: GIT_USER_NAME=... GIT_USER_EMAIL=... ./install_lab_base_universal.sh --configure-git
```

#### Lima `vcdev-env` — isolated vastcloud DEV + git forges

Use a dedicated Lima VM so host `vastcloud` 2.7.1 and Mac `~/bin/vcdev` never share a `~/.vast` / pipe.
Guest installs a **Linux** DEV binary from Artifactory (`vastcloud-linux-arm64` / `amd64`) as `~/bin/vcdev` — do not copy the host Mach-O binary.

```shell
# On Mac (ssh-agent must already have github + git.vastdata.com keys):
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/ed25519_gitlab

cd ~/github/system-tools
./bash_env/lima/bootstrap_vcdev_lab.sh
# options: --recreate  --skip-clone  --no-alias  --name other-env

limactl shell vcdev-env
# inside: vcdev --version   # also aliased as vastcloud by default
#         ls ~/repos ~/repos-vast
#         git -C ~/repos-vast/vastoncloud pull
```

Pieces:

| Path | Role |
|------|------|
| `lima/lab-ubuntu-vcdev.yaml` | Lima template (agent forward, host mounts read-only) |
| `lima/bootstrap_vcdev_lab.sh` | Host orchestrator: create/start → lab base → vcdev → clone |
| `install_vastcloud_universal.sh` | `--release` / `--dev` (Artifactory fallback) / `--both` |
| `common/repo_lists/lima-vcdev.txt` | system-tools + automation-tools + vastoncloud |
| `ssh/config` | `Host github.com` + `Host git.vastdata.com` templates |

Git: agent-forwarded SSH + `ssh-keyscan` into guest `known_hosts`. Personal → `~/repos`, VAST GitLab → `~/repos-vast`.


---
### Sharing with colleagues who use zsh (porting notes)
---

This stack is **Bash-first**. It is **not** a drop-in for zsh. Colleagues on zsh should not source `bashrc.d.*` wholesale from `~/.zshrc`.

**Safe to reuse with light edits** (cloud helpers / aliases — most of the value):

* `05-vastcloud-functions.sh` (or equivalent VASTCloud wrappers)
* `10`–`14` GCP / AWS / Azure / Terraform helpers
* Most of `03` utility functions and `20` aliases
* Private secrets / maps from `~/.bash_environment.sh` — exports are fine; associative arrays need a small syntax tweak

**Must rewrite for zsh** (shell integration):

| Bash piece | Why it fails in zsh | zsh direction |
|------------|---------------------|---------------|
| Loader (`.bash_profile` → `~/.bashrc.d/*`) | Different startup files | `~/.zshrc` + `for f in ~/.zshrc.d/*; do source "$f"; done` |
| `02-terminal-settings.sh` | `shopt`, `bind`, `PROMPT_COMMAND`, bash `PS1` (`\u \h \w`, `\[\]`) | `setopt`, `bindkey`, `precmd` hooks, `%n %m %~` / `%F{...}` |
| Bash completion | `bash_completion.sh` | `compinit` / native zsh completions |
| `shopt -s nullglob` (e.g. Terraform helpers) | No `shopt` | `setopt nullglob` or glob qualifier `(N)` |
| `declare -gA MAP=(...)` | Bash declare flags | `typeset -gA MAP=(...)` |
| `"${!MAP[@]}"` | Bash keys expansion | `"${(k)MAP[@]}"` |

**Suggested approach for a zsh port:**

1. Keep Bash modules as the source of truth for cloud functions.
2. Add a thin `~/.zshrc` that sources only the helper scripts (skip `02`, skip bash completion).
3. Provide a tiny `compat.zsh` (or inline tweaks) for associative-array key iteration and `nullglob`.
4. Write a zsh-native prompt / history / vi-mode file instead of reusing `02`.

There is no maintained `zshrc.d/` tree in this repo yet — contributions welcome if someone ports the shell layer cleanly.

---
### How it works - WARNING - This will overwrite your existing environment so be careful.
---

This environment is designed to be highly portable using a set of custom synchronization scripts:

1. **`git_setup.sh` / `git_clone.sh`**: Bootstrap Git and clone your repos on a new machine.
2. **`git_sync.sh`**: Will loop through a list of local repos amd do a "pull" on all of them - use to update your laptop when you go on the road
3. **`update_repo.sh`**: Backup active workstation config into this repo. **Default** copies `~/.bashrc.d` → `bashrc.d.darwin/` or `bashrc.d.linux/` (detected from OS). Pass **`--all`** to also sync shared dotfiles into `common/`, scrubbing secrets from `bash_environment` and personal info from `gitconfig`.
4. **`rehydrate_repo.sh`**: Run this immediately after cloning the repository onto a brand-new WSL distro or cloud VM. It instantly deploys the repository files into your new home directory, securely adding the required `.` prefixes to hide the dotfiles and configuring directory permissions. 
5. **`install_cloud_sdks_universal.sh`**: Universal bootstrap for macOS and Linux. Detects Homebrew vs `apt` / `dnf` / `yum` and installs AWS CLI, Azure CLI, gcloud, OCI CLI, Terraform, and Asciinema (plus `wslu` on WSL).

---
### Files
---

```text
bash_env/
│
├─ bashrc                # Main Bash config
├─ bash_environment.sh   # Exported env variables (secrets are scrubbed in the repo; .sh for editor formatting)
├─ bash_aliases          # Personal command aliases
├─ dircolors             # Terminal colors (dark)
├─ dircolors.light       # Terminal colors (light)
├─ tmux.conf             # tmux configuration
├─ gitconfig             # Git configuration (user details scrubbed)
├─ s3cfg-basic           # simple s3cfg file
├─ s3cfg-example         # full s3cfg file
├─ vimrc                 # Example .vimrc
│
├── Setup & GitOps Scripts
│  ├─ git_setup.sh           # Initial Git bootstrap script
│  ├─ git_clone.sh           # Script to pull down repositories
│  ├─ git_sync.sh            # Custom Git workflow script (powers gpull, gpush, gstat)
│  ├─ install_cloud_sdks_universal.sh  # Bootstraps AWS, Azure, GCP, OCI, Terraform (macOS + Linux)
│  ├─ install_lab_base_universal.sh    # Lean lab/Lima base: vim git python pip asciinema tree jq …
│  ├─ update_repo.sh         # Sync ~/.bashrc.d → bashrc.d.{darwin|linux}; --all for common/
│  └─ rehydrate_repo.sh      # Deploys configurations from the repo to a new machine
│
├─ server_bashrc_files/  # Drop-in ~/.bashrc for cloud/lab VMs
│  └─ bashrc_lab_server.sh
├─ ssh/                  # SSH client config templates (with Linux & Windows proxy examples)
│
├─ bashrc.d.linux/       # Modular scripts for WSL/Linux
└─ bashrc.d.darwin/      # Modular scripts for macOS (Homebrew / Apple Silicon)
   ├─ 01-set-env_variables.sh      # Env vars, PATH, sources ~/.bash_environment.sh
   ├─ 02-terminal-settings.sh      # History, prompt, completions (Bash-only)
   ├─ 03-utility-functions.sh      # General utilities
   ├─ 04-terminal-multiplexers.sh  # tmux & screen helpers
   ├─ 05-vastcloud-functions.sh    # VASTCloud / Polaris helpers
   ├─ 10–14 cloud / Terraform helpers
   ├─ 15-iterm-session-log-functions.sh
   └─ 20-set-aliases.sh            # Aliases
```




```text
┌─────────────┐
│   Terminal  │
└─────┬───────┘
      │
      ▼
  [ ~/.bashrc ] ──► Sources all scripts in ~/.bashrc.d/
      │
      ▼
  ┌─────────────────────┐
  │ Modular Functions & │
  │ Aliases             │
  └───────┬─────────────┘
          │
          ▼
  Cloud & DevOps Tools
  (AWS, GCP, Azure, Terraform)
          │
          ▼
   Productivity Boost!
```
