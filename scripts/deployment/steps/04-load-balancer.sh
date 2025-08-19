#!/bin/bash

# Deploy Step 4: HAProxy Load Balancer with Comprehensive Validation
# This deploys the load balancer with full validation and dependency checking
# Usage: ./deploy-step4-haproxy.sh [dev|prod]

# ================================================================================
#                        🌐 STEP 4: LOAD BALANCER SUMMARY
# ================================================================================
#
# 🎯 PURPOSE:
#   Deploys HAProxy load balancer to provide external access to the Nirmata platform.
#   Enables high-availability routing and external connectivity for production use.
#
# 📦 WHAT THIS STEP DEPLOYS:
#   ✅ HAProxy load balancer pod
#   ✅ HAProxy service for external access
#   ✅ Load balancing configuration for all Nirmata services
#   ✅ High-availability routing rules
#   ✅ SSL/TLS termination configuration
#   ✅ Health checks and failover handling
#
# 🔗 DEPENDENCIES:
#   ✅ Step 1 completed (Prerequisites installed)
#   ✅ Step 2 completed (Data services running)
#   ✅ Step 3 completed (All Nirmata services running)
#   ✅ TLS certificates configured (server-certificate)
#   ✅ HAProxy configuration ready (haproxy-nirmata-config)
#
# ⏱️  ESTIMATED TIME: 2-3 minutes
#
# 🎊 AFTER THIS STEP:
#   ✅ Platform accessible via external load balancer
#   ✅ HAProxy providing high-availability routing
#   ✅ External traffic routing to Nirmata services
#   ✅ Production-ready external connectivity
#   ✅ Ready to run Step 5 (License & Tenant configuration)
#
# ================================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment
TIMEOUT="10m"  # HAProxy deploys quickly

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

log "🚀 Starting NCH Charts Step 4 Deployment..."
log "📦 Components: HAProxy Load Balancer (External Access)"
log "🌍 Environment: $ENVIRONMENT"
log "🏷️  Namespace: $NAMESPACE"

# Display step summary at runtime
display_step_summary() {
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo "                        🌐 STEP 4: LOAD BALANCER SUMMARY"
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
  log "🎯 PURPOSE:"
  log "   Deploys HAProxy load balancer to provide external access to the Nirmata platform."
  log "   Enables high-availability routing and external connectivity for production use."
  echo ""
  log "📦 WHAT THIS STEP DEPLOYS:"
  log "   ✅ HAProxy load balancer pod"
  log "   ✅ HAProxy service for external access"
  log "   ✅ Load balancing configuration for all Nirmata services"
  log "   ✅ High-availability routing rules"
  log "   ✅ SSL/TLS termination configuration"
  log "   ✅ Health checks and failover handling"
  echo ""
  log "⏱️  ESTIMATED TIME: 2-3 minutes"
  echo ""
  log "🎊 AFTER THIS STEP:"
  log "   ✅ Platform accessible via external load balancer"
  log "   ✅ HAProxy providing high-availability routing"
  log "   ✅ External traffic routing to Nirmata services"
  log "   ✅ Production-ready external connectivity"
  log "   ✅ Ready to run Step 5 (License & Tenant configuration)"
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
}

# Display the summary
display_step_summary

# Pre-flight checks - OPTIMIZED: Only essential checks
preflight_checks() {
  log "🚀 Running essential pre-flight checks for Step 4..."
  
  # Basic cluster connectivity - ESSENTIAL
  validate_cluster_connectivity || exit 1
  
  # Check if required values files exist - ESSENTIAL
  local base_values="$SCRIPT_DIR/../../../config/values/base.yaml"
  local env_values="$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  local step_values="$SCRIPT_DIR/../../../config/values/steps/load-balancer.yaml"
  
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
  
  validate_helm_release "nch-services" "$NAMESPACE" "deployed" || {
    error "Step 3 application services not ready! Please run Step 3 first:"
    error "  ./deploy-step3-nirmata-services.sh $ENVIRONMENT"
    exit 1
  }
}

# Create namespace with proper labels for Step 4
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
    nirmata.io/step: "4"
    nirmata.io/load-balancer: "true"
EOF
}

