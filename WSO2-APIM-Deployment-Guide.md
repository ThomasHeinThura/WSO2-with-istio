# WSO2 APIM Pattern 3 Kubernetes Deployment - Quick Reference Guide

## 📋 Prerequisites Checklist
- [ ] Docker installed and running
- [ ] Kind CLI installed 
- [ ] kubectl configured
- [ ] Helm 3.x installed
- [ ] At least 8GB RAM and 4 CPU cores available

## 🚀 Quick Deployment Steps

### 1. Create Kind Cluster
```bash
# Save kind-cluster-config.yaml from configurations
kind create cluster --config=kind-multi.yaml
```

### 2. Install Istio
```bash
istioctl install --set values.defaultRevision=default -y

# Enable sidecar injection
kubectl create namespace wso2-system
kubectl label namespace wso2-system istio-injection=enabled
```

### 3. Deploy MySQL Operator
```bash
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.4.0-2.2.5/deploy/deploy-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.4.0-2.2.5/deploy/deploy-operator.yaml
kubectl wait --for=condition=available --timeout=300s deployment/mysql-operator -n mysql-operator
```
```bash
kubectl create secret generic mypwds \
        --from-literal=rootUser=root \
        --from-literal=rootHost=% \
        --from-literal=rootPassword="1qaz!QAZ"
```

### 4. Deploy MySQL Cluster
```bash
# Apply mysql-cluster.yaml from configurations
kubectl apply -f mysql-cluster.yaml
kubectl wait --for=condition=ready --timeout=600s innodbcluster/wso2-mysql-cluster -n wso2-system
```

### 5. Deploy WSO2 APIM Pattern 3
```bash
helm repo add wso2 https://helm.wso2.com && helm repo update
helm install wso2apim-pattern3 wso2/am-pattern-3 \
  --version 4.2.0-2 \
  --namespace wso2-system \
  --values wso2-apim-pattern3-values.yaml \
  --wait --timeout=600s
```

### 6. Configure Istio Gateway
```bash
kubectl apply -f istio-gateway.yaml
```

## 🔍 Troubleshooting 404 Errors

### Common Causes:
1. **JMS Connection Issues**: Control Plane cannot communicate with Gateway
2. **DNS Resolution**: Services cannot resolve each other
3. **Certificate Trust**: SSL/TLS handshake failures
4. **Istio Sidecar**: Incorrect proxy configuration
5. **Database Connectivity**: CP cannot access MySQL

### Quick Diagnostic Commands:
```bash
# Check JMS connection errors
kubectl logs deployment/wso2am-pattern-3-am-gw -n wso2-system | grep -i "DataEndpointConnectionWorker\|JMS\|Cannot borrow client"

# Check gateway event reception
kubectl logs deployment/wso2am-pattern-3-am-gw -n wso2-system | grep -i "Event received in JMS Event Receiver\|DEPLOY_API_IN_GATEWAY"

# Test internal data endpoints
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- curl -k https://wso2am-cp-service:9443/internal/data/v1/apis

# Check DNS resolution
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- nslookup wso2am-cp-service.wso2-system.svc.cluster.local

# Check Istio sidecar injection
kubectl get pods -n wso2-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy
```

### Resolution Steps:
```bash
# 1. Restart deployments
kubectl rollout restart deployment/wso2am-pattern-3-am-cp -n wso2-system
kubectl rollout restart deployment/wso2am-pattern-3-am-gw -n wso2-system

# 2. Check service endpoints
kubectl get endpoints -n wso2-system

# 3. Verify database connectivity
kubectl exec -it deployment/wso2am-pattern-3-am-cp -n wso2-system -- mysql -h wso2-mysql-cluster.wso2-system.svc.cluster.local -u wso2carbon -pwso2carbon -e 'SHOW DATABASES;'

# 4. Analyze Istio configuration
istioctl analyze -n wso2-system
```

## 📊 Architecture Components

### Control Plane (2 replicas)
- **Ports**: 9443 (HTTPS), 9763 (HTTP)
- **Services**: Publisher, DevPortal, Admin
- **Resources**: 2-3Gi Memory, 1-2 CPU cores

### Gateway (2 replicas)
- **Ports**: 8243 (HTTPS), 8280 (HTTP)
- **Services**: API Runtime, Traffic Manager
- **Resources**: 2-3Gi Memory, 1-2 CPU cores

### MySQL InnoDB Cluster (3 replicas)
- **Version**: MySQL 8.0
- **Storage**: 20Gi per instance
- **Router**: 2 instances for load balancing

## 🌐 Access URLs (after port-forwarding)
- **Publisher Portal**: https://localhost:8443/publisher
- **Developer Portal**: https://localhost:8443/devportal
- **Admin Portal**: https://localhost:8443/admin
- **Gateway**: https://localhost:8443
- **Default Credentials**: admin/admin

## ⚠️ Common Issues and Solutions

### Issue: Pod stuck in "Init" state
**Solution**: Check if MySQL cluster is ready and accessible

### Issue: 404 errors after API deployment
**Solution**: Check JMS connection and restart gateway pods

### Issue: Istio sidecar not injected
**Solution**: Verify namespace has istio-injection=enabled label

### Issue: Database connection failures
**Solution**: Verify MySQL cluster is running and credentials are correct

### Issue: Certificate trust errors
**Solution**: Update keystore with proper certificates or use self-signed certs

## 🛠️ Monitoring Commands
```bash
# Watch pod status
kubectl get pods -n wso2-system -w

# Check resource usage
kubectl top pods -n wso2-system

# View logs
kubectl logs -f deployment/wso2am-pattern-3-am-cp -n wso2-system
kubectl logs -f deployment/wso2am-pattern-3-am-gw -n wso2-system

# Check Istio proxy logs
kubectl logs -f deployment/wso2am-pattern-3-am-gw -n wso2-system -c istio-proxy
```

## 🔧 Configuration Files Required
1. `kind-cluster-config.yaml` - Kind cluster configuration
2. `mysql-cluster.yaml` - MySQL InnoDB cluster definition
3. `wso2-apim-pattern3-values.yaml` - Helm values for WSO2 APIM
4. `istio-gateway.yaml` - Istio Gateway and VirtualService
5. `deploy-wso2-apim.sh` - Complete deployment script
6. `troubleshoot-wso2-apim.sh` - Troubleshooting script

## 📝 Notes
- Deployment typically takes 15-20 minutes
- Ensure sufficient resources (8GB RAM, 4 CPU cores minimum)
- Use the troubleshooting script when encountering 404 errors
- Monitor logs during deployment for early issue detection
