# 🛠️ Nirmata Troubleshooting Guide

> **Common issues and solutions for Nirmata Helm Charts deployment**

This guide covers the most frequent problems encountered during Nirmata deployment and their solutions. For quick deployment, see [Quick Start Guide](quick-start.md).

## 🚨 Emergency Recovery

### Complete System Reset
```bash
# Nuclear option - clean everything and start fresh (modern)
make cleanup-dev
kubectl delete namespace nch-dev1 --force --grace-period=0
make deploy-dev

# Or using direct scripts
scripts/clean dev
kubectl delete namespace nch-dev1 --force --grace-period=0
scripts/deploy dev
```

### Check System Health
```bash
# Quick health check (adjust namespace as needed)
kubectl get pods -n nch-dev1
kubectl get svc -n nch-dev1
helm list -n nch-dev1

# Monitor with dedicated tools
make monitor-health ENV=dev
```

## 📦 Deployment Issues

### 1. Helm Release Already Exists
**Problem**: `Error: release "nch-services" failed, and has been uninstalled due to atomic being set: deployments.apps "cluster" already exists`

**Solution**:
```bash
# Check for leftover resources
kubectl get all -n nch-dev1
kubectl get pvc -n nch-dev1

# Clean up specific release (modern approach)
helm uninstall nch-services -n nch-dev1
kubectl delete deployment cluster -n nch-dev1 --ignore-not-found

# Clean up only application services
make cleanup-step3 ENV=dev

# Or complete cleanup
make cleanup-dev
# Alternative: scripts/clean dev
```

### 2. Namespace Stuck in Terminating
**Problem**: Namespace stuck in `Terminating` state for >5 minutes

**Solution** (automated in modern cleanup script):
```bash
# Method 1: Remove finalizers
kubectl patch namespace nch-dev1 -p '{"metadata":{"finalizers":null}}' --type=merge

# Method 2: Use the enhanced cleanup script (modern)
make cleanup-dev  # Handles force deletion automatically
# Alternative: scripts/clean dev

# Method 3: Manual API call (for stuck namespaces)
kubectl proxy --port=8080 &
PROXY_PID=$!
kubectl get namespace nch-dev1 -o json | \
  jq '.spec.finalizers = []' | \
  curl -k -H "Content-Type: application/json" -X PUT --data-binary @- \
       "http://127.0.0.1:8080/api/v1/namespaces/nch-dev1/finalize"
kill $PROXY_PID
```

### 3. Image Pull Errors
**Problem**: `ImagePullBackOff` or `ErrImagePull`

**Solution**:
```bash
# Check image pull secret (adjust namespace as needed)
kubectl get secret amazon-ecr -n nch-dev1
kubectl describe secret amazon-ecr -n nch-dev1

# Recreate ECR token (expires every 12 hours)
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin 844333597536.dkr.ecr.us-west-1.amazonaws.com

# Update secret
kubectl delete secret amazon-ecr -n nch-dev1 --ignore-not-found
kubectl create secret docker-registry amazon-ecr \
  --docker-server=844333597536.dkr.ecr.us-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-west-1) \
  -n nch-dev1

# Check pod logs
kubectl describe pod <pod-name> -n nch-dev1
```

### 4. Timeout During Deployment
**Problem**: `timeout waiting for condition`

**Solution**:
```bash
# Check cluster resources
kubectl top nodes
kubectl get pods --all-namespaces | grep -v Running

# Retry specific step with modern commands
make deploy-step3 ENV=dev
# Or using direct scripts:
scripts/deployment/steps/03-app-services.sh dev

# Check for resource constraints
kubectl describe nodes
kubectl get events --sort-by='.lastTimestamp' -n nch-dev1
```

## 🗄️ Database Issues

### 5. MongoDB Connection Failures
**Problem**: Services can't connect to MongoDB

**Diagnosis**:
```bash
# Check MongoDB pod status (adjust namespace as needed)
kubectl get pods -n nch-dev1 | grep mongodb

# Check MongoDB logs
kubectl logs mongodb-0 -n nch-dev1

# Verify MongoDB service
kubectl get svc mongodb-hs -n nch-dev1
kubectl get endpoints mongodb-hs -n nch-dev1

# Test connection from another pod
kubectl run test-mongo --rm -i --tty --image=mongo --namespace=nch-dev1 -- \
  mongosh mongodb-hs.nch-dev1.svc.cluster.local:27017/admin
```

**Solutions**:
```bash
# Check credentials secret
kubectl get secret mongo-credentials -n nch-dev1 -o yaml

# Verify MongoDB is ready
kubectl wait --for=condition=ready pod/mongodb-0 -n nch-dev1 --timeout=300s

# Restart MongoDB if needed
kubectl delete pod mongodb-0 -n nch-dev1
```

### 6. Missing MongoDB Credentials
**Problem**: `mongo-credentials` secret not found

