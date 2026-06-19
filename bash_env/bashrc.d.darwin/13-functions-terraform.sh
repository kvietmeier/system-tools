###===============================================================================================###
### Terraform Helper Functions
### File: .bashrc.d/13-functions-terraform.sh
### Purpose: 
###   Simplify common Terraform operations and output for VAST on Cloud
### Created by Karl Vietmeier
### License: Apache 2.0
###===============================================================================================###

###--- Base Terraform directory
# Dynamically pull from 01-set-env_variables.sh, fallback if not set
export VOC_BASE="${VOCDIR:-${HOME}/repos/vast_on_cloud}"

###--- Terraform Apply/Destroy/Plan with all .tfvars in current dir
tfapply() {
    shopt -s nullglob
    local var_files=(*.tfvars)
    shopt -u nullglob
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform apply --auto-approve "${var_files[@]/#/-var-file=}"
}

tfdestroy() {
    shopt -s nullglob
    local var_files=(*.tfvars)
    shopt -u nullglob
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform destroy --auto-approve "${var_files[@]/#/-var-file=}"
}

tfplan() {
    shopt -s nullglob
    local var_files=(*.tfvars)
    shopt -u nullglob
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform plan "${var_files[@]/#/-var-file=}"
}

###--- Terraform Output Helpers
tf_vms()      { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw cluster_mgmt 2>/dev/null || echo "Error getting cluster_mgmt"; echo ""; }
tf_vmsmon()   { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw vms_monitor 2>/dev/null || echo "Error getting vms_monitor"; echo ""; }
tf_vmsip()    { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw vms_ip 2>/dev/null || echo "Error getting vms_ip"; echo ""; }

tf_all() {
    local tf_dir="${1:-$VOC_BASE}"
    echo "Cluster Management URL:"; tf_vms "$tf_dir"; echo ""
    echo "Monitoring URL:"; tf_vmsmon "$tf_dir"; echo ""
    echo "VMS IP Address:"; tf_vmsip "$tf_dir"; echo ""
}

tf_private_ips() {
    local tf_dir="$VOC_BASE"
    local ips_json count=1 prefix="ebox"
    ips_json=$(terraform -chdir="$tf_dir" output -json private_ips 2>/dev/null) || { echo "Error getting private_ips"; return 1; }

    local type=$(echo "$ips_json" | jq -r 'type')
    if [[ "$type" == "string" ]]; then
        printf "%-15s %s%02d\n" "$ips_json" "$prefix" "$count"
    elif [[ "$type" == "array" ]]; then
        for ip in $(echo "$ips_json" | jq -r '.[]'); do
            printf "%-15s %s%02d\n" "$ip" "$prefix" "$count"
            ((count++))
        done
    else
        echo "Unexpected JSON type: $type" >&2
        return 1
    fi
}

###--- Terraform Utility Functions
tfshow() { terraform output; }
tfinit() { terraform init; }

tfclean() {
    echo "Removing .terraform dirs, tfstate files, and backups..."
    find . -type d -name ".terraform" -exec rm -rf {} +
    rm -f terraform.tfstate terraform.tfstate.backup
    echo "Reinitializing Terraform..."
    terraform init
}

tfclstate() {
    echo "Removing tfstate files and backups (keeping .terraform)..."
    rm -f terraform.tfstate terraform.tfstate.backup
    terraform init
}

###=================================================================================================###
###  Aliases
###=================================================================================================###

# --- Terraform / VoC aliases only if Terraform is installed
if command -v terraform >/dev/null 2>&1; then

    ###--- Output helper aliases
    alias vms='tf_vms'
    alias vmsmon='tf_vmsmon'
    alias vmsip='tf_vmsip'
    alias eboxips='tf_private_ips'

    # VAST Terraform / VoC shortcuts (Wired dynamically to 01-set-env_variables.sh)
    alias vasttf="cd ${VASTTF}"
    alias vocdir="cd ${VOCDIR}/5_3"
    alias vastdir="cd ${VASTTF}"
    alias cluster01="cd ${TFGCP}/cluster01"
    alias cluster02="cd ${TFGCP}/cluster02"
    alias cluster03="cd ${TFGCP}/cluster03"

    # Optional VoC scripts
    alias install_vast01="${HOME}/bin/vast.voc.install.py"
    alias pgpsecrets="${HOME}/Terraform/scripts/vast.extracts3secret.sh"
    alias vmsstat="${HOME}/bin/vms.status.py"
fi