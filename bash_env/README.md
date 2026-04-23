## Bash Environment Setup (WSL/Linux DevOps)

This repository contains my personal Bash environment setup for WSL and Linux DevOps workstations. It includes custom Bash configurations, aliases, functions, and other development utilities to streamline cloud and infrastructure workflows.

  * Designed for WSL and Linux DevOps environments.
  * Modular `.bashrc.d/` directory makes it easy to extend and maintain functions.
  * Works seamlessly with cloud providers (AWS, GCP, Azure, OCI) and Terraform workflows.
  * Includes light and dark terminal color schemes.
  * Has settings for `ssh/config` for lab use and proxy tunneling.
  * You get a prompt that dynamically identifies where the host you are logged into is running:
    ```shell
    karlv@ghostcanyon [WSL] :~$
    karlv@devops01 [GCP] :~$
    ```

The bashrc files in **server_bashrc_files** are standalone files that you can drop onto a cloud or lab server that will set the prompt you see above and other useful aliases and settings like `set -o vi`.

---
### How it works - 
---

This environment is designed to be highly portable using a set of custom synchronization scripts:

1. **`git_setup.sh` / `git_clone.sh`**: Use these to bootstrap Git and pull down this repository onto a fresh machine.
2. **`update_repo.sh`**: Run this on your active workstation when you make changes to your environment. It automatically copies your active `~/.bashrc.d` and dotfiles into the local Git repository while **stripping out personal details and cloud secrets** (like Azure Client IDs and GCP credentials) from `bash_environment` and `gitconfig`.
3. **`rehydrate_repo.sh`**: Run this immediately after cloning the repository onto a brand-new WSL distro or cloud VM. It instantly deploys the repository files into your new home directory, securely adding the required `.` prefixes to hide the dotfiles and configuring directory permissions. 
4. **`install_cloud_sdks.sh`**: A cross-platform deployment script that automatically detects your OS package manager (`apt`, `dnf`, `yum`) and installs the cloud toolchains (AWS CLI, Azure CLI, gcloud, OCI, Terraform, and Asciinema).


---
### Files
---

`
---
### Files
---

```text
bash_env/
│
├─ bashrc                # Main Bash config
├─ bash_environment      # Exported env variables (secrets are scrubbed in the repo)
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
│  ├─ install_cloud_sdks.sh  # Bootstraps AWS, Azure, GCP, OCI, Terraform, and Asciinema
│  ├─ update_repo.sh         # Secures and syncs active dotfiles into the Git repository
│  └─ rehydrate_repo.sh      # Deploys configurations from the repo to a new machine
│
├─ server_bashrc_files/  # Standalone bashrc files for cloud/lab servers
├─ ssh/                  # SSH client config templates (with Linux & Windows proxy examples)
│
└─ bashrc.d/             # Modular function scripts
   ├─ 01-set-env_variables.sh      # Environment variables & cloud detection
   ├─ 02-terminal-settings.sh      # Terminal tweaks
   ├─ 03-functions-utility.sh      # General utility functions
   ├─ 04-terminal-multiplexers.sh  # tmux & multiplexer helpers
   ├─ 10-functions-gcp.sh          # GCP helper functions
   ├─ 11-functions-aws.sh          # AWS helper functions
   ├─ 12-functions-azure.sh        # Azure helper functions
   ├─ 13-functions-terraform.sh    # Terraform helper functions
   └─ 20-set-aliases.sh            # Command aliases
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
