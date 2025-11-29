# Monitoring Guide for Linkding with Prometheus & Grafana

This guide shows you what you can monitor for your Linkding deployment using Prometheus and Grafana.

## What You Can Monitor

### 1. **PostgreSQL Database Metrics**

Your setup already includes the PostgreSQL exporter, which provides:

#### Database Health
- **Connection counts**: Active connections, max connections, connection pool usage
- **Database size**: Total database size, table sizes, growth over time
- **Query performance**: Slow queries, query duration, transactions per second
- **Locks**: Deadlocks, lock waits, blocked queries
- **Replication lag**: (If you add replicas later)
- **Cache hit ratio**: How often data is served from cache vs disk

#### Key Metrics to Watch
```
# Connection metrics
pg_stat_database_numbackends          # Active connections
pg_stat_database_xact_commit         # Committed transactions
pg_stat_database_xact_rollback       # Rolled back transactions

# Performance metrics
pg_stat_database_blks_hit            # Cache hits
pg_stat_database_blks_read           # Disk reads
pg_stat_database_tup_fetched         # Rows fetched
pg_stat_database_tup_inserted        # Rows inserted

# Database size
pg_database_size_bytes               # Database size in bytes
```

### 2. **Linkding Application Metrics**

#### Kubernetes Pod Metrics (Already Available)
- **CPU usage**: Per pod, per container
- **Memory usage**: Current usage vs limits
- **Network traffic**: Bytes in/out per pod
- **Restart count**: How often pods restart
- **Uptime**: How long pods have been running

#### Application-Specific Metrics (If Linkding Exposes Them)
- **HTTP requests**: Request rate, response times, status codes
- **Bookmark operations**: Bookmarks created, updated, deleted
- **API calls**: API request rate, authentication failures
- **Background tasks**: Task completion rate, failures

### 3. **Infrastructure Metrics**

#### Node Metrics (From Node Exporter)
- **CPU**: Usage, load average, CPU time per core
- **Memory**: Used, available, swap usage
- **Disk**: I/O operations, disk space, read/write latency
- **Network**: Bandwidth, packet errors, connection counts

#### Kubernetes Metrics
- **Pod status**: Running, pending, failed pods
- **Resource quotas**: CPU/memory requests vs limits
- **PVC usage**: Storage used vs allocated
- **Service endpoints**: Healthy vs unhealthy endpoints

## Grafana Dashboard Ideas

### Dashboard 1: Linkding Overview

**Panels to include:**
1. **Application Status**
   - Pod status (up/down)
   - Request rate (requests/second)
   - Error rate (4xx, 5xx responses)
   - Response time (p50, p95, p99)

2. **Resource Usage**
   - CPU usage per pod (gauge)
   - Memory usage per pod (gauge)
   - Network I/O (graph)

3. **Bookmark Statistics** (if available via metrics)
   - Total bookmarks
   - Bookmarks added today/week
   - Most active tags

### Dashboard 2: PostgreSQL Database

**Panels to include:**
1. **Database Health**
   - Active connections (gauge)
   - Database size over time (graph)
   - Cache hit ratio (gauge - should be >95%)

2. **Performance**
   - Transactions per second (graph)
   - Query duration (histogram)
   - Slow queries count (graph)
   - Deadlocks (counter)

3. **Storage**
   - Database size (graph)
   - Table sizes (pie chart)
   - Disk I/O (graph)

4. **Connections**
   - Connection pool usage (gauge)
   - Connection wait time (graph)
   - Idle vs active connections (stacked graph)

### Dashboard 3: Infrastructure

**Panels to include:**
1. **Node Resources**
   - CPU usage (graph)
   - Memory usage (graph)
   - Disk I/O (graph)
   - Network traffic (graph)

2. **Kubernetes Resources**
   - Pod count by namespace (table)
   - Resource requests vs limits (bar chart)
   - PVC usage (table)

3. **Storage**
   - PVC sizes (table)
   - Storage growth rate (graph)
   - Available storage (gauge)

## Useful Prometheus Queries

### Linkding Pod Metrics

