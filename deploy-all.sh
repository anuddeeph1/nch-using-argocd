#!/usr/bin/env bash

# Main deployment entry point for NCH Charts
# This script provides a clean interface to the deployment system

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
    exec "$SCRIPT_DIR/deployment/all.sh" --help
fi

# Configuration
ENVIRONMENT="${1:-dev}"
shift || true

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ Invalid environment '$ENVIRONMENT'. Use 'dev' or 'prod'"
    echo ""
    echo "Usage: $0 [dev|prod] [options]"
    echo "  dev   - Deploy to development environment (default)"
    echo "  prod  - Deploy to production environment"
    echo ""
    echo "For detailed help: $0 dev --help"
    exit 1
fi

# Execute the deployment
exec "$SCRIPT_DIR/deployment/all.sh" "$ENVIRONMENT" "$@"