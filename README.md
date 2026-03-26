# Agent Template

## Usage

### Prepare and open docker container

Run the Docker container based on the setup in [Nollde/claude-nersc](https://github.com/Nollde/claude-nersc).

This means you have to clone the repository, copy the `claude-nersc` script to `~/.local/bin/claude-nersc` and make it executable. Then you can run `claude-nersc` to start the container.

You want to update the agent image such that the additional software from this repo is included.

```shell
claude-nersc -A m3246 -t 1:00:00 -g 1 -w <your_directory> --agent-image docker.io/jobirk/agent:latest
```

### Example
First we need to load the plan skill to create the PRD:

> (PROMPT) Load the plan skill and create a PRD for replication (incl reimplementation of the code) of the paper https://arxiv.org/abs/2109.00546 up until figure 6 (right). Because resources on this machine are very limited I want to have a very small setup for the MAF (small architecture, limited number of epochs).
We want to investigate the plan and optionally make changes.

Then we can transform the plan into a `project.json`:
> (PROMPT) Load the setup skill and convert analysis-plan.md to project.json

Third step, we run the researcher on the project.json:
`./researcher.sh --tool claude 10`