```promql
# CPU usage per Linkding pod
rate(container_cpu_usage_seconds_total{namespace="linkding", pod=~"linkding-.*"}[5m])

# Memory usage per Linkding pod
container_memory_working_set_bytes{namespace="linkding", pod=~"linkding-.*"}

# Pod restarts
kube_pod_container_status_restarts_total{namespace="linkding", pod=~"linkding-.*"}

# Pod uptime
time() - kube_pod_start_time{namespace="linkding", pod=~"linkding-.*"}
```

### PostgreSQL Metrics

```promql
# Active connections
pg_stat_database_numbackends{datname="linkding"}

# Database size
pg_database_size_bytes{datname="linkding"}

# Cache hit ratio (should be >95%)
rate(pg_stat_database_blks_hit{datname="linkding"}[5m]) / 
(rate(pg_stat_database_blks_hit{datname="linkding"}[5m]) + 
 rate(pg_stat_database_blks_read{datname="linkding"}[5m])) * 100

# Transactions per second
rate(pg_stat_database_xact_commit{datname="linkding"}[5m]) + 
rate(pg_stat_database_xact_rollback{datname="linkding"}[5m])

# Slow queries (queries taking >1 second)
pg_stat_statements_mean_exec_time{datname="linkding"} > 1
```

### Infrastructure Metrics

```promql
# Node CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# PVC usage
kubelet_volume_stats_used_bytes{namespace="linkding"} / 
kubelet_volume_stats_capacity_bytes{namespace="linkding"} * 100
```

## Alerting Rules

Create alerts for critical issues:

### Application Alerts

```yaml
# Linkding pod down
- alert: LinkdingPodDown
  expr: up{job="linkding"} == 0
  for: 5m
  annotations:
    summary: "Linkding pod is down"
    description: "Linkding pod {{ $labels.pod }} has been down for more than 5 minutes"

# High error rate
- alert: LinkdingHighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
  for: 5m
  annotations:
    summary: "High error rate in Linkding"
    description: "Error rate is {{ $value }} errors/second"
```

### Database Alerts

```yaml
# PostgreSQL down
- alert: PostgreSQLDown
  expr: up{job="postgres-exporter"} == 0
  for: 5m
  annotations:
    summary: "PostgreSQL is down"
    description: "PostgreSQL exporter is not responding"

# High connection count
- alert: PostgreSQLHighConnections
  expr: pg_stat_database_numbackends{datname="linkding"} > 80
  for: 5m
  annotations:
    summary: "High PostgreSQL connection count"
    description: "PostgreSQL has {{ $value }} active connections"

# Low cache hit ratio
- alert: PostgreSQLLowCacheHitRatio
  expr: |
    (rate(pg_stat_database_blks_hit{datname="linkding"}[5m]) / 
     (rate(pg_stat_database_blks_hit{datname="linkding"}[5m]) + 
      rate(pg_stat_database_blks_read{datname="linkding"}[5m]))) * 100 < 90
  for: 10m
  annotations:
    summary: "Low PostgreSQL cache hit ratio"
    description: "Cache hit ratio is {{ $value }}% (should be >90%)"

# Database size growing fast
- alert: PostgreSQLRapidGrowth
  expr: |
    (increase(pg_database_size_bytes{datname="linkding"}[1h]) / 
     pg_database_size_bytes{datname="linkding"}) * 100 > 10
  for: 1h
  annotations:
    summary: "PostgreSQL database growing rapidly"
    description: "Database grew by {{ $value }}% in the last hour"
```

### Infrastructure Alerts

```yaml
# High CPU usage
- alert: HighCPUUsage
  expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 10m
  annotations:
    summary: "High CPU usage on node"
    description: "CPU usage is {{ $value }}%"

# High memory usage
- alert: HighMemoryUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
  for: 10m
  annotations:
    summary: "High memory usage on node"
    description: "Memory usage is {{ $value }}%"

# Disk space low
- alert: LowDiskSpace
  expr: |
    (1 - (node_filesystem_avail_bytes{mountpoint="/"} / 
          node_filesystem_size_bytes{mountpoint="/"})) * 100 > 85
  for: 10m
  annotations:
    summary: "Low disk space"
    description: "Disk usage is {{ $value }}%"
```

## Step-by-Step Setup

### 1. Verify ServiceMonitors Are Working

