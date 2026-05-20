iSponsorBlockTV connects to your YouTube TV app and automatically skips sponsored segments, intros, outros, and other unwanted content using the community-powered [SponsorBlock](https://sponsor.ajay.app/) API.

## Features

- Automatically skip sponsors, intros, outros, self-promotions, and more
- Auto-mute YouTube ads and press "Skip Ad" the moment it appears
- Works with Apple TV, Samsung TV, LG TV, Android TV, Chromecast, Google TV, Roku, Fire TV, Xbox, PlayStation, and more
- Device discovery via mDNS/SSDP or manual pairing with a YouTube TV code
- No need to be on the same network after initial setup — only internet access required
- Configurable via a web-based setup UI on first launch

## Initial Setup

Run the interactive CLI setup after installing the app:

```bash
CONTAINER=$(sudo docker ps --filter name=isponsorblocktv --format "{{.Names}}" | head -1)
IMAGE=$(sudo docker inspect "$CONTAINER" --format '{{.Config.Image}}')
DATA=$(sudo docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/app/data"}}{{.Source}}{{end}}{{end}}')

sudo docker run -it --rm \
    --network host \
    -v "$DATA:/app/data" \
    "$IMAGE" \
    --setup-cli
```
