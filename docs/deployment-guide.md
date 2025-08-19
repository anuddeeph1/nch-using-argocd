# Nirmata SaaS Deployment Guide

## Overview

This comprehensive guide provides detailed steps to deploy the Nirmata SaaS platform using the modern 5-step deployment system with all current fixes and optimizations applied.

### Prerequisites

- Kubernetes cluster (v1.23-v1.26) with kubectl access
- Helm 3.x installed
- Container registry access configured
- **Environments**: 
  - Development: `nch-dev1` namespace
  - Production: `nch-pe` namespace
- **Recommended cluster resources**: 5+ nodes, 8+ vCPUs, 16+ GB RAM per node

### Modern Deployment Options

Choose your preferred deployment method:

1. **Makefile Interface (Recommended)**: `make deploy-dev`
2. **Direct Scripts**: `scripts/deploy dev`
3. **Legacy Compatibility**: `./deploy-all.sh dev`

### Step-by-Step Deployment

The deployment follows a **5-step process** optimized for dependency management and resource allocation:

#### Step 1: Deploy Prerequisites (CRDs, ConfigMaps, Secrets)

```bash
# Using Makefile (recommended)
make deploy-step1 ENV=dev

# Or direct script
scripts/deployment/steps/01-prerequisites.sh dev

# Legacy compatibility
./deploy-step1-prereq.sh dev
```

**What this does:**
- Creates namespace (e.g., `nch-dev1` for dev environment)
- Installs MongoDB Community Operator CRDs
- Creates ConfigMaps (nirmata-config, haproxy-config, policy-studio-config)
- Sets up essential secrets and certificates
- Configures RBAC resources and priority classes

#### Step 2: Deploy Data Services (MongoDB, Kafka)

```bash
# Using Makefile (recommended)
make deploy-step2 ENV=dev

# Or direct script
scripts/deployment/steps/02-data-services.sh dev

# Legacy compatibility
./deploy-step2-mongodb-kafka.sh dev
```

**What this does:**
- Deploys MongoDB Community Operator
- Creates MongoDB cluster with authentication and encryption
- Deploys Kafka cluster for event streaming and messaging
- Configures MongoDB headless service (`mongodb-hs:27017`)
- Sets up database authentication secrets

#### Step 3: Deploy Application Services (All Nirmata Microservices)

```bash
# Using Makefile (recommended)
make deploy-step3 ENV=dev

# Or direct script
scripts/deployment/steps/03-app-services.sh dev

# Legacy compatibility  
./deploy-step3-nirmata-services.sh dev
```

**What this does:**
- Deploys all 11 Nirmata microservices:
  - users, security, activity, client-gateway
  - cluster, cluster-processor, policies, policies-processor, policies-event-processor
  - webclient, gateway-service, tunnel, llm-apps, policy-studio
- Configures inter-service communication
- Sets up service discovery and networking
- Configures database connections and authentication

#### Step 4: Deploy Load Balancer (HAProxy)

```bash
# Using Makefile (recommended)
make deploy-step4 ENV=dev

# Or direct script
scripts/deployment/steps/04-load-balancer.sh dev

# Legacy compatibility
./deploy-step4-haproxy.sh dev
```

**What this does:**
- Verifies all previous services are running
- Deploys HAProxy load balancer for external access
- Configures high-availability routing to all services
- Sets up SSL/TLS termination and health checks
- Enables production-ready external connectivity

#### Step 5: Platform Configuration (License & Tenant Setup)

```bash
# Using Makefile (recommended)
make deploy-step5 ENV=dev

# Or direct script
scripts/deployment/steps/05-configuration.sh dev

# Legacy compatibility
./deploy-step5-config.sh dev
```

**What this does:**
- Verifies platform connectivity and health
- Validates and activates Nirmata license via API
- Creates initial tenant and admin user account
- Configures company and organization settings
- Activates 20+ platform feature flags
- Completes end-to-end platform configuration

### Complete Automated Deployment

For a full automated deployment, choose your preferred method:

```bash
# Modern interface (recommended)
make deploy-dev    # Development environment
make deploy-prod   # Production environment

# Direct scripts
scripts/deploy dev   # Development environment
scripts/deploy prod  # Production environment

# Legacy compatibility
./deploy-all.sh dev   # Development environment
./deploy-all.sh prod  # Production environment
```

This runs all 5 steps in sequence with:
- Comprehensive error handling and validation
- Optimized step-only validation (85%+ time reduction)
- Service preservation on interruption (Step 3+)
- Automatic retry logic and troubleshooting guidance

### Verification

Check all services are running:

```bash
# Development environment
kubectl get pods -n nch-dev1

# Production environment  
kubectl get pods -n nch-pe

# Or use monitoring tools
make monitor-health ENV=dev
```