**Solution**:
```bash
# Check if secret exists
kubectl get secret mongo-credentials -n nch-dev1

# Force recreation via Step 2 (modern approach)
make deploy-step2 ENV=dev
# Alternative: scripts/deployment/steps/02-data-services.sh dev

# Manual secret creation (if automated fails)
kubectl create secret generic mongo-credentials \
  --from-literal=username=admin \
  --from-literal=password=MongoDBTest123 \
  --from-literal=authdb=admin \
  -n nch-dev1

# Database operations helper
make db-operations ENV=dev
```

## 🔐 Security & Access Issues

### 7. TLS Certificate Problems
**Problem**: SSL/TLS connection errors

**Diagnosis**:
```bash
# Check certificate secret (adjust namespace as needed)
kubectl get secret helm-secret -n nch-dev1 -o yaml

# Verify certificate validity
kubectl get secret helm-secret -n nch-dev1 -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Check HAProxy TLS configuration
kubectl logs -l app=haproxy -n nch-dev1 | grep -i tls
```

**Solutions**:
```bash
# Update certificate in values file
# Edit config/values/environments/dev.yaml or config/values/environments/prod.yaml:
# global.security.tls.enabled: true
# (TLS certificates are managed via Kubernetes secrets - see deployment guide)

# Redeploy with new certificate (modern approach)
make deploy-step1 ENV=dev
# Alternative: scripts/deployment/steps/01-prerequisites.sh dev
```

### 8. HAProxy Not Accessible
**Problem**: Cannot access Nirmata platform via HAProxy

**Diagnosis**:
```bash
# Check HAProxy service
kubectl get svc haproxy -n nch-dev1
kubectl describe svc haproxy -n nch-dev1

# Check HAProxy pods
kubectl get pods -l app=haproxy -n nch-dev1
kubectl logs -l app=haproxy -n nch-dev1

# Test internal connectivity
kubectl run test-haproxy --rm -i --tty --image=curlimages/curl --namespace=nch-dev1 -- \
  curl -k https://haproxy.nch-dev1.svc.cluster.local
```

**Solutions**:
```bash
# Check service type
kubectl patch svc haproxy -n nch-dev1 -p '{"spec": {"type": "LoadBalancer"}}'

# For NodePort access
kubectl get svc haproxy -n nch-dev1 -o jsonpath='{.spec.ports[0].nodePort}'
kubectl get nodes -o wide

# Check load balancer provisioning
kubectl describe svc haproxy -n nch-dev1

# Port forward for testing
kubectl port-forward svc/haproxy 8443:443 -n nch-dev1
```

## 🔧 Pod Issues

### 9. Pods Stuck in Pending
**Problem**: Pods remain in `Pending` state

**Diagnosis**:
```bash
# Check pod events (adjust namespace as needed)
kubectl describe pod <pod-name> -n nch-dev1

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check PVC binding
kubectl get pvc -n nch-dev1
kubectl describe pvc <pvc-name> -n nch-dev1
```

**Solutions**:
```bash
# Resource constraints
kubectl get limitranges -n nch-dev1
kubectl get resourcequotas -n nch-dev1

# Storage issues
kubectl get storageclass
kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Node selector issues
kubectl label nodes <node-name> nirmata=true
```

### 10. Pods CrashLoopBackOff
**Problem**: Pods keep restarting

**Diagnosis**:
```bash
# Check pod logs (adjust namespace as needed)
kubectl logs <pod-name> -n nch-dev1 --previous
kubectl logs <pod-name> -n nch-dev1 --tail=50

# Check resource limits
kubectl describe pod <pod-name> -n nch-dev1

# Check liveness/readiness probes
kubectl get pod <pod-name> -n nch-dev1 -o yaml | grep -A 5 -B 5 probe
```

**Solutions**:
```bash
# Increase resource limits in values file
# Edit config/values/environments/dev.yaml:
# global.resources.defaults.limits.memory: "2Gi"

# Disable probes temporarily
kubectl patch deployment <deployment-name> -n nch-dev1 --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","livenessProbe":null,"readinessProbe":null}]}}}}'

# Check for missing dependencies
kubectl get pods -n nch-dev1 | grep -v Running
```

## 🌐 Network Issues

### 11. Service Discovery Problems
**Problem**: Services can't find each other

**Diagnosis**:
```bash
# Check DNS resolution (adjust namespace as needed)
kubectl run test-dns --rm -i --tty --image=busybox --namespace=nch-dev1 -- nslookup mongodb-hs.nch-dev1.svc.cluster.local

# Check service endpoints
kubectl get endpoints -n nch-dev1

# Test connectivity
kubectl run test-connectivity --rm -i --tty --image=curlimages/curl --namespace=nch-dev1 -- \
  curl -v http://activity.nch-dev1.svc.cluster.local:8080/health
```

