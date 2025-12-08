# Quick Start Guide

### Install Ingress Controller (If Not Already Installed)

**Check if you already have nginx-ingress**:

```bash
kubectl get ingressclass
```

**If you see `nginx` in the output, skip to Step 2.**

**If not, install it**:

```bash
# Install nginx-ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# Verify
kubectl get ingressclass
```

### Step 2: Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### Step 3: Create Secrets

#### 3a. PostgreSQL Secret

```bash
# Generate a strong password
openssl rand -base64 32

# Create the secret (replace <strong-password> with the generated password)
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD='<strong-password>' \
  --from-literal=POSTGRES_DB=linkding
```

#### 3b. TLS Certificate (For HTTPS)

**Option A: Self-Signed Certificate (For Local Use)**

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=linkding.local"

# Create TLS secret
kubectl create secret tls linkding-tls \
  --namespace=linkding \
  --cert=tls.crt \
  --key=tls.key

# Clean up local files (optional)
rm tls.key tls.crt
```

**Option B: Use HTTP Instead (Simpler for Local)**
If you don't need HTTPS, you can skip TLS and modify `ingress.yaml` to remove the TLS section (see LOCAL_SETUP_GUIDE.md).

#### 3c. Linkding API Secret (Create After Deployment)

**IMPORTANT: Create this AFTER Step 8 (after Linkding is running and you've generated the API token)**

```bash
# This will be done later - see Step 9
```

### Step 4: Update Configuration Files (If Needed)

**For Local Network Use (linkding.local)**:

- Files are already configured for `linkding.local` - **no changes needed!**
- Just make sure to add `linkding.local` to your hosts file on devices you want to access from

**To add to hosts file** (on your laptop/other devices):

```bash
# Find your server IP
# On homeserver: hostname -I

# On your laptop (Linux/Mac):
sudo nano /etc/hosts
# Add: <your-server-ip>  linkding.local

# On Windows:
# Edit C:\Windows\System32\drivers\etc\hosts as Administrator
# Add: <your-server-ip>  linkding.local
```

**If using a different domain or IP**, update:

- `deploy.yaml` (lines 81, 83) - LD_SERVER_URL and LD_ALLOWED_HOSTS
- `ingress.yaml` (lines 36, 39) - TLS hosts and rules
- `ldhc.yaml` (line 42) - API_URL

### Step 5: Check Storage Class (Optional)

```bash
# Check available storage classes
kubectl get storageclass

# If you have a specific one you want to use, uncomment and update:
# - postgres.yaml (line 188)
# - pvcs.yaml (storageClassName lines)
```

**If no storage class is specified, Kubernetes will use the default.**

### Step 6: Deploy Service Accounts

```bash
kubectl apply -f service-accounts.yaml
```

### Step 7: Deploy ConfigMaps

```bash
kubectl apply -f postgres-exporter-config.yaml
```

### Step 8: Deploy Persistent Volume Claims

```bash
kubectl apply -f pvcs.yaml
```

### Step 9: Deploy PostgreSQL

```bash
kubectl apply -f postgres.yaml

# Wait for PostgreSQL to be ready (this takes ~30-60 seconds)
kubectl wait --for=condition=ready pod -l app=postgres -n linkding --timeout=300s

# Verify it's running
kubectl get pods -n linkding
```

You should see `postgres-0` in Running state.

### Step 10: Deploy Linkding Application

```bash
kubectl apply -f deploy.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=linkding -n linkding --timeout=300s

# Verify
kubectl get pods -n linkding
```

You should see 2 `linkding-xxxxx` pods in Running state.

### Step 11: Deploy Ingress

```bash
kubectl apply -f ingress.yaml

# Check ingress status
kubectl get ingress -n linkding
```

### Step 12: Deploy Network Policies

```bash
kubectl apply -f network-policy.yaml
```

**Note**: If network policies don't work, check your namespace labels match (see PRE_DEPLOYMENT_CHECKLIST.md).

### Step 13: Deploy Monitoring (If Using Prometheus Operator)

```bash
kubectl apply -f monitoring.yaml
kubectl apply -f linkding-monitoring.yaml
```

**Note**: Only if you have Prometheus Operator installed. Update the `release` label if needed.

### Step 14: Deploy LDHC CronJob

```bash
kubectl apply -f ldhc.yaml
```

**Note**: LDHC won't work until you complete Step 15 (API token setup).

## Post-Deployment Setup

### Step 15: Initial Linkding Setup

1. **Access Linkding**:

   - Via `https://linkding.local` (if using local setup with hosts file)
   - Or via NodePort: `kubectl get svc -n ingress-nginx` to find the port