**Expected output after Step 5 (complete deployment):**
```
NAME                                          READY   STATUS    RESTARTS   AGE
activity-xxx                                  1/1     Running   0          5m
client-gateway-xxx                            1/1     Running   0          5m
cluster-xxx                                   1/1     Running   0          5m
cluster-processor-xxx                         1/1     Running   0          5m
gateway-service-xxx                           1/1     Running   0          5m
haproxy-xxx                                   1/1     Running   0          2m
kafka-0                                       1/1     Running   0          30m
kafka-controller-0                            1/1     Running   0          30m
llm-apps-xxx                                  1/1     Running   0          5m
mongodb-0                                     2/2     Running   0          25m
mongodb-kubernetes-operator-xxx               1/1     Running   0          30m
policies-xxx                                  1/1     Running   0          5m
policies-event-processor-xxx                  1/1     Running   0          5m
policies-processor-xxx                        1/1     Running   0          5m
security-xxx                                  1/1     Running   0          5m
tunnel-0                                      1/1     Running   0          5m
users-xxx                                     1/1     Running   0          5m
webclient-xxx                                 1/1     Running   0          5m
```

### Resource Requirements

**Step 2 & 3 require significant resources:**
- **CPU**: 8+ vCPUs per node recommended
- **Memory**: 16+ GB RAM per node recommended  
- **Storage**: SSD-backed persistent volumes with dynamic provisioning
- **Nodes**: 3+ nodes minimum, 5+ recommended for production
- **Network**: Load balancer support for external access

**If deployment fails due to resources:**
```bash
# Scale your cluster (example for EKS)
aws eks update-nodegroup-config \
  --cluster-name your-cluster \
  --nodegroup-name your-nodegroup \
  --scaling-config minSize=3,maxSize=10,desiredSize=5

# Check resource usage
kubectl top nodes
kubectl top pods -n nch-dev1
```

### Modern Features & Optimizations

1.  **5-Step Deployment**: Complete process including automated license and tenant configuration
2.  **Organized Structure**: Modern project layout with `config/`, `docs/`, `scripts/` directories
3.  **Multiple Interfaces**: Makefile commands, direct scripts, and legacy compatibility
4.  **Ultra-Fast Validation**: 85%+ validation time reduction with step-only validation
5.  **Service Preservation**: Smart cleanup that preserves services on interruption (Step 3+)
6.  **Automated Configuration**: API-driven license validation and tenant setup (Step 5)
7.  **Feature Flag Activation**: 20+ platform features automatically enabled
8.  **Enhanced Error Handling**: Comprehensive troubleshooting guidance and retry logic
9.  **MongoDB Authentication**: Proper authentication with `mongodb-hs:27017` headless service
10. **Production Ready**: HAProxy load balancer with SSL/TLS and health checks
11. **Smart Cleanup**: Modern cleanup scripts with force namespace deletion handling

### Troubleshooting

#### Application Services Not Starting

1.  **Check resource availability:**
    ```bash
    kubectl top nodes
    kubectl describe nodes
    ```

2.  **Check pod events:**
    ```bash
    kubectl describe pod -n nch-dev1 <failing-pod-name>  # dev environment
    kubectl describe pod -n nch-pe <failing-pod-name>    # prod environment
    ```

3.  **Check application logs:**
    ```bash
    kubectl logs -l nirmata.io/service.name=<service-name> -n nch-dev1 --tail=50
    ```

4.  **Use monitoring tools:**
    ```bash
    make monitor-health ENV=dev
    ```

#### Insufficient Resources

If pods are pending due to insufficient resources:

1.  **Scale node group** (example for EKS)
2.  **Reduce resource requests** in `config/values/environments/dev.yaml` or `config/values/environments/prod.yaml`
3.  **Check current resource usage:**
    ```bash
    kubectl top pods -n nch-dev1
    kubectl describe nodes | grep -A5 "Allocated resources"
    ```

#### MongoDB Connection Issues

1.  Check MongoDB is running:
    ```bash
    kubectl get pods -n nch-dev1 -l name=mongodb-kubernetes-operator
    kubectl get pods -n nch-dev1 | grep mongodb
    ```

2.  Verify secrets exist:
    ```bash
    kubectl get secrets -n nch-dev1 | grep mongo
    ```

3.  Test MongoDB connectivity:
    ```bash
    kubectl exec mongodb-0 -n nch-dev1 -c mongod -- mongosh --username admin --password MongoDBTest123 --authenticationDatabase admin --eval "db.runCommand('ping')"
    ```

#### Services Not Starting After Step 3

If users or security services show authentication errors:

1.  Check users service logs:
    ```bash
    kubectl logs -l nirmata.io/service.name=users -n nch-dev1 --tail=50
    ```

2.  Check security service logs:
    ```bash
    kubectl logs -l nirmata.io/service.name=security -n nch-dev1 --tail=50
    ```

3.  Verify MongoDB connectivity and authentication secrets are properly configured

#### Step 5 Configuration Issues

If license validation or tenant setup fails:

