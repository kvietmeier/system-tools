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

A modular Bash environment customized for **macOS Apple Silicon (Darwin)** with cross-platform support for Linux/Cloud VMs. Designed for multi-cloud infrastructure engineers working with **AWS**, **GCP**, **Azure**, **Terraform**, and **VAST Polaris Cloud**.

---

### Architecture & Directory Layout

To install, place the main entry points in your `$HOME` directory and modularize configurations inside `~/.bashrc.d/`:

```text
~/.bash_environment.sh            # Private/Sensitive local variables (git-ignored; .sh for editor formatting)
~/.bashrc                         # Main shell initialization file
~/.bashrc.d/
├── 01-set-env_variables.sh       # Paths, Homebrew, and Environment Tagging
├── 02-terminal-settings.sh       # History, Prompt (PS1), terminal titles
├── 03-functions-utility.sh       # IP lookup, browser isolation, asciinema logging
├── 04-terminal-mux.sh            # Tmux and Screen aliases
├── 05-vastcloud-functions.sh     # VAST Cloud & Polaris context management
├── 10-gcp-functions.sh           # GCP IAM, ADC authentication, and profiles
├── 11-gcp-utilities.sh           # GCP Compute, VPC, and Route management
├── 12-aws-functions.sh           # AWS SSO authentication and VAST context syncing
├── 13-azure-functions.sh         # Azure Service Principal auth & resource listing
├── 14-terraform-utilities.sh     # Terraform shortcut wrappers and state cleaning
├── 15-iterm-session-tools.sh     # iTerm2 log cleanup, archiving, and compression
└── 20-set-aliases.sh             # Core GNU aliases, navigation, and shortcuts
```

---

### Installation & Setup Instructions

### 1. Environment File Setup

Create `~/.bash_environment.sh` to store your non-committed secrets and default values:

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_SA_EMAIL="your-sa@project.iam.gserviceaccount.com"
export AZURE_CLIENT_ID="your-azure-app-id"
export AZURE_CLIENT_SECRET="your-azure-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SUBSCRIPTION_ID="your-sub-id"
```

### 2. Source Configuration

Add the following sourcing snippet into your `$HOME/.bashrc` or `$HOME/.bash_profile`:

```bash
if [ -d "$HOME/.bashrc.d" ]; then
    for file in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$file" ] && source "$file"
    done
fi
```

---

## Component Breakdown & How-To

### 1. General & System Utilities

* **Homebrew Integration**: Auto-evaluates Homebrew paths (`/opt/homebrew`) and exposes GNU `coreutils` (`gls`, `gdircolors`).
* **Environment Tagging**: Automatically detects if running locally on macOS (`[Local]`) or inside an AWS, GCP, or Azure VM.
* **Interactive IP Fetching**: Run `myip` or `get_my_ip` to fetch your current public IP via `ipinfo.io` and export `$MYIP`.

### 2. Session & Terminal Logging

* **Asciinema Recording**:
  * `logson`: Starts real-time session recording saved to `~/repos/personal/session_logs/`.
  * `logsoff`: Reminds you to exit the active recording.
  * `listlogs`: Lists all existing `.cast` recordings by date.
* **iTerm2 Maintenance (`terminal_log`)**:
  * `terminal_log view`: Strips ANSI codes and opens the active log in VS Code.
  * `terminal_log archive`: Organizes logs into `Profile/YYYY-MM` folders.
  * `terminal_log compress`: Compresses log files over 50MB into `.tar.gz`.
  * `terminal_log rg <pattern>`: Search through log histories using Ripgrep.

### 3. Isolated Workspaces & Browsers

Launch air-gapped or single-use ephemeral browser instances directly from your terminal:

* `pedge` / `pchrome`: Launches Edge or Chrome with dedicated personal profile directories.
* `chrome_isol <url>` / `edge_isol <url>`: Launches a temporary browser in RAM (`mktemp`) that completely purges all data upon closing.

### 4. VAST Cloud & Polaris Context Management

* `vcstat` / `vcstatus`: Displays current AWS profile, active Polaris context, and auth status.
* `vclogin`: Non-interactive Polaris login for the current context (staging vs prod credentials from `~/.bash_environment.sh`).
* `vccreategcp [name] [nodes]`: Deploys a GCP VAST cluster.
* `vccreateaws [name] [nodes]`: Deploys an AWS VAST cluster.

### 5. Multi-Cloud Authentication & Operations

* `gcplogin`: Authenticates human identity, acquires Application Default Credentials (ADC), sets the target project, and impersonates service accounts.
* `gcplogout`: Revokes credentials and purges local auth matrices.
* `gcplabvms <start|stop|resume|list> [count] [type]`: Manages batches of lab/gateway VMs in parallel background threads.
* `gcporphan`: Lists orphaned routes missing active next-hops.

#### Amazon Web Services (AWS)

* `awslogin <profile_or_shortcut>`: Authenticates via AWS SSO and automatically updates your corresponding VAST Polaris context.
* `awswho`: Displays identity table using AWS STS.
* `awspurge`: Logs out of SSO and purges local credential caches.

#### Microsoft Azure

* `azlogin`: Logs in using Service Principal details defined in `~/.bash_environment.sh`.
* `azvms`, `azvnets`, `azsubnets`, `azdisks`: Helper functions for quick tabular resource discovery.

### 6. Terraform Helpers

* `tfapply` / `tfplan` / `tfdestroy`: Automatically injects all `*.tfvars` in the current directory using `-var-file` flags.
* `tfclean`: Purges `.terraform` directories, state files, and re-initializes.
* `tf_all`: Prints VMS management URLs, monitoring endpoints, and IP details.
* `cloudauth` / `check_cloud_auth`: Quick Polaris + Azure/GCP/AWS identity check.
* `cleantform_state [dir]`: Recursive tree clean of `*.tfstate` and `.terraform` dirs (no re-init).
