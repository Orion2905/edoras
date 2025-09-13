# Guida al Deployment - Edoras Project

## Panoramica

Questa guida copre tutti gli aspetti del deployment dell'applicazione Edoras su Azure, dalla configurazione iniziale alla gestione degli ambienti di produzione.

## Prerequisiti

### 1. Software Richiesto

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Node.js (versione 18+)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Git
sudo apt-get install git
```

### 2. Account e Permessi Azure

- Account Azure attivo
- Sottoscrizione Azure con permessi Contributor
- Resource group creation permissions

### 3. Configurazione Azure CLI

```bash
# Login
az login

# Verifica sottoscrizione
az account show

# Cambia sottoscrizione se necessario
az account set --subscription "Your Subscription Name"
```

## Configurazione Iniziale

### 1. Preparazione del Progetto

```bash
# Clone del progetto
git clone <your-repo-url>
cd edoras

# Setup ambiente locale
./scripts/setup.sh
```

### 2. Configurazione Environment Variables

#### Backend (.env)
```env
NODE_ENV=production
PORT=80

# Database (verrà generato automaticamente)
DATABASE_URL=

# Storage (verrà generato automaticamente)  
AZURE_STORAGE_CONNECTION_STRING=

# JWT Secret (genera uno secure)
JWT_SECRET=your-super-secure-jwt-secret-here

# CORS
CORS_ORIGIN=https://your-frontend-domain.azurewebsites.net
```

#### Frontend (.env)
```env
REACT_APP_ENVIRONMENT=production
REACT_APP_API_URL=https://your-backend-domain.azurewebsites.net/api
```

## Deployment Steps

### 1. Deploy Ambiente Development

```bash
# Deploy completo dev
./scripts/deploy.sh

# O step by step:
./scripts/deploy.sh --infrastructure    # Solo infrastruttura
./scripts/deploy.sh --apps-only        # Solo applicazioni
```

### 2. Deploy Ambiente Production

```bash
# Deploy completo produzione
./scripts/deploy.sh --environment prod

# Verifica prima solo l'infrastruttura
./scripts/deploy.sh --environment prod --infrastructure
```

### 3. Deploy Parziali

```bash
# Solo backend
./scripts/deploy.sh --apps-only --skip-build

# Solo frontend  
./scripts/deploy.sh --apps-only --skip-build

# Senza build (se già buildato)
./scripts/deploy.sh --skip-build
```

## Configurazioni per Ambiente

### Development Environment

**Resource Group**: `rg-edoras-dev`

**Caratteristiche:**
- App Service Plan: Basic B1
- Database: Basic tier
- Minimal monitoring
- Auto-delete dopo 30 giorni di inattività

```bash
# Deploy dev con override parametri
./scripts/deploy.sh \
  --environment dev \
  --resource-group "rg-edoras-dev-custom" \
  --region "northeurope"
```

### Staging Environment

**Resource Group**: `rg-edoras-staging`

**Caratteristiche:**
- App Service Plan: Standard S1
- Database: Standard tier
- Full monitoring
- Backup settimanali

```bash
# Deploy staging
./scripts/deploy.sh --environment staging
```

### Production Environment

**Resource Group**: `rg-edoras-prod`

**Caratteristiche:**
- App Service Plan: Premium P1V2
- Database: Premium tier con geo-replication
- 99.9% SLA
- Backup giornalieri
- Alert configurati

```bash
# Deploy production
./scripts/deploy.sh --environment prod
```

## Gestione dei Segreti

### 1. Azure Key Vault

Il deployment automatico configura Azure Key Vault per gestire i segreti:

```bash
# Lista segreti
az keyvault secret list --vault-name "edoras-prod-uniqueid-kv"

# Aggiorna un segreto
az keyvault secret set \
  --vault-name "edoras-prod-uniqueid-kv" \
  --name "jwt-secret" \
  --value "new-super-secure-secret"
