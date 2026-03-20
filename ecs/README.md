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

---

## Initial Setup (first time only)

### Prerequisites

- **AWS CLI** — `brew install awscli` on macOS
- **Docker** installed
- **Session Manager plugin** (needed to open a shell in the container) — `brew install session-manager-plugin` on macOS
- **jq** — `brew install jq` on macOS (used by the setup script to parse the AMI ID)

#### SSH key

Generate a dedicated SSH key for this project (first time only):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa_aws_agent_project -C "ecs-agent-project"
```

This creates `~/.ssh/id_rsa_aws_agent_project` (private) and `~/.ssh/id_rsa_aws_agent_project.pub` (public). The public key is automatically injected into the container at launch. To connect, use:

```bash
ssh -p 2222 -i ~/.ssh/id_rsa_aws_agent_project researcher@<PUBLIC_IP>
```

#### Environment file (`ecs/.env`)

The container can clone our GitHub repository at startup. Configuration is stored in a local `ecs/.env` file (git-ignored, never committed).

Copy the example and fill in your values:

```bash
cp ecs/.env.example ecs/.env
```

Edit `ecs/.env`:

```bash
# GitHub Personal Access Token (fine-grained, scoped to your repo)
GH_TOKEN=github_pat_...

# GitHub repository to clone into the container (owner/repo)
# Has to be owned by the same user as the token
GH_REPO=YourUser/agent_template
```

**Creating a GitHub token** (first time only):

1. Go to [GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens](https://github.com/settings/personal-access-tokens/new)
2. Set a name (e.g., `ecs-agent-project`), expiration, and scope it to your repository
3. Grant **Contents: Read and write** permission (for clone/push/pull)
4. Copy the token into `ecs/.env`

The `start-ecs.sh` script automatically sources `ecs/.env` and passes both variables to the container.

#### AWS authentication

Then log in via the browser:

```bash
aws login
```

Set your default region (you can skip the access key prompts by pressing Enter):

```bash
aws configure
```

```text
AWS Access Key ID [None]:
AWS Secret Access Key [None]:
Default region name [None]: us-west-1
Default output format [None]:
```

### 1. Run the setup script

This detects your AWS account ID and subnet, creates the required IAM roles (for ECS tasks and the EC2 instance), an instance profile, a security group, and the logging setup. It also looks up the ECS-optimized AMI. Use `source` so the exports are available in your current shell:

```bash
source ./ecs/setup-ecs.sh
```

### 2. Create an ECR repository

This creates a container registry where your Docker image will be stored.

```bash
aws ecr create-repository --repository-name agent-image
```

### 3. Create an ECS cluster

A cluster is a logical grouping of tasks (running containers).

```bash
aws ecs create-cluster --cluster-name agent-cluster
```

### 4. Build, push, and register

Build the Docker image, push it to ECR, and register the task definition:

```bash
source ./ecs/deploy-ecs.sh
```

<details>
<summary>Manual steps (if you prefer not to use the script)</summary>

Authenticate Docker with ECR:

```bash
aws ecr get-login-password --region us-west-1 \
    | docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-1.amazonaws.com
```

Build the image:

```bash
docker buildx build --platform linux/amd64 -t agent-image ./.devcontainer
```

Tag and push to ECR:

```bash
docker tag agent-image:latest \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-1.amazonaws.com/agent-image:latest
```

```bash
docker push \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-1.amazonaws.com/agent-image:latest
```

Register the task definition (`agent-container.yaml` contains `${AWS_ACCOUNT_ID}` placeholders, so we use `envsubst` to fill them in):

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```

</details>

---

## Daily Usage

### Quick start / stop

Three helper scripts handle common workflows. All must be **sourced** (not executed) so that environment variables like `INSTANCE_ID` and `TASK_ID` are available in your shell.

