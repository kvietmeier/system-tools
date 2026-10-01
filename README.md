# system-tools

Quick-drop utilities and shell/PowerShell environment for laptops and lab hosts.
Thin bootstrap helpers only — not a substitute for Ansible (fleet config) or `cloud-tools` (cloud procedures).

## What's here

| Path | Purpose |
|------|---------|
| `bash_env/` | Modular Bash env (`bashrc.d.darwin` / `bashrc.d.linux`), sync scripts, lab VM drop-in bashrcs |
| `powershell/` | Profile, Windows/WSL workstation setup, AD helpers. Cloud PS lives in `cloud-tools` |
| `*.sh` (repo root) | One-shot host helpers: users, hosts file, initial config, WSL XDG, etc. |

Edit live config under `~/.bashrc.d`, then run `bash_env/update_repo.sh` to copy back into the repo (`--all` also syncs `common/`).

More detail for the Bash stack: [`bash_env/README.md`](bash_env/README.md).

---

## macOS (Darwin) Bash Environment Setup

```shell
bash_env/bashrc.d.darwin
```

Modular Bash for **macOS Apple Silicon (Darwin)** with Linux/cloud VM support. Focused on **AWS**, **GCP**, **Azure**, and **Terraform** lab workflows.

---

### Architecture & Directory Layout

Install entry points under `$HOME` and modular configs in `~/.bashrc.d/`:

```text
~/.bash_environment.sh            # Private/sensitive local variables (not committed)
~/.bashrc                         # Main shell initialization file
~/.bashrc.d/
├── 01-set-env_variables.sh       # Paths, Homebrew, environment tagging
├── 02-terminal-settings.sh       # History, prompt (PS1), terminal titles
├── 03-utility-functions.sh       # IP lookup, browser isolation, cloudauth
├── 04-terminal-mux.sh            # Tmux and Screen aliases
├── 10-gcp-functions.sh           # GCP IAM, ADC authentication, profiles
├── 11-gcp-utilities.sh           # GCP Compute, VPC, route helpers
├── 12-aws-functions.sh           # AWS SSO authentication
├── 13-azure-functions.sh         # Azure SP auth & resource listing
├── 14-terraform-utilities.sh     # Terraform wrappers and state cleaning
├── 15-iterm-session-tools.sh     # iTerm2 log cleanup / archive
└── 20-set-aliases.sh             # Core aliases and navigation shortcuts
```

---

### Installation & Setup

#### 1. Environment file

Create `~/.bash_environment.sh` for secrets and defaults (placeholders only in docs):

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_SA_EMAIL="your-sa@project.iam.gserviceaccount.com"
export AZURE_CLIENT_ID="your-azure-app-id"
export AZURE_CLIENT_SECRET="your-azure-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_SUBSCRIPTION_NAME="your-sub-display-name"   # optional
# After editing: source ~/.bash_environment.sh && azlogin
```

#### 2. Source configuration

In `$HOME/.bashrc` or `$HOME/.bash_profile`:

```bash
if [ -d "$HOME/.bashrc.d" ]; then
    for file in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$file" ] && source "$file"
    done
fi
```

---

## Component breakdown

### General utilities

* Homebrew paths (`/opt/homebrew`) and GNU `coreutils` (`gls`, `gdircolors`)
* Environment tag: macOS `[Local]` or AWS / GCP / Azure VM
* `myip` / `get_my_ip` — public IP via ipinfo.io → `$MYIP`

### Session & terminal logging

* Asciinema: `logson`, `logsoff`, `listlogs`
* iTerm2: `terminal_log view|archive|compress|rg`

### Isolated browsers

* `pedge` / `pchrome` — dedicated personal profiles
* `chrome_isol` / `edge_isol` — ephemeral RAM profiles

### Multi-cloud auth & ops

* `gcplogin` / `gcplogout` — ADC, project, SA impersonation
* `gcplabvms <start|stop|resume|list>` — lab/gateway VM batches
* `gcporphan` — orphaned routes
* `awslogin <profile_or_shortcut>` — AWS SSO
* `awswho` / `awspurge` — identity / cache cleanup
* `azlogin`, `azvms`, `azvnets`, `azsubnets`, `azdisks`
* `cloudauth` — one-shot Azure / GCP / AWS identity check

### Terraform helpers

* `tfapply` / `tfplan` / `tfdestroy` — auto `-var-file` for `*.tfvars`
* `tfclean` — purge `.terraform` / state and re-init
* `tf_all` — common output helpers (mgmt URLs, IPs)
* `cleantform_state [dir]` — recursive state / `.terraform` clean
