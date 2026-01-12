# Linkding Kubernetes Deployment

[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=aaronwittchen_linkding&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=aaronwittchen_linkding)

Production-grade Kubernetes deployment for [Linkding](https://github.com/sissbruecker/linkding) - a self-hosted bookmark service.

## Quick Start

```bash
# 1. Configure secrets
cd base
nano secrets.yaml  # Set your postgres password

# 2. Encrypt secrets with SOPS
sops -e -i secrets.yaml

# 3. Deploy with Kustomize (choose your storage backend)
kubectl apply -k overlays/longhorn/    # For Longhorn storage
# OR
kubectl apply -k overlays/local-path/  # For local-path storage

# 4. Verify deployment
kubectl get pods -n linkding
kubectl get httproute -n linkding

# 5. Create admin user
kubectl exec -it -n linkding deploy/linkding -- python manage.py createsuperuser
```

## ArgoCD Deployment

This repository is configured for GitOps deployment with ArgoCD.

1. Configure and encrypt secrets:
   ```bash
   nano base/secrets.yaml  # Set your postgres password
   sops -e -i base/secrets.yaml
   ```

2. Commit and push:
   ```bash
   git add .
   git commit -m "Configure linkding secrets"
   git push
   ```

3. Deploy via ArgoCD UI or CLI:
   ```bash
   kubectl apply -f /path/to/ArgoCD/applications/linkding.yaml
   ```

ArgoCD will automatically sync changes from the `linkding/overlays/longhorn` path.

## Initial Setup

After deployment, run database migrations and create the admin user:

```bash
export KUBECONFIG=/home/onion/k8s-nixos-cluster/kubeconfig

# Run database migrations (required on first deploy)
kubectl exec -it -n linkding deploy/linkding -- python manage.py migrate

# Create admin user
kubectl exec -it -n linkding deploy/linkding -- python manage.py createsuperuser
```

You will be prompted for:
- Username
- Email (optional, press Enter to skip)
- Password

Then access `https://linkding.k8s.local` and login with your credentials.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Gateway API with Istio
- Storage class (Longhorn or local-path)
- Kustomize (built into kubectl 1.14+)
- SOPS and age for secrets encryption

## Deployment Options

### Option 1: ArgoCD (Recommended)

See [ArgoCD Deployment](#argocd-deployment) above.

### Option 2: Kustomize

```bash
# Preview what will be deployed
kubectl kustomize overlays/longhorn/

# Deploy
kubectl apply -k overlays/longhorn/
```

### Option 3: Direct Apply

```bash
# Apply base resources individually
kubectl apply -f base/namespace.yaml
kubectl apply -f base/service-accounts.yaml
kubectl apply -f base/secrets.yaml  # Must be SOPS encrypted first
kubectl apply -f base/postgres-config.yaml
kubectl apply -f base/pvcs.yaml
kubectl apply -f base/postgres.yaml
kubectl apply -f base/deployment.yaml
kubectl apply -f base/httproute.yaml
```

## Secrets Setup

Secrets are managed with [SOPS](https://github.com/mozilla/sops) encryption using age keys.

### Required: PostgreSQL Secret

Edit `base/secrets.yaml` with your password, then encrypt:

```bash
# Edit the password
nano base/secrets.yaml

# Encrypt with SOPS
sops -e -i base/secrets.yaml

# Verify it's encrypted
cat base/secrets.yaml  # Should show encrypted values
```

### Optional: API Secret (for LDHC)

After deploying Linkding, generate an API token in the UI (Settings -> API), then add to secrets.

### Decrypting Secrets

```bash
# View decrypted content
sops -d base/secrets.yaml

# Edit encrypted file
sops base/secrets.yaml
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

Currently configured for:

| File                   | Setting          | Value                       |
| ---------------------- | ---------------- | --------------------------- |
| `base/deployment.yaml` | LD_SERVER_URL    | `https://linkding.k8s.local` |
| `base/deployment.yaml` | LD_ALLOWED_HOSTS | `linkding.k8s.local`        |
| `base/httproute.yaml`  | hostnames        | `linkding.k8s.local`        |
| `base/httproute.yaml`  | gateway          | `istio-system/cluster-gateway` |

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
- Secrets encrypted with SOPS/age

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
kubectl get gateway -n istio-system

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
