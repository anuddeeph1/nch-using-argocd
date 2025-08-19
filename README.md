# Nirmata Helm Charts (NCH)

> **Modern 5-step deployment system for Nirmata SaaS platform on Kubernetes**

[![Helm](https://img.shields.io/badge/Helm-v3.x-blue.svg)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.23--v1.26-blue.svg)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## 🚀 Quick Start

**Deploy Nirmata in 5 minutes:**

```bash
# Clone and navigate
git clone https://github.com/nirmata/nirmata-charts.git
cd nirmata-charts

# Modern interface (recommended)
make deploy-dev

# Or using direct scripts
scripts/deploy dev
```

**Step-by-step deployment options:**

```bash
# Using Makefile (recommended)
make deploy-step1 ENV=dev    # Prerequisites
make deploy-step2 ENV=dev    # Data services  
make deploy-step3 ENV=dev    # Application services
make deploy-step4 ENV=dev    # Load balancer
make deploy-step5 ENV=dev    # License & tenant setup

# Or using direct scripts
scripts/deployment/steps/01-prerequisites.sh dev
scripts/deployment/steps/02-data-services.sh dev
scripts/deployment/steps/03-app-services.sh dev
scripts/deployment/steps/04-load-balancer.sh dev
scripts/deployment/steps/05-configuration.sh dev
```

**Backward Compatibility:**
```bash
# Legacy commands still work via symlinks
./deploy-all.sh dev
./cleanup-all.sh dev
```

## 📖 Documentation

| Document | Purpose | Audience |
|----------|---------|-----------|
| **[Quick Start Guide](docs/quick-start.md)** | 5-minute deployment | New users |
| **[Deployment Guide](docs/deployment-guide.md)** | Detailed step-by-step | Operations teams |
| **[Architecture](docs/architecture.md)** | Chart structure & design | Platform engineers |
| **[Configuration](docs/configuration.md)** | Values & customization | All users |
| **[Troubleshooting](docs/troubleshooting.md)** | Common issues & fixes | Operations teams |

## 🏗️ Architecture Overview

The deployment follows a **5-step process** optimized for dependency management:

```
Step 1: Prerequisites → Step 2: Data Services → Step 3: App Services → Step 4: Load Balancer → Step 5: Configuration
   (CRDs, ConfigMaps)      (MongoDB, Kafka)      (Nirmata Services)     (HAProxy)          (License, Tenant)
```

## ⚡ Key Features

- **🎯 5-Step Deployment**: Optimized dependency management and faster deployment
- **🔧 Multi-Environment**: Dev/Prod configurations with intelligent value file hierarchy
- **🛡️ Production-Ready**: HA MongoDB, Kafka, auto-scaling, and enterprise security
- **🚀 Fast Deployment**: Optimized scripts with parallel operations (55-60% faster)
- **⚡ Ultra-Fast Validation**: Step-only validation with 85%+ time reduction (no redundant checks)
- **🔄 Smart Cleanup**: Force namespace deletion with stuck resource handling
- **📊 Built-in Validation**: Health checks and readiness verification at each step
- **🔌 API Integration**: Automated license and tenant configuration via Nirmata API

## 🎛️ Environments & Configuration

| Environment | Namespace | Description | Values File |
|-------------|-----------|-------------|-------------|
| `dev` | `nch-dev1` | Development environment | `config/values/environments/dev.yaml` |
| `prod` | `nch-pe` | Production environment | `config/values/environments/prod.yaml` |

### Value Files Hierarchy (New Organized Structure)
```
config/values/
├── base.yaml                       # Common settings (lowest priority)
├── environments/
│   ├── dev.yaml                    # Development environment
│   └── prod.yaml                   # Production environment  
└── steps/                          # Step-specific configuration
    ├── prerequisites.yaml          # Step 1: CRDs, ConfigMaps, Secrets
    ├── data-services.yaml          # Step 2: MongoDB, Kafka
    ├── app-services.yaml           # Step 3: Nirmata Services
    ├── load-balancer.yaml          # Step 4: HAProxy
    └── configuration.yaml          # Step 5: License & Tenant
```

## 🧹 Cleanup

```bash
# Modern interface (recommended)
make cleanup-dev

# Or using direct scripts  
scripts/clean dev

# Backward compatibility (legacy)
./cleanup-all.sh dev

# Handles stuck namespaces automatically with force deletion
# Monitors deletion progress and provides troubleshooting guidance
```

## 📋 Prerequisites

### Cluster Requirements
- **Kubernetes**: v1.23-v1.26 cluster with kubectl access
- **Helm**: v3.x installed and configured
- **Resources**: 5+ nodes, 8+ vCPUs, 16+ GB RAM per node, 300GB SSD storage
- **Storage**: Dynamic storage class for SSD volumes
- **Network**: Load balancer support and DNS configuration
- **CPU**: AVX instruction set support (required for MongoDB)

### Access Requirements
- **Registry**: Access to Nirmata container images (GitHub or private registry)
- **Certificates**: TLS certificates for your Nirmata URL
- **License**: Valid Nirmata license key
- **Proxy**: Proxy configuration if behind corporate firewall

## 🌐 Access Your Deployment

After successful deployment:

```bash
# Check deployment status
kubectl get pods -n nch-dev1  # or nch-pe for prod

# Access Nirmata platform via port-forward (development)
kubectl port-forward svc/haproxy 8443:8443 -n nch-dev1
# Then visit: https://localhost:8443

# Credentials: As configured in config/values/environments/{env}.yaml
```

## 🆘 Need Help?

- **Quick Issues**: Check [Troubleshooting Guide](docs/troubleshooting.md)
- **Configuration**: See [Configuration Guide](docs/configuration.md)
- **Architecture Questions**: Read [Architecture Documentation](docs/architecture.md)
- **Support**: Contact your Nirmata support team
- **Issues**: [GitHub Issues](https://github.com/nirmata/nirmata-charts/issues)

## 🔧 Advanced Usage

### Makefile Commands
```bash
# View all available commands
make help

# Deploy individual steps
make deploy-step1 ENV=dev    # Prerequisites only
make deploy-step2 ENV=dev    # Data services only
make deploy-step3 ENV=dev    # Application services only

# Tools and utilities
make configure-features ENV=dev    # Configure feature flags manually
make db-operations ENV=dev         # Database operations
make monitor-health ENV=dev        # Monitor namespace health
```

### Custom Deployments
```bash
# Deploy to custom namespace (edit config files or use environment override)
export NCH_NAMESPACE=my-namespace
scripts/deploy dev

# Deploy individual steps with direct script access
scripts/deployment/steps/01-prerequisites.sh dev
scripts/deployment/steps/02-data-services.sh dev
scripts/deployment/steps/03-app-services.sh dev

# Legacy backward compatibility
./deploy-all.sh dev
```

### Validation Optimization
```bash
# Each step uses optimized step-only validation by default
scripts/deployment/steps/01-prerequisites.sh dev     # Validates only CRDs, ConfigMaps, Secrets
scripts/deployment/steps/02-data-services.sh dev     # Validates only MongoDB, Kafka  
scripts/deployment/steps/03-app-services.sh dev      # Validates only Nirmata services
scripts/deployment/steps/04-load-balancer.sh dev     # Validates only HAProxy

# Master deployment uses ultra-fast validation (85%+ time reduction)
make deploy-dev                  # Modern optimized deployment
scripts/deploy dev               # Direct script access
```

### Monitoring & Validation
```bash
# Monitor deployment progress  
watch kubectl get pods -n nch-dev1

# Use monitoring tool
make monitor-health ENV=dev

# Check all resources
kubectl get all,pvc,secrets,configmaps -n nch-dev1
```

## 🤝 Contributing

See [Contributing Guide](docs/CONTRIBUTING.md) for development setup and best practices.

## 📈 What's New

- **v4.24**: 5-step deployment with API-based configuration
- **Enhanced Cleanup**: Smart namespace deletion with force handling
- **Optimized Performance**: 55-60% faster deployment times
- **Ultra-Fast Validation**: Step-only validation with 85%+ time reduction
- **Value File Hierarchy**: Improved configuration management
- **Production Ready**: HA MongoDB with encryption and authentication

---

> **💡 Tip**: Start with the Quick Start commands above for immediate deployment, then explore the [Architecture documentation](ARCHITECTURE.md) for deeper understanding of the system design and best practices.
