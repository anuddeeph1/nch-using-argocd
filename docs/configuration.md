# ⚙️ Nirmata Configuration Guide

> **Complete guide to customizing your Nirmata deployment**

This guide explains how to configure Nirmata using the modern organized values structure, covering everything from basic environment setup to advanced production configurations.

## 📁 Modern Configuration Structure

Nirmata uses a **clean, organized configuration system** with logical separation:

```
config/values/
├── base.yaml                       # 🏗️  Common settings (shared across all)
├── environments/                   # 🌍 Environment-specific configurations
│   ├── dev.yaml                    # Development environment
│   └── prod.yaml                   # Production environment
└── steps/                          # 🔧 Step-specific configurations
    ├── prerequisites.yaml          # Step 1: CRDs, ConfigMaps, Secrets
    ├── data-services.yaml          # Step 2: MongoDB, Kafka
    ├── app-services.yaml           # Step 3: Nirmata Services
    ├── load-balancer.yaml          # Step 4: HAProxy
    └── configuration.yaml          # Step 5: License & Tenant
```

### File Loading Order (Automatic)
```bash
# Modern deployment handles this automatically
make deploy-step3 ENV=dev

# Equivalent to:
helm install nch-services ./nch-charts \
  --values config/values/base.yaml \              # 1️⃣ Base settings
  --values config/values/steps/app-services.yaml \# 2️⃣ Step settings  
  --values config/values/environments/dev.yaml   # 3️⃣ Environment overrides
```

### Benefits of New Structure
- **📂 Clear Organization**: Logical separation by purpose
- **🎯 Environment Focus**: Dedicated env configs (dev/prod)
- **🔧 Step Granularity**: Fine-grained step control
- **🚀 Modern Interface**: Makefile and script automation
- **🔄 Backward Compatible**: Legacy commands still work

## 🏗️ Base Configuration (`config/values/base.yaml`)

### Global Infrastructure Settings
```yaml
global:
  # Infrastructure basics
  namespaceOverride: "nch-pe"        # Base namespace (overridden by environments)
  provider: "eks"                    # Cloud provider (eks, gke, aks, openshift)
  storageClassName: "gp3"            # Storage class for PVCs
  tenancyModel: "single"             # single or multi-tenant
  
  # Image registry configuration
  common:
    registry: "844333597536.dkr.ecr.us-west-1.amazonaws.com/nirmata"
    version: "4.24.0-rc1"            # Default image tag
    tunnelServerAddress: "https://tunnel-0.tunnel:9090"
    clusterIP: "None"
    kubectlImage: "kubectl:1.30"
    
  # Image pull secrets (standardized name)
  imagePullSecrets:
    name: "image-registry"           # Standardized secret name
    
  # Image registry credentials (empty by default, configure per environment)
  imageRegistry:
    server: ""                       # Configure in environment files
    username: ""                     # Configure in environment files  
    password: ""                     # Configure in environment files
```

### MongoDB Configuration
```yaml
global:
  mongo:
    hostedMongo: false               # Use internal MongoDB
    mongoDBServiceName: "mongodb-hs:27017"
    mongoDBUsername: "admin"
    mongoDBPassword: "MongoDBTest123"
    authdb: "admin"
```

### Security Settings
```yaml
global:
  security:
    tls:
      enabled: true                  # Enable TLS encryption
    networkPolicies:
      enabled: false                 # Network isolation
```

### Resource Defaults
```yaml
global:
  resources:
    defaults:
      limits:
        memory: "1Gi"
        cpu: "1000m"
      requests:
        memory: "512Mi"
        cpu: "250m"
```

## 🎯 Environment-Specific Configuration

### Development Environment (`config/values/environments/dev.yaml`)
```yaml
global:
  # Development namespace override
  namespaceOverride: "nch-dev1"      # Updated dev namespace
  
  # Development image registry
  imageRegistry:
    server: "844333597536.dkr.ecr.us-west-1.amazonaws.com"
    username: ""                     # ECR uses token-based auth
    password: ""                     # Configure with ECR token
    
  # Development-specific product configuration  
  product:
    url: "onprem-nch-external-mongodb.nirmata.co"
    product: "Enterprise"
    productName: "PrivateEdition"
    productVersion: "4.24.0-rc1"
    isNchOnly: true
    
  # Development license and tenant configuration
  nirmataConfig:
    license:
      key: "sIUCD9EF3eExtPo8FWhEe4zdoDI8N0eh5Ato+KDtrYWXgsF/mQ3EsErcmYgxKpxWBHZbWKPVPKaT4pN0iA3QL1QhqAcFc2oSxhWmVEGCpWUmcGyo6WPoOS2wbqIiB+6dzxOgXGz3biN4SXxB4qYqrYQCZ7mXDSTzuHVDEDX4bB3S0M6iSH1OT0GT98/D1gzvx8JmzTNVxWY4LBWhnbfprBmNlurmDN0ETIbkEScApqazlyAi/UNysHl+YRBeUoxGm6BS4qaBc1VoC4AnopBzrA=="
      type: "development"
    tenant:
      name: "damien@nirmata.com"
      adminEmail: "damien@nirmata.com"
      adminPassword: "Nirmata2013"
      companyName: "Nirmata Platform"
    
  # Development-specific settings
  environment: "development"
  
  # Relaxed security for development
  security:
    tls:
      enabled: false                 # Disable TLS for easier debugging
    networkPolicies:
      enabled: false
      
  # Development resource limits (lower for cost savings)
  resources:
    defaults:
      limits:
        memory: "512Mi"
        cpu: "500m"
      requests:
        memory: "256Mi"
        cpu: "100m"
```

