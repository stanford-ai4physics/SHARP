# ECS Deployment

Deploy and run the agent container on [AWS ECS](https://aws.amazon.com/ecs/) with EC2 instances. The default setup uses a small CPU instance; see [Enabling GPU Support](#enabling-gpu-support) to switch to GPU instances.

## Overview

The deployment involves:

- **ECR** (Elastic Container Registry) — stores your Docker image in the cloud
- **ECS** (Elastic Container Service) — orchestrates the container
- **EC2** (Elastic Compute Cloud) instance — runs the container (default: `t3.small`, 2 vCPUs, 2 GB RAM)
- **IAM** (Identity and Access Management) roles — grant permissions for ECS tasks and the EC2 instance
- **AMI** (Amazon Machine Image) — pre-built OS image for EC2 instances (like a Docker image but for VMs)
- **ARN** (Amazon Resource Name) — AWS's universal ID format for any resource

### Architecture

1. You launch an EC2 instance with the ECS-optimized AMI
2. The instance auto-registers with your ECS cluster (via user data)
3. You run ECS tasks on that instance (same `run-task` / `stop-task` CLI workflow)
4. When done, you stop or terminate the instance to stop billing

## Prerequisites

- **AWS CLI** — `brew install awscli` on macOS

- **Docker** installed

- **Session Manager plugin** (needed to open a shell in the container) — `brew install session-manager-plugin` on macOS

- **jq** — `brew install jq` on macOS (used by the setup script to parse the AMI ID)

### AWS authentication

First, set your default region (you can skip the access key prompts by pressing Enter):

```bash
aws configure
```

```text
AWS Access Key ID [None]:
AWS Secret Access Key [None]:
Default region name [None]: eu-central-1
Default output format [None]:
```

Then log in via the browser:

```bash
aws login
```

This will open a browser window where you can authenticate with your AWS account (IAM or root user).

## Setup

### 1. Run the setup script

This detects your AWS account ID and subnet, creates the required IAM roles (for ECS tasks and the EC2 instance), an instance profile, a security group, and the logging setup. It also looks up the ECS-optimized AMI. Use `source` so the exports are available in your current shell:

```bash
source ./ecs/setup-ecs.sh
```

### 2. Create an ECR repository (first time only)

This creates a container registry where your Docker image will be stored.

```bash
aws ecr create-repository --repository-name agent-image
```

### 3. Build and push the Docker image

Authenticate Docker with ECR:

```bash
aws ecr get-login-password --region eu-central-1 \
    | docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com
```

Build the image:

```bash
docker buildx build --platform linux/amd64 -t agent-image ./.devcontainer
```

Tag and push to ECR:

```bash
docker tag agent-image:latest \
    ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/agent-image:latest
```

```bash
docker push \
    ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com/agent-image:latest
```

### 4. Create an ECS cluster (first time only)

A cluster is a logical grouping of tasks (running containers).

```bash
aws ecs create-cluster --cluster-name my-agent-test-cluster
```

### 5. Register the task definition

The task definition (`agent-container.yaml`) tells ECS which image to run and how much CPU/memory to allocate. Since it contains `${AWS_ACCOUNT_ID}` placeholders, we use `envsubst` to fill them in before registering:

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
```

```bash
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```

### 6. Launch the EC2 instance

Launch the instance. The `--user-data` script tells the ECS agent which cluster to join. The `$AMI_ID` variable (an ECS-optimized AMI — a pre-built OS image for EC2) was set by the setup script in step 1:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
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
echo "INSTANCE_ID=${INSTANCE_ID}"
```

Wait 1–2 minutes for the instance to boot and register with ECS, then verify:

```bash
aws ecs list-container-instances --cluster my-agent-test-cluster
```

You should see one container instance ARN.

> **Note**: If `run-instances` fails with "invalid instance profile", wait 10 seconds and retry — newly created instance profiles can take a moment to propagate.

## Logging

Container stdout/stderr is shipped to **CloudWatch Logs** via the `awslogs` log driver configured in the task definition. The log group `/ecs/agent-container` is created automatically by the setup script.

View logs in the AWS Console under **CloudWatch → Log groups → /ecs/agent-container**, or from the CLI:

```bash
aws logs tail /ecs/agent-container --follow
```

## Running

Make sure you have run `source ./ecs/setup-ecs.sh` in your current shell first (step 1), and that your EC2 instance is running (step 6).

### Start a task

A "task" is a running instance of the container on the EC2 instance.

```bash
aws ecs run-task \
    --cluster my-agent-test-cluster \
    --launch-type EC2 \
    --task-definition agent-container \
    --enable-execute-command
```

### Connect to the container

Wait ~30 seconds for the task to reach RUNNING state.

List running tasks — copy the task ID (the long string after the last `/`):

```bash
aws ecs list-tasks --cluster my-agent-test-cluster
```

Open a shell in the container:

```bash
aws ecs execute-command \
    --cluster my-agent-test-cluster \
    --task <TASK_ID> \
    --container researcher \
    --interactive \
    --command "/bin/bash"
```

### Stop a task

```bash
aws ecs stop-task --cluster my-agent-test-cluster --task <TASK_ID>
```

### List EC2 instances

If you lost track of the instance ID, list all running/stopped instances:

```bash
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,Name:Tags[?Key=='Name']|[0].Value}" \
    --output table
```

### Stop the EC2 instance (when done working)

**Important**: You are billed while the instance is running. Stop it when you are not using it.

Stop (preserves the instance, can restart later — no billing while stopped):

```bash
aws ec2 stop-instances --instance-ids $INSTANCE_ID
```

Restart later:

```bash
aws ec2 start-instances --instance-ids $INSTANCE_ID
```

Terminate (permanently deletes the instance):

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

> **Note**: When you stop and restart the instance, it automatically re-registers with the ECS cluster. Wait 1–2 minutes before running new tasks.

## Updating

After modifying `agent-container.yaml`, re-register the task definition:

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
```

```bash
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```

## Enabling GPU Support

To switch to a GPU instance, three things need to change:

### 1. Task definition

In `agent-container.yaml`, uncomment the `resourceRequirements` block and adjust `cpu`/`memory` to match the GPU instance:

```yaml
    cpu: 4096   # 4 vCPUs (g4dn.xlarge)
    memory: 15360 # 15 GB
    resourceRequirements:
      - type: GPU
        value: "1"
```

Then re-register the task definition (see [Updating](#updating)).

### 2. AMI

In `setup-ecs.sh`, change the AMI SSM parameter path to use the **GPU-optimized** variant (includes NVIDIA drivers):

```bash
# change this:
/aws/service/ecs/optimized-ami/amazon-linux-2/recommended
# to this:
/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended
```

Then re-run `source ./ecs/setup-ecs.sh` to pick up the new `$AMI_ID`.

### 3. Instance type and user data

Launch a GPU instance with GPU support enabled:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type g4dn.xlarge \
    --count 1 \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name=ecsInstanceProfile \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ecs-gpu-worker}]' \
    --user-data "$(printf '#!/bin/bash\necho ECS_CLUSTER=my-agent-test-cluster >> /etc/ecs/ecs.config\necho ECS_ENABLE_GPU_SUPPORT=true >> /etc/ecs/ecs.config')" \
    --query "Instances[0].InstanceId" --output text)
```

Verify GPU is available after the instance registers:

```bash
nvidia-smi   # run inside the container - but make sure it's installed in the image
```
