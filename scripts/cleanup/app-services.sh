#!/bin/bash
# Cleanup Script for Step 3: Application Services Only
# This script removes only the Step 3 deployment (nch-services) while keeping 
# infrastructure components (MongoDB, Kafka, Users, Security) intact

set -e

NAMESPACE="nch-pe"

echo "🧹 Starting Step 3 cleanup (Application Services only)..."
echo "Namespace: $NAMESPACE"
echo ""
echo "ℹ️  This will keep infrastructure components running:"
echo "   ✅ MongoDB & Kafka (Step 2)"  
echo "   ✅ Prerequisites & CRDs (Step 1)"
echo ""

# Function to check if resource exists
resource_exists() {
    kubectl get "$1" "$2" -n "$NAMESPACE" >/dev/null 2>&1
}

# 1. Uninstall Step 3 Helm release only
echo "📦 Uninstalling Step 3 Helm release..."

if helm list -n $NAMESPACE | grep -q "nch-services"; then
  echo "  - Uninstalling nch-services (All Nirmata Services)..."
  helm uninstall nch-services -n $NAMESPACE
  echo "    ✅ nch-services uninstalled"
else
  echo "    ℹ️  nch-services not found (Step 3 not deployed)"
fi

# Also clean up legacy releases
if helm list -n $NAMESPACE | grep -q "nch-apps"; then
  echo "  - Uninstalling legacy nch-apps (Application Services)..."
  helm uninstall nch-apps -n $NAMESPACE
  echo "    ✅ nch-apps uninstalled"
fi

if helm list -n $NAMESPACE | grep -q "nch-users"; then
  echo "  - Uninstalling legacy nch-users (Users & Security)..."
  helm uninstall nch-users -n $NAMESPACE
  echo "    ✅ nch-users uninstalled"
fi

echo ""

# 2. Clean up Step 3 PodDisruptionBudgets FIRST (prevents "already exists" errors)
echo "🛡️  Cleaning up Step 3 PodDisruptionBudgets..."
STEP3_PDBS=(
    "activity-pdb"
    "client-gateway-pdb"
    "cluster-pdb"
    "cluster-processor-pdb"
    "gateway-service-pdb"
    "policies-pdb"
    "policies-processor-pdb"
    "policies-event-processor-pdb"
    "policy-studio-pdb"
    "tunnel-pdb"
    "webclient-pdb"
)

for pdb in "${STEP3_PDBS[@]}"; do
    if resource_exists poddisruptionbudget "$pdb"; then
        echo "  - Deleting PodDisruptionBudget: $pdb"
        kubectl delete poddisruptionbudget "$pdb" -n $NAMESPACE
    else
        echo "    ℹ️  PodDisruptionBudget $pdb not found"
    fi
done
echo "    ✅ Step 3 PodDisruptionBudgets cleanup completed"
echo ""

# 3. Wait for Step 3 pods to terminate
echo "⏳ Waiting for Step 3 pods to terminate..."
timeout=120
elapsed=0

# List of Step 3 application services
STEP3_SERVICES=(
    "activity"
    "client-gateway" 
    "cluster"
    "gateway-service"
    "llm-apps"
    "policies"
    "policies-processor"
    "cluster-processor"
    "tunnel"
    "webclient"
)

# Wait for Step 3 pods to terminate
while true; do
    step3_pods_remaining=false
    
    for service in "${STEP3_SERVICES[@]}"; do
        if kubectl get pods -n $NAMESPACE -l "nirmata.io/service.name=$service" --no-headers 2>/dev/null | grep -v "Terminating" | grep -q .; then
            step3_pods_remaining=true
            break
        fi
    done
    
    if ! $step3_pods_remaining; then
        break
    fi
    
    if [ $elapsed -ge $timeout ]; then
        echo "    ⚠️  Timeout waiting for Step 3 pods to terminate. Continuing..."
        break
    fi
    
    echo "    Waiting for Step 3 pods to terminate... ($elapsed/$timeout seconds)"
    sleep 5
    elapsed=$((elapsed + 5))
done

echo "    ✅ Step 3 pods terminated"
echo ""

# 4. Clean up Step 3 Services
echo "🔗 Cleaning up Step 3 Services..."
STEP3_SERVICES_NAMES=(
    "activity"
    "catalog"
    "client-gateway"
    "cluster"
    "cluster-processor"
    "config"
    "gateway"
    "llm-apps"
    "policies"
    "policy-studio"
    "tunnel"
    "tunnel-wss"
    "webclient"
)

for svc in "${STEP3_SERVICES_NAMES[@]}"; do
    if resource_exists service "$svc"; then
        echo "  - Deleting Service: $svc"
        kubectl delete service "$svc" -n $NAMESPACE
    else
        echo "    ℹ️  Service $svc not found"
    fi
done
echo "    ✅ Step 3 Services cleanup completed"
echo ""

# 5. Clean up Step 3 specific PVCs (if any)
echo "💾 Cleaning up Step 3 Persistent Volume Claims..."
STEP3_PVCs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep -E "(tunnel|webclient|activity|policies)" | awk '{print $1}' || true)

if [ -n "$STEP3_PVCs" ]; then
    for pvc in $STEP3_PVCs; do
        echo "  - Deleting Step 3 PVC: $pvc"
        kubectl delete pvc "$pvc" -n $NAMESPACE
    done
    echo "    ✅ Step 3 PVCs deleted"
else
    echo "    ℹ️  No Step 3 PVCs found"
fi
echo ""

# 6. Clean up Step 3 ServiceAccounts
echo "👤 Cleaning up Step 3 ServiceAccounts..."
STEP3_SERVICEACCOUNTS=(
    "activity"
    "clientgateway"
    "cluster"
    "cluster-processor"
    "gateway-service"
    "llm-apps"
    "policies"
    "policies-event-processor"
    "policies-processor"
    "policy-rag"
    "policy-studio"
    "tunnel"
    "webclient"
)