| Script | What it does |
|---|---|
| `source ./ecs/start-ecs.sh` | Load env, register task def, launch/restart EC2 instance, run task with SSH |
| `source ./ecs/start-ecs.sh --no-ssh` | Same as above, but without SSH (connect via ECS exec only) |
| `source ./ecs/stop-ecs.sh` | Stop all tasks and stop the EC2 instance (preserves it for restart) |
| `source ./ecs/stop-ecs.sh --terminate` | Stop all tasks and permanently delete the EC2 instance |
| `source ./ecs/deploy-ecs.sh` | Build image, push to ECR, register task definition |

Example session:

```bash
# Make sure ecs/.env exists (see "Environment file" above)

# Start everything (SSH enabled by default)
source ./ecs/start-ecs.sh

# ... work ...

# Shut down when done
source ./ecs/stop-ecs.sh
```

### Start (manual)

Make sure you have run `source ./ecs/setup-ecs.sh` in your current shell first.

#### Launch the EC2 instance

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
    --user-data "$(printf '#!/bin/bash\necho ECS_CLUSTER=agent-cluster >> /etc/ecs/ecs.config')" \
    --query "Instances[0].InstanceId" --output text)
echo "INSTANCE_ID=${INSTANCE_ID}"
```

Wait 1–2 minutes for the instance to boot and register with ECS, then verify:

```bash
aws ecs list-container-instances --cluster agent-cluster
```

> **Note**: If `run-instances` fails with "invalid instance profile", wait 10 seconds and retry — newly created instance profiles can take a moment to propagate.

#### Start a task

**Without SSH** (connect via ECS exec only):

```bash
aws ecs run-task \
    --cluster agent-cluster \
    --launch-type EC2 \
    --task-definition agent-container \
    --enable-execute-command
```

**With SSH** — pass your public key via `--overrides` to enable SSH access:

```bash
aws ecs run-task \
    --cluster agent-cluster \
    --launch-type EC2 \
    --task-definition agent-container \
    --enable-execute-command \
    --overrides "{
      \"containerOverrides\": [{
        \"name\": \"researcher\",
        \"environment\": [{
          \"name\": \"SSH_PUBKEY\",
          \"value\": \"$(cat ~/.ssh/id_rsa_aws_agent_project.pub)\"
        }]
      }]
    }"
```

This injects your public key into the container at startup. Only key-based authentication is allowed (password authentication is disabled).

### Connect to the container

Wait ~30 seconds for the task to reach RUNNING state.

List running tasks — copy the task ID (the long string after the last `/`):

```bash
aws ecs list-tasks --cluster agent-cluster
```

**Via ECS exec** (always available):

```bash
aws ecs execute-command \
    --cluster agent-cluster \
    --task <TASK_ID> \
    --container researcher \
    --interactive \
    --command "/bin/bash"
```

**Via SSH** (if launched with `SSH_PUBKEY`):

Get the public IP of the EC2 instance:

```bash
aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text
```

Connect:

```bash
ssh -p 2222 -i ~/.ssh/id_rsa_aws_agent_project researcher@<PUBLIC_IP>
```

### Stop (manual)

#### Stop a task

```bash
aws ecs stop-task --cluster agent-cluster --task <TASK_ID>
```

#### Stop the EC2 instance

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

### Useful commands

#### List EC2 instances

```bash
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,Name:Tags[?Key=='Name']|[0].Value}" \
    --output table
```

#### View logs

Container stdout/stderr is shipped to **CloudWatch Logs** via the `awslogs` log driver configured in the task definition. The log group `/ecs/agent-container` is created automatically by the setup script.

```bash
aws logs tail /ecs/agent-container --follow
```

---

## Updating

After modifying the Docker image or `agent-container.yaml`, rebuild and re-register:

```bash
source ./ecs/deploy-ecs.sh
```

Or manually:

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```

---

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
    --user-data "$(printf '#!/bin/bash\necho ECS_CLUSTER=agent-cluster >> /etc/ecs/ecs.config\necho ECS_ENABLE_GPU_SUPPORT=true >> /etc/ecs/ecs.config')" \
    --query "Instances[0].InstanceId" --output text)
```

Verify GPU is available after the instance registers:

```bash
nvidia-smi   # run inside the container - but make sure it's installed in the image
```
