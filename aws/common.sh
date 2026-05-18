#!/bin/bash
# common.sh — Shared startup functions for AWS Budget Guard scripts
# Source this file, do not execute it directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

check_prerequisites() {
    local missing=0

    if ! command -v aws &>/dev/null; then
        echo "ERROR: AWS CLI not found."
        echo "  Install via: brew install awscli"
        missing=1
    fi

    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq not found."
        echo "  Install via: brew install jq"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        echo "Install the missing dependencies above and try again."
        exit 1
    fi
}

load_config() {
    local config_file="$SCRIPT_DIR/config.env"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: config.env not found at $config_file"
        echo "  Copy the example and fill in your values:"
        echo "  cp config.env.example config.env"
        exit 1
    fi

    source "$config_file"

    if [[ -n "${AWS_PROFILE:-}" ]]; then
        export AWS_PROFILE
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN 2>/dev/null || true
    fi

    local missing=0

    if [[ -z "$AWS_ALLOWED_ACCOUNT_ID" ]]; then
        echo "ERROR: AWS_ALLOWED_ACCOUNT_ID is not set in config.env"
        missing=1
    fi

    if [[ -z "$AWS_ALLOWED_ACCOUNT_EMAIL" ]]; then
        echo "ERROR: AWS_ALLOWED_ACCOUNT_EMAIL is not set in config.env"
        missing=1
    fi

    if [[ -z "$BUDGET_NAME" ]]; then
        echo "ERROR: BUDGET_NAME is not set in config.env"
        missing=1
    fi

    if [[ -z "$BUDGET_AMOUNT" ]]; then
        echo "ERROR: BUDGET_AMOUNT is not set in config.env"
        missing=1
    fi

    if [[ -z "$SNS_TOPIC_NAME" ]]; then
        echo "ERROR: SNS_TOPIC_NAME is not set in config.env"
        missing=1
    fi

    if [[ -z "$AWS_REGION" ]]; then
        echo "ERROR: AWS_REGION is not set in config.env"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        echo "Fill in the missing values in config.env and try again."
        exit 1
    fi
}

verify_account() {
    local identity
    identity=$(aws sts get-caller-identity --output json 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to get AWS identity. Are your credentials configured?"
        echo "  Source your personal account credentials before running."
        echo ""
        echo "  AWS error: $identity"
        exit 1
    fi

    local account_id
    local arn
    account_id=$(echo "$identity" | jq -r '.Account')
    arn=$(echo "$identity" | jq -r '.Arn')

    if [[ -z "$account_id" || "$account_id" == "null" ]]; then
        echo "ERROR: Failed to parse AWS identity response."
        echo "  Response: $identity"
        exit 1
    fi

    if [[ "$account_id" != "$AWS_ALLOWED_ACCOUNT_ID" ]]; then
        echo "ERROR: Wrong AWS account!"
        echo ""
        echo "  Current account: $account_id"
        echo "  Current ARN:     $arn"
        echo "  Expected account: $AWS_ALLOWED_ACCOUNT_ID"
        echo ""
        echo "  This is NOT your personal account. Exiting."
        exit 1
    fi

    echo "AWS Account: $account_id"
    echo "ARN:         $arn"
    echo ""
    read -r -p "You are running as the above identity on personal account $account_id. Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
}
