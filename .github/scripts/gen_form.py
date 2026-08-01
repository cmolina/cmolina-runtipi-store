#!/usr/bin/env python3
"""Generate form data for installing a runtipi app.

Usage:
  STORE=<store-name> python3 gen_form.py <path/to/config.json>

Outputs JSON with exposed=true, domain, and all form_fields populated.
"""
import json
import os
import secrets
import sys


def main():
    config_path = sys.argv[1]
    config = json.load(open(config_path))

    form = {}
    for f in config.get("form_fields", []):
        env = f["env_variable"]
        t = f["type"]
        if t == "random":
            n = f.get("min", 32)
            if f.get("encoding") == "hex":
                form[env] = secrets.token_hex((n + 1) // 2)[:n]
            else:
                form[env] = secrets.token_urlsafe(n)[:n]
        elif t == "boolean":
            form[env] = str(f.get("default", False)).lower()
        elif f.get("default") is not None:
            form[env] = str(f["default"])
        elif t in ("text", "password") and f.get("required"):
            if "email" in env.lower() or "email" in f.get("label", "").lower():
                form[env] = "preview@example.com"
            else:
                form[env] = "preview-value"

    store = os.environ.get("STORE", "")
    suffix = f"-{store}" if store else ""
    form["exposed"] = True
    form["domain"] = f"{config['id']}{suffix}-preview.cmolina.cl"
    print(json.dumps(form))


if __name__ == '__main__':
    main()
