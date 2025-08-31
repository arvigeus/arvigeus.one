#!/bin/bash


# Script to generate or update dependabot.yml based on docker-compose.yml files

# Usage: ./generate-dependabot.sh


# Colors for output

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

NC='\033[0m' # No Color


# Function to print colored output

print_status() {

    echo -e "${BLUE}[INFO]${NC} $1"

}


print_success() {

    echo -e "${GREEN}[SUCCESS]${NC} $1"

}


print_warning() {

    echo -e "${YELLOW}[WARNING]${NC} $1"

}


print_error() {

    echo -e "${RED}[ERROR]${NC} $1"

}


print_status "Starting dependabot.yml generation..."


mkdir -p .github


tmpfile=$(mktemp)

trap 'rm -f "$tmpfile"' EXIT


# Header

cat > "$tmpfile" <<'YAML'

version: 2

updates:

  - package-ecosystem: "docker-compose"

    directories:

YAML


# Find and sort all docker-compose.yml directories

print_status "Scanning for docker-compose.yml files..."


found_directories=0

while IFS= read -r file; do

    dir=$(dirname "$file" | sed 's|^\./||')

    print_status "Found compose file in: $dir"

    echo "      - \"/$dir\"" >> "$tmpfile"

    ((found_directories++))

done < <(find ./services -name "docker-compose.yml" -type f | sort)


if [[ $found_directories -eq 0 ]]; then

    print_warning "No docker-compose.yml files found"

    exit 0

fi


# Append the schedule block

cat >> "$tmpfile" <<'YAML'

    schedule:

      interval: "daily"

YAML


# Install if changed

if ! [ -f .github/dependabot.yml ] || ! cmp -s "$tmpfile" .github/dependabot.yml; then

  mv "$tmpfile" .github/dependabot.yml

  print_success "Updated .github/dependabot.yml!"

  print_status "Found $found_directories directories with compose files"

else

  print_status "No changes to .github/dependabot.yml"

  print_status "Found $found_directories directories with compose files"

fi


print_success "Dependabot configuration generation completed!"