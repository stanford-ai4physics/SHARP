## Steps:
1. Create docker container: `docker build -t agent .`
2. Start docker container: `docker run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW -v $(pwd):/workspace agent /bin/bash -c "sudo /usr/local/bin/init-firewall.sh && /bin/bash"`
3. Run Claude: `claude --dangerously-skip-permissions`