### Production Environment (`config/values/environments/prod.yaml`)
```yaml
global:
  # Production namespace
  namespaceOverride: "nch-pe"
  
  # Product configuration
  product:
    url: "nirmata.mycompany.com"
    product: "Enterprise"
    productName: "PrivateEdition"
    productVersion: "4.24.0-rc1"
    
  # Production-specific settings
  environment: "production"
  
  # Enhanced security for production
  security:
    tls:
      enabled: true                  # Always enable TLS in production
    networkPolicies:
      enabled: true                  # Enable network isolation
      
  # Production resources
  resources:
    defaults:
      limits:
        memory: "2Gi"                # Increased memory limits
        cpu: "2000m"
      requests:
        memory: "1Gi"
        cpu: "500m"
        
  # Production license and tenant (Step 5)
  nirmataConfig:
    license:
      key: "PROD-LICENSE-KEY-REPLACE-ME"
      type: "production"
    tenant:
      name: "admin@mycompany.com"
      adminEmail: "admin@mycompany.com"
      adminPassword: "SecureProductionPassword123!"
      companyName: "MyCompany"
```

## 🔧 Step-Specific Configuration

### Step 1: Prerequisites (`config/values/steps/prerequisites.yaml`)
```yaml
# Step 1 specific overrides
global:
  # Force MongoDB CRD installation in Step 1 (regardless of hosted setting)
  mongo:
    hostedMongo: false  # Must be false to install CRDs
  
  # Step 1 specific product overrides (inherits URL from environment profile)
  product:
    productVersion: ""  # Empty for Step 1

# Component enablement for Step 1
prereq:
  enabled: true

# Disable all other components for step 1
base:
  enabled: false

postreq:
  enabled: false

others:
  enabled: false
```

### Step 2: Data Services (`config/values/steps/data-services.yaml`)
```yaml
# Step 2 specific overrides
global:
  # Disable all other components except data services
  mongo:
    hostedMongo: false      # Use internal MongoDB

# Component enablement for Step 2
prereq:
  enabled: false

base:
  enabled: true            # Enable data services
  
postreq:
  enabled: false

others:
  enabled: false

# MongoDB and Kafka get deployed with their default configurations
# from the main chart, with environment-specific overrides applied
```

### Step 3: Application Services (`config/values/steps/app-services.yaml`)
```yaml
# Step 3 specific overrides  
global:
  # Application services configuration
  product:
    isNchOnly: true

# Component enablement for Step 3
prereq:
  enabled: false

base:
  enabled: false
  
postreq:
  enabled: true           # Enable Nirmata services

others:
  enabled: false

# Individual Nirmata services get deployed with their default configurations
# from nirmata-services-chart, with environment-specific resource overrides
```

### Step 4: Load Balancer (`config/values/steps/load-balancer.yaml`)
```yaml
# Step 4 specific overrides
global:
  # Load balancer configuration
  product:
    isNchOnly: true

# Component enablement for Step 4
prereq:
  enabled: false

base:
  enabled: false
  
postreq:
  enabled: false

others:
  enabled: true           # Enable HAProxy and other external components
```

### Step 5: Configuration (`config/values/steps/configuration.yaml`)
```yaml
# Step 5 - API-driven configuration (no Helm resources)
# This step uses extracted values from the merged configuration
# to perform license validation and tenant setup via API calls

# The configuration script automatically merges:
# - base.yaml
# - configuration.yaml (this file)  
# - environment-specific values
# 
# And extracts license keys, tenant info, and platform URLs
# for API-based configuration
```

## 🎛️ Common Customizations

### 1. Change Namespace
```yaml
# In config/values/environments/{env}.yaml
global:
  namespaceOverride: "my-nirmata-namespace"
```

