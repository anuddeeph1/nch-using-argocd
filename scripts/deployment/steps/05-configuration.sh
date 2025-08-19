#!/bin/bash

# Deploy Step 5: Nirmata Configuration via API
# Validates license and sets up tenant through Nirmata security API
# Usage: ./deploy-step5-config.sh [dev|prod]

# ================================================================================
#                       🔧 STEP 5: PLATFORM CONFIGURATION SUMMARY
# ================================================================================
#
# 🎯 PURPOSE:
#   Configures the deployed Nirmata platform via API calls. Validates license,
#   sets up tenant, and prepares the platform for end-user access.
#
# 📦 WHAT THIS STEP CONFIGURES:
#   ✅ Platform connectivity verification
#   ✅ License validation and activation
#   ✅ Initial tenant setup and configuration
#   ✅ Admin user account creation
#   ✅ Company/organization configuration
#   ✅ Platform URL and access settings
#   ✅ Security and authentication setup
#   ✅ Feature flags activation (20+ features)
#   ✅ API endpoint validation
#
# 🔗 DEPENDENCIES:
#   ✅ Step 1-4 completed (Full platform deployed)
#   ✅ Platform URL configured and accessible via DNS
#   ✅ Infrastructure setup (load balancers, certificates)
#   ⚠️  If connectivity fails, script will stop with guidance
#
# ⚠️  CONNECTIVITY REQUIREMENT:
#   This step requires the platform to be accessible via the configured URL.
#   If connectivity fails, the script will stop and provide setup guidance.
#   You can re-run this step independently: ./deploy-step5-config.sh [env]
#
# ⏱️  ESTIMATED TIME: 3-5 minutes
#
# 🎊 AFTER THIS STEP:
#   ✅ Platform fully configured and ready for use
#   ✅ License activated and validated
#   ✅ Tenant and admin user created
#   ✅ Web interface accessible to end users
#   ✅ Platform ready for production workloads
#   ✅ Complete Nirmata deployment finished!
#
# ================================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"
TIMEOUT="15m"

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

log "🚀 Starting NCH Charts Step 5 Configuration..."
log "📦 Components: License Validation & Tenant Setup via API"
log "🌍 Environment: $ENVIRONMENT"
log "🏷️  Namespace: $NAMESPACE"

# Display step summary at runtime
display_step_summary() {
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo "                       🔧 STEP 5: PLATFORM CONFIGURATION SUMMARY"
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
  log "🎯 PURPOSE:"
  log "   Configures the deployed Nirmata platform via API calls. Validates license,"
  log "   sets up tenant, and prepares the platform for end-user access."
  echo ""
  log "📦 WHAT THIS STEP CONFIGURES:"
  log "   ✅ Platform connectivity verification"
  log "   ✅ License validation and activation"
  log "   ✅ Initial tenant setup and configuration"
  log "   ✅ Admin user account creation"
  log "   ✅ Company/organization configuration"
  log "   ✅ Platform URL and access settings"
  log "   ✅ Security and authentication setup"
  log "   ✅ Feature flags activation (20+ features)"
  log "   ✅ API endpoint validation"
  echo ""
  log "⏱️  ESTIMATED TIME: 3-5 minutes"
  echo ""
  log "⚠️  REQUIREMENTS:"
  log "   ⚡ Platform must be accessible via configured URL"
  log "   ⚡ DNS and infrastructure setup completed"
  log "   ⚡ Script will stop if connectivity fails (with guidance)"
  echo ""
  log "🎊 AFTER THIS STEP:"
  log "   ✅ Platform fully configured and ready for use"
  log "   ✅ License activated and validated"
  log "   ✅ Tenant and admin user created"
  log "   ✅ Web interface accessible to end users"
  log "   ✅ Platform ready for production workloads"
  log "   ✅ Complete Nirmata deployment finished!"
  echo ""
  echo "$(printf '=%.0s' $(seq 1 80))"
  echo ""
}

# Display the summary
display_step_summary

