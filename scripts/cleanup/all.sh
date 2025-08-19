#!/bin/bash
# Comprehensive Cleanup Script for Nirmata Deployment
# This script removes all deployed components: prereq, kafka, mongodb, users & security
# Usage: ./cleanup-all.sh [dev|prod]

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"  # Default to dev environment

# Validate environment parameter
if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    echo "❌ Invalid environment '$ENVIRONMENT'. Use 'dev' or 'prod'"
    echo ""
    echo "Usage: $0 [dev|prod]"
    echo "  dev   - Clean development environment (default)"
    echo "  prod  - Clean production environment"
    echo ""
    echo "Environment variables:"
    echo "  NCH_NAMESPACE - Override target namespace (reads from config/values/environments/{env}.yaml)"
    echo ""
    exit 1
fi

# Extract namespace from environment-specific values file
extract_namespace_from_values() {
  local env_file="config/values/environments/${ENVIRONMENT}.yaml"
  
  if [[ ! -f "$env_file" ]]; then
    echo "❌ Environment values file not found: $env_file"
    exit 1
  fi
  
  # Extract namespaceOverride from the YAML file
  local namespace=$(grep "namespaceOverride:" "$env_file" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  
  if [[ -z "$namespace" ]]; then
    echo "❌ namespaceOverride not found in $env_file"
    exit 1
  fi
  
  echo "$namespace"
}

# Get namespace from environment values file (allow NCH_NAMESPACE override for backward compatibility)
NAMESPACE="${NCH_NAMESPACE:-$(extract_namespace_from_values)}"

echo "================================================================================"
echo "🧹 NCH CHARTS CLEANUP"
echo "================================================================================"
echo "🌍 Environment: $ENVIRONMENT"
echo "🏷️  Namespace: $NAMESPACE"
echo "================================================================================"
echo ""

# Function to check if resource exists
resource_exists() {
    kubectl get "$1" "$2" -n "$NAMESPACE" >/dev/null 2>&1
}

# 1. Uninstall Helm releases
echo "📦 Uninstalling Helm releases..."

if helm list -n $NAMESPACE -a | grep -q "nch-haproxy"; then
    echo "  - Uninstalling nch-haproxy (HAProxy Load Balancer)..."
    helm uninstall nch-haproxy -n $NAMESPACE
    echo "    ✅ nch-haproxy uninstalled"
else
    echo "    ℹ️  nch-haproxy not found"
fi

if helm list -n $NAMESPACE -a | grep -q "nch-services"; then
    echo "  - Uninstalling nch-services (All Nirmata Services)..."
    helm uninstall nch-services -n $NAMESPACE
    echo "    ✅ nch-services uninstalled"
else
    echo "    ℹ️  nch-services not found"
fi



if helm list -n $NAMESPACE -a | grep -q "nch-data"; then
    echo "  - Uninstalling nch-data (MongoDB & Kafka)..."
    helm uninstall nch-data -n $NAMESPACE
    echo "    ✅ nch-data uninstalled"
else
    echo "    ℹ️  nch-data not found"
fi

if helm list -n $NAMESPACE -a | grep -q "nch-prereq"; then
    echo "  - Uninstalling nch-prereq (Prerequisites)..."
    helm uninstall nch-prereq -n $NAMESPACE
    echo "    ✅ nch-prereq uninstalled"
else
    echo "    ℹ️  nch-prereq not found"
fi

echo ""

# 2. Wait for pods to terminate
echo "⏳ Waiting for pods to terminate..."
timeout=120
elapsed=0
while kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v "Terminating" | grep -q .; do
    if [ $elapsed -ge $timeout ]; then
        echo "    ⚠️  Timeout waiting for pods to terminate. Continuing with cleanup..."
        break
    fi
    echo "    Waiting... ($elapsed/$timeout seconds)"
    sleep 5
    elapsed=$((elapsed + 5))
done
echo "    ✅ Pods terminated"
echo ""

# 3. Delete PVCs (Persistent Volume Claims)
echo "💾 Cleaning up Persistent Volume Claims..."
PVCs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $1}' || true)
if [ -n "$PVCs" ]; then
    for pvc in $PVCs; do
        echo "  - Deleting PVC: $pvc"
        kubectl delete pvc "$pvc" -n $NAMESPACE
    done
    echo "    ✅ All PVCs deleted"
else
    echo "    ℹ️  No PVCs found"
fi
echo ""