```

### 2. Segreti Principali

- `sql-admin-password`: Password amministratore database
- `jwt-secret`: Secret per firma JWT tokens
- `storage-connection-string`: Connection string storage account
- `database-url`: URL completo database

### 3. Rotazione Segreti

```bash
# Script per rotazione automatica password database
az sql server update \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-sql-server" \
  --admin-password "$(openssl rand -base64 32)"
```

## Database Management

### 1. Backup e Restore

```bash
# Backup manuale
az sql db export \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --storage-key-type "StorageAccessKey" \
  --storage-key "$(az storage account keys list -g rg-edoras-prod -n storage-account --query '[0].value' -o tsv)" \
  --storage-uri "https://storage-account.blob.core.windows.net/backups/backup-$(date +%Y%m%d).bacpac"

# Restore da backup
az sql db import \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database-restored" \
  --storage-key-type "StorageAccessKey" \
  --storage-key "storage-key" \
  --storage-uri "https://storage-account.blob.core.windows.net/backups/backup-20231201.bacpac"
```

### 2. Scaling Database

```bash
# Scale up database
az sql db update \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --service-objective "S2"
```

### 3. Migrazione Dati

```bash
# Export da dev
az sql db export [parametri dev]

# Import in staging per test
az sql db import [parametri staging]

# Se tutto ok, import in production
az sql db import [parametri production]
```

## Monitoring e Alerting

### 1. Application Insights

```bash
# Configura alert su errori
az monitor metrics alert create \
  --name "High Error Rate" \
  --resource-group "rg-edoras-prod" \
  --scopes "/subscriptions/{subscription}/resourceGroups/rg-edoras-prod/providers/Microsoft.Insights/components/edoras-prod-insights" \
  --condition "count 'requests/failed' > 10" \
  --description "Alert when error rate is high"
```

### 2. Performance Monitoring

```bash
# Alert su response time
az monitor metrics alert create \
  --name "Slow Response Time" \
  --resource-group "rg-edoras-prod" \
  --condition "avg 'requests/duration' > 5000" \
  --description "Alert when response time > 5 seconds"
```

### 3. Resource Usage

```bash
# Alert su CPU usage
az monitor metrics alert create \
  --name "High CPU Usage" \
  --resource-group "rg-edoras-prod" \
  --condition "avg 'CpuPercentage' > 80" \
  --description "Alert when CPU > 80%"
```

## Troubleshooting

### 1. Common Issues

#### Deploy Script Fails

```bash
# Verifica login Azure
az account show

# Verifica permessi resource group
az group show --name "rg-edoras-dev"

# Debug verbose
./scripts/deploy.sh --environment dev --verbose
```

#### App Service Non Risponde

```bash
# Controlla logs applicazione
az webapp log tail \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend"

# Restart app service
az webapp restart \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend"
```

#### Database Connection Issues

```bash
# Test connessione database
az sql db show-connection-string \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --client sqlcmd

# Verifica firewall rules
az sql server firewall-rule list \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server"
```

### 2. Logs Analysis

```bash
# Stream logs in real-time
az webapp log tail --name "edoras-prod-backend" --resource-group "rg-edoras-prod"

# Download log files
az webapp log download --name "edoras-prod-backend" --resource-group "rg-edoras-prod"

# Query Application Insights
az monitor app-insights query \
  --app "edoras-prod-insights" \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"
```

## CI/CD Pipeline

### 1. GitHub Actions Setup

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
          
      - name: Deploy to Azure
        run: |
          chmod +x ./scripts/deploy.sh
          ./scripts/deploy.sh --environment prod
```

### 2. Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: NodeTool@0
  inputs:
    versionSpec: '18.x'
    
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Azure Subscription'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: './scripts/deploy.sh'
    arguments: '--environment prod'
```

## Security Best Practices

### 1. Network Security

```bash
# Configura App Service per accesso solo HTTPS
az webapp update \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend" \
  --https-only true

