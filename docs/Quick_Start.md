# Quick Start Guide

This guide walks you through deploying Linkding on Kubernetes using Kustomize.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured and connected
- Ingress controller installed (nginx-ingress)
- Storage class available (Longhorn or local-path)

### Check Ingress Controller

```bash
kubectl get ingressclass
```

If you don't see `nginx`, install it:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml
```

## Step 1: Create Namespace

```bash
kubectl create namespace linkding
```

## Step 2: Create Secrets

### PostgreSQL Secret (Required)

```bash
# Generate a strong password
POSTGRES_PASSWORD=$(openssl rand -base64 32)
echo "Save this password: $POSTGRES_PASSWORD"

# Create the secret
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_DB=linkding
```

### TLS Certificate (Optional, for HTTPS)

**Option A: Self-Signed Certificate**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=linkding.k8s.home"

kubectl create secret tls linkding-tls \
  --namespace=linkding \
  --cert=tls.crt \
  --key=tls.key

rm tls.key tls.crt
```

**Option B: Use HTTP only** - Skip this step and remove TLS from ingress.yaml.

## Step 3: Configure Domain (If Needed)

The default domain is `linkding.k8s.home`. To change it, edit:

- `base/deployment.yaml` - Update `LD_SERVER_URL` and `LD_ALLOWED_HOSTS`
- `base/ingress.yaml` - Update `host`

## Step 4: Deploy with Kustomize

Choose your storage backend:

### For Longhorn Storage (Recommended)

```bash
# Preview the configuration
kubectl kustomize overlays/longhorn/

# Deploy
kubectl apply -k overlays/longhorn/
```

### For Local-Path Storage

```bash
kubectl apply -k overlays/local-path/
```

### Alternative: Direct Apply

```bash
kubectl apply -f base/namespace.yaml
kubectl apply -f base/service-accounts.yaml
kubectl apply -f base/postgres-config.yaml
kubectl apply -f base/pvcs.yaml
kubectl apply -f base/postgres.yaml
kubectl apply -f base/deployment.yaml
kubectl apply -f base/ingress.yaml
```

## Step 5: Wait for Deployment

```bash
# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n linkding --timeout=300s

# Wait for Linkding
kubectl wait --for=condition=ready pod -l app=linkding -n linkding --timeout=300s
```

## Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n linkding

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# linkding-xxxxx-xxxxx        1/1     Running   0          1m
# postgres-0                  1/1     Running   0          2m

# Check services
kubectl get svc -n linkding

# Check ingress
kubectl get ingress -n linkding
```

## Step 7: Access Linkding

### Via Ingress (Recommended)

Add DNS entry or hosts file:

```bash
# Linux/Mac
echo "192.168.68.200 linkding.k8s.home" | sudo tee -a /etc/hosts

# Windows (run as Administrator)
echo 192.168.68.200 linkding.k8s.home >> C:\Windows\System32\drivers\etc\hosts
```

Then access: `http://linkding.k8s.home`

### Via Port Forward (Testing)

```bash
kubectl port-forward -n linkding svc/linkding 9090:9090
```

Access: `http://localhost:9090`

## Step 8: Create Admin User

On first access, create your admin account in the Linkding web interface.

## Step 9: Deploy Optional Features

### Network Policies

```bash
kubectl apply -f optional/network-policy.yaml
```

### Linkding Health Check (LDHC)

After logging into Linkding:

1. Go to **Settings -> API**
2. Click **Create Token**
3. Copy the token
4. Create the secret:

```bash
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='your-token-here'
```

5. Deploy LDHC:

```bash
kubectl apply -f optional/ldhc.yaml
```

### Prometheus Monitoring

```bash
kubectl apply -f optional/monitoring.yaml
```

### Horizontal Pod Autoscaler

```bash
kubectl apply -f optional/hpa.yaml
```

## Troubleshooting

### Check Logs

```bash
# Linkding logs
kubectl logs -n linkding -l app=linkding --tail=50

# PostgreSQL logs
kubectl logs -n linkding postgres-0 --tail=50

# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

### Check Events

```bash
kubectl get events -n linkding --sort-by='.lastTimestamp'
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity
kubectl exec -it -n linkding postgres-0 -- pg_isready
```

### Restart Deployment

```bash
kubectl rollout restart deployment/linkding -n linkding
```

## Summary Checklist

- [ ] Ingress controller installed
- [ ] Namespace created
- [ ] PostgreSQL secret created
- [ ] Deployed with Kustomize
- [ ] Pods running
- [ ] Ingress accessible
- [ ] Admin user created
- [ ] (Optional) TLS configured
- [ ] (Optional) Network policies deployed
- [ ] (Optional) LDHC deployed
- [ ] (Optional) Monitoring deployed

## Next Steps

- Review [Deployment_Checklist.md](./Deployment_Checklist.md) for detailed configuration
- Set up [backups](./Backup_And_Restore.md)
- Configure [monitoring](./Monitoring_Guide.md)
