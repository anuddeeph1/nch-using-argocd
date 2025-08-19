#!/usr/bin/env bash

# Main cleanup entry point for NCH Charts
# This script provides a clean interface to the cleanup system

set -euo pipefail

# Get the directory of this script (resolve symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Handle help option first
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "NCH Charts Cleanup System"
    echo ""
    echo "Usage: $0 [dev|prod]"
    echo "  dev   - Clean development environment (default)"
    echo "  prod  - Clean production environment"
    echo ""
    echo "Environment variables:"
    echo "  NCH_NAMESPACE - Override target namespace (reads from config/values/environments/{env}.yaml)"
    exit 0
fi

# Configuration
ENVIRONMENT="${1:-dev}"
shift || true

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ Invalid environment '$ENVIRONMENT'. Use 'dev' or 'prod'"
    echo ""
    echo "Usage: $0 [dev|prod]"
    echo "  dev   - Clean development environment (default)"
    echo "  prod  - Clean production environment"
    echo ""
    echo "Environment variables:"
    echo "  NCH_NAMESPACE - Override target namespace (reads from config/values/environments/{env}.yaml)"
    exit 1
fi

# Execute the cleanup
exec "$SCRIPT_DIR/cleanup/all.sh" "$ENVIRONMENT" "$@"