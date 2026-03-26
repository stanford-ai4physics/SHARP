## Local Docker

1. Build: `docker build -t agent .devcontainer/`
2. Run: `docker run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW -v $(pwd):/workspace agent`
3. Inside container: `claude --dangerously-skip-permissions`

The entrypoint automatically sets up the iptables firewall.

## Perlmutter / Shifter (NERSC)

Shifter doesn't support `--cap-add`, so network restriction uses a Squid proxy in a second container.

### One-time setup

Build and push both images:

```bash
# Agent image
docker build --platform linux/amd64 -t nollde24/agent:latest .devcontainer/
docker push nollde24/agent:latest

# Squid proxy image
docker build --platform linux/amd64 -t nollde24/squid-proxy:latest squid-proxy/
docker push nollde24/squid-proxy:latest
```

Pull on Perlmutter:

```bash
shifterimg pull nollde24/agent:latest
shifterimg pull nollde24/squid-proxy:latest
```

### Running

Get an interactive allocation, then start the proxy and agent:

```bash
# Get a node
salloc --nodes 1 --qos interactive --time 01:00:00 --constraint gpu --gpus 1 --account m3246

# Terminal 1 — start Squid proxy
srun --overlap shifter --image=nollde24/squid-proxy:latest squid -N -f /etc/squid/squid.conf &

# Terminal 2 — start agent with proxy
srun --overlap shifter --image=nollde24/agent:latest --env SQUID_PROXY=127.0.0.1:3128 --volume=$(pwd):/workspace --entry /bin/bash
```

The entrypoint detects `SQUID_PROXY` and sets `http_proxy`/`https_proxy` automatically.

### Editing the domain whitelist

Allowed domains are defined in two places (keep them in sync):
- `init-firewall.sh` — iptables rules for local Docker
- `squid-proxy/squid.conf` — Squid ACLs for Perlmutter
