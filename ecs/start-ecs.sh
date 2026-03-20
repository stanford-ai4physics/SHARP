#!/bin/bash
# Start the ECS stack: load environment, (re-)register the task definition,
# launch or restart the EC2 instance, and run the container task.
#
# Usage:
#   source ./ecs/start-ecs.sh              # with SSH (default, injects ~/.ssh/id_rsa_aws_agent_project.pub)
#   source ./ecs/start-ecs.sh --no-ssh     # without SSH (connect via ECS exec only)
#
# Must be sourced (not executed) so that INSTANCE_ID etc. are available afterwards.

# Resolve script directory (works in both bash and zsh).
_START_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- Parse arguments ---
_SSH_ENABLED=true
for arg in "$@"; do
    case "$arg" in
        --no-ssh) _SSH_ENABLED=false ;;
    esac
done

# --- 1. Load environment variables ---
echo "==> Loading environment..."
if [ -f "${_START_SCRIPT_DIR}/.env" ]; then
    echo "Loading ecs/.env..."
    set -a
    . "${_START_SCRIPT_DIR}/.env"
    set +a
fi
source "${_START_SCRIPT_DIR}/setup-ecs.sh"

# --- 2. Register task definition (always re-register to pick up changes) ---
echo "==> Registering task definition..."
envsubst < "${_START_SCRIPT_DIR}/agent-container.yaml" > /tmp/agent-container.yaml
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml > /dev/null
echo "Task definition registered."

# --- 3. Launch or restart the EC2 instance ---
# Check if there's an existing stopped instance tagged ecs-worker.
_EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=ecs-worker" "Name=instance-state-name,Values=stopped" \
    --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null || true)

if [ "$_EXISTING_INSTANCE" != "None" ] && [ -n "$_EXISTING_INSTANCE" ]; then
    echo "==> Restarting stopped instance ${_EXISTING_INSTANCE}..."
    aws ec2 start-instances --instance-ids "$_EXISTING_INSTANCE" > /dev/null
    export INSTANCE_ID="$_EXISTING_INSTANCE"
else
    echo "==> Launching new EC2 instance..."
    export INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t3.small \
        --count 1 \
        --subnet-id "$SUBNET_ID" \
        --security-group-ids "$SG_ID" \
        --iam-instance-profile Name=ecsInstanceProfile \
        --associate-public-ip-address \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ecs-worker}]' \
        --user-data "$(printf '#!/bin/bash\necho ECS_CLUSTER=my-agent-test-cluster >> /etc/ecs/ecs.config')" \
        --query "Instances[0].InstanceId" --output text)
fi
echo "INSTANCE_ID=${INSTANCE_ID}"

# --- 4. Wait for the instance to register with ECS ---
echo "==> Waiting for instance to register with ECS cluster..."
_i=0
while [ $_i -lt 30 ]; do
    _COUNT=$(aws ecs list-container-instances --cluster my-agent-test-cluster \
        --query "length(containerInstanceArns)" --output text 2>/dev/null || true)
    if [ "$_COUNT" != "0" ] && [ "$_COUNT" != "None" ] && [ -n "$_COUNT" ]; then
        echo "Instance registered."
        break
    fi
    _i=$((_i + 1))
    if [ $_i -eq 30 ]; then
        echo "WARNING: Instance did not register after 60 seconds. Check the AWS console."
        break
    fi
    sleep 2
done

# --- 5. Run the task (with retries — placement can fail right after instance registers) ---
echo "==> Starting ECS task..."

# Build the environment overrides
_ENV_OVERRIDES=""
if [ "$_SSH_ENABLED" = true ]; then
    if [ ! -f ~/.ssh/id_rsa_aws_agent_project.pub ]; then
        echo "ERROR: ~/.ssh/id_rsa_aws_agent_project.pub not found. Generate it first or use --no-ssh."
        unset _START_SCRIPT_DIR _SSH_ENABLED _EXISTING_INSTANCE _i _CONNECTED _AGENT_CONNECTED
        return 1 2>/dev/null || exit 1
    fi
    _PUBKEY=$(cat ~/.ssh/id_rsa_aws_agent_project.pub)
    _ENV_OVERRIDES="{\"name\":\"SSH_PUBKEY\",\"value\":\"${_PUBKEY}\"}"
fi
if [ -n "${GH_TOKEN:-}" ]; then
    if [ -n "$_ENV_OVERRIDES" ]; then
        _ENV_OVERRIDES="${_ENV_OVERRIDES},"
    fi
    _ENV_OVERRIDES="${_ENV_OVERRIDES}{\"name\":\"GH_TOKEN\",\"value\":\"${GH_TOKEN}\"}"
else
    echo "WARNING: GH_TOKEN not set — repo will not be cloned in the container."