# 4. Delete MongoDB-related secrets
echo "🔐 Cleaning up MongoDB secrets..."
MONGO_SECRETS=(
    "mongo-credentials"
    "mongo-truststore-keystore"
    "mongodb-admin-admin"
    "mongodb-keystore"
    "mongodb-truststore"
)

for secret in "${MONGO_SECRETS[@]}"; do
    if resource_exists secret "$secret"; then
        echo "  - Deleting secret: $secret"
        kubectl delete secret "$secret" -n $NAMESPACE
    else
        echo "    ℹ️  Secret $secret not found"
    fi
done
echo "    ✅ MongoDB secrets cleanup completed"
echo ""

# 5. Delete any remaining jobs (pre-install hooks, etc.)
echo "🏃 Cleaning up remaining jobs..."
JOBS=$(kubectl get jobs -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $1}' || true)
if [ -n "$JOBS" ]; then
    for job in $JOBS; do
        echo "  - Deleting job: $job"
        kubectl delete job "$job" -n $NAMESPACE
    done
    echo "    ✅ All jobs deleted"
else
    echo "    ℹ️  No jobs found"
fi
echo ""

# 6. Delete any remaining configmaps (if not auto-deleted)
echo "📝 Cleaning up remaining configmaps..."
CONFIGMAPS=$(kubectl get configmap -n $NAMESPACE --no-headers 2>/dev/null | grep -v "kube-" | awk '{print $1}' || true)
if [ -n "$CONFIGMAPS" ]; then
    for cm in $CONFIGMAPS; do
        echo "  - Deleting configmap: $cm"
        kubectl delete configmap "$cm" -n $NAMESPACE
    done
    echo "    ✅ All configmaps deleted"
else
    echo "    ℹ️  No custom configmaps found"
fi
echo ""

# 7. Delete MongoDB CRDs (Custom Resource Definitions)
echo "🗂️  Cleaning up MongoDB Custom Resource Definitions..."
MONGODB_CRDS=$(kubectl get crd --no-headers 2>/dev/null | grep -i mongodb | awk '{print $1}' || true)
if [ -n "$MONGODB_CRDS" ]; then
    for crd in $MONGODB_CRDS; do
        echo "  - Deleting CRD: $crd"
        kubectl delete crd "$crd" 2>/dev/null || echo "    ⚠️  Failed to delete CRD: $crd (may not exist or be protected)"
    done
    echo "    ✅ MongoDB CRDs cleanup completed"
else
    echo "    ℹ️  No MongoDB CRDs found"
fi
echo ""

# 8. Clean up PriorityClasses (cluster-scoped resources)
echo "🎯 Cleaning up Nirmata PriorityClasses..."
NIRMATA_PRIORITY_CLASSES="nirmata-app-critical nirmata-app-lower nirmata-data-critical nirmata-data-lower"
for pc in $NIRMATA_PRIORITY_CLASSES; do
    if kubectl get priorityclass "$pc" >/dev/null 2>&1; then
        echo "  - Deleting PriorityClass: $pc"
        kubectl delete priorityclass "$pc" 2>/dev/null || echo "    ⚠️  Failed to delete PriorityClass: $pc (may not exist or be protected)"
    else
        echo "    ℹ️  PriorityClass $pc not found"
    fi
done
echo "    ✅ PriorityClass cleanup completed"
echo ""

# 9. Verify cleanup
echo "🔍 Verifying cleanup..."
REMAINING_RESOURCES=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_RESOURCES" -eq 0 ]; then
    echo "    ✅ All resources successfully removed"
else
    echo "    ⚠️  Some resources may still exist:"
    kubectl get all -n $NAMESPACE
fi

echo ""

# 10. Delete namespace with monitoring
echo "🗑️  Deleting namespace: $NAMESPACE"

# Function to check namespace status
check_namespace_status() {
    kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound"
}