**Solutions**:
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Restart networking
kubectl delete pod -l k8s-app=kube-dns -n kube-system
kubectl rollout restart daemonset -n kube-system
```

## 📊 Performance Issues

### 12. Slow Deployment Times
**Problem**: Deployment takes >20 minutes

**Solutions**:
```bash
# Use modern deployment commands (optimized for speed)
make deploy-dev      # Parallel operations, optimized timeouts
# Alternative: scripts/deploy dev

# Check cluster performance
kubectl top nodes
kubectl top pods -n nch-dev1

# Pre-pull images (adjust namespace as needed)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-puller
  namespace: nch-dev1
spec:
  selector:
    matchLabels:
      app: image-puller
  template:
    metadata:
      labels:
        app: image-puller
    spec:
      containers:
      - name: puller
        image: 844333597536.dkr.ecr.us-west-1.amazonaws.com/nirmata/cluster:4.24.0-rc1
        command: ["sleep", "3600"]
      imagePullSecrets:
      - name: amazon-ecr
EOF

# Monitor deployment progress
make monitor-health ENV=dev
```

## 🔍 Debugging Commands

### Essential Debugging Toolkit
```bash
# Get overview (adjust namespace as needed)
kubectl get all -n nch-dev1
kubectl get pvc -n nch-dev1
kubectl get secrets -n nch-dev1
kubectl get configmaps -n nch-dev1

# Check events
kubectl get events -n nch-dev1 --sort-by='.lastTimestamp' | tail -20

# Pod debugging
kubectl describe pod <pod-name> -n nch-dev1
kubectl logs <pod-name> -n nch-dev1 --tail=100
kubectl exec -it <pod-name> -n nch-dev1 -- /bin/bash

# Service debugging  
kubectl get endpoints -n nch-dev1
kubectl describe svc <service-name> -n nch-dev1

# Storage debugging
kubectl get pv
kubectl describe pvc <pvc-name> -n nch-dev1

# Resource usage
kubectl top nodes
kubectl top pods -n nch-dev1

# Modern monitoring tools
make monitor-health ENV=dev
```

### Advanced Debugging
```bash
# Network debugging
kubectl run netshoot --rm -i --tty --image=nicolaka/netshoot --namespace=nch-dev1 -- /bin/bash

# Database debugging (modern MongoDB shell)
kubectl exec -it mongodb-0 -n nch-dev1 -- mongosh admin --eval "db.runCommand('ismaster')"

# Database operations tool
make db-operations ENV=dev

# Certificate debugging
kubectl get secret helm-secret -n nch-dev1 -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -dates -noout
```

## 📞 Getting Help

### Before Contacting Support
1. **Run diagnostics**:
   ```bash
   kubectl get pods -n nch-dev1 -o wide
   kubectl get events -n nch-dev1 --sort-by='.lastTimestamp' | tail -20
   helm list -n nch-dev1
   ```

2. **Collect logs**:
   ```bash
   # Save all pod logs (adjust namespace as needed)
   for pod in $(kubectl get pods -n nch-dev1 -o name); do
     echo "=== $pod ===" >> /tmp/nirmata-logs.txt
     kubectl logs $pod -n nch-dev1 >> /tmp/nirmata-logs.txt 2>&1
   done
   ```

3. **Check configuration**:
   ```bash
   helm get values nch-services -n nch-dev1 > /tmp/nirmata-config.yaml
   
   # Or check merged configuration
   cat config/values/base.yaml config/values/environments/dev.yaml > /tmp/nirmata-config.yaml
   ```

### Useful Information for Support
- Kubernetes version: `kubectl version --short`
- Helm version: `helm version --short`  
- Cloud provider and region
- Values files used (from `config/values/` directory)
- Error messages and timestamps
- Steps that led to the issue

### Modern Tools Summary
```bash
# Quick deployment diagnostics
make monitor-health ENV=dev      # Monitor deployment health
make configure-features ENV=dev  # Configure feature flags
make db-operations ENV=dev       # Database operations

# Complete deployment workflow
make deploy-dev                  # Full development deployment
make cleanup-dev                 # Complete cleanup

# Individual steps
make deploy-step1 ENV=dev        # Prerequisites only
make deploy-step2 ENV=dev        # Data services only
make deploy-step3 ENV=dev        # Application services only
make deploy-step4 ENV=dev        # Load balancer only
make deploy-step5 ENV=dev        # Configuration only
```

---

## 📚 Related Documentation

- **[Quick Start Guide](quick-start.md)** - Get started quickly
- **[Deployment Guide](deployment-guide.md)** - Detailed deployment instructions  
- **[Configuration Guide](configuration.md)** - Configuration options
- **[Architecture Guide](architecture.md)** - System architecture

> **💡 Prevention Tip**: Most issues can be avoided by following the [Quick Start Guide](quick-start.md) exactly and ensuring all prerequisites are met before deployment.

**Still stuck?** → [Architecture Guide](architecture.md) | [Configuration Guide](configuration.md) 