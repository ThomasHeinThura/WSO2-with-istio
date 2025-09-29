#!/bin/bash
# troubleshoot-wso2-apim.sh - Troubleshooting script for 404 errors

set -e

echo "🔍 WSO2 APIM 404 Error Troubleshooting Script"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Checking JMS Connection between Control Plane and Gateway${NC}"

# Enable JMS debugging logs
echo "Enabling JMS debug logs..."
kubectl exec -it deployment/wso2am-pattern-3-am-cp -n wso2-system -- \
  sh -c 'echo "logger.jms_listner.name = org.wso2.carbon.apimgt.gateway.listeners
logger.jms_listner.level = DEBUG
loggers = jms_listner, AUDIT_LOG, trace-messages, org-apache-synapse-transport-jms, org-apache-axis2" >> /home/wso2carbon/wso2am-4.2.0/repository/conf/log4j2.properties'

echo -e "${YELLOW}Check JMS connection errors:${NC}"
kubectl logs deployment/wso2am-pattern-3-am-gw -n wso2-system | grep -i "DataEndpointConnectionWorker\|JMS\|Cannot borrow client" || echo "No JMS errors found"

echo -e "${BLUE}Step 2: Checking Gateway Event Reception${NC}"

echo "Checking if gateway receives deployment events..."
kubectl logs deployment/wso2am-pattern-3-am-gw -n wso2-system | grep -i "Event received in JMS Event Receiver\|DEPLOY_API_IN_GATEWAY\|SUBSCRIPTIONS_CREATE" || echo "No deployment events found"

echo -e "${BLUE}Step 3: Checking Internal Data Endpoints${NC}"

echo "Testing internal/data/v1 endpoints..."
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- \
  curl -k https://wso2am-cp-service:9443/internal/data/v1/apis 2>/dev/null || echo "❌ Internal data endpoint not accessible"

echo -e "${BLUE}Step 4: DNS and Service Discovery${NC}"

echo "Checking DNS resolution between components..."
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- \
  nslookup wso2am-cp-service.wso2-system.svc.cluster.local || echo "❌ DNS resolution failed"

echo "Checking service endpoints..."
kubectl get endpoints -n wso2-system | grep wso2am

echo -e "${BLUE}Step 5: Certificate and Trust Store Check${NC}"

echo "Checking certificate trust between components..."
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- \
  openssl s_client -connect wso2am-cp-service:9443 -servername wso2am-cp-service 2>/dev/null || echo "❌ Certificate trust issue"

echo -e "${BLUE}Step 6: Istio Sidecar Configuration${NC}"

echo "Checking Istio sidecar injection..."
kubectl get pods -n wso2-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy || echo "❌ No Istio sidecars found"

echo "Checking Istio proxy configuration..."
kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -c istio-proxy -- \
  pilot-agent request GET config_dump | jq '.configs[].dynamic_route_configs[].route_config.virtual_hosts[].domains' || echo "❌ Istio config issue"

echo -e "${BLUE}Step 7: API Deployment Status${NC}"

echo "Checking API deployment status in Control Plane..."
kubectl exec -it deployment/wso2am-pattern-3-am-cp -n wso2-system -- \
  curl -k -u admin:admin https://localhost:9443/api/am/publisher/v4/apis | jq '.list[] | {name: .name, lifeCycleStatus: .lifeCycleStatus}' || echo "❌ Cannot access Publisher API"

echo -e "${BLUE}Step 8: Common Resolution Steps${NC}"

echo -e "${YELLOW}If issues persist, try these resolution steps:${NC}"
echo "1. Restart Control Plane pods:"
echo "   kubectl rollout restart deployment/wso2am-pattern-3-am-cp -n wso2-system"
echo ""
echo "2. Restart Gateway pods:"
echo "   kubectl rollout restart deployment/wso2am-pattern-3-am-gw -n wso2-system" 
echo ""
echo "3. Check if JMS broker is accessible:"
echo "   kubectl exec -it deployment/wso2am-pattern-3-am-gw -n wso2-system -- netstat -tlnp | grep 9711"
echo ""
echo "4. Verify database connectivity:"
echo "   kubectl exec -it deployment/wso2am-pattern-3-am-cp -n wso2-system -- mysql -h wso2-mysql-cluster.wso2-system.svc.cluster.local -u wso2carbon -pwso2carbon -e 'SHOW DATABASES;'"
echo ""
echo "5. Check Istio configuration:"
echo "   istioctl analyze -n wso2-system"

echo -e "${GREEN}✅ Troubleshooting analysis complete${NC}"
