# Derived image: iSponsorBlockTV + locked-down ttyd setup terminal.
# Store schema has no build: key - build & publish, then reference the tag:
#   docker build -t ghcr.io/cmolina/isponsorblocktv-ttyd:v2.11.0 .
#   docker push ghcr.io/cmolina/isponsorblocktv-ttyd:v2.11.0
FROM ghcr.io/dmunozv04/isponsorblocktv:v2.11.0

RUN apk add --no-cache ttyd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7681

ENTRYPOINT ["/entrypoint.sh"]
