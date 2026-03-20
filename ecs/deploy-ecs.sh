#!/bin/bash
# Build, push, and register the container image and task definition.
#
# Usage:
#   source ./ecs/deploy-ecs.sh
#
# Must be sourced so it can access AWS_ACCOUNT_ID from the environment.

# Resolve script directory (works in both bash and zsh).
_DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- 1. Load environment if needed ---
if [ -z "${AWS_ACCOUNT_ID:-}" ]; then
    echo "==> Loading environment..."
    source "${_DEPLOY_SCRIPT_DIR}/setup-ecs.sh"
fi

# Run the rest in a subshell so set -e doesn't kill the caller.
(
    set -euo pipefail

    REGION="us-west-1"
    REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

    # --- 2. Authenticate Docker with ECR ---
    echo "==> Authenticating Docker with ECR..."
    aws ecr get-login-password --region "$REGION" \
        | docker login --username AWS --password-stdin "$REPO"

    # --- 3. Build the image ---
    echo "==> Building Docker image..."
    docker buildx build --platform linux/amd64 -t agent-image ./.devcontainer

    # --- 4. Tag and push ---
    echo "==> Pushing image to ECR..."
    docker tag agent-image:latest "${REPO}/agent-image:latest"
    docker push "${REPO}/agent-image:latest"

    # --- 5. Register task definition ---
    echo "==> Registering task definition..."
    envsubst < "${_DEPLOY_SCRIPT_DIR}/agent-container.yaml" > /tmp/agent-container.yaml
    aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml > /dev/null
    echo "Task definition registered."

    echo "Done."
)
_deploy_rc=$?

unset _DEPLOY_SCRIPT_DIR
if [ $_deploy_rc -ne 0 ]; then
    echo "ERROR: deploy-ecs.sh failed."
fi
return $_deploy_rc 2>/dev/null || exit $_deploy_rc
