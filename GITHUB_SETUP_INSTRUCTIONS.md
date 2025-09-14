# 🔐 Configurazione GitHub Secrets per Edoras Deployment

## ⚠️ Importante: Personal Access Token

Prima di tutto, devi aggiornare il tuo Personal Access Token con i permessi necessari:

1. Vai su GitHub → Settings → Developer settings → Personal access tokens
2. Genera un nuovo token con questi permessi:
   - ✅ `repo` (Full control of repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
   - ✅ `write:packages` (Write packages to GitHub Package Registry)

## 🔄 Ripristino dei Workflows

Dopo aver aggiornato il token, esegui:

```bash
cd /Users/orionstanchieri/Documents/Projects/Edoras
mv .github/workflows_temp .github/workflows
git add .
git commit -m "feat: restore GitHub Actions workflows"
git push origin main
```

## 🔧 Configurazione Azure e GitHub Secrets

### Step 1: Esegui setup Azure
```bash
# Imposta password per SQL Server
export SQL_ADMIN_PASSWORD="YourSecurePassword123!"

# Esegui setup automatico
./scripts/setup-azure-app-service.sh
```

### Step 2: Configura GitHub Secrets

Vai su **GitHub** → **Settings** → **Secrets and variables** → **Actions**

Aggiungi questi secrets dall'output dello script:

| Secret Name | Valore | Descrizione |
|-------------|--------|-------------|
| `AZURE_CREDENTIALS` | `{"clientId": "...", "clientSecret": "...", ...}` | Service Principal JSON |
| `AZURE_RESOURCE_GROUP` | `rg-edoras-2025` | Nome Resource Group |
| `DATABASE_URL` | `mssql+pyodbc://edorasadmin:PASSWORD@...` | Connection string database |
| `SECRET_KEY` | `generated-hex-string` | Chiave segreta Flask |
| `JWT_SECRET_KEY` | `generated-hex-string` | Chiave JWT |
| `AZURE_KEYVAULT_URL` | `https://edoras-keyvault-2025.vault.azure.net/` | URL Key Vault |
| `AZURE_CLIENT_ID` | `client-id-from-sp` | Client ID Service Principal |
| `AZURE_CLIENT_SECRET` | `client-secret-from-sp` | Client Secret Service Principal |
| `AZURE_TENANT_ID` | `tenant-id-from-sp` | Tenant ID Azure |

### Step 3: Test Deployment

Dopo aver configurato i secrets:

1. Ripristina i workflows (comando sopra)
2. Fai un push per triggerare il deployment:
   ```bash
   git commit --allow-empty -m "trigger: start Azure deployment"
   git push origin main
   ```

### Step 4: Verifica

L'app sarà disponibile su:
- **URL**: https://edoras-backend-api-2025.azurewebsites.net
- **Health Check**: https://edoras-backend-api-2025.azurewebsites.net/api/health
- **API Docs**: https://edoras-backend-api-2025.azurewebsites.net/api/v1/

## 🎯 Stato Attuale

✅ **Repository GitHub configurato**: https://github.com/Orion2905/edoras  
✅ **Codice pushato**: 185 files, 23k+ lines  
✅ **Booking CRUD completo**: 13 schemas + 11 endpoints  
✅ **Azure scripts pronti**: setup-azure-app-service.sh  
⏳ **Prossimo**: Configurare Personal Access Token e GitHub Secrets  

## 📁 Struttura Repository

```
edoras/
├── .github/workflows_temp/          # Workflows temporaneamente spostati
│   ├── deploy-app-service.yml       # Azure App Service deployment
│   ├── deploy-backend.yml          # Azure Container Apps deployment  
│   └── database-setup.yml          # Database migrations
├── backend/                         # Flask API backend
│   ├── src/app/                    # Application code
│   ├── requirements.txt            # Python dependencies
│   ├── Dockerfile                  # Container configuration
│   ├── startup.txt                 # Azure App Service startup
│   └── web.config                  # IIS configuration
├── scripts/                         # Setup scripts
│   ├── setup-azure-app-service.sh  # Azure App Service setup
│   └── setup-azure-deployment.sh   # Azure Container Apps setup
└── docs/                           # Documentation
    ├── AZURE_APP_SERVICE_GUIDE.md  # App Service guide
    └── AZURE_DEPLOYMENT_GUIDE.md   # Container Apps guide
```

Una volta configurato il Personal Access Token e i GitHub Secrets, il deployment sarà completamente automatico! 🚀
