# Ingress Controller Setup Guide

## What is an Ingress Controller?

An Ingress Controller is a component that exposes your Kubernetes services to the outside world. It handles:
- Routing traffic from the internet to your pods
- HTTPS/TLS termination (SSL certificates)
- Load balancing
- Security headers

**Think of it as**: A reverse proxy that sits in front of your applications.

## Installation (Simple Method)

### Using Helm

```bash
# Add the nginx-ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install nginx-ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort
```

## Verify Installation

After installation, check that it's running:

```bash
# Check if nginx-ingress pods are running
kubectl get pods -n ingress-nginx

# Check ingress class
kubectl get ingressclass

# You should see "nginx" in the output
```

Expected output:
```
NAME     CONTROLLER             PARAMETERS   AGE
nginx    k8s.io/ingress-nginx   <none>       1m
```

## For Single-Node Clusters (Your Setup)

Since you have a single-node cluster, you have a few options:

### Option A: NodePort (Simplest for Local)

The ingress controller will use NodePort, which means you can access it via:
- `http://<your-server-ip>:<nodeport>`
- Or configure your router to forward port 80/443 to your server

Find the NodePort:
```bash
kubectl get svc -n ingress-nginx
```

Look for the `ingress-nginx-controller` service and note the port (e.g., `80:3xxxx/TCP`).

### Option B: HostNetwork (For Direct Access)

If you want to access directly on ports 80/443:

```bash
# Install with hostNetwork enabled
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.service.type=ClusterIP
```

**Note**: This requires running with appropriate privileges and may conflict with other services using ports 80/443.

### Option C: LoadBalancer (If You Have One)

If you have a load balancer (like MetalLB), you can use:
```bash
--set controller.service.type=LoadBalancer
```

## Configuration for Your Setup

Your `ingress.yaml` is already configured for nginx:

```yaml
spec:
  ingressClassName: nginx  # This matches nginx-ingress
```

**No changes needed!** Just make sure nginx-ingress is installed.

## Testing

After installing nginx-ingress and deploying Linkding:

1. **Check ingress status**:
   ```bash
   kubectl get ingress -n linkding
   ```

2. **Check nginx logs** (if issues):
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

3. **Access Linkding**:
   - Via your domain (if DNS is set up)
   - Via `linkding.local` (if added to hosts file)
   - Via NodePort: `http://<server-ip>:<nodeport>`

## Quick Install Command

For your single-node cluster, use this:

```bash
# Install nginx-ingress (simplest method)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Verify
kubectl get ingressclass
```