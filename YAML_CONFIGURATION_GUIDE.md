# Linkding Kubernetes Configuration Guide

This document provides a comprehensive explanation of all YAML configuration files in this deployment, explaining what each configuration does, why it was chosen, and how it contributes to a production-grade setup.

## Table of Contents

1. [deploy.yaml - Linkding Application Deployment](#deployyaml---linkding-application-deployment)
2. [postgres.yaml - PostgreSQL Database StatefulSet](#postgresyaml---postgresql-database-statefulset)
3. [ingress.yaml - Ingress Controller Configuration](#ingressyaml---ingress-controller-configuration)
4. [network-policy.yaml - Network Security Policies](#network-policyyaml---network-security-policies)
5. [service-accounts.yaml - Service Account Definitions](#service-accountsyaml---service-account-definitions)
6. [pvcs.yaml - Persistent Volume Claims](#pvcsyaml---persistent-volume-claims)
7. [secrets.yaml - Secret Management](#secretsyaml---secret-management)
8. [monitoring.yaml - PostgreSQL Monitoring](#monitoringyaml---postgresql-monitoring)
9. [linkding-monitoring.yaml - Application Monitoring](#linkding-monitoringyaml---application-monitoring)
10. [ldhc.yaml - Linkding Health Check CronJob](#ldhcyaml---linkding-health-check-cronjob)
11. [namespace.yaml - Namespace Definition](#namespaceyaml---namespace-definition)

## deploy.yaml - Linkding Application Deployment

This file defines the main Linkding application deployment, service, and PodDisruptionBudget.

### Deployment Resource

#### Metadata and Labels
```yaml
metadata:
  name: linkding
  namespace: linkding
  labels:
    app: linkding
    version: "1.44.1" # v1.44.1 Latest on Oct 11
```

Labels enable service discovery, monitoring, and network policy matching. The version label helps track which version is deployed.

#### Replicas and High Availability
```yaml
spec:
  replicas: 2  # Increased for High Availability
```

Running 2 replicas provides high availability. If one pod fails or is being updated, the other continues serving traffic. This is essential for production environments where downtime is unacceptable.

#### Rolling Update Strategy
```yaml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

- `maxSurge: 1` - Allows creating 1 extra pod during updates (so you can have 3 pods temporarily)
- `maxUnavailable: 0` - Ensures at least 2 pods are always available during updates

This ensures zero-downtime deployments. The application remains fully available even during updates.

#### Service Account
```yaml
serviceAccountName: linkding
```

Instead of using the default service account (which has broad permissions), we use a dedicated service account. This follows the principle of least privilege - the pod only gets permissions it actually needs.

#### Pod Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 33  # www-data
  runAsGroup: 33
  fsGroup: 33
  seccompProfile:
    type: RuntimeDefault
```

- `runAsNonRoot: true` - Prevents running as root user
- `runAsUser: 33` - Runs as www-data user (standard web server user in Linux)
- `fsGroup: 33` - Sets group ownership of volumes
- `seccompProfile` - Restricts system calls the container can make

Running as non-root significantly reduces the attack surface. If a container is compromised, the attacker doesn't have root privileges. Seccomp profiles limit what system calls can be made, preventing many attack vectors.

#### Termination Grace Period
```yaml
terminationGracePeriodSeconds: 30
```

Gives the container 30 seconds to shut down gracefully when Kubernetes sends a termination signal.

Applications need time to finish processing requests, close database connections, and clean up resources. Without this, Kubernetes might kill the process abruptly, causing data loss or corruption.

#### Pod Anti-Affinity
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - linkding
          topologyKey: kubernetes.io/hostname
```

Tells Kubernetes to prefer scheduling Linkding pods on different nodes.

If you have multiple nodes, this ensures that if one node fails, the other pod on a different node continues running. This is "preferred" (not required) so Kubernetes can still schedule both pods on the same node if needed, but will try to spread them out.

#### Container Image and Pull Policy
```yaml
image: sissbruecker/linkding:1.44.1
imagePullPolicy: IfNotPresent
```

- Uses a specific version (1.44.1) instead of `latest`
- `IfNotPresent` means only pull the image if it's not already on the node

Pinning versions ensures reproducible deployments. You know exactly what version is running. `IfNotPresent` reduces unnecessary image pulls, speeding up pod startup.

#### Environment Variables

##### Database Configuration
```yaml
- name: LD_DB_ENGINE
  value: postgres
- name: LD_DB_HOST
  value: postgres
- name: LD_DB_PORT
  value: '5432'
```

These configure Linkding to use PostgreSQL. The host is `postgres` which resolves to the PostgreSQL service in the same namespace via Kubernetes DNS.

##### Secrets from Kubernetes Secrets
```yaml
- name: LD_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_PASSWORD
```

Pulls the database password from a Kubernetes Secret instead of hardcoding it.

Secrets are encrypted at rest and can be managed separately from the deployment. This is a security best practice.

##### Production Configuration
```yaml
- name: LD_SERVER_URL
  value: 'https://linkding.local'
- name: LD_ALLOWED_HOSTS
  value: 'linkding.local'
- name: LD_LOG_LEVEL
  value: 'INFO'
- name: LD_ENABLE_BACKGROUND_TASKS
  value: 'true'
```

- `LD_SERVER_URL` - Tells Linkding its public URL (for generating absolute URLs)
- `LD_ALLOWED_HOSTS` - Security feature that prevents Host header attacks
- `LD_LOG_LEVEL` - Controls logging verbosity
- `LD_ENABLE_BACKGROUND_TASKS` - Enables async tasks like fetching webpage metadata

These are essential for production. Without `LD_SERVER_URL`, Linkding might generate incorrect URLs. `LD_ALLOWED_HOSTS` prevents security vulnerabilities.

#### Resource Limits and Requests
```yaml
resources:
  requests:
    memory: '512Mi'
    cpu: '100m'
  limits:
    memory: '1Gi'
    cpu: '500m'
```

- **Requests**: Guaranteed resources the pod will get
- **Limits**: Maximum resources the pod can use

- Requests help Kubernetes schedule pods on nodes with enough resources
- Limits prevent a single pod from consuming all resources and starving other pods
- This ensures predictable performance and prevents resource exhaustion

#### Container Security Context
```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

- `allowPrivilegeEscalation: false` - Prevents the process from gaining more privileges
- `readOnlyRootFilesystem: true` - Makes the root filesystem read-only
- `capabilities: drop: ALL` - Removes all Linux capabilities

These are defense-in-depth security measures. Even if an attacker compromises the application, they have minimal privileges and can't modify the filesystem.

#### Health Probes

##### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 9090
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

Checks if the container is still alive. If it fails 3 times, Kubernetes restarts the container.

If the application hangs or deadlocks, Kubernetes will automatically restart it, improving reliability.

##### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 9090
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

Checks if the container is ready to receive traffic. If it fails, Kubernetes removes it from the service load balancer.

Prevents sending traffic to pods that are still starting up or are temporarily unhealthy. This ensures users only hit healthy pods.

##### Startup Probe
```yaml
startupProbe:
  httpGet:
    path: /health
    port: 9090
  failureThreshold: 20
  periodSeconds: 5
  timeoutSeconds: 3
```

Gives the container up to 100 seconds (20 × 5) to start before the liveness probe takes over.

Some applications take time to start. Without this, the liveness probe might kill the container before it finishes starting.

#### Volume Mounts
```yaml
volumeMounts:
  - name: linkding-data
    mountPath: /etc/linkding/data
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache
```

Mounts persistent storage for data and temporary storage for cache/tmp.

- `linkding-data` persists user data across pod restarts
- `tmp` and `cache` use `emptyDir` which is ephemeral (cleared on pod restart) - this is fine for temporary files

### Service Resource

```yaml
apiVersion: v1
kind: Service
metadata:
  name: linkding
  namespace: linkding
spec:
  type: ClusterIP
  selector:
    app: linkding
  ports:
    - name: http
      port: 9090
      targetPort: 9090
      protocol: TCP
```

Creates a stable network endpoint that load balances traffic to all Linkding pods.
 
- Pods have ephemeral IPs that change on restart
- The Service provides a stable DNS name (`linkding.linkding.svc.cluster.local`)
- `ClusterIP` means it's only accessible within the cluster (external access via Ingress)

### PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: linkding-pdb
  namespace: linkding
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: linkding
```

Prevents Kubernetes from voluntarily evicting pods if it would leave fewer than 1 pod running.

During node maintenance or cluster updates, Kubernetes might try to evict pods. The PDB ensures at least 1 pod always runs, maintaining availability.

---

## postgres.yaml - PostgreSQL Database StatefulSet

This file defines the PostgreSQL database as a StatefulSet (instead of Deployment), along with monitoring, backups, and services.

### Why StatefulSet Instead of Deployment?

**Deployments** are for stateless applications where pods are interchangeable. **StatefulSets** are for stateful applications where:
- Pods have stable identities (names, hostnames)
- Storage is persistent and tied to specific pods
- Pods are created and deleted in order

**Why for PostgreSQL**: Databases are stateful. Each pod has its own data, and you want predictable pod names and stable storage.

### StatefulSet Configuration

#### Service Name
```yaml
spec:
  serviceName: postgres
```

**What it does**: Creates a headless service (ClusterIP: None) that provides stable DNS names for pods.

**Why**: StatefulSet pods get predictable DNS names like `postgres-0.postgres.linkding.svc.cluster.local`, which is important for database connections.

#### Volume Claim Templates
```yaml
volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
```

**What it does**: Automatically creates a PersistentVolumeClaim for each StatefulSet pod.

**Why**: Each pod gets its own persistent storage. If the pod is recreated, it gets the same storage back. This is essential for databases.

### PostgreSQL Container

#### Security Context
```yaml
securityContext:
  runAsUser: 999
  runAsGroup: 999
  runAsNonRoot: true
  fsGroup: 999
```

**Why**: PostgreSQL runs as user 999 (postgres user) instead of root. This is the standard PostgreSQL user ID.

#### Capabilities
```yaml
capabilities:
  drop:
    - ALL
  add:
    - CHOWN
    - DAC_OVERRIDE
    - FOWNER
    - SETGID
    - SETUID
```

**What it does**: Removes all Linux capabilities, then adds back only what PostgreSQL needs.

**Why**: PostgreSQL needs these specific capabilities to manage file ownership and permissions. We only grant what's necessary.

#### Authentication Configuration
```yaml
- name: POSTGRES_INITDB_ARGS
  value: "--auth-host=scram-sha-256"
- name: POSTGRES_HOST_AUTH_METHOD
  value: "scram-sha-256"
```

**What it does**: Configures PostgreSQL to use SCRAM-SHA-256 authentication instead of the weaker MD5.

**Why**: SCRAM-SHA-256 is more secure and is the recommended authentication method for PostgreSQL.

#### Health Probes with pg_isready
```yaml
livenessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

**What it does**: Uses PostgreSQL's `pg_isready` command to check if the database is accepting connections.

**Why**: This is more reliable than a simple TCP check - it verifies PostgreSQL is actually ready, not just listening.

### PostgreSQL Exporter (Sidecar Container)

```yaml
- name: postgres-exporter
  image: prometheuscommunity/postgres-exporter:v0.15.0
```

**What it does**: Runs a sidecar container that exports PostgreSQL metrics for Prometheus.

**Why**: Enables monitoring of database performance, connection counts, query times, etc. Essential for production observability.

#### Exporter Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534  # nobody
  readOnlyRootFilesystem: true
```

**Why**: The exporter doesn't need to write anything, so it runs as a non-privileged user with a read-only filesystem.

### Services

#### Headless Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None  # Headless service
```

**What it does**: Creates a headless service (no ClusterIP) that returns individual pod IPs.

**Why**: StatefulSets need headless services to provide stable DNS names for each pod. This is required for StatefulSet functionality.

#### Read Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-read
spec:
  type: ClusterIP
```

**What it does**: Creates a regular service for read connections.

**Why**: Provides a stable endpoint for applications to connect. If you later add read replicas, you can route read traffic to this service.

### Backup CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: '0 2 * * *'  # 2 AM daily
```

**What it does**: Runs a backup job every day at 2 AM.

**Why**: Regular backups are essential for disaster recovery. The schedule avoids peak usage times.

#### Backup Script Features

##### Error Handling
```bash
set -euo pipefail
```

**What it does**: 
- `-e` - Exit on any error
- `-u` - Error on undefined variables
- `-o pipefail` - Return exit code of failed command in a pipeline

**Why**: Ensures the job fails properly if anything goes wrong, allowing Kubernetes to track failures.

##### Backup Verification
```bash
if gzip -t "$BACKUP_FILE" 2>/dev/null; then
  echo "Backup integrity verified"
else
  echo "ERROR: Backup file is corrupted!"
  rm -f "$BACKUP_FILE"
  exit 1
fi
```

**What it does**: Tests if the compressed backup file is valid before considering the backup successful.

**Why**: A corrupted backup is worse than no backup - it gives false confidence. This catches corruption immediately.

##### Retention Policy
```bash
find "$BACKUP_DIR" -name "linkding_backup_*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
```

**What it does**: Deletes backups older than the retention period (7 days by default).

**Why**: Prevents backup storage from growing indefinitely while keeping recent backups for recovery.

---

## ingress.yaml - Ingress Controller Configuration

The Ingress resource exposes the Linkding service to the internet through an ingress controller (like nginx-ingress).

### Security Headers

#### Force SSL Redirect
```yaml
nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

**What it does**: Automatically redirects HTTP traffic to HTTPS.

**Why**: Ensures all traffic is encrypted. Critical for protecting user credentials and data.

#### SSL Protocols and Ciphers
```yaml
nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256,..."
```

**What it does**: Restricts which TLS versions and cipher suites can be used.

**Why**: Disables weak/outdated protocols (TLS 1.0, 1.1) and ciphers that are vulnerable to attacks.

#### Security Headers via Configuration Snippet
```yaml
nginx.ingress.kubernetes.io/configuration-snippet: |
  more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
  more_set_headers "X-Frame-Options: DENY";
  more_set_headers "X-Content-Type-Options: nosniff";
  ...
```

**What each header does**:
- **Strict-Transport-Security (HSTS)**: Tells browsers to always use HTTPS for 1 year
- **X-Frame-Options: DENY**: Prevents the site from being embedded in iframes (prevents clickjacking)
- **X-Content-Type-Options: nosniff**: Prevents MIME type sniffing attacks
- **X-XSS-Protection**: Enables browser XSS filtering
- **Referrer-Policy**: Controls what referrer information is sent
- **Permissions-Policy**: Restricts browser features (geolocation, camera, etc.)

**Why**: These headers protect against common web vulnerabilities and attacks. They're security best practices recommended by OWASP.

### Rate Limiting

```yaml
nginx.ingress.kubernetes.io/limit-rps: "100"
nginx.ingress.kubernetes.io/limit-connections: "10"
```

**What it does**: 
- Limits to 100 requests per second per IP
- Limits to 10 concurrent connections per IP

**Why**: Prevents abuse, DDoS attacks, and ensures fair resource usage. Protects the application from being overwhelmed.

### Timeouts and Buffers

```yaml
nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
nginx.ingress.kubernetes.io/proxy-body-size: "10m"
nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
```

**What it does**: Configures how long nginx waits for connections, sends data, reads responses, and limits request body size.

**Why**: Prevents slow clients from holding connections open indefinitely and protects against large request attacks.

### TLS Configuration

```yaml
spec:
  tls:
    - hosts:
        - linkding.local
      secretName: linkding-tls
```

**What it does**: Configures TLS encryption using a certificate stored in a Kubernetes Secret.

**Why**: Encrypts traffic between clients and the ingress controller. The certificate should be from a trusted CA (or use cert-manager for automatic Let's Encrypt certificates).

---

## network-policy.yaml - Network Security Policies

Network Policies implement network segmentation and micro-segmentation, controlling which pods can communicate with each other.

### Linkding App Policy

#### Ingress Rules
```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
    ports:
      - protocol: TCP
        port: 9090
```

**What it does**: Only allows incoming traffic from the ingress-nginx namespace on port 9090.

**Why**: Prevents other pods from directly accessing Linkding. Only traffic through the ingress controller is allowed.

#### Egress Rules
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
    ports:
      - protocol: UDP
        port: 53
  - to:
      - podSelector:
          matchLabels:
            app: postgres
    ports:
      - protocol: TCP
        port: 5432
  - to:
      - namespaceSelector: {}
    ports:
      - protocol: TCP
        port: 443
      - protocol: TCP
        port: 80
```

**What it does**: Allows Linkding to:
- Query DNS (kube-system namespace)
- Connect to PostgreSQL
- Make outbound HTTP/HTTPS requests (for fetching webpage metadata)

**Why**: Implements the principle of least privilege. Linkding can only access what it needs - the database and external websites for metadata fetching.

### PostgreSQL Policy

```yaml
ingress:
  - from:
      - podSelector:
          matchLabels:
            app: linkding
    ports:
      - protocol: TCP
        port: 5432
  - from:
      - podSelector:
          matchLabels:
            app: postgres-backup
    ports:
      - protocol: TCP
        port: 5432
  - from:
      - namespaceSelector:
          matchLabels:
            name: monitoring
    ports:
      - protocol: TCP
        port: 9187
```

**What it does**: Only allows:
- Linkding pods to connect to the database
- Backup jobs to connect to the database
- Prometheus (in monitoring namespace) to scrape metrics

**Why**: Database should only accept connections from authorized sources. This prevents unauthorized access even if an attacker compromises another pod.

### Default Deny

**Important**: Network Policies work as whitelists. If a Network Policy exists for a pod, only explicitly allowed traffic is permitted. All other traffic is denied by default.

**Why**: This is a security best practice - deny by default, allow only what's necessary.

---

## service-accounts.yaml - Service Account Definitions

Service Accounts are Kubernetes identities that pods use to authenticate to the API server and other services.

### Why Dedicated Service Accounts?

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: linkding
  namespace: linkding
```

**What it does**: Creates a service account specifically for Linkding pods.

**Why**: 
- The default service account has broad permissions
- Dedicated service accounts allow fine-grained RBAC (Role-Based Access Control)
- You can grant only the permissions each component needs
- Better security and auditability

**Current setup**: These service accounts are minimal (no RBAC roles yet), but they're ready for when you need to add permissions (e.g., for reading ConfigMaps, Secrets, or accessing external services).

---

## pvcs.yaml - Persistent Volume Claims

PVCs request storage from the cluster's storage system.

### Linkding Data PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: linkding-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

**What it does**: Requests 1GB of storage that can be mounted by one pod at a time.

**Why**: 
- `ReadWriteOnce` means only one pod can mount it (sufficient for single-instance or when using shared storage)
- Persists Linkding's data directory across pod restarts
- Without this, data would be lost when pods restart

### PostgreSQL Backup PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backup-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

**What it does**: Provides storage for database backups.

**Why**: Backups need to persist independently of the database pod. This allows backups to survive even if the database pod is deleted.

### Storage Classes

```yaml
# storageClassName: fast-ssd  # Uncomment and set your storage class
```

**What it does**: Specifies which storage class to use (SSD, HDD, network storage, etc.).

**Why**: Different storage classes have different performance characteristics and costs. You can use fast SSD for the database and slower storage for backups.

**Note**: PostgreSQL StatefulSet uses `volumeClaimTemplates`, so storage is managed automatically. The manual PVCs are for Linkding data and backups.

---

## secrets.yaml - Secret Management

Secrets store sensitive data like passwords, API keys, and certificates.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: linkding
type: Opaque
stringData:
  POSTGRES_USER: linkding
  POSTGRES_PASSWORD: "123"
  POSTGRES_DB: linkding
```

### Why Secrets Instead of Environment Variables?

**Security**:
- Secrets are encrypted at rest (if encryption at rest is enabled)
- Not visible in pod descriptions or environment variable dumps
- Can be managed separately from deployments
- Support rotation without redeploying

### Current Password

**IMPORTANT**: The password "123" is a placeholder. **You must change this to a strong password before deploying to production.**

### Best Practices

1. **Use strong passwords**: Generate random, complex passwords
2. **Rotate regularly**: Change passwords periodically
3. **Use external secret management**: Consider tools like:
   - Sealed Secrets (encrypts secrets for Git)
   - External Secrets Operator (pulls from Vault, AWS Secrets Manager, etc.)
   - cert-manager (for TLS certificates)

---

## monitoring.yaml - PostgreSQL Monitoring

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-exporter
  namespace: linkding
  labels:
    release: prom-stack
spec:
  selector:
    matchLabels:
      app: postgres
  endpoints:
    - port: exporter
      interval: 30s
```

**What it does**: Tells Prometheus to scrape metrics from the postgres-exporter sidecar container every 30 seconds.

**Why**: 
- Enables monitoring of database health, performance, and resource usage
- Essential for production observability
- Allows setting up alerts for database issues

**How it works**: 
- Prometheus Operator watches for ServiceMonitor resources
- It automatically configures Prometheus to scrape the endpoints
- The `release: prom-stack` label tells Prometheus which instance to use (if you have multiple)

---

## linkding-monitoring.yaml - Application Monitoring

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: linkding
  namespace: linkding
  labels:
    app: linkding
    release: prom-stack
spec:
  selector:
    matchLabels:
      app: linkding
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
      scheme: http
```

**What it does**: Configures Prometheus to scrape Linkding's metrics endpoint.

**Why**: 
- Monitors application health, request rates, response times
- Enables alerting on application issues
- Provides metrics for Grafana dashboards

**Note**: This assumes Linkding exposes a `/metrics` endpoint. If it doesn't, you may need to add a metrics exporter sidecar or use a different monitoring approach.

---

## ldhc.yaml - Linkding Health Check CronJob

LDHC (Linkding Health Check) is a tool that checks bookmarks for broken links.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ldhc
spec:
  schedule: '0 3 * * 0'  # Weekly, Sundays at 3 AM
  concurrencyPolicy: Forbid
```

### Schedule Format

The schedule uses cron syntax: `minute hour day-of-month month day-of-week`
- `0 3 * * 0` = Every Sunday at 3:00 AM
- `0 0 * * *` = Every day at midnight
- `*/30 * * * *` = Every 30 minutes

### Concurrency Policy

```yaml
concurrencyPolicy: Forbid
```

**What it does**: Prevents multiple instances of the job from running simultaneously.

**Why**: If a job takes longer than expected and the next scheduled time arrives, this prevents overlapping runs that could cause conflicts or duplicate work.

### Active Deadline

```yaml
activeDeadlineSeconds: 3600  # 1 hour timeout
```

**What it does**: Kills the job if it runs longer than 1 hour.

**Why**: Prevents jobs from running indefinitely if they hang or get stuck.

### Image Version Pinning

```yaml
image: ghcr.io/sebw/ldhc:v1.0.0  # Update with actual version
```

**IMPORTANT**: This is a placeholder version. You should:
1. Check what versions are available
2. Use a specific version instead of `latest`
3. Update periodically for security patches

**Why**: Pinning versions ensures reproducible runs and prevents unexpected changes from breaking your setup.

---

## namespace.yaml - Namespace Definition

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: linkding
  labels:
    name: linkding
```

**What it does**: Creates a namespace to isolate Linkding resources from other applications.

**Why**:
- **Isolation**: Resources in different namespaces are isolated
- **Organization**: Groups related resources together
- **Access Control**: RBAC can be applied per-namespace
- **Network Policies**: Network policies can use namespace labels for matching
- **Resource Quotas**: Can set limits per namespace

### Namespace Labels

The labels on the namespace are used by:
- **Network Policies**: To allow/deny traffic based on namespace
- **Service Monitors**: To configure Prometheus scraping
- **RBAC**: For role bindings

**Note**: The commented labels (`name: ingress-nginx`, `name: monitoring`) should be uncommented and set to match your actual setup if you want network policies to work correctly.

---

## Summary: Production-Grade Principles Applied

This deployment follows several key production-grade principles:

### 1. **Security**
- Non-root containers
- Minimal capabilities
- Network policies (micro-segmentation)
- Secrets management
- Security headers
- TLS encryption

### 2. **Reliability**
- Multiple replicas
- Health probes
- Pod disruption budgets
- Graceful shutdowns
- Backup and recovery

### 3. **Observability**
- Health probes
- Metrics endpoints
- ServiceMonitors for Prometheus
- Structured logging

### 4. **Maintainability**
- Version pinning
- Clear labeling
- Documentation
- Separation of concerns

### 5. **Performance**
- Resource limits
- Rate limiting
- Proper timeouts
- Efficient storage

### 6. **Scalability**
- Horizontal scaling (multiple replicas)
- Resource requests/limits
- Pod anti-affinity

Each configuration decision serves one or more of these principles, creating a robust, secure, and maintainable production deployment.

