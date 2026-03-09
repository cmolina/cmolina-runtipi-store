Libation is a free, open-source application for managing your Audible audiobook library. It downloads your audiobooks, removes DRM, and lets you truly own your purchases forever.

## Features

- **DRM Removal**: Automatically download and decrypt all your Audible audiobooks
- **Multi-Region Support**: Works with Audible US, UK, Canada, Germany, France, Australia, Japan, India, and Spain
- **Background Service**: Runs as a daemon that periodically checks for and liberates new titles
- **Fast Decryption**: Powered by AAXClean for efficient decryption without heavy dependencies
- **Library Import**: Import your existing Audible library including cover art and metadata
- **PDF Support**: Download accompanying PDFs alongside your audiobooks

## Setup (required before first run)

Libation needs your Audible account credentials to work. You must create an `AccountsSettings.json` file before the app will start:

1. Install [Libation desktop](https://github.com/rmcrackan/Libation/releases/latest) on your computer
2. Open it and add your Audible account through the UI
3. Locate `AccountsSettings.json` in your Libation config folder (check your home directory under the Libation folder)
4. Copy `AccountsSettings.json` into the Libation app-data directory on your Runtipi server (`app-data/cmolina/libation/`)
5. Optionally copy `Settings.json` for custom settings (if not provided, defaults are used)
6. Start or restart the app

For more details see the [official Docker documentation](https://getlibation.com/docs/installation/docker).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SLEEP_TIME` | `10m` | How often to scan for new books. Use Go duration format (`10m`, `1h`, `6h`). Set to `-1` to run once and exit. |
