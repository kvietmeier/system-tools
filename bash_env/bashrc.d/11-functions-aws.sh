###=================================================================================================###
### AWS Authentication Helpers
### File: .bashrc.d/11-functions-aws.sh
### Purpose:
###   Simplify AWS SSO login via dynamic profile selection
### Created by Karl Vietmeier
### License: Apache 2.0
###=================================================================================================###

###--- Set Active AWS Profile
aws_use() {
    if [ -z "$1" ]; then
        echo "Usage: aws_use <profile>"
        return 1
    fi

    export AWS_PROFILE="$1"
    echo "🔹 AWS profile set to: $AWS_PROFILE"
}


###--- AWS SSO Login Function (Interactive / AWS_PROFILE-aware)
aws_sso_login() {
    local profile="${1:-${AWS_PROFILE:-}}"

    if [ -n "$profile" ]; then
        export AWS_PROFILE="$profile"
        echo "🔐 Logging into AWS SSO using profile: $AWS_PROFILE ..."
        aws sso login --profile "$AWS_PROFILE" --no-browser
        return
    fi

    # Interactive fallback
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
            aws sso login --profile "$profile" --no-browser
            break
        else
            echo "Invalid choice. Please select a number from the list."
        fi
    done
}

# Convenience aliases for specific AWS SSO profiles (customize as needed)
aws_rnd() { aws_sso_login VastData_RnD-Admin; }
aws_poc() { aws_sso_login AWS-POC-VOC-Admin; }

###--- Check AWS SSO Login Status for Current Profile
aws_sso_status() {
    local cache_file
    cache_file=$(ls -t ~/.aws/sso/cache/*.json 2>/dev/null | head -n 1)

    if [ -z "$cache_file" ]; then
        echo "❌ Not logged in (no cache)"
        return 1
    fi

    local expires exp_epoch now_epoch
    expires=$(jq -r '.expiresAt' "$cache_file")
    exp_epoch=$(date -d "$expires" +%s 2>/dev/null)
    now_epoch=$(date +%s)

    if [ "$now_epoch" -lt "$exp_epoch" ]; then
        echo "✅ SSO session valid until $expires"
    else
        echo "⚠️ SSO session expired"
    fi
}


###--- AWS CLI Version Check
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

###--- AWS WhoAmI Function (Current Caller Identity)
aws_whoami() {
    echo "🔹 Profile: ${AWS_PROFILE:-none}"
    aws sts get-caller-identity \
        --query '{Account:Account, Arn:Arn}' \
        --output table 2>/dev/null || echo "❌ Not logged in"
}


###--- List AWS Profiles
aws_list_profiles() {
    echo "i###---  Available AWS Profiles  ---###"
    grep '^\[profile ' ~/.aws/config 2>/dev/null | sed -E 's/^\[profile (.+)\]/\1/' || echo "No profiles found"
}

###--- AWS Purge All Credentials (SSO + static)
aws_purge_creds() {
    echo "Logging out from all AWS SSO sessions..."
    aws sso logout
    echo "Logged out from AWS SSO"

    echo "Purging all AWS cached credentials..."

    # Remove AWS SSO cache
    if [ -d "$HOME/.aws/sso/cache" ]; then
        rm -f "$HOME/.aws/sso/cache"/*
        echo "Cleared ~/.aws/sso/cache"
    else
        echo "No SSO cache found."
    fi

    # Remove all credentials from ~/.aws/credentials
    if [ -f "$HOME/.aws/credentials" ]; then
        > "$HOME/.aws/credentials"
        echo "Cleared ~/.aws/credentials file"
    else
        echo "No credentials file found."
    fi

    echo "AWS credential purge complete."
}


###=================================================================================================###
###  Aliases
###=================================================================================================###

if command -v aws >/dev/null 2>&1; then
   # AWS SSO login/logout and profile management
   alias awslogin=aws_sso_login
   alias awslist=aws_list_profiles
   alias awsversion=aws_cli_version
   alias awslogout=aws_sso_logout
   alias awspurge=aws_purge_creds
   
   # AWS WhoAmI and SSO status
   alias awswho=aws_whoami
   alias awstatus=aws_sso_status
   
   # Convenience aliases for specific AWS SSO profiles (customize as needed)
   alias awsrnd='aws_sso_login VastData_RnD-Admin'
   alias awspoc='aws_sso_login AWS-POC-VOC-Admin'
fi


###=================================================================================================###
### Doesn't work
###--- Check AWS SSO Login Status (Dynamic, Skip Key Profiles)
aws_check_all_profiles() {
    local profiles
    profiles=($(aws configure list-profiles 2>/dev/null))

    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No AWS profiles found."
        return 1
    fi

    for profile in "${profiles[@]}"; do
        [[ "$profile" == *Key* ]] && continue

        echo "===> Checking profile: $profile"

        # Try to get role credentials (forces SSO validation)
        if aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
            # Now check if token is actually valid via cache expiration
            local cache_file
            cache_file=$(ls -t ~/.aws/sso/cache/*.json 2>/dev/null | head -n 1)

            if [ -n "$cache_file" ]; then
                local expires
                expires=$(jq -r '.expiresAt' "$cache_file" 2>/dev/null)

                if [ -n "$expires" ]; then
                    local exp_epoch now_epoch
                    exp_epoch=$(date -d "$expires" +%s 2>/dev/null)
                    now_epoch=$(date +%s)

                    if [ "$now_epoch" -lt "$exp_epoch" ]; then
                        echo "✅ Logged in (valid until $expires)"
                    else
                        echo "⚠️ Token expired"
                    fi
                else
                    echo "⚠️ Could not read expiration"
                fi
            else
                echo "⚠️ No SSO cache found"
            fi
        else
            echo "❌ Not logged in"
        fi

        echo "---------------------------------------------"
    done
}