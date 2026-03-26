#!/bin/bash

# Try iptables firewall first (Docker with --cap-add=NET_ADMIN)
if sudo /usr/local/bin/init-firewall.sh 2>/dev/null; then
    echo "Network restricted via iptables firewall"
else
    echo "iptables unavailable — expecting external Squid proxy"
    # SQUID_PROXY can be set via env (e.g. 127.0.0.1:3128 on same node)
    if [ -n "$SQUID_PROXY" ]; then
        export http_proxy="http://$SQUID_PROXY"
        export https_proxy="http://$SQUID_PROXY"
        export HTTP_PROXY="http://$SQUID_PROXY"
        export HTTPS_PROXY="http://$SQUID_PROXY"
        readonly http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
        echo "Proxy set to $SQUID_PROXY"
    else
        echo "WARNING: No SQUID_PROXY set — network is unrestricted"
    fi
fi

exec "$@"
