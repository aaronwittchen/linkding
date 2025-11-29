# Pre-Deployment Checklist

### 1. Domain Names (3 files)

**For Local Network Use (No Public Domain):**

If running this on local network (like a homeserver):

#### Option A: Use `linkding.local` (Recommended for Local)
Keep `linkding.local` as-is - it's perfect for local use! Just make sure to:
1. Add it to your `/etc/hosts` file on devices you want to access it from:
   ```bash
   # On Linux/Mac: /etc/hosts
   # On Windows: C:\Windows\System32\drivers\etc\hosts
   
   <your-server-ip>  linkding.local
   ```
   Replace `<your-server-ip>` with your homeserver's IP address (e.g., `192.168.1.100`)

2. The files are already configured with `linkding.local` - no changes needed!

#### Option B: Use Your Server's IP Address
If you prefer using IP directly, replace `linkding.local` with your server's IP:

**deploy.yaml** (lines 81, 83):
```yaml
- name: LD_SERVER_URL
  value: 'http://192.168.1.100'  # Use your server IP (HTTP, not HTTPS for local)
- name: LD_ALLOWED_HOSTS
  value: '192.168.1.100'  # Use your server IP
```

**ingress.yaml** (lines 36, 39):
```yaml
tls:
  - hosts:
      - 192.168.1.100  # Use your server IP (or remove TLS section for HTTP)
rules:
  - host: 192.168.1.100  # Use your server IP
```

**ldhc.yaml** (line 42):
```yaml
- name: API_URL
  value: 'http://192.168.1.100/api/bookmarks'  # Use your server IP
```

**Note**: If using IP address, you might want to remove TLS/HTTPS or use a self-signed certificate.

#### Option C: Use a Public Domain (If You Have One)
If you have a domain name (like `linkding.example.com`), replace `linkding.local` with it in all three files.

### 3. Secrets (DO NOT COMMIT TO GIT!)
Create these secrets on your homeserver using kubectl:

```bash
# PostgreSQL secret
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD='<generate-strong-password>' \
  --from-literal=POSTGRES_DB=linkding

# Generate strong password:
openssl rand -base64 32

# Linkding API secret for LDHC
# IMPORTANT: Create this AFTER deploying Linkding and generating the API token
# See "Post-Deployment" section below for instructions
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='<generate-token-from-linkding-ui>'
```

**Note**: The `linkding-api-secret` should be created **after** you've deployed Linkding and generated an API token from the UI (Settings → API). You can create a placeholder secret first, then update it later.

### 4. TLS Certificate
Create TLS secret for HTTPS:

```bash
# Option 1: Self-signed (for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=your-domain.com"

kubectl create secret tls linkding-tls \
  --namespace=linkding \
  --cert=tls.crt \
  --key=tls.key

# Option 2: Use cert-manager for Let's Encrypt (recommended for production)
```

## Important - Check Your Cluster Setup

### 5. Storage Class
Check if you need to specify a storage class:

```bash
# Check available storage classes
kubectl get storageclass
```

If you have a specific storage class, uncomment and update in:
- **postgres.yaml** (line 188): `storageClassName: fast-ssd`
- **pvcs.yaml**: Uncomment `storageClassName` lines

### 6. Ingress Controller Class
Check your ingress controller:

```bash
# Check ingress classes
kubectl get ingressclass
```

Update **ingress.yaml** (line 33) if your class name is different:
```yaml
ingressClassName: nginx  # Change if different
```

### 7. Namespace Labels for Network Policies
Check your namespace labels:

```bash
# Check your ingress namespace labels
kubectl get namespace ingress-nginx --show-labels  # or your ingress namespace

# Check your monitoring namespace labels
kubectl get namespace monitoring --show-labels  # or your monitoring namespace
```

Update **namespace.yaml** to match:
```yaml
labels:
  name: linkding
  # Uncomment and set based on your cluster:
  # name: ingress-nginx  # If your ingress namespace has this label
  # name: monitoring     # If your monitoring namespace has this label
```

Update **network-policy.yaml** (lines 18, 85) to match your namespace labels:
```yaml
- namespaceSelector:
    matchLabels:
      name: ingress-nginx  # Update to match your ingress namespace label
```

### 8. Prometheus Operator Release Label
If using Prometheus Operator, check the release label:

```bash
kubectl get prometheus -A
```

Update in:
- **monitoring.yaml** (line 8): `release: prom-stack`
- **linkding-monitoring.yaml** (line 8): `release: prom-stack`

Change `prom-stack` to match your actual Prometheus release name.

## Optional - Nice to Have

### 9. Resource Limits
Review and adjust if needed based on your cluster resources:
- **deploy.yaml**: Memory/CPU requests and limits
- **postgres.yaml**: Memory/CPU requests and limits

### 10. Backup Retention
Adjust backup retention period in **postgres.yaml** (line 274):
```yaml
- name: BACKUP_RETENTION_DAYS
  value: "7"  # Adjust as needed
```

### 11. Replica Count
Currently set to 2 replicas for Linkding. Adjust in **deploy.yaml** (line 10) if needed:
```yaml
replicas: 2  # Adjust based on your needs
```

## Verification Commands

After updating, verify your configuration:

```bash
# Check all files for your domain
grep -r "linkding.local" . --exclude-dir=.git

# Verify YAML syntax
kubectl apply --dry-run=client -f deploy.yaml
kubectl apply --dry-run=client -f postgres.yaml
kubectl apply --dry-run=client -f ingress.yaml

# Check for placeholder values
grep -r "CHANGE_ME\|TODO\|FIXME\|placeholder" . --exclude-dir=.git
```

## Summary

**Must do before deployment:**
1. Update domain names (3 files)
2. Update LDHC image version
3. Create secrets (on homeserver, not in Git)
4. Create TLS certificate secret
5. Check/update storage classes
6. Check/update ingress class
7. Check/update namespace labels
8. Check/update Prometheus release label

**After first deployment:**
- Generate API token in Linkding UI (Settings → API)
- Update `linkding-api-secret` with the token (see command below)
- Verify backups are working
- Set up monitoring dashboards (if using Grafana)

**LDHC (Linkding Health Check) Setup:**
After deploying Linkding, you need to configure the API token for LDHC to work:

1. Access Linkding UI → **Settings → API**
2. Click **"Create Token"** or **"Generate Token"**
3. Copy the generated token
4. Update the secret:
   ```bash
   kubectl create secret generic linkding-api-secret \
     --namespace=linkding \
     --from-literal=API_TOKEN='<paste-your-token-here>' \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

**What LDHC Does:**
- Automatically checks all bookmarks weekly for broken links
- Tags broken links with `@HEALTH_HTTP_<code>`, `@HEALTH_DNS`, or `@HEALTH_other`
- Finds duplicate bookmarks
- Removes health tags when sites come back online

**Repository**: [sebw/linkding-healthcheck](https://github.com/sebw/linkding-healthcheck)  
**Schedule**: Runs weekly on Sundays at 8/9 PM CET
