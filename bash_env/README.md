## Bash Environment Setup (WSL/Linux DevOps)

The tarball bashsetup.tar contains my personal Bash environment setup for WSL and Linux DevOps workstations. It includes custom Bash configurations,  aliases, functions, and other development utilities to streamline cloud and infrastructure workflows.

  * Designed for WSL and Linux DevOps environments.
  * Modular .bashrc.d/ directory makes it easy to extend and maintain functions.
  * Works seamlessly with cloud providers (AWS, GCP, Azure) and Terraform workflows.
  * Includes light and dark terminal color schemes.

This will create a prompt that identifies where the host you are logged into is running:
```shell
karlv@ghostcanyon [WSL] :~$
karlv@devops01 [GCP] :~$
```

<br>

---
### Files
---

```text
bashsetup.tar
│
├─ .bashrc                # Main Bash config
├─ .bash_environment      # Exported env variables
├─ .bash_aliases          # Personal command aliases
├─ .dircolors             # Terminal colors (dark)
├─ .dircolors.light       # Terminal colors (light)
├─ .tmux.conf             # tmux configuration
├─ .ssh/config            # SSH client config
├─ .s3cfg.basic           # simple s3cfg file
├─ .s3cfg.example         # full s3cfg file
├─ .vimrc                 # Example.vimrc
└─ .bashrc.d/             # Modular function scripts
   ├─ 01-set-env_variables.sh      # Environment variables
   ├─ 02-terminal-settings.sh      # Terminal tweaks
   ├─ 03-functions-utility.sh      # General utility functions
   ├─ 04-terminal-multiplexers.sh  # tmux & multiplexer helpers
   ├─ 10-functions-gcp.sh          # GCP helper functions
   ├─ 11-functions-aws.sh          # AWS helper functions
   ├─ 12-functions-azure.sh        # Azure helper functions
   ├─ 13-functions-terraform.sh    # Terraform helper functions
   └─ 20-set-aliases.sh            # Command aliases
```

---
### How it works - 
---

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
