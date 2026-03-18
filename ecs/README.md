# ECS Deployment

Deploy and run the agent container on [AWS ECS Fargate](https://aws.amazon.com/fargate/) — a serverless compute engine that runs Docker containers without managing servers.

## Overview

The deployment involves:

- **ECR** (Elastic Container Registry) — stores your Docker image in the cloud
- **ECS** (Elastic Container Service) — runs the container from that image
- **IAM roles** — grant permissions for ECS to pull images and for you to connect to the running container
- **Fargate** — the serverless launch mode (no EC2 instances to manage)

## Prerequisites

- **AWS CLI** — `brew install awscli` on macOS

- **Docker** installed

- **Session Manager plugin** (needed to open a shell in the container) — `brew install session-manager-plugin` on macOS

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

This detects your AWS account ID and subnet, creates the required IAM roles, and exports environment variables used by subsequent commands. Use `source` so the exports are available in your current shell:

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

Build the image for both ARM and x86 architectures:

```bash
docker buildx build --platform linux/arm64/v8,linux/amd64 -t agent-image ./.devcontainer
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

The task definition (`agent-container.yaml`) tells ECS which image to run, how much CPU/memory to allocate, and which roles to use. Since it contains `${AWS_ACCOUNT_ID}` placeholders, we use `envsubst` to fill them in before registering. The corresponding env variables are set by the `setup-ecs.sh` script (step 1).

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
```

```bash
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```

## Running

Make sure you have run `source ./ecs/setup-ecs.sh` in your current shell first (step 1).

### Start a task

A "task" is a running instance of the container.

```bash
aws ecs run-task \
    --cluster my-agent-test-cluster \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ID}],assignPublicIp=ENABLED}" \
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

## Updating

After modifying `agent-container.yaml`, re-register the task definition:

```bash
envsubst < ecs/agent-container.yaml > /tmp/agent-container.yaml
```

```bash
aws ecs register-task-definition --cli-input-yaml file:///tmp/agent-container.yaml
```
