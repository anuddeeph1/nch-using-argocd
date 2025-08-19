#!/bin/bash

# Deploy Step 2: MongoDB and Kafka with Comprehensive Validation
# This deploys data services with full validation and dependency checking
# Usage: ./deploy-step2-mongodb-kafka.sh [dev|prod]

# ================================================================================
#                          💾 STEP 2: DATA SERVICES SUMMARY
# ================================================================================
#
# 🎯 PURPOSE:
#   Deploys the core data infrastructure required by Nirmata application services.
#   Provides persistent storage and event streaming capabilities.
#
# 📦 WHAT THIS STEP DEPLOYS:
#   ✅ MongoDB Community Operator (database management)
#   ✅ MongoDB cluster with authentication and encryption
#   ✅ MongoDB headless service (mongodb-hs:27017)
#   ✅ Kafka cluster for event streaming and messaging
#   ✅ Kafka controller and data services
#   ✅ Database authentication secrets (mongo-credentials)
#
# 🔗 DEPENDENCIES:
#   ✅ Step 1 completed (Prerequisites and CRDs installed)
#   ✅ Sufficient cluster resources (8+ vCPUs, 16+ GB RAM)
#   ✅ Persistent storage available
#   ✅ MongoDB Community Operator CRDs ready
#
# ⏱️  ESTIMATED TIME: 5-8 minutes
#
# 🎊 AFTER THIS STEP:
#   ✅ MongoDB cluster running and accessible
#   ✅ Kafka cluster ready for messaging
#   ✅ Database authentication configured
#   ✅ Data services ready for Nirmata applications
#   ✅ Ready to run Step 3 (Nirmata Services deployment)
#
# ================================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment
TIMEOUT="15m"  # Longer timeout for data services

# Load validation library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../../lib/validation.sh" ]]; then
source "$SCRIPT_DIR/../../lib/validation.sh"
else
echo "ERROR: Validation library not found at $SCRIPT_DIR/../../lib/validation.sh"
  exit 1
fi

