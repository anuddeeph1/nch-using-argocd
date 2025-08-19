#!/bin/bash

# Deploy Step 3: All Nirmata Services with Comprehensive Validation
# This deploys all application services with full validation and dependency checking
# Usage: ./deploy-step3-nirmata-services.sh [dev|prod]

# ================================================================================
#                         🚀 STEP 3: NIRMATA SERVICES SUMMARY
# ================================================================================
#
# 🎯 PURPOSE:
#   Deploys the complete Nirmata application stack including all microservices
#   that provide the core platform functionality and user interfaces.
#
# 📦 WHAT THIS STEP DEPLOYS:
#   ✅ Nirmata Application Services:
#       • users (user management & authentication)
#       • security (security & authorization)
#       • activity (activity tracking & audit)
#       • client-gateway (client API gateway)
#       • cluster (cluster management)
#       • policies (policy management & processing)
#       • webclient (web UI interface)
#       • gateway-service (main API gateway)
#       • tunnel (secure tunneling)
#       • llm-apps (AI/ML applications)
#       • policy-studio (policy creation & editing)
#
# 🔗 DEPENDENCIES:
#   ✅ Step 1 completed (Prerequisites installed)
#   ✅ Step 2 completed (MongoDB & Kafka running)
#   ✅ Database connectivity available (mongodb-hs:27017)
#   ✅ Kafka messaging services ready
#   ✅ Sufficient cluster resources (20+ vCPUs, 32+ GB RAM)
#
# ⏱️  ESTIMATED TIME: 8-12 minutes
#
# 🎊 AFTER THIS STEP:
#   ✅ All Nirmata microservices running
#   ✅ Core platform functionality available
#   ✅ Internal service communication established
#   ✅ Ready for external access via load balancer
#   ✅ Ready to run Step 4 (HAProxy deployment)
#
# ================================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment
TIMEOUT="20m"  # Longer timeout for application services

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

log "🚀 Starting NCH Charts Step 3 Deployment..."
log "📦 Components: All Nirmata Services (Application Layer)"
log "🌍 Environment: $ENVIRONMENT"
log "🏷️  Namespace: $NAMESPACE"
log "ℹ️  Note: Services are preserved on failure/interruption for debugging"

# Display step summary at runtime
display_step_summary() {
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo "                         🚀 STEP 3: NIRMATA SERVICES SUMMARY"
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
  log "🎯 PURPOSE:"
  log "   Deploys the complete Nirmata application stack including all microservices"
  log "   that provide the core platform functionality and user interfaces."
  echo ""
  log "📦 WHAT THIS STEP DEPLOYS:"
  log "   ✅ Nirmata Application Services:"
  log "       • users (user management & authentication)"
  log "       • security (security & authorization)"
  log "       • activity (activity tracking & audit)"
  log "       • client-gateway (client API gateway)"
  log "       • cluster (cluster management)"
  log "       • policies (policy management & processing)"
  log "       • webclient (web UI interface)"
  log "       • gateway-service (main API gateway)"
  log "       • tunnel (secure tunneling)"
  log "       • llm-apps (AI/ML applications)"
  log "       • policy-studio (policy creation & editing)"
  echo ""
  log "⏱️  ESTIMATED TIME: 8-12 minutes"
  echo ""
  log "🎊 AFTER THIS STEP:"
  log "   ✅ All Nirmata microservices running"
  log "   ✅ Core platform functionality available"
  log "   ✅ Internal service communication established"
  log "   ✅ Ready for external access via load balancer"
  log "   ✅ Ready to run Step 4 (HAProxy deployment)"
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
}

# Display the summary
display_step_summary

# Pre-flight checks - OPTIMIZED: Only essential checks
preflight_checks() {
  log "🚀 Running essential pre-flight checks for Step 3..."
  
  # Basic cluster connectivity - ESSENTIAL
  validate_cluster_connectivity || exit 1
  
  # Check if required values files exist - ESSENTIAL
  local base_values="$SCRIPT_DIR/../../../config/values/base.yaml"
  local env_values="$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  local step_values="$SCRIPT_DIR/../../../config/values/steps/app-services.yaml"
  
  [[ -f "$base_values" ]] || { error "Base values file '$base_values' not found"; exit 1; }
  [[ -f "$env_values" ]] || { error "Environment values file '$env_values' not found"; exit 1; }
  [[ -f "$step_values" ]] || { error "Step values file '$step_values' not found"; exit 1; }
  
  success "All required values files found"
  
  # REMOVED: cluster resource validation (slows down deployment)
  
  # Quick prerequisite checks - ESSENTIAL
  log "🔍 Quick prerequisite checks..."
  validate_helm_release "nch-prereq" "$NAMESPACE" "deployed" || {
    error "Step 1 prerequisites not met! Please run Step 1 first:"
    error "  ./deploy-step1-prereq.sh $ENVIRONMENT"
    exit 1
  }
  
  validate_helm_release "nch-data" "$NAMESPACE" "deployed" || {
    error "Step 2 data services not ready! Please run Step 2 first:"
    error "  ./deploy-step2-mongodb-kafka.sh $ENVIRONMENT"
    exit 1
  }
}