```bash
# Check ServiceMonitors
kubectl get servicemonitor -n linkding

# Check if Prometheus discovered them
# Access Prometheus UI and go to Status → Targets
# You should see:
# - postgres-exporter (port 9187)
# - linkding (port 9090, if metrics endpoint exists)
```

### 2. Import Grafana Dashboards

#### Option A: Use Pre-built Dashboards

1. **PostgreSQL Dashboard**:
   - Dashboard ID: `9628` (PostgreSQL Database)
   - Or search for "PostgreSQL" in Grafana dashboard library

2. **Kubernetes Dashboard**:
   - Dashboard ID: `315` (Kubernetes Cluster Monitoring)
   - Dashboard ID: `11074` (Node Exporter for Prometheus)

3. **Linkding Custom Dashboard**:
   - Create a new dashboard
   - Add panels using the queries above

#### Option B: Create Custom Dashboard

1. Go to Grafana → Dashboards → New Dashboard
2. Add panels for:
   - Linkding pod metrics (CPU, memory, restarts)
   - PostgreSQL metrics (connections, size, performance)
   - Infrastructure metrics (node resources)

### 3. Set Up Alerts

1. **In Prometheus**:
   - Create alert rules file (see examples above)
   - Add to Prometheus configuration

2. **In Grafana**:
   - Go to Alerting → Alert Rules
   - Create new alert rules using the queries above
   - Configure notification channels (email, Slack, etc.)

### 4. Useful Grafana Variables

Add these variables to your dashboards for filtering:

```yaml
# Pod name variable
- name: pod
  query: label_values(container_memory_working_set_bytes{namespace="linkding"}, pod)
  multi: true

# Namespace variable
- name: namespace
  query: label_values(container_memory_working_set_bytes, namespace)
  includeAll: true
```

## Quick Wins

### Start With These 3 Dashboards

1. **Linkding Health Dashboard**
   - Pod status
   - CPU/Memory usage
   - Restart count
   - Uptime

2. **PostgreSQL Performance Dashboard**
   - Active connections
   - Database size
   - Cache hit ratio
   - Transactions per second

3. **Infrastructure Overview**
   - Node CPU/Memory
   - Disk usage
   - Network traffic
   - Pod count

### Essential Alerts

Set up these alerts first:
1. Pod down (Linkding or PostgreSQL)
2. High CPU usage (>80% for 10 minutes)
3. High memory usage (>85% for 10 minutes)
4. Low disk space (<15% free)
5. PostgreSQL high connections (>80)

## Additional Resources

- **Grafana Dashboard Library**: https://grafana.com/grafana/dashboards/
- **PostgreSQL Exporter Metrics**: https://github.com/prometheus-community/postgres_exporter
- **Prometheus Query Examples**: https://prometheus.io/docs/prometheus/latest/querying/examples/

## Troubleshooting

### Metrics Not Showing Up?

1. **Check ServiceMonitor labels**:
   ```bash
   kubectl get servicemonitor -n linkding --show-labels
   # Make sure the 'release' label matches your Prometheus operator
   ```

2. **Check Prometheus targets**:
   - Access Prometheus UI → Status → Targets
   - Look for your services (postgres-exporter, linkding)
   - Check if they're "UP" or "DOWN"

3. **Check pod annotations**:
   ```bash
   kubectl get pod -n linkding -o yaml | grep prometheus
   # Should see prometheus.io/scrape: 'true'
   ```

4. **Check exporter logs**:
   ```bash
   kubectl logs -n linkding postgres-0 -c postgres-exporter
   ```

### Dashboard Not Loading Data?

1. **Check time range**: Make sure you're looking at the right time period
2. **Check query syntax**: Test queries in Prometheus first
3. **Check data source**: Verify Grafana is connected to the right Prometheus instance
4. **Check labels**: Make sure label names match (namespace, pod names, etc.)

## Summary

With your current setup, you can monitor:
- PostgreSQL database health and performance
- Linkding pod resources (CPU, memory, network)
- Infrastructure metrics (node resources, storage)
- Application availability and uptime

**Next Steps**:
1. Verify ServiceMonitors are working
2. Import a PostgreSQL dashboard (ID: 9628)
3. Create a simple Linkding health dashboard
4. Set up basic alerts for pod down and high resource usage

This gives you full visibility into your Linkding deployment!

