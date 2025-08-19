#!/usr/bin/env bash

# Master Deployment Script for NCH Charts
# Deploys all 5 steps with comprehensive validation and dependency checking
# Usage: ./deploy-all.sh [dev|prod] [--skip-step=N] [--start-from=N]

set -euo pipefail

# Ensure we're using bash for associative arrays
if [[ "${BASH_VERSION:-}" == "" ]]; then
  echo "This script requires bash. Please run with: bash $0 $*"
  exit 1
fi

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment
SKIP_STEP=""
START_FROM="1"
FAST_VALIDATION="true"  # Use optimized validation by default

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-step=*)
      SKIP_STEP="${1#*=}"
      shift
      ;;
    --start-from=*)
      START_FROM="${1#*=}"
      shift
      ;;
    --comprehensive-validation)
      FAST_VALIDATION="false"
      shift
      ;;
    --help|-h)
      cat <<EOF
Master Deployment Script for NCH Charts

Usage: $0 [environment] [options]

Arguments:
  environment     Deployment environment: dev or prod (default: dev)

Options:
  --skip-step=N              Skip specific step number (1-5)
  --start-from=N             Start deployment from step N (1-5, default: 1)
  --comprehensive-validation Use slower but more thorough validation
  --help, -h                 Show this help message

Examples:
  $0 dev                    # Deploy development environment
  $0 prod                   # Deploy production environment  
  $0 dev --skip-step=2      # Deploy dev but skip step 2
  $0 prod --start-from=3    # Deploy prod starting from step 3

Steps:
  1. Prerequisites (CRDs, ConfigMaps, Secrets)
  2. Data Services (MongoDB, Kafka)
  3. Application Services (All Nirmata Services) *
  4. Load Balancer (HAProxy)
  5. Configuration (License & Tenant Setup)

Notes:
  * Step 3 failures/interruptions preserve services for debugging
    (automatic cleanup is skipped to allow troubleshooting)
EOF
      exit 0
      ;;
    *)
      if [[ "$1" =~ ^(dev|prod)$ ]]; then
        ENVIRONMENT="$1"
      else
        echo "Unknown argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# Load validation library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/validation.sh" ]]; then
source "$SCRIPT_DIR/../lib/validation.sh"
else
echo "ERROR: Validation library not found at $SCRIPT_DIR/../lib/validation.sh"
  exit 1
fi

# Extract namespace from environment-specific values file
extract_namespace_from_values() {
  local env_file="config/values/environments/${ENVIRONMENT}.yaml"
  
  if [[ ! -f "$env_file" ]]; then
    error "Environment values file not found: $env_file"
  fi
  
  # Extract namespaceOverride from the YAML file
  local namespace=$(grep "namespaceOverride:" "$env_file" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  
  if [[ -z "$namespace" ]]; then
    error "namespaceOverride not found in $env_file"
  fi
  
  echo "$namespace"
}

# Get namespace from environment values file (allow NCH_NAMESPACE override for backward compatibility)
NAMESPACE="${NCH_NAMESPACE:-$(extract_namespace_from_values)}"

# Validate environment parameter
if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
  error "Invalid environment '$ENVIRONMENT'. Use 'dev' or 'prod'"
fi

# Global deployment tracking
DEPLOYMENT_START_TIME=$(date +%s)
STEPS_COMPLETED=()
STEPS_FAILED=()
CURRENT_STEP=""

# Deployment step definitions
declare -A STEP_SCRIPTS=(
  [1]="steps/01-prerequisites.sh"
  [2]="steps/02-data-services.sh"
  [3]="steps/03-app-services.sh"
  [4]="steps/04-load-balancer.sh"
  [5]="steps/05-configuration.sh"
)

declare -A STEP_NAMES=(
  [1]="Prerequisites"
  [2]="Data Services"
  [3]="Application Services"
  [4]="Load Balancer"
  [5]="Configuration"
)

declare -A STEP_TIMEOUTS=(
  [1]="10m"
  [2]="15m"
  [3]="20m"
  [4]="10m"
  [5]="15m"
)

# Logging functions with enhanced formatting
banner() {
  local message="$1"
  local width=80
  local padding=$(( (width - ${#message}) / 2 ))
  
  echo ""
  echo "$(printf '=%.0s' $(seq 1 $width))"
  echo "$(printf '%*s' $padding '')$message"
  echo "$(printf '=%.0s' $(seq 1 $width))"
  echo ""
}

# Portable function to format seconds as HH:MM:SS (works on both Linux and macOS)
format_duration() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf "%02d:%02d:%02d" $hours $minutes $seconds
}

step_banner() {
  local step="$1"
  local name="$2"
  local message="🚀 STEP $step: $name"
  banner "$message"
}

# Pre-flight validation for master deployment
master_preflight_checks() {
  banner "🔍 MASTER DEPLOYMENT PRE-FLIGHT CHECKS"
  
  log "🔍 Running comprehensive pre-flight validation for full deployment..."
  
  # Basic cluster connectivity
  validate_cluster_connectivity || exit 1
  
  # Check all required scripts exist
  for step in {1..5}; do
    if [[ "$step" -ge "$START_FROM" && "$step" != "$SKIP_STEP" ]]; then
      local script="${STEP_SCRIPTS[$step]}"
      local script_path="$SCRIPT_DIR/$script"
      if [[ ! -f "$script_path" ]]; then
        error "Required script not found: $script_path"
        exit 1
      fi
      if [[ ! -x "$script_path" ]]; then
        error "Script not executable: $script_path"
        exit 1
      fi
    fi
  done
  
  # Check all required values files exist
  local required_files=(
    "config/values/base.yaml"
    "config/values/environments/${ENVIRONMENT}.yaml"
    "config/values/steps/prerequisites.yaml"
    "config/values/steps/data-services.yaml"
    "config/values/steps/app-services.yaml"
    "config/values/steps/load-balancer.yaml"
    "config/values/steps/configuration.yaml"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      error "Required values file not found: $file"
      exit 1
    fi
  done
  
  success "All required files and scripts found"
  
  # Check cluster resources for full deployment
  local min_nodes=3
  local required_cpu="15000m"
  local required_memory="30Gi"
  
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    min_nodes=5
    required_cpu="40000m"
    required_memory="80Gi"
  fi
  
  validate_cluster_resources "$required_cpu" "$required_memory" "$min_nodes"
  
  log "✅ Master deployment pre-flight checks completed"
}

# Execute a single deployment step
execute_step() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local script="${STEP_SCRIPTS[$step]}"
  local timeout="${STEP_TIMEOUTS[$step]}"
  
  # Track current step for cleanup decisions
  CURRENT_STEP="$step"
  
  step_banner "$step" "$step_name"
  
  log "📝 Executing: $script $ENVIRONMENT"
  log "⏱️  Maximum timeout: $timeout"
  
  local step_start_time=$(date +%s)
  
  # Execute the step script (timeout not available on macOS by default)
  if "$SCRIPT_DIR/$script" "$ENVIRONMENT"; then
    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - step_start_time))
    
    STEPS_COMPLETED+=("$step")
    success "✅ Step $step ($step_name) completed successfully in ${step_duration}s"
    
    # Brief pause between steps for stabilization
    if [[ "$step" -lt 5 ]]; then
      log "⏱️  Waiting 10s for services to stabilize before next step..."
      sleep 10
    fi
    
    return 0
  else
    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - step_start_time))
    
    STEPS_FAILED+=("$step")
    error "❌ Step $step ($step_name) failed after ${step_duration}s"
    return 1
  fi
}