2. **Create Admin User**:

   - First time accessing will prompt you to create an admin account
   - Follow the setup wizard

3. **Generate API Token for LDHC**:

   - Go to **Settings → API** in Linkding UI
   - Click **"Create Token"** or **"Generate Token"**
   - **Copy the token** (you won't see it again!)

4. **Update the API Token Secret**:

   ```bash
   kubectl create secret generic linkding-api-secret \
     --namespace=linkding \
     --from-literal=API_TOKEN='<paste-your-token-here>' \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

   Now LDHC will work! It runs weekly on Sundays at 8/9 PM CET.

## Verification

### Check Everything is Running

```bash
# Check all pods
kubectl get pods -n linkding

# Should see:
# - postgres-0 (Running)
# - linkding-xxxxx (2 pods, Running)

# Check services
kubectl get svc -n linkding

# Check ingress
kubectl get ingress -n linkding

# Check PVCs
kubectl get pvc -n linkding
```

### Check Logs (If Issues)

```bash
# Linkding logs
kubectl logs -n linkding -l app=linkding --tail=50

# PostgreSQL logs
kubectl logs -n linkding postgres-0 -c postgres --tail=50

# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

### Test Access

```bash
# Port forward to test locally (if ingress not working)
kubectl port-forward -n linkding svc/linkding 9090:9090

# Then visit http://localhost:9090
```

## Summary Checklist

- [ ] Ingress controller installed
- [ ] Namespace created
- [ ] PostgreSQL secret created
- [ ] TLS certificate created (or using HTTP)
- [ ] Service accounts deployed
- [ ] ConfigMaps deployed
- [ ] PVCs created
- [ ] PostgreSQL running
- [ ] Linkding running (2 pods)
- [ ] Ingress deployed
- [ ] Network policies deployed
- [ ] Monitoring deployed (if applicable)
- [ ] LDHC deployed
- [ ] Admin user created in Linkding
- [ ] API token generated and secret updated

## Next Steps

- Read [YAML_CONFIGURATION_GUIDE.md](./YAML_CONFIGURATION_GUIDE.md) to understand the configuration
- Set up monitoring dashboards in Grafana (if using)
- Test backups: `kubectl create job --from=cronjob/postgres-backup test-backup -n linkding`
- Review [PRODUCTION_IMPROVEMENTS.md](./PRODUCTION_IMPROVEMENTS.md) for additional features

- `https://linkding.local`

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml
kubectl create namespace linkding
kubectl create secret generic postgres-secret \
 --namespace=linkding \
 --from-literal=POSTGRES_USER=linkding \
 --from-literal=POSTGRES_PASSWORD='123' \
 --from-literal=POSTGRES_DB=linkding
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
 -keyout tls.key -out tls.crt \
 -subj "/CN=linkding.local"

kubectl create secret tls linkding-tls \
 --namespace=linkding \
 --cert=tls.crt \
 --key=tls.key

rm tls.key tls.crt

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl patch storageclass local-path \
 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl label namespace kube-system name=kube-system

# Service Accounts

kubectl apply -f service-accounts.yaml

# ConfigMaps (for postgres exporter)

kubectl apply -f postgres-exporter-config.yaml

# PVCs (persistent storage for Postgres and backups)

kubectl apply -f pvcs.yaml

# PostgreSQL StatefulSet

kubectl apply -f postgres.yaml

# Deploy Linkding app

kubectl apply -f deploy.yaml

# Ingress (exposes Linkding)

kubectl apply -f ingress.yaml

# Network policies

kubectl apply -f network-policy.yaml

# Monitoring (if using Prometheus operator)

kubectl apply -f monitoring.yaml
kubectl apply -f linkding-monitoring.yaml

# LDHC health check CronJob

kubectl apply -f ldhc.yaml

kubectl get pods -n linkding
kubectl get svc -n linkding
kubectl get ingress -n linkding
kubectl get pvc -n linkding

kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

kubectl exec -it -n linkding linkding-68948fb578-g9mtv -- python manage.py createsuperuser

kubectl label servicemonitor -n linkding postgres-exporter --overwrite release=prometheus
kubectl label servicemonitor -n linkding linkding --overwrite release=prometheus

kubectl get nodes -o wide
sudo nano /etc/hosts
add 192.168.2.207 linkding.local

kubectl label namespace monitoring name=monitoring
kubectl apply -f linkding-setup/network-policy.yaml

kubectl exec -it -n linkding postgres-0 -- psql -U linkding -d linkding -c "SELECT COUNT(\*) FROM bookmarks_bookmark;"
kubectl exec -it -n linkding postgres-0 -- psql -U linkding -d linkding -c "SELECT title, url FROM bookmarks_bookmark LIMIT 10;"