# Extract namespace from environment-specific values file
extract_namespace_from_values() {
  local env_file="$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  
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

log "🚀 Starting NCH Charts Step 2 Deployment..."
log "📦 Components: MongoDB & Kafka (Data Services)"
log "🌍 Environment: $ENVIRONMENT"
log "🏷️  Namespace: $NAMESPACE"

# Display step summary at runtime
display_step_summary() {
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo "                          💾 STEP 2: DATA SERVICES SUMMARY"
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
  log "🎯 PURPOSE:"
  log "   Deploys the core data infrastructure required by Nirmata application services."
  log "   Provides persistent storage and event streaming capabilities."
  echo ""
  log "📦 WHAT THIS STEP DEPLOYS:"
  log "   ✅ MongoDB Community Operator (database management)"
  log "   ✅ MongoDB cluster with authentication and encryption"
  log "   ✅ MongoDB headless service (mongodb-hs:27017)"
  log "   ✅ Kafka cluster for event streaming and messaging"
  log "   ✅ Kafka controller and data services"
  log "   ✅ Database authentication secrets (mongo-credentials)"
  echo ""
  log "⏱️  ESTIMATED TIME: 5-8 minutes"
  echo ""
  log "🎊 AFTER THIS STEP:"
  log "   ✅ MongoDB cluster running and accessible"
  log "   ✅ Kafka cluster ready for messaging"
  log "   ✅ Database authentication configured"
  log "   ✅ Data services ready for Nirmata applications"
  log "   ✅ Ready to run Step 3 (Nirmata Services deployment)"
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
}

# Display the summary
display_step_summary

# Pre-flight checks - OPTIMIZED: Only essential checks
preflight_checks() {
  log "🚀 Running essential pre-flight checks..."
  
  # Basic cluster connectivity - ESSENTIAL
  validate_cluster_connectivity || exit 1
  
  # Check if required values files exist - ESSENTIAL
  local base_values="$SCRIPT_DIR/../../../config/values/base.yaml"
  local env_values="$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  local step_values="$SCRIPT_DIR/../../../config/values/steps/data-services.yaml"
  
  [[ -f "$base_values" ]] || { error "Base values file '$base_values' not found"; exit 1; }
  [[ -f "$env_values" ]] || { error "Environment values file '$env_values' not found"; exit 1; }
  [[ -f "$step_values" ]] || { error "Step values file '$step_values' not found"; exit 1; }
  
  success "All required values files found"
  
  # REMOVED: cluster resource validation (slows down deployment)
  
  # Quick Step 1 check - ESSENTIAL
  log "🔍 Quick Step 1 prerequisite check..."
  validate_helm_release "nch-prereq" "$NAMESPACE" "deployed" || {
    error "Step 1 prerequisites not met! Please run Step 1 first:"
    error "  ./deploy-step1-prereq.sh $ENVIRONMENT"
    exit 1
  }
}

# Create namespace with proper labels for Step 2
create_namespace() {
  log "📁 Ensuring namespace $NAMESPACE exists with proper labels..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    environment: $ENVIRONMENT
    nirmata.io/managed: "true"
    nirmata.io/step: "2"
    nirmata.io/data-services: "true"
EOF
}

# Main deployment function
deploy_step2() {
  log "📁 Changing to chart directory..."
  cd "$SCRIPT_DIR/../../../nch-charts/"

  log "🔄 Updating Helm dependencies..."
  helm dependency update

  log "⚡ Deploying Step 2 components with $ENVIRONMENT profile..."
  log "📄 Using values files: config/values/base.yaml + config/values/steps/data-services.yaml + config/values/environments/$ENVIRONMENT.yaml"
  
  # Deploy with layered values files (corrected order: base → step → environment)
  helm upgrade --install nch-data . \
    --namespace "$NAMESPACE" \
    --set global.namespaceOverride="$NAMESPACE" \
    --values "../config/values/base.yaml" \
    --values "../config/values/steps/data-services.yaml" \
    --values "../config/values/environments/$ENVIRONMENT.yaml" \
    --timeout "$TIMEOUT" \
    --wait \
    --atomic
    
  success "Step 2 deployment completed successfully!"
}

# Final validation - OPTIMIZED: Reduced wait time and focused checks
validate_deployment() {
  log "🔍 Running final Step 2 validation..."
  
  # Reset validation counters
  VALIDATION_ERRORS=0
  VALIDATION_WARNINGS=0
  
  # Optimized wait time for step-only validation
  log "⏱️  Waiting for resources to stabilize..."
  sleep 10
  
  # Run Step 2 ONLY validation (optimized - no previous step dependencies)
  validate_step2_only "$NAMESPACE"
  
  # Print validation summary
  if print_validation_summary; then
    success "Step 2 validation completed successfully!"
    return 0
  else
    error "Step 2 validation failed!"
    return 1
  fi
}

# Show next steps
show_next_steps() {
  success "🎉 Step 2 (Data Services) deployment completed successfully!"
  log ""
  log "📋 Next steps:"
  log "  1. Run Step 3: ./deploy-step3-nirmata-services.sh $ENVIRONMENT"
  log "  2. Check MongoDB status: kubectl get mongodb -n $NAMESPACE"
  log "  3. Check Kafka status: kubectl get pods -l app=kafka -n $NAMESPACE"
  log "  4. View all services: kubectl get svc -n $NAMESPACE"
  log ""
  log "🔧 Troubleshooting:"
  log "  - Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
  log "  - MongoDB logs: kubectl logs -l name=mongodb-kubernetes-operator -n $NAMESPACE"
  log "  - Kafka logs: kubectl logs -l app=kafka -n $NAMESPACE"
  log ""
  log "💾 Data Services Ready:"
  log "  - MongoDB service: mongodb-hs:27017"
  log "  - Kafka service: kafka:9092"
}

# Cleanup function for failed deployments
cleanup_failed_deployment() {
  warning "🧹 Deployment failed, checking if cleanup is needed..."
  
  if helm list -n "$NAMESPACE" | grep -q "nch-data"; then
    local status=$(helm status "nch-data" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    if [[ "$status" == "failed" || "$status" == "pending-install" ]]; then
      warning "Found failed/stuck release, cleaning up..."
      helm uninstall "nch-data" -n "$NAMESPACE" --no-hooks || true
    fi
  fi
}

# Main execution
main() {
  log "🏁 Starting Step 2 deployment with environment: $ENVIRONMENT"
  
  # Set up error handling
  trap cleanup_failed_deployment ERR
  
  preflight_checks
  create_namespace
  deploy_step2
  validate_deployment
  show_next_steps
  
  success "🏁 Step 2 deployment completed successfully!"
}

# Execute main function
main "$@" 