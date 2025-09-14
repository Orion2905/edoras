# 🚀 Guida al Deployment Azure - Edoras Backend API

Questa guida ti accompagna nel deployment del backend API Edoras su Azure Container Apps tramite GitHub Actions.

## 📋 Prerequisiti

- [x] Account Azure attivo
- [x] Repository GitHub con il codice
- [x] Azure CLI installato (`az --version`)
- [x] Docker installato (per test locali)
- [x] jq installato (`brew install jq` su macOS)

## 🎯 Overview dell'Architettura

```
GitHub Repository
    ↓ (push/PR)
GitHub Actions
    ↓ (build & deploy)
Azure Container Registry (ACR)
    ↓ (pull image)
Azure Container Apps
    ↓ (connect to)
Azure SQL Database + Key Vault
```

## 🔧 Step 1: Setup Azure Resources

### Automatico (Raccomandato)
```bash
# Esegui lo script di setup automatico
./scripts/setup-azure-deployment.sh
```

### Manuale
```bash
# 1. Login in Azure
az login

# 2. Creare Resource Group
az group create --name rg-edoras-2025 --location "West Europe"

# 3. Creare Container Registry
az acr create --resource-group rg-edoras-2025 --name edorasregistry2025 --sku Basic --admin-enabled true

# 4. Creare Container Apps Environment
az containerapp env create --name edoras-container-env --resource-group rg-edoras-2025 --location "West Europe"

# 5. Ottenere credenziali ACR
az acr credential show --name edorasregistry2025
```

## 🔐 Step 2: Configurare GitHub Secrets

Vai su GitHub → Settings → Secrets and variables → Actions e aggiungi:

### Secrets Obbligatori
| Secret Name | Descrizione | Come ottenerlo |
|-------------|-------------|----------------|
| `ACR_USERNAME` | Username Container Registry | `az acr credential show --name edorasregistry2025` |
| `ACR_PASSWORD` | Password Container Registry | `az acr credential show --name edorasregistry2025` |
| `AZURE_CREDENTIALS` | Service Principal JSON | `az ad sp create-for-rbac...` (vedi output script) |
| `DATABASE_URL` | Connection string database | Dal tuo database Azure |
| `SECRET_KEY` | Chiave segreta Flask | Genera con `python -c "import secrets; print(secrets.token_hex(32))"` |
| `JWT_SECRET_KEY` | Chiave JWT | Genera con `python -c "import secrets; print(secrets.token_hex(32))"` |
| `AZURE_KEYVAULT_URL` | URL Key Vault | `https://edoras-keyvault-2025.vault.azure.net/` |
| `AZURE_CLIENT_ID` | Client ID Service Principal | Dal JSON AZURE_CREDENTIALS |
| `AZURE_CLIENT_SECRET` | Client Secret Service Principal | Dal JSON AZURE_CREDENTIALS |
| `AZURE_TENANT_ID` | Tenant ID Azure | Dal JSON AZURE_CREDENTIALS |

## 💾 Step 3: Setup Database

### Opzione 1: Azure SQL Database (Raccomandato)
```bash
# Creare Azure SQL Server
az sql server create \
  --name edoras-sql-server-2025 \
  --resource-group rg-edoras-2025 \
  --location "West Europe" \
  --admin-user edorasadmin \
  --admin-password "YourSecurePassword123!"

# Creare database
az sql db create \
  --resource-group rg-edoras-2025 \
  --server edoras-sql-server-2025 \
  --name edoras-db \
  --service-objective Basic

# Configurare firewall per Azure services
az sql server firewall-rule create \
  --resource-group rg-edoras-2025 \
  --server edoras-sql-server-2025 \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

**Connection String:**
```
mssql+pyodbc://edorasadmin:YourSecurePassword123!@edoras-sql-server-2025.database.windows.net/edoras-db?driver=ODBC+Driver+17+for+SQL+Server
```

### Opzione 2: PostgreSQL
```bash
# Creare PostgreSQL server
az postgres server create \
  --resource-group rg-edoras-2025 \
  --name edoras-postgres-2025 \
  --location "West Europe" \
  --admin-user edorasadmin \
  --admin-password "YourSecurePassword123!" \
  --sku-name GP_Gen5_2