### 2. Use External MongoDB
```yaml
# In config/values/environments/{env}.yaml
global:
  mongo:
    hostedMongo: true
    mongoDBServiceName: "external-mongo.company.com:27017"
    mongoDBUsername: "nirmata-user"
    mongoDBPassword: "secure-password"
    mongoDBKeystorePassword: "keystore-password"
    mongoDBTruststorePassword: "truststore-password"
    authdb: "admin"
```

### 3. Custom Image Registry
```yaml
# In config/values/environments/{env}.yaml
global:
  common:
    registry: "my-registry.company.com/nirmata"
    
  imagePullSecrets:
    name: "my-registry-secret"
```

### 4. Resource Scaling
```yaml
# In config/values/environments/{env}.yaml
nirmata-services-chart:
  cluster:
    replicas: 3                     # Scale to 3 replicas
    resources:
      limits:
        memory: 4Gi                 # Increase memory
        cpu: 2000m
      requests:
        memory: 2Gi
        cpu: 1000m
        
  # Scale other services similarly
  policies:
    replicas: 2
    resources:
      limits:
        memory: 2Gi
        cpu: 1000m
```

### 5. Storage Configuration
```yaml
# In config/values/base.yaml or config/values/environments/{env}.yaml
global:
  storageClassName: "fast-ssd"      # Custom storage class

# In config/values/environments/{env}.yaml for larger storage
mongodb-chart:
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 100Gi            # Larger MongoDB storage
      storageClassName: "fast-ssd"
    
kafka-chart:
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 50Gi             # Larger Kafka storage
```

### 6. TLS/SSL Certificates
```yaml
# In config/values/environments/{env}.yaml
global:
  security:
    tls:
      enabled: true
      
# Custom certificates are managed via Kubernetes secrets
# See deployment guide for certificate setup instructions
```

### 7. Proxy Configuration
```yaml
# In config/values/base.yaml or config/values/environments/{env}.yaml
global:
  proxy:
    http_proxy: "http://proxy.company.com:8080"
    https_proxy: "http://proxy.company.com:8080"
    no_proxy: "localhost,127.0.0.1,.company.com"
    HTTP_PROXY: "http://proxy.company.com:8080"
    HTTPS_PROXY: "http://proxy.company.com:8080"
    NO_PROXY: "localhost,127.0.0.1,.company.com"
```

## 🏢 Enterprise Configurations

### High Availability Setup
```yaml
# In config/values/environments/prod.yaml
global:
  # Production environment settings
  environment: "production"
  
# MongoDB high availability
mongodb-chart:
  replicaCount: 3                   # MongoDB replica set
  resources:
    limits:
      memory: 4Gi
    requests:
      memory: 2Gi
  
# Kafka high availability
kafka-chart:
  replicaCount: 3                   # Kafka cluster
  resources:
    limits:
      memory: 4Gi
    requests:
      memory: 2Gi
  
# Nirmata services high availability
nirmata-services-chart:
  cluster:
    replicas: 2
  activity:
    replicas: 2
  gatewayservice:
    replicas: 2
  users:
    replicas: 2
  security:
    replicas: 2
```

### Resource Optimization
```yaml
# In config/values/environments/prod.yaml
global:
  resources:
    defaults:
      limits:
        memory: "4Gi"
        cpu: "2000m"
      requests:
        memory: "2Gi"
        cpu: "1000m"
        
# Node affinity for critical services (advanced configuration)
nirmata-services-chart:
  cluster:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role
            operator: In
            values: ["critical"]
```

### Security Hardening
```yaml
# In config/values/environments/prod.yaml
global:
  security:
    tls:
      enabled: true                  # Always enable in production
    networkPolicies:
      enabled: true                  # Enable network isolation
      
  # Enhanced security settings
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
```

## 🔍 Configuration Validation

### Modern Configuration Checking
```bash
# Check merged configuration for development
make deploy-step3 ENV=dev --dry-run

# Or manually check specific step configuration
helm template nch-services ./nch-charts \
  --values config/values/base.yaml \
  --values config/values/steps/app-services.yaml \
  --values config/values/environments/dev.yaml \
  --dry-run > merged-config.yaml
```

### Validate Values
```bash
# Test configuration without deploying (modern)
make deploy-step3 ENV=dev --dry-run

# Legacy method
helm install nch-services ./nch-charts \
  --values config/values/base.yaml \
  --values config/values/steps/app-services.yaml \
  --values config/values/environments/dev.yaml \
  --dry-run --debug
```

