# Azure Container Apps Configuration
# Questo file documenta la configurazione per il deployment

# Risorse Azure necessarie:
# 1. Container Registry (ACR)
# 2. Container Apps Environment  
# 3. Container App
# 4. Key Vault per i segreti
# 5. Database (Azure SQL o PostgreSQL)

# Comandi Azure CLI per setup iniziale:

# 1. Creare il Resource Group
# az group create --name rg-edoras-2025 --location "West Europe"

# 2. Creare il Container Registry
# az acr create --resource-group rg-edoras-2025 --name edorasregistry2025 --sku Basic --admin-enabled true

# 3. Creare Container Apps Environment
# az containerapp env create --name edoras-container-env --resource-group rg-edoras-2025 --location "West Europe"

# 4. Ottenere le credenziali ACR per GitHub Secrets
# az acr credential show --name edorasregistry2025

# 5. Creare Service Principal per GitHub Actions
# az ad sp create-for-rbac --name "edoras-github-deploy" --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/rg-edoras-2025 --sdk-auth

# Environment Variables richieste:
ENV_VARS = {
    "FLASK_ENV": "production",
    "FLASK_APP": "app.py", 
    "DATABASE_URL": "your-database-connection-string",
    "SECRET_KEY": "your-secret-key",
    "JWT_SECRET_KEY": "your-jwt-secret-key",
    "AZURE_KEYVAULT_URL": "https://edoras-keyvault-2025.vault.azure.net/",
    "AZURE_CLIENT_ID": "your-service-principal-client-id",
    "AZURE_CLIENT_SECRET": "your-service-principal-client-secret", 
    "AZURE_TENANT_ID": "your-azure-tenant-id"
}

# GitHub Secrets richiesti:
GITHUB_SECRETS = {
    "ACR_USERNAME": "Username del Container Registry",
    "ACR_PASSWORD": "Password del Container Registry", 
    "AZURE_CREDENTIALS": "JSON del Service Principal per deploy",
    "DATABASE_URL": "Connection string del database",
    "SECRET_KEY": "Chiave segreta Flask",
    "JWT_SECRET_KEY": "Chiave JWT",
    "AZURE_KEYVAULT_URL": "URL del Key Vault",
    "AZURE_CLIENT_ID": "Client ID del Service Principal",
    "AZURE_CLIENT_SECRET": "Client Secret del Service Principal",
    "AZURE_TENANT_ID": "Tenant ID Azure"
}

# Scaling Configuration:
SCALING = {
    "minReplicas": 1,
    "maxReplicas": 10,
    "targetCPU": 70,
    "targetMemory": 80
}
