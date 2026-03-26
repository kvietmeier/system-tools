###############################################################################
### AWS Authentication Helpers
### File: .bashrc.d/11-functions-aws.sh
### Purpose: 
###   Simplify AWS SSO login via dynamic profile selection
### Created by Karl Vietmeier
### License: Apache 2.0
###############################################################################

###--- AWS SSO Login Function
aws_sso_login() {
    # Get all profile names from ~/.aws/config
    local profiles
    profiles=($(grep '^\[profile ' ~/.aws/config 2>/dev/null | sed -E 's/^\[profile (.+)\]/\1/'))

    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No AWS profiles found in ~/.aws/config."
        return 1
    fi

    echo "Select AWS SSO profile:"
    select profile in "${profiles[@]}"; do
        if [ -n "$profile" ]; then
            echo "Logging into $profile ..."
            aws sso login --profile "$profile"
            break
        else
            echo "Invalid choice. Please select a number from the list."
        fi
    done
}

# --- AWS CLI Version Check
aws_cli_version() {
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI is not installed."        
        return 1
    fi
    aws --version
}

###--- AWS SSO Logout Function
aws_sso_logout() {
    echo "Logging out from all AWS SSO sessions..."  
    aws sso logout
    echo "All AWS SSO sessions logged out."
}


###--- Check AWS SSO Login Status
aws_check_all_profiles() {
    local profiles=(
        "AWS-POC-VOC-Admin"
        "AWS-POC-VOC-Cluster"
        "vast-s3-reader"
    )

    for profile in "${profiles[@]}"; do
        echo "🔍 Checking AWS SSO Login Status for profile: $profile"
        aws sts get-caller-identity --profile "$profile" --output json || echo "❌ Not logged in"
        echo "---------------------------------------------"
    done
}

###--- List AWS Profiles
aws_list_profiles() {
    echo "Available AWS Profiles:"
    grep '^\[profile ' ~/.aws/config 2>/dev/null | sed -E 's/^\[profile (.+)\]/\1/' || echo "No profiles found" 
}

