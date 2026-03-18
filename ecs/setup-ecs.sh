#!/bin/bash
# Set up ECS infrastructure: environment variables, IAM roles, cluster, and task definition.
# Safe to run multiple times — skips resources that already exist.
# Designed to be sourced (`source ./ecs/setup-ecs.sh`) so exports reach the caller.

# Resolve script directory (works in both bash and zsh).
_SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- Environment variables (exported into the caller's shell) ---
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export SUBNET_ID=$(aws ec2 describe-subnets --query "Subnets[0].SubnetId" --output text)
echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
echo "SUBNET_ID=${SUBNET_ID}"

# --- IAM roles & log group (run in a subshell so set -e doesn't leak) ---
(
    set -euo pipefail

    create_role_if_missing() {
        local role_name="$1"
        local policy_arn="$2"

        if aws iam get-role --role-name "$role_name" &>/dev/null; then
            echo "$role_name already exists, skipping."
        else
            echo "Creating $role_name..."
            aws iam create-role \
                --role-name "$role_name" \
                --assume-role-policy-document "file://${_SETUP_SCRIPT_DIR}/trust-policy.json"
            aws iam attach-role-policy \
                --role-name "$role_name" \
                --policy-arn "$policy_arn"
        fi
    }

    create_role_if_missing ECSTaskExecutionRole \
        arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

    create_role_if_missing ECSTaskRole \
        arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

    # --- CloudWatch log group ---
    LOG_GROUP="/ecs/agent-container"
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
        --query "logGroups[?logGroupName=='$LOG_GROUP']" --output text | grep -q "$LOG_GROUP"; then
        echo "Log group $LOG_GROUP already exists, skipping."
    else
        echo "Creating CloudWatch log group $LOG_GROUP..."
        aws logs create-log-group --log-group-name "$LOG_GROUP"
    fi
)

unset _SETUP_SCRIPT_DIR
echo "Done."
