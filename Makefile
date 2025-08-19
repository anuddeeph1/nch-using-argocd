# NCH Charts Deployment Makefile
# Modern interface for deploying and managing Nirmata platform

.PHONY: deploy cleanup deploy-dev deploy-prod cleanup-dev cleanup-prod help docs tools

# Default environment
ENV ?= dev

# Main targets
deploy:
	@./scripts/deploy $(ENV)

cleanup:
	@./scripts/clean $(ENV)

# Environment-specific shortcuts
deploy-dev:
#	@./scripts/deploy dev
	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/deploy dev

deploy-prod:
#	@./scripts/deploy prod
	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/deploy prod

cleanup-dev:
#	@./scripts/clean dev
	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/clean dev

cleanup-prod:
#	@./scripts/clean prod
	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/clean prod

# Individual deployment steps
deploy-step1:
	@./scripts/deployment/steps/01-prerequisites.sh $(ENV)
#	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/deployment/steps/01-prerequisites.sh $(ENV)

deploy-step2:
	@./scripts/deployment/steps/02-data-services.sh $(ENV)
#	@PATH="/opt/homebrew/bin:$$PATH" ./scripts/deployment/steps/02-data-services.sh $(ENV)

deploy-step3:
	@./scripts/deployment/steps/03-app-services.sh $(ENV)

deploy-step4:
	@./scripts/deployment/steps/04-load-balancer.sh $(ENV)

deploy-step5:
	@./scripts/deployment/steps/05-configuration.sh $(ENV)

# Tools
configure-features:
	@./scripts/tools/configure-features

db-operations:
	@./scripts/tools/db-operations

monitor-health:
	@./scripts/tools/monitor-health

# Documentation shortcuts
docs:
	@echo "📚 Available documentation:"
	@echo "  • docs/quick-start.md      - Get started quickly"
	@echo "  • docs/deployment-guide.md - Complete deployment guide"
	@echo "  • docs/configuration.md    - Configuration options"
	@echo "  • docs/architecture.md     - System architecture"
	@echo "  • docs/troubleshooting.md  - Troubleshooting guide"

# Status and info
status:
	@echo "🔍 Checking deployment status..."
	@kubectl get pods -n nch-$(ENV) 2>/dev/null || echo "No deployment found for $(ENV) environment"

logs:
	@echo "📋 Recent logs for $(ENV) environment:"
	@kubectl logs -n nch-$(ENV) --tail=100 -l app.kubernetes.io/instance=nch-services 2>/dev/null || echo "No logs found"

# Help
help:
	@echo "NCH Charts Deployment System"
	@echo ""
	@echo "🚀 Deployment Commands:"
	@echo "  make deploy ENV=dev        Deploy to specified environment (default: dev)"
	@echo "  make deploy-dev            Deploy to development environment"
	@echo "  make deploy-prod           Deploy to production environment"
	@echo ""
	@echo "🧹 Cleanup Commands:"
	@echo "  make cleanup ENV=dev       Cleanup specified environment"
	@echo "  make cleanup-dev           Cleanup development environment"
	@echo "  make cleanup-prod          Cleanup production environment"
	@echo ""
	@echo "🔧 Individual Steps:"
	@echo "  make deploy-step1 ENV=dev  Run prerequisites step"
	@echo "  make deploy-step2 ENV=dev  Run data services step"
	@echo "  make deploy-step3 ENV=dev  Run application services step"
	@echo "  make deploy-step4 ENV=dev  Run load balancer step"
	@echo "  make deploy-step5 ENV=dev  Run configuration step"
	@echo ""
	@echo "🛠️  Tools:"
	@echo "  make configure-features    Configure feature flags"
	@echo "  make db-operations         Database operations"
	@echo "  make monitor-health        Monitor namespace health"
	@echo ""
	@echo "📚 Information:"
	@echo "  make docs                  Show documentation"
	@echo "  make status ENV=dev        Check deployment status"
	@echo "  make logs ENV=dev          Show recent logs"
	@echo "  make help                  Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-dev            # Deploy to development"
	@echo "  make deploy ENV=prod       # Deploy to production"
	@echo "  make cleanup-dev           # Clean development environment"