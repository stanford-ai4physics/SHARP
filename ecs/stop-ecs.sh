#!/bin/bash
# Stop the ECS stack: stop running tasks and stop the EC2 instance.
#
# Usage:
#   source ./ecs/stop-ecs.sh                # stop instance (can restart later)
#   source ./ecs/stop-ecs.sh --terminate    # permanently delete the instance
#
# Must be sourced so it can read INSTANCE_ID from the current shell.

# --- Parse arguments ---
_TERMINATE=false
for arg in "$@"; do
    case "$arg" in
        --terminate) _TERMINATE=true ;;
    esac
done

_CLUSTER="my-agent-test-cluster"

# --- 1. Stop all tasks (RUNNING and PENDING) ---
echo "==> Stopping all tasks..."
_STOPPED_COUNT=0
for _DESIRED_STATUS in RUNNING PENDING; do
    _TASK_ARNS=$(aws ecs list-tasks --cluster "$_CLUSTER" \
        --desired-status "$_DESIRED_STATUS" \
        --query "taskArns[]" --output text 2>/dev/null || true)
    if [ -n "$_TASK_ARNS" ] && [ "$_TASK_ARNS" != "None" ]; then
        for _ARN in $_TASK_ARNS; do
            echo "Stopping task $(echo "$_ARN" | awk -F'/' '{print $NF}') (${_DESIRED_STATUS})..."
            aws ecs stop-task --cluster "$_CLUSTER" --task "$_ARN" > /dev/null
            _STOPPED_COUNT=$((_STOPPED_COUNT + 1))
        done
    fi
done
if [ $_STOPPED_COUNT -gt 0 ]; then
    echo "Stopped ${_STOPPED_COUNT} task(s)."
else
    echo "No active tasks found."
fi

# --- 2. Stop or terminate the EC2 instance ---
# Try $INSTANCE_ID from the environment first, then look up by tag.
if [ -z "${INSTANCE_ID:-}" ]; then
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=ecs-worker" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null || true)
fi

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo "No running ecs-worker instance found."
else
    if [ "$_TERMINATE" = true ]; then
        echo "==> Terminating instance ${INSTANCE_ID}..."
        aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
        echo "Instance terminated."
    else
        echo "==> Stopping instance ${INSTANCE_ID} (can restart later)..."
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" > /dev/null
        echo "Instance stopped. No billing while stopped."
    fi
fi

unset _TERMINATE _CLUSTER _TASK_ARNS _ARN _DESIRED_STATUS _STOPPED_COUNT
echo "Done."
