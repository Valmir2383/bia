# Configuração de Ambientes - BIA Pipeline

## Staging Environment
- **Branch:** develop
- **ECR Repository:** bia-staging
- **ECS Service:** bia-staging
- **Cluster:** bia-cluster-staging
- **URL:** https://bia-staging.exemplo.com

## Production Environment  
- **Branch:** main
- **ECR Repository:** bia-production
- **ECS Service:** bia-production
- **Cluster:** bia-cluster-production
- **URL:** https://bia-prod.exemplo.com

## Variáveis de Ambiente Necessárias

### CodeBuild Projects
```bash
# Para staging
AWS_ACCOUNT_ID=<sua-conta-id>
AWS_DEFAULT_REGION=us-east-1
ENVIRONMENT=staging

# Para production
AWS_ACCOUNT_ID=<sua-conta-id>
AWS_DEFAULT_REGION=us-east-1
ENVIRONMENT=production
```

### GitHub Secrets
```
AWS_ACCESS_KEY_ID=<access-key>
AWS_SECRET_ACCESS_KEY=<secret-key>
```

## Comandos para Configurar

### 1. Criar repositórios ECR
```bash
aws ecr create-repository --repository-name bia-staging
aws ecr create-repository --repository-name bia-production
```

### 2. Criar projetos CodeBuild
```bash
# Staging
aws codebuild create-project --name bia-build-staging --source type=GITHUB,location=https://github.com/Valmir2383/bia.git --artifacts type=NO_ARTIFACTS --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_MEDIUM --service-role arn:aws:iam::<account>:role/CodeBuildServiceRole

# Production  
aws codebuild create-project --name bia-build-production --source type=GITHUB,location=https://github.com/Valmir2383/bia.git --artifacts type=NO_ARTIFACTS --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_MEDIUM --service-role arn:aws:iam::<account>:role/CodeBuildServiceRole
```
