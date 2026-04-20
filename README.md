# SHARP: A Scientific Human-Agent Reproduction Pipeline

## Abstract
> Reproducing scientific analyses is essential for preserving knowledge, building extensible codebases, and deepening researcher understanding -- yet the effort often outweighs its academic recognition.
> We argue that the reproduction of scientific data analyses is fundamentally a translation task: converting human-readable knowledge (papers, documentation) into machine-readable analysis code.
> This makes it uniquely well-suited for AI agents.
> We present SHARP (Scientific Human-Agent Reproduction Pipeline), a structured framework for reproducing scientific analyses through human-agent collaboration.
> SHARP decomposes a reproduction task into discrete steps, which an AI agent executes autonomously using specialized subagents for code generation, testing, and quality assurance.
> At defined checkpoints, the researcher reviews progress, provides feedback, and steers the analysis - keeping the human firmly in control of scientific judgment while the agent handles implementation.
> We demonstrate SHARP by reproducing a jet classification task in particle physics from a published paper.
> We evaluate the reproduction along three axes: analysis performance against the original results, code quality and faithfulness, and the nature of the human-agent conversation.
> The latter is evaluated with a novel framework for characterizing human-agent interactions.
> Our work highlights a practical model for AI-assisted scientific reproduction where the researcher's role shifts from writing code to understanding, evaluating, and directing -- elevating human understanding rather than replacing it.

## Usage

### Prepare and open docker container

Run the Docker container based on the setup in [Nollde/claude-hpc](https://github.com/Nollde/claude-hpc).

This means you have to clone the repository, copy the `claude-hpc` script to `~/.local/bin/claude-hpc` and make it executable. Then you can run `claude-hpc` to start the container.

You want to update the agent image such that the additional software from this repo is included.

Then run:
```shell
claude-hpc -A m3246 -t 1:00:00 -g 1 -w <your_directory> --agent-image docker.io/jobirk/agent:latest
```

The entire `~/.claude` directory in the container is persisted in the mounted workspace.
You can find the conversation in `<your_directory>/._claude`.

### Example
First we need to load the plan skill to create the PRD:

> (PROMPT) Load the plan skill and create a PRD for replication (incl reimplementation of the code) of the paper https://arxiv.org/abs/2109.00546 up until figure 6 (right). Because resources on this machine are very limited I want to have a very small setup for the MAF (small architecture, limited number of epochs).
We want to investigate the plan and optionally make changes.

Then we can transform the plan into a `project.json`:
> (PROMPT) Load the setup skill and convert analysis-plan.md to project.json

Third step, we run the researcher on the project.json:
`./researcher.sh --tool claude 10`
