## Steps:
1. Create docker container: `docker build -t agent .`
1. Start docker container: `docker run -it --rm -v $(pwd):/workspace agent /bin/bash`
1. Run Claude: `claude --dangerously-skip-permissions`