### Environment Comparison
```bash
# Compare dev vs prod configurations (modern)
helm template nch-services ./nch-charts \
  --values config/values/base.yaml \
  --values config/values/steps/app-services.yaml \
  --values config/values/environments/dev.yaml > dev-config.yaml
  
helm template nch-services ./nch-charts \
  --values config/values/base.yaml \
  --values config/values/steps/app-services.yaml \
  --values config/values/environments/prod.yaml > prod-config.yaml
  
diff dev-config.yaml prod-config.yaml
```

## 🔧 Advanced Configuration

### Custom Environment Files
```bash
# Create staging environment configuration
cp config/values/environments/dev.yaml config/values/environments/staging.yaml

# Edit for staging environment requirements
vim config/values/environments/staging.yaml

# Deploy with new environment
make deploy ENV=staging
# or: scripts/deploy staging
```

### Modern Command-Line Overrides
```bash
# Using Makefile with custom values
make deploy-step3 ENV=dev EXTRA_ARGS="--set global.mongo.mongoDBPassword=NewPassword123"

# Using direct scripts with overrides
scripts/deployment/steps/03-app-services.sh dev \
  --set global.mongo.mongoDBPassword=NewPassword123 \
  --set nirmata-services-chart.cluster.replicas=3
```

### Environment Variables and Customization
```bash
# Set namespace via environment variable (still supported)
export NCH_NAMESPACE=custom-namespace
scripts/deploy dev

# Modern tools for configuration management
make configure-features ENV=dev    # Configure feature flags
make db-operations ENV=dev         # Database operations
make monitor-health ENV=dev        # Health monitoring
```

## 📚 Configuration Examples

### Minimal Development Environment
```yaml
# config/values/environments/dev-minimal.yaml
global:
  namespaceOverride: "nch-dev-minimal"
  
  # Minimal resources for local development
  resources:
    defaults:
      limits:
        memory: "512Mi"
        cpu: "500m"
      requests:
        memory: "256Mi"
        cpu: "250m"
        
# Reduce storage for development
mongodb-chart:
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 5Gi
    
kafka-chart:
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 2Gi

# Single replica for all services
nirmata-services-chart:
  cluster:
    replicas: 1
  activity:
    replicas: 1
  policies:
    replicas: 1
```

### Enterprise Production Environment
```yaml
# config/values/environments/prod-enterprise.yaml
global:
  namespaceOverride: "nch-prod"
  
  # High-performance resources
  resources:
    defaults:
      limits:
        memory: "8Gi"
        cpu: "4000m"
      requests:
        memory: "4Gi"
        cpu: "2000m"
        
  # Production security
  security:
    tls:
      enabled: true
    networkPolicies:
      enabled: true
        
# High availability storage
mongodb-chart:
  replicaCount: 3
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 500Gi
      storageClassName: "fast-ssd"
    
kafka-chart:
  replicaCount: 3
  volumeClaimTemplates:
    spec:
      resources:
        requests:
          storage: 200Gi
      storageClassName: "fast-ssd"

# High availability services
nirmata-services-chart:
  cluster:
    replicas: 3
  activity:
    replicas: 2
  policies:
    replicas: 3
  users:
    replicas: 2
  security:
    replicas: 2
```

## 🔐 Security Configuration

### TLS Configuration
```yaml
# In config/values/environments/prod.yaml
global:
  security:
    tls:
      enabled: true                   # Always enable in production
      
# TLS certificates are managed via Kubernetes secrets
# See docs/deployment-guide.md for certificate setup instructions
```

### Network Policies
```yaml
# In config/values/environments/prod.yaml
global:
  security:
    networkPolicies:
      enabled: true                   # Enable network isolation
      
  # Enhanced security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    readOnlyRootFilesystem: true
```

### Authentication and Authorization
```yaml
# In config/values/environments/{env}.yaml
global:
  # Nirmata tenant configuration (applied in Step 5)
  nirmataConfig:
    tenant:
      adminEmail: "admin@company.com"
      adminPassword: "SecurePassword123!"
      companyName: "Your Company"
      
  # MongoDB authentication
  mongo:
    authdb: "admin"
    mongoDBUsername: "admin"
    mongoDBPassword: "MongoDBTest123"
```

---

## 🎯 Next Steps

After configuring your values files:

1. **Deploy Development**: `make deploy-dev` or `scripts/deploy dev`
2. **Deploy Production**: `make deploy-prod` or `scripts/deploy prod`
3. **Monitor Deployment**: `make monitor-health ENV=dev`
4. **Configure Features**: `make configure-features ENV=dev`

> **💡 Best Practice**: Start with the default configurations and make incremental changes. Test each configuration change in development before applying to production.

**Need help with configurations?** → [Troubleshooting Guide](troubleshooting.md) | [Architecture Guide](architecture.md) 