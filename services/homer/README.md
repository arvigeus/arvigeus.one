# Homer Auto-Configuration

## Overview

The `start.sh` script automatically generates Homer dashboard configuration by scanning all services in the project and reading their `data.json` files.

## How It Works

### 1. Service Discovery

- Scans all directories in `../../services/*/`
- Looks for `data.json` file in each service directory
- Validates that `data.json` contains a `ui` array

### 2. Data Structure

Each service's `data.json` should contain:

```json
{
  "ui": [
    {
      "name": "Service Name",
      "subtitle": "Service description",
      "category": "Entertainment|Productivity|System",
      "logo": "optional/path/to/logo.png",
      "url": "optional_url",
      "order": 1
    }
  ]
}
```

**Properties:**
- `name` (required): Display name for the service
- `subtitle` (optional): Description text
- `category` (optional): "Entertainment", "Productivity", or "System" (defaults to "System")
- `logo` (optional): Path to custom logo file relative to service directory
- `url` (optional): Direct URL (if not provided, auto-detected from caddy.conf)
- `order` (optional): Numeric sort order within category (defaults to 999, appears last)

### 3. Logo Handling

- **Custom logo**: If `logo` property exists, copies from service directory to `$DATA/homer/icons/`
- **Auto-detection**: If no `logo` property, looks for `logo.png` or `logo.svg` in service directory
- **Naming**: Auto-detected logos are renamed to `{service_name}_logo.{ext}` to avoid conflicts
- **Path generation**: Creates `assets/icons/{filename}` paths for Homer config

### 4. URL Auto-Detection

- **Manual URL**: Uses `url` property if specified
- **Auto-detection**: Parses `caddy.conf` in service directory
- **Pattern matching**: Looks for lines like `subdomain.{$DOMAIN}`
- **URL generation**: Creates `https://subdomain.$DOMAIN`

### 5. Configuration Generation

- Groups services by category (Entertainment, Productivity, System)
- **Sorts services by `order` property** within each category (missing order = 999, appears last)
- Uses temporary files to preserve YAML structure during sorting
- Generates YAML structure with proper Homer format
- Replaces placeholder in base `config.yml` template

### 6. File Operations

- **Cleans existing data**: Removes `$DATA/homer/` directory to avoid leftover files
- Creates `$DATA/homer/icons/` directory
- Copies service logos to icons directory
- Copies base Homer files (`config.yml`, `links.yml`, `manifest.json`)
- Merges original Homer icons with service-specific icons
- Sets proper file ownership using `$PUID:$PGID`

## Technical Details

### Array Handling

Uses indexed arrays (not associative) to avoid subshell variable scope issues:

```bash
declare -a entertainment_services=()
entertainment_services+=("$service_entry")
```

### Process Substitution

Uses process substitution instead of pipes to maintain variable scope:

```bash
while IFS= read -r entry; do
    # Process entry
done < <(jq -c '.ui[]' "$data_file")
```

### YAML Generation

Builds YAML string with proper indentation and structure for Homer categories.

### File Permissions

All generated files are owned by `$PUID:$PGID` from environment variables.

### Temporary Files
Script creates temporary YAML files in `/tmp/service_*.yml` during processing to preserve proper YAML structure when sorting. These are automatically cleaned up after generation.

## Dependencies

- `jq` for JSON parsing
- `sudo` for file operations
- Environment variables from `../../.env`

## Output

- Generated config: `$DATA/homer/config.yml`
- Service icons: `$DATA/homer/icons/`
- Homer assets: `$DATA/homer/`
