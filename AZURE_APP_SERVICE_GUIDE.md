# 🚀 Guida Deployment Azure App Service - Edoras Backend API

Questa guida ti accompagna nel deployment del backend API Edoras su Azure App Service tramite GitHub Actions.

## 📋 Prerequisiti

- [x] Account Azure attivo
- [x] Repository GitHub con il codice
- [x] Azure CLI installato (`az --version`)
- [x] jq installato (`brew install jq` su macOS)

## 🎯 Overview dell'Architettura Azure App Service

```
GitHub Repository
    ↓ (push/PR)
GitHub Actions
    ↓ (deploy)
Azure App Service (Linux Python 3.11)
    ↓ (connect to)
Azure SQL Database + Key Vault
```

## 🔧 Step 1: Setup Azure Resources

### Automatico (Raccomandato)
```bash
# Imposta password per SQL Server
export SQL_ADMIN_PASSWORD="YourSecurePassword123!"

# Esegui lo script di setup automatico
./scripts/setup-azure-app-service.sh
```

### Manuale
```bash
# 1. Login in Azure
az login

# 2. Creare Resource Group
az group create --name rg-edoras-2025 --location "West Europe"

# 3. Creare App Service Plan
az appservice plan create \
  --name edoras-app-service-plan \
  --resource-group rg-edoras-2025 \
  --location "West Europe" \
  --sku B1 \
  --is-linux

# 4. Creare Web App
az webapp create \
  --resource-group rg-edoras-2025 \
  --plan edoras-app-service-plan \
  --name edoras-backend-api-2025 \
  --runtime "PYTHON|3.11"
```

## 🔐 Step 2: Configurare GitHub Secrets

Vai su GitHub → Settings → Secrets and variables → Actions e aggiungi:

### Secrets Obbligatori (dall'output dello script)
| Secret Name | Descrizione | Esempio |
|-------------|-------------|---------|
| `AZURE_CREDENTIALS` | Service Principal JSON | `{"clientId": "...", "clientSecret": "...", ...}` |
| `AZURE_RESOURCE_GROUP` | Nome Resource Group | `rg-edoras-2025` |
| `DATABASE_URL` | Connection string SQL | `mssql+pyodbc://user:pass@server.database.windows.net/db?driver=ODBC+Driver+17+for+SQL+Server` |
| `SECRET_KEY` | Chiave segreta Flask | `generated-32-byte-hex-string` |
| `JWT_SECRET_KEY` | Chiave JWT | `generated-32-byte-hex-string` |
| `AZURE_KEYVAULT_URL` | URL Key Vault | `https://edoras-keyvault-2025.vault.azure.net/` |
| `AZURE_CLIENT_ID` | Client ID Service Principal | `client-id-from-sp-json` |
| `AZURE_CLIENT_SECRET` | Client Secret Service Principal | `client-secret-from-sp-json` |
| `AZURE_TENANT_ID` | Tenant ID Azure | `tenant-id-from-sp-json` |

## 💾 Step 3: Configurare Database

Il database Azure SQL è già creato dallo script. Connection string formato:
```
mssql+pyodbc://edorasadmin:PASSWORD@edoras-sql-server-2025.database.windows.net/edoras-db?driver=ODBC+Driver+17+for+SQL+Server
```

## 🚀 Step 4: Primo Deployment

1. **Push del codice**:
   ```bash
   git add .
   git commit -m "feat: setup Azure App Service deployment"
   git push origin main
   ```

2. **Monitorare deployment**:
   - Vai su GitHub → Actions
   - Seleziona il workflow "Deploy to Azure App Service"
   - Monitora i logs

3. **Verificare deployment**:
   ```bash
   # URL dell'app
   curl https://edoras-backend-api-2025.azurewebsites.net/api/health
   ```

## 🗄️ Step 5: Setup Database Schema

Esegui manualmente o tramite workflow:

```bash
# Connetti al database e esegui migrations
az webapp ssh --name edoras-backend-api-2025 --resource-group rg-edoras-2025

# Nel container:
cd /home/site/wwwroot
python -m flask db upgrade
python init_roles_permissions.py
```

## ⚙️ Configurazioni App Service

### Variabili d'ambiente
Configurate automaticamente dal workflow:
- `FLASK_ENV=production`
- `FLASK_APP=app.py`
- `DATABASE_URL=...`
- `SECRET_KEY=...`
- `JWT_SECRET_KEY=...`
- `AZURE_KEYVAULT_URL=...`

### Startup Command
```bash
gunicorn --bind=0.0.0.0:8000 --timeout 600 --workers 4 app:app
```

### Always On
```bash
az webapp config set \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025 \
  --always-on true
```

## 🔧 Configurazioni Avanzate

### Custom Domain
```bash
# Aggiungere dominio personalizzato
az webapp config hostname add \
  --webapp-name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025 \
  --hostname api.yourdomain.com
```

### SSL Certificate
```bash
# SSL certificate gratuito App Service Managed
az webapp config ssl create \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025 \
  --hostname api.yourdomain.com
```

### Scaling
```bash
# Auto-scaling
az monitor autoscale create \
  --resource-group rg-edoras-2025 \
  --resource edoras-backend-api-2025 \
  --resource-type Microsoft.Web/serverfarms \
  --name edoras-autoscale \
  --min-count 1 \
  --max-count 3 \
  --count 1
```

## 📊 Monitoraggio

### Application Insights
```bash
# Creare Application Insights
az monitor app-insights component create \
  --app edoras-api-insights \
  --location "West Europe" \
  --resource-group rg-edoras-2025

# Collegare all'App Service
az webapp config appsettings set \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025 \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=your-key
```

### Log Stream
```bash
# Visualizzare logs in tempo reale
az webapp log tail \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025
```

### Diagnostics
```bash
# Abilitare logging
az webapp log config \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025 \
  --application-logging filesystem \
  --level information
```

## 🐛 Troubleshooting

### SSH nel container
```bash
az webapp ssh \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025
```

### Restart App Service
```bash
az webapp restart \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025
```

### Controllare configurazione
```bash
# Visualizzare app settings
az webapp config appsettings list \
  --name edoras-backend-api-2025 \
  --resource-group rg-edoras-2025
```

## ✅ Test Endpoints

Dopo il deployment, testa questi endpoint:

```bash
BASE_URL="https://edoras-backend-api-2025.azurewebsites.net"

# Health check
curl $BASE_URL/api/health

# Health check dettagliato
curl $BASE_URL/api/health/detailed

# API test (richiede autenticazione)
curl $BASE_URL/api/v1/companies
```

## 💰 Costi Stimati

**App Service Basic B1:**
- App Service Plan B1: ~€13/mese
- Azure SQL Basic: ~€5/mese
- Key Vault: ~€1/mese
- **Totale: ~€19/mese**

## 🔄 Updates e CI/CD

Il deployment è automatico:
- **Push su main** → Deployment automatico
- **Pull Request** → Build di test
- **Workflow manuale** → Deployment controllato

## 📈 Performance Tips

1. **Always On**: Evita cold starts
2. **Application Insights**: Monitoraggio performance
3. **Connection Pooling**: Configurato in SQLAlchemy
4. **Static Files**: Gestiti da whitenoise
5. **Caching**: Implementa Redis se necessario

## 🆘 Supporto

In caso di problemi:
1. Controlla i logs: Azure Portal → App Service → Log stream
2. Verifica i secrets GitHub
3. SSH nel container per debug
4. Controlla Application Insights per errori

---

🎉 **Congratulazioni!** Il tuo backend API Edoras è ora deployed su Azure App Service con CI/CD automatico!
