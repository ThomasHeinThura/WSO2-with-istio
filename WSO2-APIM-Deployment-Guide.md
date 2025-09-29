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

#### Install metallb
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

kubectl apply -f metallb-config.yaml
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

helm install wso2am am-pattern-3/     
```

### 6. Configure Istio Gateway
```bash
kubectl apply -f istio-gateway.yaml
```