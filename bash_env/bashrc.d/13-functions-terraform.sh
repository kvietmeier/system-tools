###===============================================================================================###
### Terraform Helper Functions
### File: .bashrc.d/13-functions-terraform.sh
### Purpose: 
###   Simplify common Terraform operations and output for VAST on Cloud
### Created by Karl Vietmeier
### License: Apache 2.0
###===============================================================================================###

###--- Base Terraform directory
# Use environment variable TF_VOC_BASE if set, otherwise fallback to default
export VOC_BASE="${HOME}/Vast/vast_on_cloud"

###--- Terraform Apply/Destroy/Plan with all .tfvars in current dir
tfapply() {
    local var_files=(*.tfvars)
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform apply --auto-approve "${var_files[@]/#/-var-file=}"
}

tfdestroy() {
    local var_files=(*.tfvars)
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform destroy --auto-approve "${var_files[@]/#/-var-file=}"
}

tfplan() {
    local var_files=(*.tfvars)
    [[ ${#var_files[@]} -eq 0 ]] && { echo "No .tfvars files found."; return 1; }
    terraform plan "${var_files[@]/#/-var-file=}"
}

###--- Terraform Output Helpers
tf_vms()      { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw cluster_mgmt 2>/dev/null || echo "Error getting cluster_mgmt"; echo ""; }
tf_vmsmon()   { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw vms_monitor 2>/dev/null || echo "Error getting vms_monitor"; echo ""; }
tf_vmsip()    { local tf_dir="${1:-$VOC_BASE}"; terraform -chdir="$tf_dir" output -raw vms_ip 2>/dev/null || echo "Error getting vms_ip"; echo ""; }

tf_all() {
    local tf_dir="${1:-$TF_VOC_BASE}"
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

    ###--- Terraform convenience aliases
    alias tfclean='tfclean'
    alias tfclstate='tfclstate'
    alias tfinit='tfinit'
    alias tfshow='tfshow'
    alias tfapply='tfapply'
    alias tfdestroy='tfdestroy'
    alias tfplan='tfplan'

    ###--- Output helper aliases
    alias vms='tf_vms'
    alias vmsmon='tf_vmsmon'
    alias vmsip='tf_vmsip'
    alias eboxips='tf_private_ips'

    # VAST Terraform / VoC shortcuts
    alias vasttf="cd ${VASTTF_ROOT}"          # VAST Terraform root
    alias vocdir="cd ${TFDIR}/vast_on_cloud/5_3"
    alias vastdir="cd ${VASTTF_ROOT}"
    alias cluster01="cd ${VASTGCP}/cluster01"
    alias cluster02="cd ${VASTGCP}/cluster02"
    alias cluster03="cd ${VASTGCP}/cluster03"

    # Optional VoC scripts
    alias install_vast01="${HOME}/bin/vast.voc.install.py"
    alias pgpsecrets="${HOME}/Terraform/scripts/vast.extracts3secret.sh"
    alias vmsstat="${HOME}/bin/vms.status.py"
fi