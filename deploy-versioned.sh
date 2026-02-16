#!/bin/bash

# Deploy Versionado - Projeto BIA
# Script simples para deploy com versionamento baseado em commit hash

set -e

# Configurações
REGION="us-east-1"
ECR_REPO="bia"
CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Modo dry-run (padrão: true)
DRY_RUN=true

# Função de log
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[ATENÇÃO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# Ajuda
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    cat << EOF
Deploy Versionado - Projeto BIA

USO:
    ./deploy-versioned.sh [--execute]

OPÇÕES:
    --execute    Executa o deploy (sem essa flag, apenas mostra o que seria feito)
    -h, --help   Mostra esta ajuda

EXEMPLOS:
    # Ver o que seria feito (dry-run)
    ./deploy-versioned.sh

    # Executar o deploy
    ./deploy-versioned.sh --execute

O QUE FAZ:
    1. Pega o commit hash atual (7 caracteres)
    2. Build da imagem Docker com tag do commit
    3. Push para ECR
    4. Cria nova task definition com a imagem versionada
    5. Atualiza o serviço ECS

EOF
    exit 0
fi

# Verificar se deve executar
if [[ "$1" == "--execute" ]]; then
    DRY_RUN=false
    warn "MODO EXECUÇÃO ATIVADO"
else
    warn "MODO DRY-RUN (use --execute para executar de verdade)"
fi

# 1. Obter commit hash
log "Obtendo commit hash..."
COMMIT_HASH=$(git rev-parse --short=7 HEAD 2>/dev/null || error "Não é um repositório Git")
success "Commit hash: $COMMIT_HASH"

# 2. Obter Account ID
log "Obtendo Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"
success "ECR URI: $ECR_URI"

# 3. Verificar se imagem já existe
log "Verificando se versão já existe no ECR..."
if aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=$COMMIT_HASH &>/dev/null; then
    warn "Imagem $COMMIT_HASH já existe no ECR"
    read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        error "Deploy cancelado pelo usuário"
    fi
fi

# 4. Build da imagem
log "Build da imagem Docker..."
if [ "$DRY_RUN" = false ]; then
    docker build -t $ECR_URI:$COMMIT_HASH -t $ECR_URI:latest .
    success "Build concluído"
else
    echo "  → docker build -t $ECR_URI:$COMMIT_HASH -t $ECR_URI:latest ."
fi

# 5. Login no ECR
log "Login no ECR..."
if [ "$DRY_RUN" = false ]; then
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
    success "Login realizado"
else
    echo "  → aws ecr get-login-password | docker login..."
fi

# 6. Push da imagem
log "Push da imagem para ECR..."
if [ "$DRY_RUN" = false ]; then
    docker push $ECR_URI:$COMMIT_HASH
    docker push $ECR_URI:latest
    success "Push concluído"
else
    echo "  → docker push $ECR_URI:$COMMIT_HASH"
    echo "  → docker push $ECR_URI:latest"
fi

# 7. Obter task definition atual
log "Obtendo task definition atual..."
TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION)
success "Task definition obtida"

# 8. Criar nova task definition
log "Criando nova task definition com imagem $COMMIT_HASH..."
if [ "$DRY_RUN" = false ]; then
    TEMP_FILE=$(mktemp)
    echo $TASK_DEF | jq --arg img "$ECR_URI:$COMMIT_HASH" '
        .taskDefinition |
        .containerDefinitions[0].image = $img |
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
    ' > $TEMP_FILE
    
    NEW_REVISION=$(aws ecs register-task-definition --region $REGION --cli-input-json file://$TEMP_FILE --query 'taskDefinition.revision' --output text)
    rm -f $TEMP_FILE
    success "Nova task definition: $TASK_FAMILY:$NEW_REVISION"
else
    echo "  → Criaria nova task definition com imagem: $ECR_URI:$COMMIT_HASH"
    CURRENT_REV=$(echo $TASK_DEF | jq -r '.taskDefinition.revision')
    echo "  → Revisão atual: $CURRENT_REV"
    echo "  → Nova revisão seria: $((CURRENT_REV + 1))"
fi

# 9. Atualizar serviço ECS
log "Atualizando serviço ECS..."
if [ "$DRY_RUN" = false ]; then
    aws ecs update-service \
        --region $REGION \
        --cluster $CLUSTER \
        --service $SERVICE \
        --task-definition $TASK_FAMILY:$NEW_REVISION \
        --query 'service.serviceName' \
        --output text > /dev/null
    success "Serviço atualizado"
    
    log "Aguardando estabilização..."
    aws ecs wait services-stable --region $REGION --cluster $CLUSTER --services $SERVICE
    success "Deploy concluído!"
else
    echo "  → aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:$((CURRENT_REV + 1))"
fi

# Resumo
echo ""
echo "=========================================="
if [ "$DRY_RUN" = false ]; then
    success "DEPLOY CONCLUÍDO COM SUCESSO!"
    echo ""
    echo "Versão deployada: $COMMIT_HASH"
    echo "Task Definition: $TASK_FAMILY:$NEW_REVISION"
    echo "Cluster: $CLUSTER"
    echo "Service: $SERVICE"
else
    warn "DRY-RUN CONCLUÍDO"
    echo ""
    echo "Para executar de verdade, use:"
    echo "  ./deploy-versioned.sh --execute"
    echo ""
    echo "Versão que seria deployada: $COMMIT_HASH"
    echo "Task Definition: $TASK_FAMILY"
    echo "Cluster: $CLUSTER"
    echo "Service: $SERVICE"
fi
echo "=========================================="
