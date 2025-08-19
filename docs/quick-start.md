# 🚀 Nirmata Quick Start Guide

> **Get Nirmata running on Kubernetes in 5 minutes**

This guide gets you from zero to a fully deployed Nirmata platform as quickly as possible. For detailed explanations, see the [Deployment Guide](deployment-guide.md).

## ⚡ Prerequisites Check (2 minutes)

Run these commands to verify your environment is ready:

```bash
# 1. Verify Kubernetes connection
kubectl cluster-info
# Should show cluster endpoints

# 2. Check Helm installation
helm version
# Should show v3.x

# 3. Verify cluster resources
kubectl get nodes
# Should show 3+ nodes with Ready status

# 4. Check for required storage class
kubectl get storageclass
# Should show at least one storage class
```

**Minimum Requirements:**
- ✅ Kubernetes v1.23-v1.26
- ✅ Helm v3.x
- ✅ 3+ nodes, 8+ vCPUs, 16+ GB RAM per node
- ✅ Dynamic storage provisioning

## 🎯 Method 1: One-Command Deployment (2 minutes)

**Fastest way - deploy everything at once:**

```bash
# Clone the repository
git clone https://github.com/nirmata/nirmata-charts.git
cd nirmata-charts

# Modern interface (recommended)
make deploy-dev

# Or using direct scripts
scripts/deploy dev

# Production environment
make deploy-prod
# or: scripts/deploy prod

# Legacy backward compatibility
./deploy-all.sh dev
```

**⏱️ Expected time:** 8-12 minutes for complete deployment

## 🎯 Method 2: Step-by-Step Deployment (3 minutes)

**For better visibility and control:**

```bash
# Clone the repository
git clone https://github.com/nirmata/nirmata-charts.git
cd nirmata-charts

# Using Makefile (recommended)
make deploy-step1 ENV=dev    # Prerequisites (CRDs, ConfigMaps, Secrets)
make deploy-step2 ENV=dev    # Data Services (MongoDB, Kafka) 
make deploy-step3 ENV=dev    # Application Services (All Nirmata microservices)
make deploy-step4 ENV=dev    # Load Balancer (HAProxy)
make deploy-step5 ENV=dev    # Configuration (License & Tenant)

# Or using direct scripts
scripts/deployment/steps/01-prerequisites.sh dev
scripts/deployment/steps/02-data-services.sh dev
scripts/deployment/steps/03-app-services.sh dev
scripts/deployment/steps/04-load-balancer.sh dev
scripts/deployment/steps/05-configuration.sh dev
```

**⏱️ Expected time:** 2-3 minutes per step

## 🔍 Verify Deployment (1 minute)

Check that everything is running:

```bash
# Check all pods are running
kubectl get pods -n nch-dev1

# Verify all services
kubectl get svc -n nch-dev1

# Check Helm releases
helm list -n nch-dev1

# Look for HAProxy external access
kubectl get svc haproxy -n nch-dev1
```

**✅ Success indicators:**
- All pods show `Running` or `Completed` status
- HAProxy service has an external IP or NodePort
- 4-5 Helm releases are deployed

## 🌐 Access Your Nirmata Platform

### Development Access (Port Forward)

```bash
# Forward HAProxy port for local access
kubectl port-forward svc/haproxy 8443:8443 -n nch-dev1

# Then access in browser: https://localhost:8443
```

### Production Access (External)

```bash
# Get HAProxy service details for external access
kubectl get svc haproxy -n nch-dev1

# If using LoadBalancer, look for EXTERNAL-IP
# If using NodePort, use any node IP + node port
```

### Login Credentials

Default development credentials (configured in `config/values/environments/dev.yaml`):
- **URL**: `https://localhost:8443` (development) or `https://your-domain.com` (production)
- **Email**: `damien@nirmata.com` 
- **Password**: `Nirmata2013`
- **Company**: `Nirmata Platform`

## 🛠️ Quick Customization

### Change Environment
```bash
# Development (default)
make deploy-dev
# or: scripts/deploy dev

# Production  
make deploy-prod
# or: scripts/deploy prod
```

### Configuration Files
```bash
# Edit configuration before deployment
vim config/values/environments/dev.yaml     # Development settings
vim config/values/environments/prod.yaml    # Production settings
vim config/values/base.yaml                 # Common settings
```

### Deploy Individual Steps
```bash
# Deploy only specific steps using Makefile
make deploy-step1 ENV=dev    # Prerequisites only
make deploy-step2 ENV=dev    # Data services only
make deploy-step3 ENV=dev    # Application services only

# Or use direct scripts
scripts/deployment/steps/01-prerequisites.sh dev
scripts/deployment/steps/02-data-services.sh dev
```

## 🆘 Quick Troubleshooting

### Pods Not Starting
```bash
# Check pod details
kubectl describe pods -n nch-dev1

# Check recent events
kubectl get events -n nch-dev1 --sort-by='.lastTimestamp'

# Use monitoring tool
make monitor-health ENV=dev
```

### Services Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n nch-dev1

# Verify HAProxy configuration
kubectl logs -l nirmata.io/service.name=haproxy -n nch-dev1
```

### Stuck Resources
```bash
# Force cleanup and redeploy (modern)
make cleanup-dev
make deploy-dev

# Or using scripts
scripts/clean dev
scripts/deploy dev
```

## 🧹 Clean Up

Remove everything when done:

```bash
# Modern interface (recommended)
make cleanup-dev

# Or using direct scripts
scripts/clean dev

# Legacy backward compatibility
./cleanup-all.sh dev

# The cleanup script handles:
# - Helm release removal
# - Persistent volume cleanup  
# - Secret removal
# - Namespace deletion (with force handling)
```

## 📚 Next Steps

Once Nirmata is running:

1. **Platform Access**: License and tenant are auto-configured, just login with the credentials above
2. **Explore Features**: Create policies, deploy applications, set up compliance
3. **Production Setup**: Review [Configuration Guide](configuration.md) for production settings
4. **Troubleshooting**: See [Troubleshooting Guide](troubleshooting.md) for common issues
5. **Architecture**: Read [Architecture Guide](architecture.md) to understand the system design

## 💡 Pro Tips

- **Use development environment** (`dev`) for testing and learning
- **Monitor deployment** with `watch kubectl get pods -n nch-dev1`
- **Use modern commands**: `make help` to see all available options
- **Check logs** if issues occur: `kubectl logs <pod-name> -n nch-dev1`
- **Production deployments** should use `prod` environment with custom values
- **Backup your configuration files** in `config/` before making changes

---

> **🎉 Congratulations!** You now have a fully functional Nirmata platform. Visit your platform URL to start managing Kubernetes security and compliance!

**Need detailed explanations?** → [Deployment Guide](DEPLOYMENT-GUIDE.md)  
**Having issues?** → [Troubleshooting Guide](TROUBLESHOOTING.md)  
**Want to customize?** → [Configuration Guide](CONFIGURATION.md) 