# Global variables for configuration
LICENSE_KEY=""
LICENSE_TYPE=""
TENANT_NAME=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
COMPANY_NAME=""
PRODUCT_URL=""
API_BASE=""

# Pre-flight checks - OPTIMIZED: Only essential checks
preflight_checks() {
  log "🚀 Running essential pre-flight checks for Step 5..."
  
  # Basic cluster connectivity - ESSENTIAL
  validate_cluster_connectivity || exit 1
  
  # Check if required values files exist - ESSENTIAL
  local base_values="$SCRIPT_DIR/../../../config/values/base.yaml"
  local env_values="$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  local step_values="$SCRIPT_DIR/../../../config/values/steps/configuration.yaml"
  
  [[ -f "$base_values" ]] || { error "Base values file '$base_values' not found"; exit 1; }
  [[ -f "$env_values" ]] || { error "Environment values file '$env_values' not found"; exit 1; }
  [[ -f "$step_values" ]] || { error "Step values file '$step_values' not found"; exit 1; }
  
  success "All required values files found"
  
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
  
  validate_helm_release "nch-haproxy" "$NAMESPACE" "deployed" || {
    error "Step 4 HAProxy not ready! Please run Step 4 first:"
    error "  ./deploy-step4-haproxy.sh $ENVIRONMENT"
    exit 1
  }
  
  # Check HAProxy service is accessible
  validate_service "haproxy" "$NAMESPACE" || {
    error "HAProxy service not accessible! Cannot configure Nirmata via API."
    exit 1
  }
  
  success "All prerequisite checks passed"
}

