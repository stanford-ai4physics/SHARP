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

    # --- EC2 instance role for ECS ---
    INSTANCE_ROLE="ecsInstanceRole"
    if aws iam get-role --role-name "$INSTANCE_ROLE" &>/dev/null; then
        echo "$INSTANCE_ROLE already exists, skipping."
    else
        echo "Creating $INSTANCE_ROLE..."
        aws iam create-role \
            --role-name "$INSTANCE_ROLE" \
            --assume-role-policy-document "file://${_SETUP_SCRIPT_DIR}/ec2-trust-policy.json"
        aws iam attach-role-policy \
            --role-name "$INSTANCE_ROLE" \
            --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
        aws iam attach-role-policy \
            --role-name "$INSTANCE_ROLE" \
            --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
    fi

    # --- Instance profile (required wrapper for EC2 roles) ---
    INSTANCE_PROFILE="ecsInstanceProfile"
    if aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE" &>/dev/null; then
        echo "$INSTANCE_PROFILE already exists, skipping."
    else
        echo "Creating instance profile $INSTANCE_PROFILE..."
        aws iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE"
        aws iam add-role-to-instance-profile \
            --instance-profile-name "$INSTANCE_PROFILE" \
            --role-name "$INSTANCE_ROLE"
    fi

    # --- Security group for EC2 instance ---
    SG_NAME="ecs-instance-sg"
    EXISTING_SG=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" \
        --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

    if [ "$EXISTING_SG" != "None" ] && [ -n "$EXISTING_SG" ]; then
        echo "Security group $SG_NAME already exists ($EXISTING_SG), skipping."
    else
        echo "Creating security group $SG_NAME..."
        VPC_ID=$(aws ec2 describe-subnets \
            --subnet-ids "$SUBNET_ID" \
            --query "Subnets[0].VpcId" --output text)
        aws ec2 create-security-group \
            --group-name "$SG_NAME" \
            --description "Security group for ECS EC2 instances" \
            --vpc-id "$VPC_ID" > /dev/null
    fi

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

export SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=ecs-instance-sg" \
    --query "SecurityGroups[0].GroupId" --output text)
echo "SG_ID=${SG_ID}"

# --- ECS-optimized AMI (Amazon Machine Image = OS image for EC2 instances) ---
# For GPU instances, use the gpu variant instead:
#   /aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended
export AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
    --query "Parameters[0].Value" --output text | jq -r '.image_id')
echo "AMI_ID=${AMI_ID}"

unset _SETUP_SCRIPT_DIR
echo "Done."
