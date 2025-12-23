# Linkding Kubernetes Deployment

Production-grade Kubernetes deployment for [Linkding](https://github.com/sissbruecker/linkding) - a self-hosted bookmark service.

## Quick Start

```bash
# 1. Create namespace and secrets
kubectl create namespace linkding
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 32)" \
  --from-literal=POSTGRES_DB=linkding

# 2. Deploy with Kustomize (choose your storage backend)
kubectl apply -k overlays/longhorn/    # For Longhorn storage
# OR
kubectl apply -k overlays/local-path/  # For local-path storage

# 3. Verify deployment
kubectl get pods -n linkding
kubectl get httproute -n linkding

# 4. Create admin user
kubectl exec -it -n linkding deploy/linkding -- python manage.py createsuperuser
```

## Initial Setup

After deployment, create the admin user:

```bash
kubectl exec -it -n linkding deploy/linkding -- python manage.py createsuperuser
```

You will be prompted for:
- Username
- Email (optional, press Enter to skip)
- Password

Then access `http://linkding.k8s.home` and login with your credentials.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Gateway API with Envoy Gateway
- Storage class (Longhorn or local-path)
- Kustomize (built into kubectl 1.14+)

## Deployment Options

### Option 1: Kustomize (Recommended)

```bash
# Preview what will be deployed
kubectl kustomize overlays/longhorn/

# Deploy
kubectl apply -k overlays/longhorn/
```

### Option 2: Direct Apply

```bash
# Apply base resources individually
kubectl apply -f base/namespace.yaml
kubectl apply -f base/service-accounts.yaml
kubectl apply -f base/postgres-config.yaml
kubectl apply -f base/pvcs.yaml
kubectl apply -f base/postgres.yaml
kubectl apply -f base/deployment.yaml
kubectl apply -f base/ingress.yaml
```

## Secrets Setup

**Never commit secrets to Git.**

### Required: PostgreSQL Secret

```bash
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 32)" \
  --from-literal=POSTGRES_DB=linkding
```

### Optional: API Secret (for LDHC)

After deploying Linkding, generate an API token in the UI (Settings -> API), then:

```bash
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='your-api-token-here'
```

### Using Template File

```bash
# Copy template
cp optional/secrets.example.yaml secrets.yaml

# Edit with your values
vim secrets.yaml

# Apply
kubectl apply -f secrets.yaml
```

## Optional Features

Deploy optional components as needed:

```bash
# Network policies (micro-segmentation)
kubectl apply -f optional/network-policy.yaml

# Horizontal Pod Autoscaler
kubectl apply -f optional/hpa.yaml

# Linkding Health Check (requires API secret)
kubectl apply -f optional/ldhc.yaml

# Prometheus monitoring (requires Prometheus Operator)
kubectl apply -f optional/monitoring.yaml
```

Or deploy all optional features:

```bash
kubectl apply -k optional/
```

## Configuration

### Domain Configuration

Update the domain in these files before deploying:

| File                   | Line             | Value                      |
| ---------------------- | ---------------- | -------------------------- |
| `base/deployment.yaml` | LD_SERVER_URL    | `http://linkding.k8s.home` |
| `base/deployment.yaml` | LD_ALLOWED_HOSTS | `linkding.k8s.home`        |
| `base/httproute.yaml`  | hostnames        | `linkding.k8s.home`        |

### Storage Classes

The overlays handle storage class configuration:

- `overlays/longhorn/` - For Longhorn distributed storage
- `overlays/local-path/` - For local-path provisioner

### Image Versions

Image versions are pinned in `base/kustomization.yaml`:

```yaml
images:
  - name: sissbruecker/linkding
    newTag: 1.44.1
  - name: postgres
    newTag: 16-alpine
```

## Linkding Health Check (LDHC)

[LDHC](https://github.com/sebw/linkding-healthcheck) automatically checks bookmarks for broken links.

**Features:**

- Checks all bookmarks for broken links (404, 403, DNS errors)
- Tags broken links with `@HEALTH_HTTP_<code>`, `@HEALTH_DNS`, etc.
- Finds duplicate bookmarks
- Runs weekly (configurable in `optional/ldhc.yaml`)

**Setup:**

1. Deploy Linkding
2. Generate API token in Settings -> API
3. Create the API secret (see above)
4. Deploy LDHC: `kubectl apply -f optional/ldhc.yaml`

## Security Features

- Non-root containers
- Security contexts with dropped capabilities
- Network policies for traffic restriction
- Read-only root filesystem where possible
- Secrets managed outside Git

## Database & Backups

- **PostgreSQL**: StatefulSet with persistent storage
- **Auto Backups**: Daily at 3 AM with 7-day retention
- **Manual Backup**: `./backup_linkding.sh`
- **Restore**: `./restore_linkding.sh`

## Monitoring

Requires Prometheus Operator. Deploy ServiceMonitors:

```bash
kubectl apply -f optional/monitoring.yaml
```

## Verification

```bash
# Check all resources
kubectl get all -n linkding

# Check pods
kubectl get pods -n linkding

# Check HTTPRoute
kubectl get httproute -n linkding

# Check Gateway
kubectl get gateway -n envoy-gateway-system

# View logs
kubectl logs -n linkding -l app=linkding
kubectl logs -n linkding postgres-0
```

## Documentation

| Document                                                | Description                      |
| ------------------------------------------------------- | -------------------------------- |
| [Deploy.md](docs/Deploy.md)                             | Complete deployment guide        |
| [Quick_Start.md](docs/Quick_Start.md)                   | Quick reference for deployment   |
| [Deployment_Checklist.md](docs/Deployment_Checklist.md) | Detailed configuration checklist |
| [Backup_And_Restore.md](docs/Backup_And_Restore.md)     | Backup and restore procedures    |
| [Database_Operations.md](docs/Database_Operations.md)   | PostgreSQL operations            |
| [Monitoring_Guide.md](docs/Monitoring_Guide.md)         | Prometheus monitoring setup      |

## Credits

- [Linkding](https://github.com/sissbruecker/linkding) - The bookmark service
- [LDHC](https://github.com/sebw/linkding-healthcheck) - Health check tool
