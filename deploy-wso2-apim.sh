#!/bin/bash
# deploy-wso2-apim.sh - Complete deployment script for WSO2 APIM Pattern 3

set -e

echo "🚀 Starting WSO2 API Manager Pattern 3 deployment on Kind with Istio"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Create Kind cluster
echo -e "${YELLOW}📋 Step 1: Creating Kind cluster...${NC}"
kind create cluster --config kind-cluster-config.yaml --wait 300s

echo -e "${GREEN}✅ Kind cluster created successfully${NC}"

# Step 2: Install Istio
echo -e "${YELLOW}📋 Step 2: Installing Istio...${NC}"

# Download and install istioctl
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-*/bin:$PATH

# Install Istio with default profile
istioctl install --set values.defaultRevision=default -y

# Enable sidecar injection for wso2-system namespace
kubectl create namespace wso2-system
kubectl label namespace wso2-system istio-injection=enabled

echo -e "${GREEN}✅ Istio installed successfully${NC}"

# Step 3: Deploy MySQL Operator
echo -e "${YELLOW}📋 Step 3: Deploying MySQL Operator...${NC}"

# Install MySQL Operator CRDs
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml

# Install MySQL Operator
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml

# Wait for MySQL operator to be ready
kubectl wait --for=condition=available --timeout=300s deployment/mysql-operator -n mysql-operator

echo -e "${GREEN}✅ MySQL Operator deployed successfully${NC}"

# Step 4: Deploy MySQL InnoDB Cluster
echo -e "${YELLOW}📋 Step 4: Deploying MySQL InnoDB Cluster...${NC}"

kubectl apply -f mysql-cluster.yaml

# Wait for MySQL cluster to be ready
echo "Waiting for MySQL cluster to be ready (this may take 5-10 minutes)..."
kubectl wait --for=condition=ready --timeout=600s innodbcluster/wso2-mysql-cluster -n wso2-system

echo -e "${GREEN}✅ MySQL InnoDB Cluster deployed successfully${NC}"

# Step 5: Setup Database Schema
echo -e "${YELLOW}📋 Step 5: Setting up database schemas...${NC}"

# Create database user and schemas
kubectl exec -it wso2-mysql-cluster-0 -n wso2-system -- mysql -u root -pWSO2DBPass -e "
CREATE DATABASE IF NOT EXISTS WSO2AM_DB;
CREATE DATABASE IF NOT EXISTS WSO2_SHARED_DB;
CREATE USER IF NOT EXISTS 'wso2carbon'@'%' IDENTIFIED BY 'wso2carbon';
GRANT ALL PRIVILEGES ON WSO2AM_DB.* TO 'wso2carbon'@'%';
GRANT ALL PRIVILEGES ON WSO2_SHARED_DB.* TO 'wso2carbon'@'%';
FLUSH PRIVILEGES;
"

echo -e "${GREEN}✅ Database schemas created successfully${NC}"

# Step 6: Deploy WSO2 APIM Pattern 3
echo -e "${YELLOW}📋 Step 6: Deploying WSO2 APIM Pattern 3...${NC}"

# Add WSO2 Helm repository
helm repo add wso2 https://helm.wso2.com && helm repo update

# Install WSO2 APIM Pattern 3
helm install wso2apim-pattern3 wso2/am-pattern-3 \
  --version 4.2.0-2 \
  --namespace wso2-system \
  --values wso2-apim-pattern3-values.yaml \
  --wait --timeout=600s

echo -e "${GREEN}✅ WSO2 APIM Pattern 3 deployed successfully${NC}"

# Step 7: Deploy Istio Gateway
echo -e "${YELLOW}📋 Step 7: Configuring Istio Gateway...${NC}"

kubectl apply -f istio-gateway.yaml

echo -e "${GREEN}✅ Istio Gateway configured successfully${NC}"

# Step 8: Port forwarding setup
echo -e "${YELLOW}📋 Step 8: Setting up port forwarding...${NC}"

# Port forward Istio Gateway
kubectl port-forward service/istio-ingressgateway -n istio-system 8080:80 8443:443 &

echo -e "${GREEN}✅ Port forwarding configured${NC}"

# Final status check
echo -e "${YELLOW}📋 Final Status Check...${NC}"

echo "Checking pod status..."
kubectl get pods -n wso2-system
kubectl get pods -n mysql-operator

echo "Checking services..."
kubectl get svc -n wso2-system

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo "Access URLs:"
echo "- Publisher Portal: https://localhost:8443/publisher"
echo "- Developer Portal: https://localhost:8443/devportal"  
echo "- Admin Portal: https://localhost:8443/admin"
echo "- Gateway: https://localhost:8443"
echo ""
echo "Default credentials: admin/admin"