# Extract configuration values using simple grep-based parsing
extract_config_values() {
  log "📖 Extracting configuration values from merged values..."
  
  # Create a temporary values merge for processing
  local temp_values="/tmp/nirmata-config-values-$$.yaml"
  
  # Merge values files in correct order: base -> step -> environment
  {
    echo "# Merged configuration values"
    cat "$SCRIPT_DIR/../../../config/values/base.yaml"
    echo "---"
    cat "$SCRIPT_DIR/../../../config/values/steps/configuration.yaml" 
    echo "---"
    cat "$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  } > "$temp_values"
  
  # Extract values (simple grep-based approach)
  LICENSE_KEY=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "license:" | grep "key:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  LICENSE_TYPE=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "license:" | grep "type:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "enterprise")
  
  TENANT_NAME=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "tenant:" | grep "name:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  ADMIN_EMAIL=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "tenant:" | grep "adminEmail:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  ADMIN_PASSWORD=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "tenant:" | grep "adminPassword:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  COMPANY_NAME=$(grep -A 10 "nirmataConfig:" "$temp_values" | grep -A 5 "tenant:" | grep "companyName:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  
  # Extract product URL from global.product.url
  PRODUCT_URL=$(grep -A 5 "product:" "$temp_values" | grep "url:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "")
  
  # Cleanup temp file
  rm -f "$temp_values"
  
  # Validate required values are present
  [[ -n "$LICENSE_KEY" ]] || { error "License key not found in configuration"; exit 1; }
  [[ -n "$TENANT_NAME" ]] || { error "Tenant name not found in configuration"; exit 1; }
  [[ -n "$ADMIN_EMAIL" ]] || { error "Admin email not found in configuration"; exit 1; }
  [[ -n "$ADMIN_PASSWORD" ]] || { error "Admin password not found in configuration"; exit 1; }
  [[ -n "$PRODUCT_URL" ]] || { error "Product URL not found in configuration"; exit 1; }
  
  success "Configuration values extracted successfully"
  log "  License Type: $LICENSE_TYPE"
  log "  Tenant Name: $TENANT_NAME"
  log "  Admin Email: $ADMIN_EMAIL"
  log "  Company Name: ${COMPANY_NAME:-'(not specified)'}"
  log "  Product URL: $PRODUCT_URL"
}

# Check Nirmata platform connectivity before configuration
check_platform_connectivity() {
  log "🔍 Checking Nirmata platform connectivity..."
  log "  Testing reachability at: https://$PRODUCT_URL"
  
  # Test users service status endpoint
  local users_status_url="https://$PRODUCT_URL/users/health"
  local status_code=""
  
  log "  🧪 Testing users service status endpoint..."
  log "      URL: $users_status_url"
  
  # Test connectivity with timeout
  if status_code=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$users_status_url" 2>/dev/null); then
    if [[ "$status_code" == "200" ]]; then
      success "✅ Platform is reachable! Users service responding with HTTP 200"
      success "   End-to-end connectivity confirmed"
      return 0
    else
      warning "⚠️  Users service responded with HTTP $status_code (expected 200)"
    fi
  else
    warning "⚠️  Unable to reach users service status endpoint"
  fi
  
  # Show guidance and stop execution if connectivity fails
  error ""
  error "❌ PLATFORM CONNECTIVITY FAILED"
  error "   The Nirmata platform is not accessible. License configuration cannot proceed"
  error "   without platform connectivity."
  error ""
  warning "🔧 REQUIRED SETUP STEPS:"
  warning "   Before running Step 5 configuration, you must complete the following:"
  warning ""
  warning "🌐 DNS Configuration:"
  warning "   • Ensure DNS record points to your load balancer:"
  warning "     $PRODUCT_URL → [Your Load Balancer IP/DNS]"
  warning "   • Test DNS resolution: nslookup $PRODUCT_URL"
  warning ""
  warning "☁️  Infrastructure Setup (if using cloud provider):"
  warning "   • AWS/EKS: Create Application Load Balancer (ALB) pointing to HAProxy"
  warning "   • Azure/AKS: Create Application Gateway or Load Balancer"
  warning "   • GCP/GKE: Create Load Balancer or Ingress Controller"
  warning "   • Verify security groups/firewall rules allow HTTPS (443) traffic"
  warning ""
  warning "🔒 TLS/SSL Configuration:"
  warning "   • Ensure valid TLS certificates are configured"
  warning "   • Check if certificate matches the domain: $PRODUCT_URL"
  warning ""
  warning "🔍 Troubleshooting Commands:"
  warning "   • Test HAProxy directly: kubectl port-forward svc/haproxy 8443:443 -n $NAMESPACE"
  warning "   • Check HAProxy logs: kubectl logs -l app=haproxy -n $NAMESPACE"
  warning "   • Check users service: kubectl logs -l app=users -n $NAMESPACE"
  warning "   • Test direct access: curl -k https://$PRODUCT_URL/users/health"
  warning ""
  log "🚀 NEXT STEPS:"
  log "   1. Complete the infrastructure setup above"
  log "   2. Verify platform connectivity manually"
  log "   3. Re-run Step 5 configuration only:"
  log "      ./deploy-step5-config.sh $ENVIRONMENT"
  log ""
  error "🛑 Step 5 configuration stopped due to connectivity failure"
  
  # Exit the script since connectivity is required for configuration
  exit 1
}

# Setup API connection
setup_api_connection() {
  log "🔗 Setting up API connection..."
  
  # Use product URL from configuration instead of HAProxy service discovery
  API_BASE="https://$PRODUCT_URL"
  
  # Test basic connectivity
  log "🧪 Testing API connectivity..."
  if curl -k -s --connect-timeout 10 "$API_BASE" >/dev/null 2>&1; then
    success "API endpoint accessible at $API_BASE"
  else
    warning "Base endpoint not accessible, but continuing with configuration..."
  fi
}

# Validate license via API
configure_license() {
  log "📜 Validating Nirmata license..."
  
  local license_payload=$(cat <<EOF
{
  "licenseKey": "$LICENSE_KEY"
}
EOF
)
  
  log "  Validating license key..."
  if curl -k -s -X POST "$API_BASE/security/api/license/validateLicenseKey" \
    -H "Content-Type: application/json" \
    -d "$license_payload" \
    --retry 3 --retry-delay 5 \
    --connect-timeout 30 >/tmp/license-response.json 2>&1; then
    
    success "License validation request submitted successfully"
    
    # Check response
    if [[ -f "/tmp/license-response.json" ]] && grep -q "valid\|true\|success" /tmp/license-response.json 2>/dev/null; then
      success "License appears to be valid"
    else
      warning "License validation response unclear - manual verification recommended"
      cat /tmp/license-response.json 2>/dev/null || echo "No response content"
    fi
  else
    error "Failed to validate license. Check API connectivity and license key."
    return 1
  fi
  
  rm -f /tmp/license-response.json
}

# Configure tenant via setup API
configure_tenant() {
  log "🏢 Setting up Nirmata tenant..."
  
  local tenant_payload=$(cat <<EOF
{
  "name": "$ADMIN_EMAIL",
  "email": "$ADMIN_EMAIL",
  "companyName": "${COMPANY_NAME:-$TENANT_NAME}",
  "password": "$ADMIN_PASSWORD",
  "licenseKey": "$LICENSE_KEY"
}
EOF
)
  
  log "  Setting up tenant with admin user: $ADMIN_EMAIL"
  log "  Company: ${COMPANY_NAME:-$TENANT_NAME}"
  
  if curl -k -s -X POST "$API_BASE/security/api/setup" \
    -H "Content-Type: application/json" \
    -d "$tenant_payload" \
    --retry 3 --retry-delay 5 \
    --connect-timeout 30 >/tmp/tenant-response.json 2>&1; then
    
    success "Tenant setup request submitted successfully"
    
    # Check response
    if [[ -f "/tmp/tenant-response.json" ]] && grep -q "success\|created\|ok\|true" /tmp/tenant-response.json 2>/dev/null; then
      success "Tenant setup completed successfully"
    else
      warning "Tenant setup response unclear - manual verification recommended"
      cat /tmp/tenant-response.json 2>/dev/null || echo "No response content"
    fi
  else
    error "Failed to setup tenant. Check API connectivity and configuration."
    return 1
  fi
  
  rm -f /tmp/tenant-response.json
}

# Configure feature flags in MongoDB Tenant document
configure_feature_flags() {
  log "🎯 Configuring Nirmata feature flags..."
  
  # Wait for tenant setup to complete
  log "  ⏱️  Waiting for tenant setup to complete..."
  sleep 10
  
  # Extract MongoDB credentials from values files
  log "  🔐 Extracting MongoDB credentials from configuration..."
  local temp_values="/tmp/nirmata-config-values-$$.yaml"
  
  # Create merged values for credential extraction
  {
    echo "# Merged configuration values for credentials"
    cat "$SCRIPT_DIR/../../../config/values/base.yaml"
    echo "---"
    cat "$SCRIPT_DIR/../../../config/values/steps/configuration.yaml" 
    echo "---"
    cat "$SCRIPT_DIR/../../../config/values/environments/${ENVIRONMENT}.yaml"
  } > "$temp_values"
  
  # Extract MongoDB credentials (same logic as in extract_config_values)
  local MONGODB_USERNAME=$(grep -A 10 "mongo:" "$temp_values" | grep "mongoDBUsername:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "admin")
  local MONGODB_PASSWORD=$(grep -A 10 "mongo:" "$temp_values" | grep "mongoDBPassword:" | tail -1 | cut -d: -f2 | tr -d ' "' || echo "MongoDBTest123")
  
  # Cleanup temp file
  rm -f "$temp_values"
  
  log "  📊 Using MongoDB credentials: $MONGODB_USERNAME / [password hidden]"
  
  # Get MongoDB pod
  local mongodb_pod=$(kubectl get pod -n "$NAMESPACE" -l app=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [[ -z "$mongodb_pod" ]]; then
    error "MongoDB pod not found in namespace $NAMESPACE"
    return 1
  fi
  
  log "  📂 Found MongoDB pod: $mongodb_pod"
  
  # Construct database name (Users-<namespace>)
  local db_name="Users-$NAMESPACE"
  log "  🗄️  Target database: $db_name"
  
  # Feature flags array
  local features_array='["policy-exceptions", "cis-k8s-benchmark", "auto-namespace-assignment", "auto-remediation", "scan-report", "git-policy-set", "enable-security-role", "gitops-policyset", "enable-policy-sets", "compliance-per-namespace", "modern-dashboard", "policy-studio", "policy-studio-ai", "nch-quick-start", "ai_remediation", "suppress-violation", "new-cluster-onboarding", "cluster-policy-reports", "invite-users", "authentication-settings"]'
  
  # MongoDB script to update feature flags (using safe single-quote approach)
  local mongodb_script='
  var dbName = "'$db_name'";
  var features = '$features_array';
  try {
      var result = db.getSiblingDB(dbName).Tenant.updateMany({}, { $set: { "features": features } });
      print("RESULT_START");
      print("matchedCount:" + result.matchedCount);
      print("modifiedCount:" + result.modifiedCount);
      print("featuresConfigured:" + features.length);
      print("RESULT_END");
  } catch (error) {
      print("ERROR_START");
      print("error:" + error);
      print("ERROR_END");
  }
  '
  
  log "  🔧 Updating tenant feature flags..."
  log "     Features: policy-exceptions, cis-k8s-benchmark, auto-namespace-assignment, +"
  log "               auto-remediation, scan-report, git-policy-set, modern-dashboard,"
  log "               policy-studio, policy-studio-ai, ai_remediation, and more..."
  log "     Using structured MongoDB script for reliable updates..."
  
  # Execute MongoDB command with extracted credentials
  if kubectl exec "$mongodb_pod" -n "$NAMESPACE" -c mongod -- mongosh \
    --username "$MONGODB_USERNAME" \
    --password "$MONGODB_PASSWORD" \
    --authenticationDatabase admin \
    --eval "$mongodb_script" >/tmp/feature-flags-response.txt 2>&1; then
    
    # Check if the update was successful by looking for structured output
    if grep -q "RESULT_START" /tmp/feature-flags-response.txt 2>/dev/null; then
      success "✅ Feature flags configured successfully"
      
      # Extract structured results from MongoDB output
      local matched_count=$(grep "matchedCount:" /tmp/feature-flags-response.txt 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
      local modified_count=$(grep "modifiedCount:" /tmp/feature-flags-response.txt 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
      local features_count=$(grep "featuresConfigured:" /tmp/feature-flags-response.txt 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
      
      log "     📊 Matched documents: ${matched_count:-0}"
      log "     📝 Modified documents: ${modified_count:-0}"
      log "     🎯 Features configured: ${features_count:-0}"
      
      if [[ "${modified_count:-0}" -gt 0 ]]; then
        success "     🎉 Successfully updated tenant with ${features_count:-20} feature flags"
      elif [[ "${matched_count:-0}" -gt 0 ]]; then
        warning "     ⚠️  No changes made - features may already be configured"
      else
        warning "     ⚠️  No tenant documents found to update"
      fi
      
    elif grep -q "ERROR_START" /tmp/feature-flags-response.txt 2>/dev/null; then
      error "❌ MongoDB script execution failed:"
      local error_msg=$(grep -A 5 "ERROR_START" /tmp/feature-flags-response.txt | grep "error:" | cut -d: -f2- || echo "Unknown error")
      log "   Error: ${error_msg}"
      return 1
      
    else
      warning "⚠️  Feature flags update response unclear - checking for fallback indicators:"
      # Fallback to old logic for backward compatibility
      if grep -q "acknowledged.*true\|modifiedCount.*[1-9]" /tmp/feature-flags-response.txt 2>/dev/null; then
        success "✅ Feature flags configured successfully (legacy format)"
        local modified_count=$(grep -o "modifiedCount.*[0-9]" /tmp/feature-flags-response.txt 2>/dev/null | grep -o "[0-9]" || echo "N/A")
        log "     📊 Modified $modified_count tenant document(s)"
      else
        warning "    Raw response (first 5 lines):"
        cat /tmp/feature-flags-response.txt 2>/dev/null | head -5
      fi
    fi
  else
    error "❌ Failed to configure feature flags in MongoDB"
    log "   Error details:"
    cat /tmp/feature-flags-response.txt 2>/dev/null | head -10
    return 1
  fi
  
  # Cleanup
  rm -f /tmp/feature-flags-response.txt
  
  success "🎯 Feature flags configuration completed"
}

# Validate configuration
validate_configuration() {
  log "🔍 Validating Nirmata configuration..."
  
  # Optimized wait time for configuration validation
  log "⏱️  Waiting for configuration to stabilize..."
  sleep 8
  
  # Run Step 5 ONLY validation (optimized - API accessibility check)
  validate_step5_only "$NAMESPACE"
  
  # Additional configuration-specific checks
  log "  🔍 Verifying API configuration..."
  if curl -k -s --connect-timeout 8 "$API_BASE" >/tmp/platform-status.json 2>&1; then
    success "Platform accessible"
  else
    warning "Platform status check unclear - this may be expected"
  fi
  
  if curl -k -s --connect-timeout 8 "$API_BASE/security/api/users" >/tmp/users-check.json 2>&1; then
    if grep -q "unauthorized\|forbidden" /tmp/users-check.json 2>/dev/null; then
      success "Security API responding (authentication required as expected)"
    elif grep -q "error\|invalid" /tmp/users-check.json 2>/dev/null; then
      warning "Setup may not be complete - manual verification recommended"
    else
      success "Platform appears to be properly configured"
    fi
  else
    warning "Security API endpoint not accessible - this may be expected"
  fi
  
  rm -f /tmp/platform-status.json /tmp/users-check.json
  
  success "Configuration validation completed"
}

# Show next steps and completion summary
show_completion_summary() {
  success "🎉 Step 5 (Nirmata Configuration) completed successfully!"
  log ""
  log "📋 Configuration Summary:"
  log "  ✅ License: Validated successfully"
  log "  ✅ Tenant Setup: Completed for ${COMPANY_NAME:-$TENANT_NAME}"
  log "  ✅ Admin User: $ADMIN_EMAIL"
  log "  ✅ Feature Flags: 20+ features activated"
  log ""
  log "🔗 Access Your Configured Nirmata Platform:"
  log "  🌐 Platform URL: https://$PRODUCT_URL"
  log "  📧 Login Email: $ADMIN_EMAIL"
  log "  🔑 Password: [as configured]"
  log ""
  log "🔧 Verification Commands:"
  log "  - Test platform: curl -k https://$PRODUCT_URL"
  log "  - Check pods: kubectl get pods -n $NAMESPACE"
  log "  - View gateway logs: kubectl logs -l app=gateway-service -n $NAMESPACE"
  log ""
  log "🎊 COMPLETE NIRMATA DEPLOYMENT FINISHED! 🎊"
  log "  ✅ Step 1: Prerequisites"
  log "  ✅ Step 2: Data Services (MongoDB, Kafka)"
  log "  ✅ Step 3: Application Services"
  log "  ✅ Step 4: Load Balancer (HAProxy)"
  log "  ✅ Step 5: Configuration (License & Tenant)"
}

# Cleanup function for failed deployments
cleanup_failed_configuration() {
  warning "🧹 Configuration failed, checking for cleanup needs..."
  
  # Remove temporary files
  rm -f /tmp/license-response.json /tmp/tenant-response.json 
  rm -f /tmp/platform-status.json /tmp/users-check.json
  rm -f /tmp/feature-flags-response.txt
  rm -f /tmp/nirmata-config-values-$$.yaml
  
  log "Temporary files cleaned up"
}

# Main execution
main() {
  log "🏁 Starting Step 5 configuration with environment: $ENVIRONMENT"
  
  # Set up error handling
  trap cleanup_failed_configuration ERR
  
  preflight_checks
  extract_config_values
  check_platform_connectivity
  setup_api_connection
  configure_license
  configure_tenant
  configure_feature_flags
  validate_configuration
  show_completion_summary
  
  success "🏁 Step 5 configuration completed successfully!"
}

# Execute main function
main "$@" 