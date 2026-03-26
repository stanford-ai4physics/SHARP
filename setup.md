# Claude on NERSC:

## Shifter Setup:
Only shifter is available so need to do things a little differently, no entrypoint, global software installations, ...

In a local session:
curl -fsSL https://claude.ai/install.sh | bash
will install claude in Location: ~/.local/bin/claude

Allocate resources:
salloc --nodes 1 --qos interactive --time 01:00:00 --constraint gpu --gpus 1 --account m3246

-> sets you into interactive node

Start squid docker container:
srun --overlap shifter --image=nollde24/squid-proxy:latest squid -N -f /etc/squid/squid.conf &

Strart agent docker container with squid proxy:
srun --overlap --pty --export=ALL,http_proxy=http://127.0.0.1:3128,https_proxy=http://127.0.0.1:3128 shifter --image=nollde24/agent:latest --volume=$(pwd):/workspace bash --login


## Podman-HPC Setup:

Much better, using podman:

podman-hpc run -it --rm -e SQUID_PROXY=127.0.0.1:3128 -v $(pwd):/workspace nollde24/agent:latest

podman-hpc run -it --rm -e SQUID_PROXY=127.0.0.1:3128 -v $(pwd):/workspace --network=container:squid-proxy nollde24/agent:latest


podman-hpc run -it --rm --network=host -e SQUID_PROXY=127.0.0.1:3128 -v $(pwd):/workspace nollde24/agent:latest

This works (using host network):
allocate machine
salloc --nodes 1 --qos interactive --time 01:00:00 --constraint gpu --gpus 1 --account m3246

start squid proxy:
podman-hpc run -d --rm --name squid-proxy --network=host nollde24/squid-proxy:latest squid -N -f /etc/squid/squid.conf

start agent container:
podman-hpc run -it --rm --network=host --user root -e SQUID_PROXY=127.0.0.1:3128 -v $(pwd):/workspace nollde24/agent:latest

Try with squid network -> definitely the better solution!

salloc --nodes 1 --qos interactive --time 01:00:00 --constraint gpu --gpus 1 --account m3246

podman-hpc run -d --rm --name squid-proxy nollde24/squid-proxy:latest squid -N -f /etc/squid/squid.conf

podman-hpc run -it --rm --user root -e SQUID_PROXY=127.0.0.1:3128 -v $(pwd):/workspace --network=container:squid-proxy nollde24/agent:latest