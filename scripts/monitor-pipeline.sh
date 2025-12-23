#!/bin/bash

# Script de monitoramento para pipeline BIA
ENVIRONMENT=${1:-production}
SERVICE_NAME="bia-$ENVIRONMENT"

echo "=== Monitoramento Pipeline BIA - $ENVIRONMENT ==="

# 1. Verificar status do serviço ECS
echo "Verificando status do serviço ECS..."
aws ecs describe-services \
  --cluster bia-cluster-$ENVIRONMENT \
  --services $SERVICE_NAME \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# 2. Verificar logs recentes
echo "Verificando logs recentes..."
aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/bia-$ENVIRONMENT" \
  --query 'logGroups[0].logGroupName' \
  --output text | xargs -I {} aws logs tail {} --since 5m

# 3. Health check da aplicação
echo "Executando health check..."
if [ "$ENVIRONMENT" = "production" ]; then
  ENDPOINT="https://bia-prod.exemplo.com/ping"
else
  ENDPOINT="https://bia-staging.exemplo.com/ping"
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ Aplicação respondendo corretamente"
else
  echo "❌ Aplicação com problemas - Status: $HTTP_STATUS"
  exit 1
fi

# 4. Métricas CloudWatch
echo "Verificando métricas CloudWatch..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$SERVICE_NAME Name=ClusterName,Value=bia-cluster-$ENVIRONMENT \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average' \
  --output text

echo "=== Monitoramento concluído ==="
