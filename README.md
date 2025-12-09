# Linkding Kubernetes Deployment

[![README lint](https://github.com/aaronwittchen/linkding-setup/actions/workflows/readme-lint.yaml/badge.svg)](https://github.com/aaronwittchen/linkding-setup/actions/workflows/readme-lint.yaml)

Production-grade Kubernetes deployment for [Linkding](https://github.com/sissbruecker/linkding) - a self-hosted bookmark service.

## Quick Start

For **instructions**, see [Quick_Start.md](./Quick_Start.md).
For **detailed information**, see [Deployment_Checklist.md](./Deployment_Checklist.md).

### Quick Overview

1. **Install ingress controller** (nginx-ingress)
2. **Create secrets** on your homeserver
3. **Deploy** using kubectl (all YAML files ready to go)
4. **Set up API token** after first deployment (for LDHC)

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured to access your cluster
- Ingress controller (nginx-ingress recommended)
- Storage class configured (or default available)
- Prometheus Operator (optional, for monitoring)

## Secrets Setup

**DO NOT commit secrets to Git!**

1. Copy the template:

   ```bash
   cp secrets.yaml.template secrets.yaml
   ```

2. Edit `secrets.yaml` with your actual values, OR create secrets
   directly:

   ```bash
   kubectl create secret generic postgres-secret \
     --namespace=linkding \
     --from-literal=POSTGRES_USER=linkding \
     --from-literal=POSTGRES_PASSWORD='<strong-password>' \
     --from-literal=POSTGRES_DB=linkding
   ```

3. Generate strong passwords:

   ```bash
   openssl rand -base64 32
   ```

See [Deployment_Checklist.md](./Deployment_Checklist.md) for complete setup instructions.

## File Structure

| File                          | Description                                        |
| ----------------------------- | -------------------------------------------------- |
| backup_linkding.sh            | Script to backup Linkding data                     |
| deploy.yaml                   | Linkding application deployment                    |
| ingress.yaml                  | Ingress configuration with security headers        |
| ldhc.yaml                     | Linkding Health Check CronJob                      |
| linkding-monitoring.yaml      | Application monitoring (ServiceMonitor)            |
| monitoring.yaml               | PostgreSQL monitoring (ServiceMonitor)             |
| network-policy.yaml           | Network security policies                          |
| postgres-exporter-config.yaml | PostgreSQL exporter configuration                  |
| postgres.yaml                 | PostgreSQL StatefulSet with monitoring and backups |
| pvcs.yaml                     | Persistent volume claims                           |
| service-accounts.yaml         | Service account definitions                        |
| restore_linkding.sh           | Script to restore Linkding data                    |

## Documentation

| File                        | Description                                          |
| --------------------------- | ---------------------------------------------------- |
| Backup_And_Restore.md       | Instructions for backup and restore procedures       |
| Database_Operations.md      | PostgreSQL database operations guide                 |
| Deployment_Checklist.md     | Complete deployment guide with details               |
| Ingress_Setup.md            | Ingress controller installation guide                |
| Monitoring_Guide.md         | Linkding and PostgreSQL monitoring guide             |
| Quick_Start.md              | Step-by-step guide after pulling files (START HERE!) |
| Workflow_Setup.md           | Explanations on different GitHub workflows           |
| Yaml_Configuration_Guide.md | Detailed explanation of all configurations           |

## Configuration

**Before deploying, update:**

1. **Domain names** in:

   - `deploy.yaml` (LD_SERVER_URL, LD_ALLOWED_HOSTS)
   - `ingress.yaml` (host)
   - `ldhc.yaml` (API_URL)

2. **Storage classes** (if needed) in:

   - `postgres.yaml` (volumeClaimTemplates)
   - `pvcs.yaml`

3. **Namespace labels** in:

   - `namespace.yaml`
   - `network-policy.yaml`

4. **Prometheus release label** in:

   - `monitoring.yaml`
   - `linkding-monitoring.yaml`

5. **Ingress class** in:
   - `ingress.yaml`

## Database and Backups

- **PostgreSQL**: Deployed as StatefulSet with persistent storage
- **Backups**: Automated daily backups at 8/9 PM CET with 7-day retention
- **Storage**: Automatic PVC creation via volumeClaimTemplates

For a **fresh PostgreSQL setup**, no migration is needed - the StatefulSet will create everything automatically.

## Linkding Health Check (LDHC)

This deployment includes [LDHC](https://github.com/sebw/linkding-healthcheck) - a tool that automatically checks your bookmarks for broken links and duplicates.

**Features:**

- Checks all bookmarks for broken links (404, 403, DNS errors, etc.)
- Tags broken links with `@HEALTH_HTTP_<code>`, `@HEALTH_DNS`, or `@HEALTH_other`
- Finds duplicate bookmarks
- Automatically removes health tags when sites come back online
- Runs weekly on Sundays at 8/9 PM CET

**Setup Required:**
After deploying Linkding, you need to generate an API token:

1. Access Linkding UI → Settings → API
2. Generate a new API token
3. Update the secret:

   ```bash
   kubectl create secret generic linkding-api-secret \
     --namespace=linkding \
     --from-literal=API_TOKEN='<your-generated-token>' \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

The LDHC CronJob will then automatically run weekly to check your bookmarks.

## Security Features

- Non-root containers
- Security contexts and capabilities
- Network policies (micro-segmentation)
- TLS encryption
- Security headers (HSTS, CSP, etc.)
- Rate limiting
- Secrets management

## Monitoring

- Health probes (liveness, readiness, startup)
- Prometheus metrics (PostgreSQL exporter + application metrics)
- ServiceMonitors for automatic scraping

## Important Notes

1. **Secrets**: Never commit `secrets.yaml` to Git. Use the template or create secrets via kubectl.
2. **TLS Certificates**: Generate or use cert-manager for automatic certificates.
3. **Storage**: Ensure your cluster has a storage class configured.
4. **Domain**: Update all domain references before deploying.

## License

This deployment configuration is provided as-is for use with Linkding.

## Credits

- [Linkding](https://github.com/sissbruecker/linkding) - The bookmark service
- [LDHC (Linkding Health Check)](https://github.com/sebw/linkding-healthcheck) - Checks bookmarks for broken links and duplicates
