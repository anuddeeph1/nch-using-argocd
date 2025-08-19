#!/bin/bash

# Deploy Step 1: Prerequisites with Environment Profiles
# This demonstrates the new layered values approach with comprehensive validation
# Usage: ./deploy-step1-prereq.sh [dev|prod]

# ================================================================================
#                           📋 STEP 1: PREREQUISITES SUMMARY
# ================================================================================
#
# 🎯 PURPOSE:
#   Sets up the foundation for Nirmata deployment by installing core prerequisites
#   and preparing the Kubernetes environment for data and application services.
#
# 📦 WHAT THIS STEP DEPLOYS:
#   ✅ Namespace creation and labeling
#   ✅ MongoDB Community Operator CRDs (Custom Resource Definitions)
#   ✅ Essential ConfigMaps (nirmata-config, haproxy-nirmata-config, policy-studio-config)
#   ✅ Image pull secret (image-registry)
#   ✅ TLS certificates (server-certificate)
#   ✅ RBAC resources and priority classes
#
# 🔗 DEPENDENCIES:
#   ✅ Kubernetes cluster (v1.23-v1.26)
#   ✅ Helm 3.x installed
#   ✅ Cluster admin permissions
#   ✅ Container registry access configured
#
# ⏱️  ESTIMATED TIME: 2-3 minutes
#
# 🎊 AFTER THIS STEP:
#   ✅ Namespace ready for subsequent deployments
#   ✅ MongoDB operator CRDs installed
#   ✅ Configuration and secrets available for other steps
#   ✅ Ready to run Step 2 (MongoDB & Kafka deployment)
#
# ================================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment
TIMEOUT="10m"

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

log "🚀 Starting NCH Charts Step 1 Deployment..."
log "📦 Components: Prerequisites (CRDs, ConfigMaps, Secrets)"
log "🌍 Environment: $ENVIRONMENT"
log "🏷️  Namespace: $NAMESPACE"

# Display step summary at runtime
display_step_summary() {
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo "                           📋 STEP 1: PREREQUISITES SUMMARY"
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
  log "🎯 PURPOSE:"
  log "   Sets up the foundation for Nirmata deployment by installing core prerequisites"
  log "   and preparing the Kubernetes environment for data and application services."
  echo ""
  log "📦 WHAT THIS STEP DEPLOYS:"
  log "   ✅ Namespace creation and labeling"
  log "   ✅ MongoDB Community Operator CRDs (Custom Resource Definitions)"
  log "   ✅ Essential ConfigMaps (nirmata-config, haproxy-nirmata-config, policy-studio-config)"
  log "   ✅ Image pull secret (image-registry)"
  log "   ✅ TLS certificates (server-certificate)"
  log "   ✅ RBAC resources and priority classes"
  echo ""
  log "⏱️  ESTIMATED TIME: 2-3 minutes"
  echo ""
  log "🎊 AFTER THIS STEP:"
  log "   ✅ Namespace ready for subsequent deployments"
  log "   ✅ MongoDB operator CRDs installed"
  log "   ✅ Configuration and secrets available for other steps"
  log "   ✅ Ready to run Step 2 (MongoDB & Kafka deployment)"
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
  local step_values="$SCRIPT_DIR/../../../config/values/steps/prerequisites.yaml"
  
  [[ -f "$base_values" ]] || { error "Base values file '$base_values' not found"; exit 1; }
  [[ -f "$env_values" ]] || { error "Environment values file '$env_values' not found"; exit 1; }
  [[ -f "$step_values" ]] || { error "Step values file '$step_values' not found"; exit 1; }
  
  success "All required values files found"
  
  # REMOVED: cluster resource validation (slows down deployment)
  # REMOVED: namespace validation (not essential for pre-checks)
}

# Create namespace with proper labels
create_namespace() {
  log "📁 Creating namespace $NAMESPACE..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    environment: $ENVIRONMENT
    nirmata.io/managed: "true"
    nirmata.io/step: "1"
EOF
}

# Main deployment function
deploy_step1() {
  log "📁 Changing to chart directory..."
  cd "$SCRIPT_DIR/../../../nch-charts/"

  log "🔄 Updating Helm dependencies..."
  helm dependency update

  log "⚡ Deploying Step 1 components with $ENVIRONMENT profile..."
  log "📄 Using values files: config/values/base.yaml + config/values/steps/prerequisites.yaml + config/values/environments/$ENVIRONMENT.yaml"
  
  # Deploy with layered values files (corrected order: base → step → environment)
  helm upgrade --install nch-prereq . \
    --namespace "$NAMESPACE" \
    --set global.namespaceOverride="$NAMESPACE" \
    --values "../config/values/base.yaml" \
    --values "../config/values/steps/prerequisites.yaml" \
    --values "../config/values/environments/$ENVIRONMENT.yaml" \
    --timeout "$TIMEOUT" \
    --wait \
    --atomic
    
  log "✅ Step 1 deployment completed successfully!"
}

# Validate deployment - OPTIMIZED: Final validation only
validate_deployment() {
  log "🔍 Running final Step 1 validation..."
  
  # Reset validation counters
  VALIDATION_ERRORS=0
  VALIDATION_WARNINGS=0
  
  # Run Step 1 ONLY validation (optimized - no previous step dependencies)
  validate_step1_only "$NAMESPACE"
  
  # Print validation summary
  if print_validation_summary; then
    success "Step 1 validation completed successfully!"
    return 0
  else
    error "Step 1 validation failed!"
    return 1
  fi
}

# Show next steps
show_next_steps() {
  log "🎉 Step 1 deployment completed successfully!"
  log ""
  log "📋 Next steps:"
  log "  1. Run Step 2: ./deploy-step2-mongodb-kafka.sh $ENVIRONMENT"
  log "  2. Check status: kubectl get pods -n $NAMESPACE"
  log "  3. View logs: kubectl logs -l app=mongodb-kubernetes-operator -n $NAMESPACE"
  log ""
  log "🔧 Troubleshooting:"
  log "  - Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
  log "  - Check CRDs: kubectl get crd | grep mongodb"
}

# Main execution
main() {
  log "🏁 Starting Step 1 deployment with environment: $ENVIRONMENT"
  
  preflight_checks
  create_namespace
  deploy_step1
  validate_deployment
  show_next_steps
  
  log "🏁 Step 1 deployment completed successfully!"
}

# Execute main function
main "$@" 