# Main deployment function
deploy_step4() {
  log "📁 Changing to chart directory..."
  cd "$SCRIPT_DIR/../../../nch-charts/"

  log "🔄 Updating Helm dependencies..."
  helm dependency update

  log "⚡ Deploying Step 4 components with $ENVIRONMENT profile..."
  log "📄 Using values files: config/values/base.yaml + config/values/steps/load-balancer.yaml + config/values/environments/$ENVIRONMENT.yaml"
  
  # Deploy with layered values files (corrected order: base → step → environment)
  helm upgrade --install nch-haproxy . \
    --namespace "$NAMESPACE" \
    --set global.namespaceOverride="$NAMESPACE" \
    --values "../config/values/base.yaml" \
    --values "../config/values/steps/load-balancer.yaml" \
    --values "../config/values/environments/$ENVIRONMENT.yaml" \
    --timeout "$TIMEOUT" \
    --wait \
    --atomic
    
  success "Step 4 deployment completed successfully!"
}

# Final validation - OPTIMIZED: Reduced wait time and focused checks
validate_deployment() {
  log "🔍 Running final Step 4 validation..."
  
  # Reset validation counters
  VALIDATION_ERRORS=0
  VALIDATION_WARNINGS=0
  
  # Optimized wait time for step-only validation
  log "⏱️  Waiting for HAProxy to stabilize..."
  sleep 8
  
  # Run Step 4 ONLY validation (optimized - no previous step dependencies)
  validate_step4_only "$NAMESPACE"
  
  # Print validation summary
  if print_validation_summary; then
    success "Step 4 validation completed successfully!"
    return 0
  else
    error "Step 4 validation failed!"
    return 1
  fi
}

# Show next steps and completion summary
show_completion_summary() {
  success "🎉 Step 4 (HAProxy Load Balancer) deployment completed successfully!"
  success "🎊 ALL DEPLOYMENT STEPS COMPLETED! 🎊"
  log ""
  log "🌟 Full Nirmata Platform Deployed:"
  log "  ✅ Step 1: Prerequisites (CRDs, ConfigMaps, Secrets)"
  log "  ✅ Step 2: Data Services (MongoDB, Kafka)"
  log "  ✅ Step 3: Application Services (All Nirmata Services)"
  log "  ✅ Step 4: Load Balancer (HAProxy)"
  log ""
  log "🔗 Access Your Nirmata Platform:"
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    log "  🌐 External Access (Production):"
    log "    - Configure your DNS to point to the HAProxy service"
    log "    - Update TLS certificates for production use"
    log "    - URL: https://$(kubectl get configmap nirmata-config -n $NAMESPACE -o jsonpath='{.data.nirmata\.url}' 2>/dev/null || echo 'your-domain.com')"
  else
    log "  🖥️  Development Access:"
    log "    - Port forward: kubectl port-forward svc/haproxy 8443:8443 -n $NAMESPACE"
    log "    - Then access: https://localhost:8443"
  fi
  log ""
  log "🔧 Management Commands:"
  log "  - Check all pods: kubectl get pods -n $NAMESPACE"
  log "  - Check all services: kubectl get svc -n $NAMESPACE"
  log "  - View HAProxy stats: kubectl port-forward svc/haproxy 1936:1936 -n $NAMESPACE"
  log "  - Scale services: kubectl scale deployment <service-name> --replicas=<N> -n $NAMESPACE"
  log ""
  log "🧹 Cleanup (if needed):"
  log "  - Full cleanup: ./cleanup-all.sh"
  log "  - Single step: helm uninstall <release-name> -n $NAMESPACE"
  log ""
  log "📊 Resource Usage:"
  if kubectl top pods -n "$NAMESPACE" >/dev/null 2>&1; then
    log "  - Pod resource usage:"
    kubectl top pods -n "$NAMESPACE" --sort-by=memory 2>/dev/null | head -10 || true
  else
    log "  - Resource metrics not available (metrics server may not be running)"
  fi
}

# Cleanup function for failed deployments
cleanup_failed_deployment() {
  warning "🧹 Deployment failed, checking if cleanup is needed..."
  
  if helm list -n "$NAMESPACE" | grep -q "nch-haproxy"; then
    local status=$(helm status "nch-haproxy" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    if [[ "$status" == "failed" || "$status" == "pending-install" ]]; then
      warning "Found failed/stuck release, cleaning up..."
      helm uninstall "nch-haproxy" -n "$NAMESPACE" --no-hooks || true
    fi
  fi
}

# Main execution
main() {
  log "🏁 Starting Step 4 (Final) deployment with environment: $ENVIRONMENT"
  
  # Set up error handling
  trap cleanup_failed_deployment ERR
  
  preflight_checks
  create_namespace
  deploy_step4
  validate_deployment
  show_completion_summary
  
  success "🏁 Step 4 deployment completed successfully!"
  success "🎊 FULL NIRMATA PLATFORM DEPLOYMENT COMPLETE! 🎊"
}

# Execute main function
main "$@" 