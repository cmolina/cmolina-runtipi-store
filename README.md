# cmolina's Runtipi App Store

A curated collection of self-hosted applications for the [Runtipi](https://runtipi.io/) platform.

## Available Apps

| | App | Description | Categories |
|---:|-----|-------------|------------|
| <img src="apps/bentopdf/metadata/logo.jpg" width="32" height="32"> | **[BentoPDF](https://github.com/bentosmth/bentopdf)** | Privacy-first, client-side PDF toolkit — 100+ tools (merge, split, convert, compress, OCR, sign) that run entirely in your browser | utilities |
| <img src="apps/dawarich/metadata/logo.jpg" width="32" height="32"> | **[Dawarich](https://github.com/Freika/dawarich)** | Self-hosted alternative to Google Location History — track, visualize, and control your location data on an interactive map | utilities, network |
| <img src="apps/isponsorblocktv/metadata/logo.jpg" width="32" height="32"> | **[iSponsorBlockTV](https://github.com/iSponsorBlockTV/iSponsorBlockTV)** | Automatically skip YouTube sponsors, intros, outros, and ads on Apple TV, Android TV, Roku, and more | media, utilities |
| <img src="apps/libation/metadata/logo.jpg" width="32" height="32"> | **[Libation](https://github.com/rmcrackan/Libation)** | Free, open-source Audible audiobook manager — download, remove DRM, and truly own your audiobooks | books, media |

## Repository Structure

```
apps/
├── <app-id>/
│   ├── config.json          # App configuration and form fields
│   ├── docker-compose.json  # Docker services definition
│   └── metadata/
│       ├── description.md   # App description
│       └── logo.jpg         # App logo
├── ...
tests/
└── apps.test.ts             # Validation tests
```

## Adding Apps

Use the `/add-app <app-name>` skill (for use with an AI agent) to add a new app to this store. The skill will:

1. Research the app and find its Docker image
2. Create the required configuration files
3. Download the app logo
4. Update this README with the new app
5. Run validation tests
6. Create a PR with the new app

## Updating Apps

Use the `/update-app <app-name>` command to update an app to its latest version.

## License

This app store configuration is provided as-is for personal use.
