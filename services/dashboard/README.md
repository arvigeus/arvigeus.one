# Static Dashboard

## Overview

A zero-container, fully static dashboard: `start.sh` scans all services' `data.json` files plus `config/resources.json`, and **renders complete HTML server-side** into `./public/index.html`, which Caddy serves directly via `file_server`. No Docker image, no JavaScript, no runtime dependencies beyond `jq`.

## How It Works

1. On `start`/`update`, the script reads every `services/*/data.json`
2. Entries are grouped by category (`Entertainment → Productivity → Development → System → Resources`) and sorted by `order` → `name`; logos are copied to `public/icons/`
3. URLs come from the `url` property or are auto-detected from `caddy.conf` subdomains
4. `config/render.jq` turns each entry into an HTML card fragment (with escaping)
5. Fragments replace the `__SERVICES_HTML__` placeholder in `config/index.html`

## data.json format

```json
{
  "ui": [
    {
      "name": "Service Name",
      "subtitle": "Description",
      "category": "Entertainment|Productivity|Development|System",
      "logo": "optional/path/to/logo.svg",
      "url": "https://optional.explicit.url",
      "order": 1,
      "hidden": false
    }
  ]
}
```

- Auto-detected logos (`logo.png` / `logo.svg` in the service dir) are copied as `{service}_logo.{ext}`
- Missing `category` defaults to `System`; missing `order` sorts last

### Resources section

`config/resources.json` holds external links (rendered after all service categories); their icons live in `assets/`:

```json
[
  {"name": "r/selfhosted", "subtitle": "...", "logo": "icons/r_selfhosted.png", "url": "https://..."}
]
```

## Files

- `start.sh` — generates `public/index.html` + `public/icons/`
- `caddy.conf` — serves `public/` at the apex domain (Caddy mounts the whole `services/` dir read-only)
- `config/index.html` — page template with `__SERVICES_HTML__` and `__DOMAIN__` placeholders
- `config/render.jq` — jq program that renders entry JSON into HTML card fragments
- `config/resources.json` / `assets/` — static resource links and their icons

`public/` is generated output and gitignored.