for sa in "${STEP3_SERVICEACCOUNTS[@]}"; do
    if resource_exists serviceaccount "$sa"; then
        echo "  - Deleting ServiceAccount: $sa"
        kubectl delete serviceaccount "$sa" -n $NAMESPACE
    else
        echo "    ℹ️  ServiceAccount $sa not found"
    fi
done
echo "    ✅ Step 3 ServiceAccounts cleanup completed"
echo ""

# 7. Clean up Step 3 RoleBindings
echo "🔑 Cleaning up Step 3 RoleBindings..."
STEP3_ROLEBINDINGS=(
    "rb-activity"
    "rb-clientgateway"
    "rb-cluster"
    "rb-policies"
    "rb-tunnel"
    "rb-webclient"
)

for rb in "${STEP3_ROLEBINDINGS[@]}"; do
    if resource_exists rolebinding "$rb"; then
        echo "  - Deleting RoleBinding: $rb"
        kubectl delete rolebinding "$rb" -n $NAMESPACE
    else
        echo "    ℹ️  RoleBinding $rb not found"
    fi
done
echo "    ✅ Step 3 RoleBindings cleanup completed"
echo ""

# 8. Clean up Step 3 specific secrets (if any)
echo "🔐 Cleaning up Step 3 specific secrets..."
STEP3_SECRETS=$(kubectl get secrets -n $NAMESPACE --no-headers 2>/dev/null | grep -E "(tunnel|webclient|activity|policies|gateway)" | awk '{print $1}' || true)

if [ -n "$STEP3_SECRETS" ]; then
    for secret in $STEP3_SECRETS; do
        echo "  - Deleting Step 3 secret: $secret"
        kubectl delete secret "$secret" -n $NAMESPACE
    done
    echo "    ✅ Step 3 secrets deleted"
else
    echo "    ℹ️  No Step 3 specific secrets found"
fi
echo ""

# 9. Clean up Step 3 jobs (pre-install hooks)
echo "🏃 Cleaning up Step 3 jobs..."
STEP3_JOBS=$(kubectl get jobs -n $NAMESPACE --no-headers 2>/dev/null | grep -E "(prereq-check)" | awk '{print $1}' || true)

if [ -n "$STEP3_JOBS" ]; then
    for job in $STEP3_JOBS; do
        echo "  - Deleting Step 3 job: $job"
        kubectl delete job "$job" -n $NAMESPACE
    done
    echo "    ✅ Step 3 jobs deleted"
else
    echo "    ℹ️  No Step 3 jobs found"
fi
echo ""

# 10. Clean up any remaining Step 3 resources (catch-all)
echo "🔍 Cleaning up any remaining Step 3 resources..."

# Clean up any remaining resources with nch-services labels
echo "  - Checking for resources with nch-services labels..."
kubectl delete all -l "app.kubernetes.io/instance=nch-services" -n $NAMESPACE --ignore-not-found=true
kubectl delete configmap -l "app.kubernetes.io/instance=nch-services" -n $NAMESPACE --ignore-not-found=true
kubectl delete secret -l "app.kubernetes.io/instance=nch-services" -n $NAMESPACE --ignore-not-found=true

# Also clean up legacy nch-apps and nch-users labels
echo "  - Checking for legacy resources with nch-apps/nch-users labels..."
kubectl delete all -l "app.kubernetes.io/instance=nch-apps" -n $NAMESPACE --ignore-not-found=true
kubectl delete all -l "app.kubernetes.io/instance=nch-users" -n $NAMESPACE --ignore-not-found=true

echo "    ✅ Remaining Step 3 resources cleanup completed"
echo ""

# 11. Verify Step 3 cleanup and show remaining infrastructure
echo "🔍 Verifying Step 3 cleanup..."

# Check if any Step 3 pods remain
step3_pods_count=0
for service in "${STEP3_SERVICES[@]}"; do
    count=$(kubectl get pods -n $NAMESPACE -l "nirmata.io/service.name=$service" --no-headers 2>/dev/null | wc -l)
    step3_pods_count=$((step3_pods_count + count))
done

if [ "$step3_pods_count" -eq 0 ]; then
    echo "    ✅ Step 3 cleanup successful - no application service pods remaining"
else
    echo "    ⚠️  Warning: $step3_pods_count Step 3 pods may still exist"
fi

echo ""
echo "📊 Remaining infrastructure components:"
kubectl get pods -n $NAMESPACE -o wide 2>/dev/null | grep -E "(kafka|mongodb|users|security)" || echo "    No infrastructure pods found"

echo ""
echo "🎉 Step 3 cleanup completed!"
echo ""
echo "📋 Summary of what was cleaned up:"
echo "  • Helm release: nch-services (All Nirmata Services)"
echo "  • PodDisruptionBudgets (cluster-pdb, policies-pdb, etc.) ← FIXED!"
echo "  • Services (gateway, tunnel, webclient, etc.)"
echo "  • ServiceAccounts and RoleBindings"
echo "  • Step 3 application pods (activity, policies, webclient, etc.)"
echo "  • Step 3 specific PVCs and secrets"
echo "  • Step 3 pre-install hook jobs"
echo "  • Any remaining resources with nch-services/nch-apps/nch-users labels"
echo ""
echo "📋 What remains intact:"
echo "  • MongoDB & Kafka (Step 2)"  
echo "  • Prerequisites & CRDs (Step 1)"
echo ""
echo "🚀 To redeploy Step 3:"
echo "  ./deploy-step3-nirmata-services.sh"
echo ""
echo "🧹 To cleanup everything:"
echo "  ./cleanup-all.sh" 