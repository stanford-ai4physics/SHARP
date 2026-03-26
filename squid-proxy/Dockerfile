FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
  squid \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY squid.conf /etc/squid/squid.conf

RUN mkdir -p /tmp/squid && chown proxy:proxy /tmp/squid

EXPOSE 3128

USER proxy
CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]