# Creare database
az postgres db create \
  --resource-group rg-edoras-2025 \
  --server-name edoras-postgres-2025 \
  --name edoras-db
```

## 🚀 Step 4: Primo Deployment

1. **Push del codice**:
   ```bash
   git add .
   git commit -m "feat: setup Azure deployment"
   git push origin main
   ```

2. **Monitorare deployment**:
   - Vai su GitHub → Actions
   - Seleziona il workflow "Deploy to Azure Container Apps"
   - Monitora i logs

3. **Verificare deployment**:
   ```bash
   # Ottenere URL dell'app
   az containerapp show \
     --name edoras-backend-api \
     --resource-group rg-edoras-2025 \
     --query properties.configuration.ingress.fqdn \
     --output tsv
   ```

## 🗄️ Step 5: Setup Database Schema

Esegui il workflow "Database Setup and Migration":

1. Vai su GitHub → Actions
2. Seleziona "Database Setup and Migration"
3. Clicca "Run workflow"
4. Seleziona:
   - Environment: `production`
   - Run migrations: `true`
   - Initialize roles: `true`

## ✅ Step 6: Verifica Funzionamento

```bash
# Test health endpoint
curl https://your-app-url.azurecontainerapps.io/api/health

# Test API
curl https://your-app-url.azurecontainerapps.io/api/v1/companies
```

## 🔧 Configurazioni Avanzate

### Scaling Automatico
```bash
az containerapp update \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025 \
  --min-replicas 1 \
  --max-replicas 10 \
  --scale-rule-name "http-scale" \
  --scale-rule-type "http" \
  --scale-rule-metadata "concurrentRequests=50"
```

### Custom Domain
```bash
# Aggiungere dominio personalizzato
az containerapp hostname add \
  --hostname api.yourdomain.com \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025
```

### SSL Certificate
```bash
# Aggiungere certificato SSL
az containerapp ssl upload \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025 \
  --hostname api.yourdomain.com \
  --certificate-file cert.pfx \
  --password "cert-password"
```

## 🐛 Troubleshooting

### Visualizzare logs
```bash
az containerapp logs show \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025 \
  --follow
```

### Restart dell'app
```bash
az containerapp revision restart \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025
```

### Debug ambiente
```bash
# Eseguire shell nel container
az containerapp exec \
  --name edoras-backend-api \
  --resource-group rg-edoras-2025 \
  --command "/bin/bash"
```

## 🔄 Updates e CI/CD

Il deployment è automatico:
- **Push su main** → Deployment automatico in production
- **Pull Request** → Build di test
- **Workflow manuale** → Deployment controllato

## 📊 Monitoraggio

### Application Insights
```bash
# Creare Application Insights
az monitor app-insights component create \
  --app edoras-api-insights \
  --location "West Europe" \
  --resource-group rg-edoras-2025
```

### Log Analytics
I logs sono automaticamente disponibili in Azure Portal:
- Container Apps → edoras-backend-api → Logs

## 💰 Costi Stimati

**Configurazione Base:**
- Container Apps: ~€15/mese
- Container Registry: ~€5/mese  
- Azure SQL Basic: ~€5/mese
- Key Vault: ~€1/mese
- **Totale: ~€26/mese**

## 🆘 Supporto

In caso di problemi:
1. Controlla i logs: `az containerapp logs show...`
2. Verifica i secrets GitHub
3. Controlla lo stato delle risorse Azure
4. Consulta la documentazione Azure Container Apps

---

🎉 **Congratulazioni!** Il tuo backend API Edoras è ora deployed su Azure con CI/CD automatico!