fi
if [ -n "${GH_REPO:-}" ]; then
    if [ -n "$_ENV_OVERRIDES" ]; then
        _ENV_OVERRIDES="${_ENV_OVERRIDES},"
    fi
    _ENV_OVERRIDES="${_ENV_OVERRIDES}{\"name\":\"GH_REPO\",\"value\":\"${GH_REPO}\"}"
fi

# Build the --overrides flag if we have any env vars to pass
_OVERRIDES_FLAG=""
if [ -n "$_ENV_OVERRIDES" ]; then
    _OVERRIDES_FLAG="--overrides {\"containerOverrides\":[{\"name\":\"researcher\",\"environment\":[${_ENV_OVERRIDES}]}]}"
fi

_TASK_ARN="None"
_attempt=0
while [ "$_TASK_ARN" = "None" ] && [ $_attempt -lt 10 ]; do
    _attempt=$((_attempt + 1))
    if [ $_attempt -gt 1 ]; then
        echo "Task placement failed, retrying (${_attempt}/10)..."
        sleep 5
    fi

    if [ -n "$_OVERRIDES_FLAG" ]; then
        _RUN_RESULT=$(aws ecs run-task \
            --cluster my-agent-test-cluster \
            --launch-type EC2 \
            --task-definition agent-container \
            --enable-execute-command \
            --overrides "{\"containerOverrides\":[{\"name\":\"researcher\",\"environment\":[${_ENV_OVERRIDES}]}]}" 2>&1) || true
    else
        _RUN_RESULT=$(aws ecs run-task \
            --cluster my-agent-test-cluster \
            --launch-type EC2 \
            --task-definition agent-container \
            --enable-execute-command 2>&1) || true
    fi

    _TASK_ARN=$(echo "$_RUN_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tasks'][0]['taskArn'] if d.get('tasks') else 'None')" 2>/dev/null || echo "None")

    # Show failure reason if task didn't start
    if [ "$_TASK_ARN" = "None" ]; then
        _FAILURE=$(echo "$_RUN_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); fs=d.get('failures',[]); print(fs[0]['reason'] if fs else 'unknown')" 2>/dev/null || echo "unknown")
        echo "  Reason: ${_FAILURE}"
    fi
done

if [ "$_TASK_ARN" = "None" ]; then
    echo "ERROR: Failed to start task after 10 attempts."
    echo "Full response: $_RUN_RESULT"
    unset _START_SCRIPT_DIR _SSH_ENABLED _EXISTING_INSTANCE _i _COUNT _PUBKEY _TASK_ARN _RUN_RESULT _FAILURE _attempt
    return 1 2>/dev/null || exit 1
fi

if [ "$_SSH_ENABLED" = true ]; then
    echo "SSH enabled."
fi

export TASK_ID=$(echo "$_TASK_ARN" | awk -F'/' '{print $NF}')
echo "TASK_ID=${TASK_ID}"

# --- 6. Wait for task and collect connection info ---
echo ""
echo "==> Waiting for task to reach RUNNING state..."
_task_running=false
for _w in $(seq 1 12); do
    _STATUS=$(aws ecs describe-tasks --cluster my-agent-test-cluster --tasks "$TASK_ID" \
        --query "tasks[0].lastStatus" --output text 2>/dev/null || true)
    if [ "$_STATUS" = "RUNNING" ]; then
        _task_running=true
        break
    fi
    sleep 5
done

export PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null || true)

echo ""
echo "========================================="
echo "  ECS Stack Ready"
echo "========================================="
echo ""
echo "  Instance ID:  ${INSTANCE_ID}"
echo "  Task ID:      ${TASK_ID}"
if [ "$_task_running" = true ]; then
    echo "  Task status:  RUNNING"
else
    echo "  Task status:  ${_STATUS:-UNKNOWN} (may still be starting)"
fi
echo "  Public IP:    ${PUBLIC_IP}"
echo ""
echo "  --- Connect ---"
echo ""
if [ "$_SSH_ENABLED" = true ] && [ "$PUBLIC_IP" != "None" ] && [ -n "$PUBLIC_IP" ]; then
    echo "  SSH:       ssh -p 2222 -i ~/.ssh/id_rsa_aws_agent_project researcher@${PUBLIC_IP}"
fi
echo "  ECS exec:  aws ecs execute-command \\"
echo "               --cluster my-agent-test-cluster \\"
echo "               --task ${TASK_ID} \\"
echo "               --container researcher \\"
echo "               --interactive --command /bin/bash"
echo ""
echo "  --- Logs ---"
echo ""
echo "  aws logs tail /ecs/agent-container --follow"
echo ""
echo "========================================="

unset _START_SCRIPT_DIR _SSH_ENABLED _EXISTING_INSTANCE _i _CONNECTED _AGENT_CONNECTED _PUBKEY _ENV_OVERRIDES _OVERRIDES_FLAG _TASK_ARN _RUN_RESULT _FAILURE _attempt _PUBLIC_IP _task_running _STATUS _w
