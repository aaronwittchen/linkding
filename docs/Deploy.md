# Deploy Linkding

Step-by-step guide to deploy Linkding on your Kubernetes cluster.

## Prerequisites

- Kubernetes cluster running
- Longhorn storage class configured
- Nginx Ingress controller installed
- Pi-hole DNS (or hosts file configured)
- kubectl connected to your cluster

## Deployment Steps

### Step 1: Create Namespace and Secret

```bash
# Create namespace
kubectl create namespace linkding

# Create PostgreSQL secret with random password
kubectl create secret generic postgres-secret \
  --namespace=linkding \
  --from-literal=POSTGRES_USER=linkding \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 32)" \
  --from-literal=POSTGRES_DB=linkding
```

### Step 2: Deploy with Kustomize

```bash
# Navigate to linkding directory
cd /path/to/linkding

# Deploy using Longhorn overlay
kubectl apply -k overlays/longhorn/
```

### Step 3: Wait for Pods to be Ready

```bash
# Wait for PostgreSQL (may take 1-2 minutes)
kubectl wait --for=condition=ready pod -l app=postgres -n linkding --timeout=300s

# Wait for Linkding
kubectl wait --for=condition=ready pod -l app=linkding -n linkding --timeout=300s
```

### Step 4: Configure DNS

#### Option A: Pi-hole (Recommended)

1. Go to `http://192.168.68.10/admin`
2. Navigate to **Local DNS** → **DNS Records**
3. Add record:
   - Domain: `linkding.k8s.home`
   - IP: `192.168.68.200`

#### Option B: Hosts File

```bash
# Linux/Mac
echo "192.168.68.200 linkding.k8s.home" | sudo tee -a /etc/hosts

# Windows (run as Administrator)
echo 192.168.68.200 linkding.k8s.home >> C:\Windows\System32\drivers\etc\hosts
```

### Step 5: Access Linkding

Open your browser and go to:

```
http://linkding.k8s.home
```

Create your admin account on first access.

## Verify Deployment

```bash
# Check all resources
kubectl get all -n linkding

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# pod/linkding-xxxxxxxxx-xxxxx    1/1     Running   0          2m
# pod/postgres-0                  1/1     Running   0          3m
#
# NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)
# service/linkding   ClusterIP   10.x.x.x         <none>        9090/TCP
# service/postgres   ClusterIP   None             <none>        5432/TCP
#
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/linkding   1/1     1            1           2m
#
# NAME                                  READY   AGE
# statefulset.apps/postgres             1/1     3m

# Check ingress
kubectl get ingress -n linkding

# Check PVCs
kubectl get pvc -n linkding
```

## Optional Components

### Network Policies

Restrict network traffic for security:

```bash
kubectl apply -f optional/network-policy.yaml
```

### Horizontal Pod Autoscaler

Enable auto-scaling (requires metrics-server):

```bash
kubectl apply -f optional/hpa.yaml
```

### Linkding Health Check (LDHC)

Automatically check bookmarks for broken links:

1. Log into Linkding
2. Go to **Settings** → **API**
3. Click **Create Token**
4. Copy the token
5. Create the secret:

```bash
kubectl create secret generic linkding-api-secret \
  --namespace=linkding \
  --from-literal=API_TOKEN='your-token-here'
```

6. Deploy LDHC:

```bash
kubectl apply -f optional/ldhc.yaml
```

### Prometheus Monitoring

If you have Prometheus Operator installed:

```bash
kubectl apply -f optional/monitoring.yaml
```

## Troubleshooting

### Check Logs

```bash
# Linkding logs
kubectl logs -n linkding -l app=linkding --tail=100

# PostgreSQL logs
kubectl logs -n linkding postgres-0 --tail=100

# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

### Check Events

```bash
kubectl get events -n linkding --sort-by='.lastTimestamp'
```

### Pod Not Starting

```bash
# Describe pod for details
kubectl describe pod -n linkding -l app=linkding
kubectl describe pod -n linkding postgres-0
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity
kubectl exec -it -n linkding postgres-0 -- pg_isready

# Check PostgreSQL is accepting connections
kubectl exec -it -n linkding postgres-0 -- psql -U linkding -d linkding -c "SELECT 1"
```

### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress -n linkding linkding-ingress

# Test with port-forward
kubectl port-forward -n linkding svc/linkding 9090:9090
# Then access http://localhost:9090
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n linkding

# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system
```

## Uninstall

To remove Linkding completely:

```bash
# Delete all resources
kubectl delete -k overlays/longhorn/

# Delete optional components (if deployed)
kubectl delete -f optional/network-policy.yaml
kubectl delete -f optional/ldhc.yaml
kubectl delete -f optional/hpa.yaml
kubectl delete -f optional/monitoring.yaml

# Delete secrets
kubectl delete secret postgres-secret -n linkding
kubectl delete secret linkding-api-secret -n linkding

# Delete namespace (removes everything)
kubectl delete namespace linkding

# Delete PVCs (WARNING: deletes all data!)
kubectl delete pvc --all -n linkding
```

## Backup and Restore

### Manual Backup

```bash
# Trigger backup job
kubectl create job --from=cronjob/postgres-backup manual-backup -n linkding

# Check backup completed
kubectl get jobs -n linkding

# View backup files
kubectl exec -n linkding postgres-0 -- ls -la /var/lib/postgresql/backups/
```

### Restore from Backup

See [Backup_And_Restore.md](./Backup_And_Restore.md) for detailed restore procedures.

## Summary Checklist

- [ ] Namespace created
- [ ] PostgreSQL secret created
- [ ] Deployed with Kustomize
- [ ] PostgreSQL pod running
- [ ] Linkding pod running
- [ ] DNS configured (Pi-hole or hosts file)
- [ ] Linkding accessible via browser
- [ ] Admin account created
- [ ] (Optional) Network policies deployed
- [ ] (Optional) LDHC deployed
- [ ] (Optional) Monitoring deployed