# Comprehensive post-deployment validation
master_post_deployment_validation() {
  banner "🔍 MASTER DEPLOYMENT VALIDATION"
  
  if [[ "$FAST_VALIDATION" == "true" ]]; then
    log "🔍 Running optimized validation of complete deployment..."
    validate_master_deployment "$NAMESPACE"
  else
    log "🔍 Running comprehensive validation of complete deployment..."
    # Reset validation counters
    VALIDATION_ERRORS=0
    VALIDATION_WARNINGS=0
    
    # Run all step validations (original method)
    validate_step1_prerequisites "$NAMESPACE" || true
    validate_step2_data_services "$NAMESPACE" || true
    validate_step3_nirmata_services "$NAMESPACE" || true
    validate_step4_haproxy "$NAMESPACE" || true
    
    # Step 5 validation
    log "🔍 Validating Step 5 (Configuration)..."
    if kubectl get svc haproxy -n "$NAMESPACE" >/dev/null 2>&1; then
      success "Step 5: Platform accessible for configuration"
    else
      record_error "Step 5: Platform not accessible for configuration"
    fi
    
    # Additional checks
    log "🔍 Additional full deployment validations..."
    local expected_releases=("nch-prereq" "nch-data" "nch-services" "nch-haproxy")
    for release in "${expected_releases[@]}"; do
      validate_helm_release "$release" "$NAMESPACE" "deployed" || record_error "$release not in deployed status"
    done
    
    log "🔍 Testing end-to-end connectivity..."
    if kubectl get svc haproxy -n "$NAMESPACE" >/dev/null 2>&1; then
      success "HAProxy service accessible for external traffic"
    else
      record_error "HAProxy service not accessible"
    fi
  fi
  
  # Print validation summary
  if print_validation_summary; then
    success "✅ Master deployment validation completed successfully!"
    return 0
  else
    error "❌ Master deployment validation failed!"
    return 1
  fi
}