1.  Check platform connectivity:
    ```bash
    # Test that the platform URL is accessible
    curl -k https://your-platform-url/users/health
    ```

2.  Verify API gateway is running:
    ```bash
    kubectl get pods -l nirmata.io/service.name=gateway-service -n nch-dev1
    kubectl logs -l nirmata.io/service.name=gateway-service -n nch-dev1
    ```

3.  Manually configure features if needed:
    ```bash
    make configure-features ENV=dev
    # or: scripts/tools/configure-features
    ```

### Complete Cleanup

To remove all deployed components:

```bash
# Modern interface (recommended)
make cleanup-dev       # Development environment
make cleanup-prod      # Production environment

# Or using direct scripts
scripts/clean dev      # Development environment
scripts/clean prod     # Production environment

# Legacy compatibility
./cleanup-all.sh dev   # Development environment
./cleanup-all.sh prod  # Production environment
```

This script removes:
- All Helm releases (nch-prereq, nch-data, nch-services, nch-haproxy)
- All Persistent Volume Claims
- MongoDB authentication secrets
- Pre-install hook jobs
- Custom ConfigMaps
- Namespace (with force deletion if stuck)

### Access Your Nirmata Platform

After successful deployment (Step 5 complete):

1.  **Primary Access via HAProxy:**
    ```bash
    # Development (port forward)
    kubectl port-forward svc/haproxy 8443:8443 -n nch-dev1
    # Then access: https://localhost:8443
    
    # Production (external access)
    kubectl get svc haproxy -n nch-pe
    # Use EXTERNAL-IP or configured domain
    ```

2.  **Direct API Gateway Access:**
    ```bash
    # Port forward to gateway service
    kubectl port-forward svc/gateway-service 8443:8443 -n nch-dev1
    # API base: https://localhost:8443/
    ```

3.  **HAProxy Load Balancer** (Production):
    ```bash
    # Check HAProxy service
    kubectl get svc haproxy -n nch-pe
    
    # Port forward for testing
    kubectl port-forward svc/haproxy 8443:8443 -n nch-pe
    ```

4.  **Configure Ingress** (Production):
    - Set up ingress controller
    - Configure TLS certificates
    - Update DNS records

### Modern Project Structure

| Component | Location | Purpose |
|-----------|----------|---------|
| **Entry Points** | `make deploy-dev`, `scripts/deploy` | Modern deployment interfaces |
| **Step Scripts** | `scripts/deployment/steps/` | Individual deployment steps (01-05) |
| **Configuration** | `config/values/` | Organized values files (base, environments, steps) |
| **Tools** | `scripts/tools/` | Utilities (db-operations, configure-features, monitor-health) |
| **Documentation** | `docs/` | Comprehensive guides and references |
| **Cleanup** | `make cleanup-dev`, `scripts/clean` | Modern cleanup interfaces |

### Key Scripts Overview

| Script | Purpose | Features |
|--------|---------|----------|
| `scripts/deployment/steps/01-prerequisites.sh` | CRDs, ConfigMaps, Secrets | MongoDB operator installation |
| `scripts/deployment/steps/02-data-services.sh` | MongoDB & Kafka clusters | Authentication and persistence |
| `scripts/deployment/steps/03-app-services.sh` | All 11 Nirmata microservices | Service mesh and networking |
| `scripts/deployment/steps/04-load-balancer.sh` | HAProxy load balancer | External access and SSL |
| `scripts/deployment/steps/05-configuration.sh` | License & tenant setup | API-driven configuration |

### Configuration Files

| File | Purpose | Features |
|------|---------|----------|
| `config/values/base.yaml` | Common settings | Shared across all environments |
| `config/values/environments/dev.yaml` | Development config | Lower resources, debug settings |
| `config/values/environments/prod.yaml` | Production config | High availability, optimized |
| `config/values/steps/*.yaml` | Step-specific overrides | Granular deployment control |

### Version Information

- **Platform Version**: 4.24.0-rc1
- **MongoDB**: Community Server 8.0.10
- **Kafka**: Latest stable with controller mode
- **HAProxy**: Latest stable with health checks
- **Kubernetes**: v1.23-v1.26 supported

### Next Steps

After successful deployment:
- Configure ingress/load balancers for production access
- Set up monitoring and logging
- Configure backup strategies for MongoDB
- Set up user authentication and RBAC
- Import or create your first policies
- Configure SSL/TLS certificates for production

### Support

For detailed troubleshooting and technical support:
- Use monitoring tools: `make monitor-health ENV=dev`
- Check pod logs: `kubectl logs <pod-name> -n nch-dev1`
- Review deployment events: `kubectl get events -n nch-dev1 --sort-by='.lastTimestamp'`
- Monitor resource usage: `kubectl top pods -n nch-dev1`
- Database operations: `make db-operations ENV=dev`
- Configure features: `make configure-features ENV=dev`

For comprehensive troubleshooting, see the [Troubleshooting Guide](troubleshooting.md). 