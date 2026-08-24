## macOS (Darwin) Bash Environment Setup

```shell
bash_env/bashrc.d.darwin
```

A modular Bash environment customized for **macOS Apple Silicon (Darwin)** with cross-platform support for Linux/Cloud VMs. Designed for multi-cloud infrastructure engineers working with **AWS**, **GCP**, **Azure**, **Terraform**, and **VAST Polaris Cloud**.

---

### Architecture & Directory Layout

To install, place the main entry points in your `$HOME` directory and modularize configurations inside `~/.bashrc.d/`:

```text
~/.bash_environment         # Private/Sensitive local variables (git-ignored)
~/.bashrc                  # Main shell initialization file
~/.bashrc.d/
├── 01-set-env_variables.sh  # Paths, Homebrew, and Environment Tagging
├── 02-terminal-settings.sh # History, Prompt (PS1), terminal titles
├── 03-functions-utility.sh # IP lookup, browser isolation, asciinema logging
├── 04-terminal-mux.sh      # Tmux and Screen aliases
├── 05-functions-vast.sh    # VAST Cloud & Polaris context management
├── 10-gcp-functions.sh     # GCP IAM, ADC authentication, and profiles
├── 11-gcp-utilities.sh     # GCP Compute, VPC, and Route management
├── 11-functions-aws.sh     # AWS SSO authentication and VAST context syncing
├── 12-functions-azure.sh   # Azure Service Principal auth & resource listing
├── 13-functions-tf.sh      # Terraform shortcut wrappers and state cleaning
├── session-tools.sh        # iTerm2 log cleanup, archiving, and compression
└── 20-set-aliases.sh       # Core GNU aliases, navigation, and shortcuts
```

---

### Installation & Setup Instructions

### 1. Environment File Setup

Create `~/.bash_environment` to store your non-committed secrets and default values:

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
* `vclogin`: Initiates OIDC authentication.
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

* `azlogin`: Logs in using Service Principal details defined in `~/.bash_environment`.
* `azvms`, `azvnets`, `azsubnets`, `azdisks`: Helper functions for quick tabular resource discovery.

### 6. Terraform Helpers

* `tfapply` / `tfplan` / `tfdestroy`: Automatically injects all `*.tfvars` in the current directory using `-var-file` flags.
* `tfclean`: Purges `.terraform` directories, state files, and re-initializes.
* `tf_all`: Prints VMS management URLs, monitoring endpoints, and IP details.