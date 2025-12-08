# Deployment Checklist for Homeserver

This guide walks you through deploying Linkding from GitHub to your homeserver with a fresh PostgreSQL setup.

**Quick Start**: If you've just pulled the files, see [QUICK_START.md](./QUICK_START.md) for a step-by-step guide!

## Prerequisites

### Ingress Controller Required

**You need an ingress controller installed** for the Ingress resource to work. The easiest option is **nginx-ingress**.

**Quick Install**:

```bash
# Install nginx-ingress (one command)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# Verify it's installed
kubectl get ingressclass
```

You should see `nginx` in the output. See [INGRESS_SETUP.md](./INGRESS_SETUP.md) for more details and alternatives.

## Critical Pre-Deployment Steps

### 1. **Secrets Management**

Create secrets locally on your homeserver:

```bash
# On your homeserver, create the postgres secret
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD='123' \
  --from-literal=POSTGRES_DB=linkding

# Generate a strong password (example):
# openssl rand -base64 32

# Create the API token secret for LDHC
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='<generate-api-token>'
```

### 2. **TLS Certificate Secret**

You need to create the TLS certificate for the ingress:

```bash
# Option 1: Self-signed certificate (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=linkding.local"

kubectl create secret tls linkding-tls \
  --namespace=linkding \
  --cert=tls.crt \
  --key=tls.key

# Option 2: Use cert-manager for automatic Let's Encrypt certificates (recommended)
# Install cert-manager, then create a Certificate resource
```

### 4. **Storage Classes**

Check if your cluster has a default storage class:

```bash
kubectl get storageclass
```

If you have a specific storage class (e.g., `fast-ssd`, `local-path`), uncomment and update in:

- `postgres.yaml` (volumeClaimTemplates section)
- `pvcs.yaml` (both PVCs)

If no storage class is specified, Kubernetes will use the default.

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl patch storageclass local-path \
 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl get storageclass

### 5. **Namespace Labels**

Update `namespace.yaml` to match your actual setup:

```yaml
metadata:
  name: linkding
  labels:
    name: linkding
    # Uncomment and set these based on your cluster:
    # name: ingress-nginx  # If your ingress is in ingress-nginx namespace
    # name: monitoring      # If your Prometheus is in monitoring namespace
```

**Check your namespaces**:

```bash
kubectl get namespaces --show-labels
```

Update `network-policy.yaml` to match your actual namespace labels.

### 6. **Ingress Controller**

Verify your ingress controller class name:

```bash
kubectl get ingressclass
```

Update `ingress.yaml` if needed:

```yaml
spec:
  ingressClassName: nginx # Change if different
```

### 7. **Prometheus Operator Labels**

If you're using Prometheus Operator, check the release label:

```bash
kubectl get prometheus -A
```

Update the `release` label in:

- `monitoring.yaml`
- `linkding-monitoring.yaml`

Check available versions at: https://github.com/sebw/ldhc/releases

## Deployment Steps

### Step 1: Clone Repository on Homeserver

```bash
cd /path/to/your/k8s/configs
git clone <your-github-repo-url> linkding
cd linkding
```

### Step 2: Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### Step 3: Create Secrets (DO THIS BEFORE DEPLOYING!)

```bash
# PostgreSQL secret
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD='<strong-password>' \
  --from-literal=POSTGRES_DB=linkding

# Linkding API secret (for LDHC)
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='<generate-token>'

# TLS certificate (see section 2 above)
kubectl create secret tls linkding-tls \
  --namespace=linkding \
  --cert=tls.crt \
  --key=tls.key
```

### Step 4: Update Configuration Files

Edit these files with your actual values:

- `deploy.yaml` - Update domain names
- `ingress.yaml` - Update domain and ingress class
- `ldhc.yaml` - Update domain and image version
- `namespace.yaml` - Update labels if needed
- `network-policy.yaml` - Update namespace selectors
- `monitoring.yaml` - Update release label
- `linkding-monitoring.yaml` - Update release label
- `postgres.yaml` - Update storage class if needed
- `pvcs.yaml` - Update storage class if needed

### Step 5: Create Service Accounts

```bash
kubectl apply -f service-accounts.yaml
```

### Step 6: Create ConfigMaps

```bash
kubectl apply -f postgres-exporter-config.yaml
```

### Step 7: Create PVCs (for Linkding data and backups)

```bash
kubectl apply -f pvcs.yaml
```

### Step 8: Deploy PostgreSQL StatefulSet

```bash
kubectl apply -f postgres.yaml
```

**Wait for PostgreSQL to be ready**:

```bash
kubectl wait --for=condition=ready pod -l app=postgres -n linkding --timeout=300s
```

### Step 9: Deploy Linkding Application

```bash
kubectl apply -f deploy.yaml
```

### Step 10: Deploy Ingress

```bash
kubectl apply -f ingress.yaml
```

### Step 11: Deploy Network Policies

```bash
kubectl apply -f network-policy.yaml
```

### Step 12: Deploy Monitoring (if using Prometheus Operator)

```bash
kubectl apply -f monitoring.yaml
kubectl apply -f linkding-monitoring.yaml
```

### Step 13: Deploy LDHC CronJob

```bash
kubectl apply -f ldhc.yaml
```

## Verification Steps

### Check Pods Are Running

```bash
kubectl get pods -n linkding
```

You should see:

- `postgres-0` - Running
- `linkding-xxxxx` - 2 pods running

### Check Services

```bash
kubectl get svc -n linkding
```