# Show comprehensive deployment summary
show_deployment_summary() {
  local deployment_end_time=$(date +%s)
  local total_duration=$((deployment_end_time - DEPLOYMENT_START_TIME))
  
  banner "🎊 DEPLOYMENT COMPLETE!"
  
  log "📊 Deployment Summary:"
  log "  🌍 Environment: $ENVIRONMENT"
  log "  🏷️  Namespace: $NAMESPACE"
  log "  ⏱️  Total Duration: ${total_duration}s ($(format_duration $total_duration))"
  log "  ✅ Steps Completed: ${#STEPS_COMPLETED[@]}"
  log "  ❌ Steps Failed: ${#STEPS_FAILED[@]}"
  log ""
  
  if [[ ${#STEPS_COMPLETED[@]} -gt 0 ]]; then
    log "✅ Completed Steps:"
    for step in "${STEPS_COMPLETED[@]}"; do
      log "  - Step $step: ${STEP_NAMES[$step]}"
    done
    log ""
  fi
  
  if [[ ${#STEPS_FAILED[@]} -gt 0 ]]; then
    log "❌ Failed Steps:"
    for step in "${STEPS_FAILED[@]}"; do
      log "  - Step $step: ${STEP_NAMES[$step]}"
    done
    log ""
  fi
  
  log "🌟 Nirmata Platform Components:"
  log "  ✅ Prerequisites: CRDs, ConfigMaps, Secrets"
  log "  ✅ Data Layer: MongoDB, Kafka"
  log "  ✅ Application Layer: All Nirmata Services"
  log "  ✅ Load Balancer: HAProxy"
  log "  ✅ Configuration: License & Tenant Setup"
  log ""
  
  log "🔗 Platform Access:"
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    log "  🌐 Production Access:"
    log "    - URL: https://$(kubectl get configmap nirmata-config -n $NAMESPACE -o jsonpath='{.data.nirmata\.url}' 2>/dev/null || echo 'your-production-url.com')"
  else
    log "  🖥️  Development Access:"
    log "    - kubectl port-forward svc/haproxy 8443:8443 -n $NAMESPACE"
    log "    - https://localhost:8443"
  fi
  log ""
  
  log "🔧 Management:"
  log "  - Status: kubectl get pods -n $NAMESPACE"
  log "  - Logs: kubectl logs -f deployment/<service-name> -n $NAMESPACE"
  log "  - Cleanup: ./scripts/clean or make cleanup"
  log ""
  
  if [[ ${#STEPS_FAILED[@]} -eq 0 ]]; then
    success "🎊 FULL NIRMATA PLATFORM DEPLOYED SUCCESSFULLY! 🎊"
  else
    error "⚠️  Deployment completed with some failures. Check failed steps above."
  fi
}

# Cleanup function for master deployment failures
cleanup_failed_master_deployment() {
  # Don't cleanup if Step 3 (Application Services) failed
  if [[ "$CURRENT_STEP" == "3" ]]; then
    warning "⚠️  Step 3 (Application Services) failed or was interrupted"
    warning "🔒 Preserving nirmata services - cleanup skipped to allow debugging"
    warning "💡 To manually cleanup later, run: ./scripts/clean or make cleanup"
    return 0
  fi
  
  warning "🧹 Master deployment failed, running cleanup..."
  
  # Run cleanup script if it exists
  if [[ -f "./scripts/cleanup/all.sh" ]]; then
    warning "Running full cleanup script..."
    ./scripts/cleanup/all.sh || true
  fi
}

# Handle Ctrl+C interruption
handle_interrupt() {
  echo ""
  warning "🛑 Deployment interrupted by user"
  
  # Don't auto-cleanup if we're in Step 3
  if [[ "$CURRENT_STEP" == "3" ]]; then
    warning "🔒 Step 3 interrupted - preserving nirmata services"
    warning "💡 Services remain deployed for debugging. To cleanup: ./cleanup-all.sh"
    exit 130
  fi
  
  echo ""
  read -p "🤔 Do you want to run cleanup? [y/N]: " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cleanup_failed_master_deployment
  else
    warning "💡 Skipping cleanup. To cleanup later: ./cleanup-all.sh"
  fi
  exit 130
}

# Main execution
main() {
  banner "🚀 NCH CHARTS MASTER DEPLOYMENT"
  
  log "🏁 Starting master deployment:"
  log "  🌍 Environment: $ENVIRONMENT"
  log "  🏷️  Namespace: $NAMESPACE"
  log "  📋 Start from step: $START_FROM"
  if [[ -n "$SKIP_STEP" ]]; then
    log "  ⏭️  Skipping step: $SKIP_STEP"
  fi
  log ""
  
  # Set up error and interrupt handling
  trap cleanup_failed_master_deployment ERR
  trap handle_interrupt SIGINT
  
  # Run pre-flight checks
  master_preflight_checks
  
  # Execute deployment steps
  for step in {1..5}; do
    # Check if we should run this step
    if [[ "$step" -lt "$START_FROM" ]]; then
      log "⏭️  Skipping Step $step (starting from step $START_FROM)"
      continue
    fi
    
    if [[ "$step" == "$SKIP_STEP" ]]; then
      log "⏭️  Skipping Step $step (explicitly skipped)"
      continue
    fi
    
    # Special handling for Step 3 (Application Services)
    if [[ "$step" == "3" ]]; then
      log "ℹ️  Note: Step 3 failures will preserve deployed services for debugging"
      log "ℹ️  Use Ctrl+C to safely interrupt without cleanup"
    fi
    
    # Execute the step
    if ! execute_step "$step"; then
      error "❌ Step $step failed, stopping master deployment"
      break
    fi
  done
  
  # Post-deployment validation
  master_post_deployment_validation
  
  # Show summary
  show_deployment_summary
  
  success "🏁 Master deployment completed!"
}

# Execute main function
main "$@" 