# Configura custom domain con SSL
az webapp config hostname add \
  --webapp-name "edoras-prod-backend" \
  --resource-group "rg-edoras-prod" \
  --hostname "api.yourdomain.com"
```

### 2. Database Security

```bash
# Abilita Transparent Data Encryption
az sql db tde set \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --database "edoras-prod-database" \
  --status Enabled

# Configura Advanced Threat Protection
az sql server threat-policy update \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --state Enabled
```

### 3. Identity e Access Management

```bash
# Abilita Managed Identity per App Service
az webapp identity assign \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend"

# Configura Key Vault access policy
az keyvault set-policy \
  --name "edoras-prod-kv" \
  --object-id "$(az webapp identity show --resource-group rg-edoras-prod --name edoras-prod-backend --query principalId -o tsv)" \
  --secret-permissions get list
```

## Performance Optimization

### 1. App Service Optimization

```bash
# Abilita Always On
az webapp config set \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend" \
  --always-on true

# Configura auto-scaling
az monitor autoscale create \
  --resource-group "rg-edoras-prod" \
  --resource "edoras-prod-plan" \
  --resource-type "Microsoft.Web/serverfarms" \
  --name "edoras-autoscale" \
  --min-count 1 \
  --max-count 5 \
  --count 2
```

### 2. Database Performance

```bash
# Abilita Query Store
az sql db update \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --query-store-capture-mode All

# Configura automatic tuning
az sql db update \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --auto-tuning-mode Auto
```

## Disaster Recovery

### 1. Backup Strategy

```bash
# Configura geo-backup per database
az sql db replica create \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --partner-resource-group "rg-edoras-prod-backup" \
  --partner-server "edoras-prod-sql-server-backup"

# Backup storage account
az storage account update \
  --resource-group "rg-edoras-prod" \
  --name "edorasprodstg" \
  --enable-versioning true
```

### 2. Recovery Procedures

```bash
# Failover database
az sql db replica set-primary \
  --resource-group "rg-edoras-prod-backup" \
  --server "edoras-prod-sql-server-backup" \
  --name "edoras-prod-database"

# Update app service connection strings
az webapp config connection-string set \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend" \
  --connection-string-type SQLAzure \
  --settings DatabaseConnection="new-connection-string"
```

## Rollback Procedures

### 1. Application Rollback

```bash
# Deploy versione precedente
git checkout previous-stable-tag
./scripts/deploy.sh --environment prod --apps-only

# O usa deployment slots
az webapp deployment slot swap \
  --resource-group "rg-edoras-prod" \
  --name "edoras-prod-backend" \
  --slot "staging" \
  --target-slot "production"
```

### 2. Database Rollback

```bash
# Restore da backup point-in-time
az sql db restore \
  --resource-group "rg-edoras-prod" \
  --server "edoras-prod-sql-server" \
  --name "edoras-prod-database" \
  --dest-name "edoras-prod-database-restored" \
  --time "2023-12-01T10:00:00"
```

## Costi e Ottimizzazione

### 1. Cost Analysis

```bash
# Analizza costi resource group
az consumption usage list \
  --resource-group "rg-edoras-prod" \
  --start-date "2023-12-01" \
  --end-date "2023-12-31"

# Configura budget alerts
az consumption budget create \
  --budget-name "edoras-monthly-budget" \
  --amount 100 \
  --resource-group "rg-edoras-prod" \
  --time-grain Monthly
```

### 2. Resource Optimization

```bash
# Scale down per ambienti non-prod
az appservice plan update \
  --resource-group "rg-edoras-dev" \
  --name "edoras-dev-plan" \
  --sku "F1"  # Free tier per dev

# Scheduled shutdown per dev environment
az webapp config set \
  --resource-group "rg-edoras-dev" \
  --name "edoras-dev-backend" \
  --startup-file "scheduled-shutdown.sh"
```

---

Questa guida fornisce tutto il necessario per gestire il deployment e l'operatività dell'applicazione Edoras su Azure in modo professionale e sicuro.