### Check PVCs

```bash
kubectl get pvc -n linkding
```

You should see:

- `postgres-data-postgres-0` (created by StatefulSet)
- `postgres-backup-pvc`
- `linkding-data-pvc`

### Check Ingress

```bash
kubectl get ingress -n linkding
kubectl describe ingress linkding -n linkding
```

### Test Application

```bash
# Port forward to test locally
kubectl port-forward -n linkding svc/linkding 9090:9090

# Then visit http://localhost:9090
```

### Check Logs

```bash
# Linkding logs
kubectl logs -n linkding -l app=linkding --tail=50

# PostgreSQL logs
kubectl logs -n linkding postgres-0 -c postgres --tail=50
```

## Database Data and Backups

### Fresh PostgreSQL Setup

Since you have a **new PostgreSQL setup**, the StatefulSet approach will work perfectly:

1. **StatefulSet creates its own PVC**: The `volumeClaimTemplates` in `postgres.yaml` will automatically create `postgres-data-postgres-0` PVC when the StatefulSet is created.

2. **No migration needed**: Since it's a fresh setup, there's no existing data to migrate.

3. **Data persistence**: Once the StatefulSet is running, all database data will be stored in the persistent volume and will survive pod restarts.

### Backups

The backup CronJob will work automatically:

1. **Backup PVC**: The `postgres-backup-pvc` stores all backups
2. **Schedule**: Runs daily at 2 AM (configurable in `postgres.yaml`)
3. **Retention**: Keeps backups for 7 days (configurable via `BACKUP_RETENTION_DAYS` env var)
4. **Verification**: Automatically verifies backup integrity

**Verify backup is working**:

```bash
# Check backup job history
kubectl get jobs -n linkding -l app=postgres-backup

# Manually trigger a backup (for testing)
kubectl create job --from=cronjob/postgres-backup manual-backup -n linkding

# Check backup files
kubectl exec -n linkding postgres-0 -c backup -- ls -lh /var/lib/postgresql/backups/
```

**Note**: The backup job connects to `postgres-read` service, which points to the PostgreSQL pod.

## Post-Deployment

### Initial Setup

1. Access Linkding via your domain (or `https://linkding.local` if using local setup)
2. Create your first admin user
3. **Generate API Token for LDHC (Linkding Health Check)**:

   LDHC is included to automatically check your bookmarks for broken links. You need to set up the API token:

   - Go to Linkding UI → **Settings → API**
   - Click **"Create Token"** or **"Generate Token"**
   - Copy the generated token
   - Update the Kubernetes secret:
     ```bash
     kubectl create secret generic linkding-api-secret \
       --namespace=linkding \
       --from-literal=API_TOKEN='<paste-your-token-here>' \
       --dry-run=client -o yaml | kubectl apply -f -
     ```

   **What LDHC Does:**

   - Checks all bookmarks weekly for broken links (404, 403, DNS errors, etc.)
   - Tags broken links with `@HEALTH_HTTP_<code>`, `@HEALTH_DNS`, or `@HEALTH_other`
   - Finds duplicate bookmarks
   - Automatically removes health tags when sites come back online

   **Repository**: [sebw/linkding-healthcheck](https://github.com/sebw/linkding-healthcheck)

   The LDHC CronJob runs weekly on Sundays at 8/9 PM CET and will automatically start working once the API token is configured.

### Monitoring Setup

1. Verify Prometheus is scraping metrics:

   ```bash
   # Check ServiceMonitor
   kubectl get servicemonitor -n linkding

   # Check if Prometheus discovered it
   # (check Prometheus UI -> Status -> Targets)
   ```

### Backup Verification

1. Wait for first backup (or trigger manually)
2. Verify backup file exists and is valid
3. Test restore procedure (document this separately)

## Quick Start Script

Here's a quick deployment script (customize as needed):

```bash
#!/bin/bash
set -euo pipefail

NAMESPACE="linkding"
DOMAIN="your-domain.com"  # UPDATE THIS

# Create namespace
kubectl apply -f namespace.yaml

# Create secrets (UPDATE PASSWORDS!)
echo "Creating secrets..."
kubectl create secret generic postgres-secret \
  --namespace=$NAMESPACE \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD='<CHANGE-ME>' \
  --from-literal=POSTGRES_DB=linkding \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic linkding-api-secret \
  --namespace=$NAMESPACE \
  --from-literal=API_TOKEN='<CHANGE-ME>' \
  --dry-run=client -o yaml | kubectl apply -f -

# Create TLS secret (you need to generate this first)
# kubectl create secret tls linkding-tls \
#   --namespace=$NAMESPACE \
#   --cert=tls.crt \
#   --key=tls.key \
#   --dry-run=client -o yaml | kubectl apply -f -

# Apply all resources
kubectl apply -f service-accounts.yaml
kubectl apply -f postgres-exporter-config.yaml
kubectl apply -f pvcs.yaml
kubectl apply -f postgres.yaml

# Wait for postgres
echo "Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s

# Deploy application
kubectl apply -f deploy.yaml
kubectl apply -f ingress.yaml
kubectl apply -f network-policy.yaml
kubectl apply -f monitoring.yaml
kubectl apply -f linkding-monitoring.yaml
kubectl apply -f ldhc.yaml

echo "Deployment complete! Check status with: kubectl get pods -n $NAMESPACE"
```

Save this as `deploy.sh`, make it executable (`chmod +x deploy.sh`), update the variables, and run it.
