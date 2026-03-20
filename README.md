# Agent Template

## Usage

### Prepare and open docker container
- see [here](https://github.com/Nollde/agent_template/tree/main/.devcontainer)

### Example
First we need to load the plan skill to create the PRD:

> (PROMPT) Load the plan skill and create a PRD for replication (incl reimplementation of the code) of the paper https://arxiv.org/abs/2109.00546 up until figure 6 (right). Because resources on this machine are very limited I want to have a very small setup for the MAF (small architecture, limited number of epochs).
We want to investigate the plan and optionally make changes.

Then we can transform the plan into a `project.json`:
> (PROMPT) Load the setup skill and convert analysis-plan.md to project.json

Third step, we run the researcher on the project.json:
`./researcher.sh --tool claude 10`