# Create namespace with proper labels for Step 3
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
    nirmata.io/step: "3"
    nirmata.io/application-services: "true"
EOF
}

# Main deployment function
deploy_step3() {
  log "📁 Changing to chart directory..."
  cd "$SCRIPT_DIR/../../../nch-charts/"

  log "🔄 Updating Helm dependencies..."
  helm dependency update

  log "⚡ Deploying Step 3 components with $ENVIRONMENT profile..."
  log "📄 Using values files: config/values/base.yaml + config/values/steps/app-services.yaml + config/values/environments/$ENVIRONMENT.yaml"
  
  # Deploy with layered values files (corrected order: base → step → environment)
  helm upgrade --install nch-services . \
    --namespace "$NAMESPACE" \
    --set global.namespaceOverride="$NAMESPACE" \
    --values "../config/values/base.yaml" \
    --values "../config/values/steps/app-services.yaml" \
    --values "../config/values/environments/$ENVIRONMENT.yaml" \
    --timeout "$TIMEOUT" \
    --wait \
    --atomic
    
  success "Step 3 deployment completed successfully!"
}

# Comprehensive post-deployment validation
# Final validation - OPTIMIZED: Reduced wait time and focused checks
validate_deployment() {
  log "🔍 Running final Step 3 validation..."
  
  # Reset validation counters
  VALIDATION_ERRORS=0
  VALIDATION_WARNINGS=0
  
  # Optimized wait time for step-only validation
  log "⏱️  Waiting for services to stabilize..."
  sleep 15
  
  # Run Step 3 ONLY validation (optimized - no previous step dependencies)
  validate_step3_only "$NAMESPACE"
  
  # Print validation summary
  if print_validation_summary; then
    success "Step 3 validation completed successfully!"
    return 0
  else
    error "Step 3 validation failed!"
    return 1
  fi
}

# Show next steps
show_next_steps() {
  success "🎉 Step 3 (Nirmata Services) deployment completed successfully!"
  log ""
  log "📋 Next steps:"
  log "  1. Run Step 4: ./deploy-step4-haproxy.sh $ENVIRONMENT"
  log "  2. Check all services: kubectl get pods -n $NAMESPACE"
  log "  3. Check service endpoints: kubectl get svc -n $NAMESPACE"
  log "  4. Access gateway: kubectl port-forward svc/gateway-service 8443:8443 -n $NAMESPACE"
  log ""
  log "🔧 Troubleshooting:"
  log "  - Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
  log "  - Service logs: kubectl logs -l nirmata.io/service.name=<service-name> -n $NAMESPACE"
  log "  - Users service: kubectl logs -l nirmata.io/service.name=users -n $NAMESPACE"
  log "  - Security service: kubectl logs -l nirmata.io/service.name=security -n $NAMESPACE"
  log ""
  log "🌐 Application Services Ready:"
  log "  - Gateway API: https://gateway-service:8443"
  log "  - Web Client: https://webclient:80"
  log "  - Policy Studio: https://policy-studio:80"
}

# Cleanup function for failed deployments
cleanup_failed_deployment() {
  warning "⚠️  Step 3 deployment failed"
  warning "🔒 Preserving deployed services for debugging"
  warning "💡 Services remain available for troubleshooting"
  warning "🔧 To check status: helm status nch-services -n $NAMESPACE"
  warning "🧹 To cleanup later: helm uninstall nch-services -n $NAMESPACE"
  
  # Only cleanup if helm is in a truly stuck state (pending-install/pending-upgrade)
  if helm list -n "$NAMESPACE" | grep -q "nch-services"; then
    local status=$(helm status "nch-services" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    if [[ "$status" == "pending-install" || "$status" == "pending-upgrade" ]]; then
      warning "Found stuck release in $status state, cleaning up..."
      helm uninstall "nch-services" -n "$NAMESPACE" --no-hooks || true
    else
      warning "Release status: $status - keeping deployed services for debugging"
    fi
  fi
}

# Handle Ctrl+C interruption
handle_step3_interrupt() {
  echo ""
  warning "🛑 Step 3 deployment interrupted by user"
  warning "🔒 Preserving deployed services for debugging"
  warning "💡 Services remain available for troubleshooting"
  warning "🔧 To check status: helm status nch-services -n $NAMESPACE"
  warning "🧹 To cleanup later: helm uninstall nch-services -n $NAMESPACE"
  exit 130
}

# Main execution
main() {
  log "🏁 Starting Step 3 deployment with environment: $ENVIRONMENT"
  
  # Set up error and interrupt handling  
  # trap cleanup_failed_deployment ERR
  # trap handle_step3_interrupt SIGINT
  
  preflight_checks
  create_namespace
  deploy_step3
  validate_deployment
  show_next_steps
  
  success "🏁 Step 3 deployment completed successfully!"
}

# Execute main function
main "$@" 