# Function to force delete namespace by removing finalizers
force_delete_namespace() {
    echo "    🚨 Namespace stuck in Terminating state. Attempting force deletion..."
    
    # Method 1: Remove finalizers using kubectl patch
    echo "    🔧 Removing finalizers from namespace..."
    kubectl patch namespace "$NAMESPACE" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    
    # Wait a bit and check again
    sleep 5
    status=$(check_namespace_status)
    if [ "$status" = "NotFound" ]; then
        echo "    ✅ Namespace successfully force-deleted using finalizer removal"
        return 0
    fi
    
    # Method 2: Use kubectl API proxy to force delete
    echo "    🔧 Attempting API-based force deletion..."
    (
        kubectl proxy --port=8080 >/dev/null 2>&1 &
        PROXY_PID=$!
        sleep 2
        
        # Get namespace with finalizers and remove them
        kubectl get namespace "$NAMESPACE" -o json | \
        jq '.spec.finalizers = []' | \
        curl -k -H "Content-Type: application/json" -X PUT --data-binary @- \
             "http://127.0.0.1:8080/api/v1/namespaces/$NAMESPACE/finalize" >/dev/null 2>&1 || true
        
        kill $PROXY_PID 2>/dev/null || true
    ) &
    
    # Wait and check final status
    sleep 10
    status=$(check_namespace_status)
    if [ "$status" = "NotFound" ]; then
        echo "    ✅ Namespace successfully force-deleted using API method"
        return 0
    else
        echo "    ❌ Force deletion failed. Manual intervention may be required."
        echo "    💡 Try: kubectl get namespace $NAMESPACE -o yaml"
        echo "    💡 Then manually edit/remove finalizers if needed"
        return 1
    fi
}

# Check if namespace exists
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "  - Initiating namespace deletion..."
    kubectl delete namespace "$NAMESPACE" --timeout=60s || true
    
    # Monitor deletion progress
    echo "  - Monitoring namespace deletion..."
    timeout=180  # 3 minutes timeout
    elapsed=0
    check_interval=5
    
    while [ $elapsed -lt $timeout ]; do
        status=$(check_namespace_status)
        
        case "$status" in
            "NotFound")
                echo "    ✅ Namespace successfully deleted"
                break
                ;;
            "Terminating")
                echo "    ⏳ Namespace terminating... ($elapsed/$timeout seconds)"
                if [ $elapsed -ge 60 ]; then  # If stuck for more than 1 minute
                    force_delete_namespace
                    break
                fi
                ;;
            "Active")
                echo "    ⚠️  Namespace still active, continuing to wait..."
                ;;
            *)
                echo "    ⚠️  Namespace in unknown state: $status"
                ;;
        esac
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    # Final check
    final_status=$(check_namespace_status)
    if [ "$final_status" != "NotFound" ]; then
        echo "    ❌ Namespace deletion timeout reached"
        echo "    📊 Final namespace status: $final_status"
        echo "    💡 You may need to manually investigate stuck resources:"
        echo "       kubectl get namespace $NAMESPACE -o yaml"
        echo "       kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n $NAMESPACE"
    fi
else
    echo "    ℹ️  Namespace $NAMESPACE does not exist"
fi

echo ""
echo "================================================================================"
echo "🎉 CLEANUP COMPLETED SUCCESSFULLY!"
echo "================================================================================"
echo ""
echo "📋 Summary of what was cleaned up:"
echo "  • Helm releases: nch-haproxy, nch-services, nch-data, nch-prereq"
echo "  • All Persistent Volume Claims"
echo "  • MongoDB authentication secrets"
echo "  • Pre-install hook jobs"
echo "  • Custom ConfigMaps"
echo "  • MongoDB Custom Resource Definitions (CRDs)"
echo "  • Nirmata PriorityClasses (cluster-scoped resources)"
echo "  • Namespace: $NAMESPACE (with force deletion if needed)"
echo ""
echo "🚀 Ready to redeploy from scratch:"
echo ""
echo "🎯 Recommended (Modern Interface):"
echo "  make deploy-$ENVIRONMENT              # Complete deployment"
echo "  make deploy ENV=$ENVIRONMENT          # Alternative syntax"
echo ""
echo "🔧 Step-by-step (Individual Steps):"
echo "  make deploy-step1 ENV=$ENVIRONMENT    # Prerequisites"
echo "  make deploy-step2 ENV=$ENVIRONMENT    # Data Services"
echo "  make deploy-step3 ENV=$ENVIRONMENT    # Application Services"
echo "  make deploy-step4 ENV=$ENVIRONMENT    # Load Balancer"
echo "  make deploy-step5 ENV=$ENVIRONMENT    # Configuration"
echo ""
echo "📜 Traditional (Backward Compatible):"
echo "  ./deploy-all.sh $ENVIRONMENT          # Complete deployment"
echo ""
echo "💡 For help: make help or ./deploy-all.sh --help"
echo ""
echo "✅ The namespace has been deleted and will be automatically recreated during deployment." 