#!/bin/bash

# Script per setup Azure App Service deployment
# Edoras Backend API - App Service Setup

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
RESOURCE_GROUP="rg-edoras-prod"
LOCATION="West Europe"
APP_SERVICE_PLAN="edoras-app-service-plan"
WEBAPP_NAME="edoras-backend-api"
KEYVAULT_NAME="edoras-keyvault"
SQL_SERVER_NAME="edoras-sql-server"
SQL_DATABASE_NAME="edoras-db"
SQL_ADMIN_USER="edorasadmin"

echo -e "${BLUE}🚀 Setup Azure App Service per Edoras Backend API${NC}"
echo "=================================================="

# Verifica se SQL_ADMIN_PASSWORD è impostata
if [ -z "$SQL_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}🔐 Inserisci password per SQL Server admin (min 8 caratteri, lettere maiuscole, minuscole, numeri):${NC}"
    read -s SQL_ADMIN_PASSWORD
    echo
fi

# 1. Verifica login Azure
echo -e "${YELLOW}📝 Verificando login Azure...${NC}"
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}❌ Non sei loggato in Azure. Esegui: az login${NC}"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✅ Login Azure OK - Subscription: $SUBSCRIPTION_ID${NC}"

# 2. Verificare Resource Group esistente
echo -e "${YELLOW}📦 Verificando Resource Group esistente...${NC}"
if az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo -e "${GREEN}✅ Resource Group $RESOURCE_GROUP esiste già${NC}"
else
    echo -e "${RED}❌ Resource Group $RESOURCE_GROUP non trovato${NC}"
    echo -e "${YELLOW}Creando Resource Group...${NC}"
    az group create \
        --name $RESOURCE_GROUP \
        --location "$LOCATION" \
        --output table
    echo -e "${GREEN}✅ Resource Group creato${NC}"
fi

# 3. Creare App Service Plan
echo -e "${YELLOW}🏗️ Creando App Service Plan...${NC}"
az appservice plan create \
    --name $APP_SERVICE_PLAN \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --sku B1 \
    --is-linux \
    --output table

echo -e "${GREEN}✅ App Service Plan creato${NC}"

# 4. Creare Web App
echo -e "${YELLOW}🌐 Creando Web App...${NC}"
az webapp create \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --name $WEBAPP_NAME \
    --runtime "PYTHON|3.11" \
    --startup-file "gunicorn --bind=0.0.0.0:8000 --timeout 600 app:app" \
    --output table

echo -e "${GREEN}✅ Web App creata${NC}"

# 5. Configurare HTTPS only
echo -e "${YELLOW}🔒 Configurando HTTPS only...${NC}"
az webapp update \
    --name $WEBAPP_NAME \
    --resource-group $RESOURCE_GROUP \
    --https-only true \
    --output table

# 6. Creare Azure SQL Server e Database
echo -e "${YELLOW}💾 Creando Azure SQL Server...${NC}"
az sql server create \
    --name $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --admin-user $SQL_ADMIN_USER \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --output table

echo -e "${GREEN}✅ SQL Server creato${NC}"

# 7. Configurare firewall SQL Server per Azure services
echo -e "${YELLOW}🔥 Configurando firewall SQL Server...${NC}"
az sql server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --server $SQL_SERVER_NAME \
    --name AllowAzureServices \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    --output table

# 8. Creare database
echo -e "${YELLOW}🗄️ Creando database...${NC}"
az sql db create \
    --resource-group $RESOURCE_GROUP \
    --server $SQL_SERVER_NAME \
    --name $SQL_DATABASE_NAME \
    --service-objective Basic \
    --output table

echo -e "${GREEN}✅ Database creato${NC}"

# 9. Creare Key Vault (se non esiste)
echo -e "${YELLOW}🔐 Verificando Key Vault...${NC}"
if ! az keyvault show --name $KEYVAULT_NAME > /dev/null 2>&1; then
    echo -e "${YELLOW}🔑 Creando Key Vault...${NC}"
    az keyvault create \
        --name $KEYVAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location "$LOCATION" \
        --output table
    echo -e "${GREEN}✅ Key Vault creato${NC}"
else
    echo -e "${GREEN}✅ Key Vault già esistente${NC}"
fi

# 10. Ottenere identità gestita per la Web App
echo -e "${YELLOW}🆔 Configurando identità gestita...${NC}"
WEBAPP_IDENTITY=$(az webapp identity assign \
    --name $WEBAPP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query principalId \
    --output tsv)

echo -e "${GREEN}✅ Identità gestita configurata: $WEBAPP_IDENTITY${NC}"

# 11. Dare permessi alla Web App per accedere al Key Vault
echo -e "${YELLOW}🔑 Configurando permessi Key Vault...${NC}"
az keyvault set-policy \
    --name $KEYVAULT_NAME \
    --object-id $WEBAPP_IDENTITY \
    --secret-permissions get list \
    --output table

echo -e "${GREEN}✅ Permessi Key Vault configurati${NC}"

# 12. Creare Service Principal per GitHub Actions
echo -e "${YELLOW}👤 Creando Service Principal per GitHub Actions...${NC}"
SP_NAME="edoras-github-deploy-appservice"
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# Elimina SP esistente se presente
az ad sp delete --id "http://$SP_NAME" 2>/dev/null || true

# Crea nuovo SP
SP_CREDS=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role contributor \
    --scopes "$SCOPE" \
    --sdk-auth)

echo -e "${GREEN}✅ Service Principal creato${NC}"

# 13. Ottenere connection string del database
echo -e "${YELLOW}🔗 Generando connection string...${NC}"
CONNECTION_STRING="mssql+pyodbc://${SQL_ADMIN_USER}:${SQL_ADMIN_PASSWORD}@${SQL_SERVER_NAME}.database.windows.net/${SQL_DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server"

# 14. Generare chiavi segrete
echo -e "${YELLOW}🔐 Generando chiavi segrete...${NC}"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# 15. Output finale
echo -e "\n${BLUE}🎯 SETUP AZURE APP SERVICE COMPLETATO!${NC}"
echo "============================================="
echo ""
echo -e "${GREEN}📱 Web App URL:${NC} https://${WEBAPP_NAME}.azurewebsites.net"
echo -e "${GREEN}🗄️ Database Server:${NC} ${SQL_SERVER_NAME}.database.windows.net"
echo -e "${GREEN}🔑 Key Vault URL:${NC} https://${KEYVAULT_NAME}.vault.azure.net/"
echo ""
echo -e "${YELLOW}📋 GitHub Secrets da configurare:${NC}"
echo ""
echo -e "${GREEN}AZURE_CREDENTIALS:${NC}"
echo "$SP_CREDS"
echo ""
echo -e "${GREEN}AZURE_RESOURCE_GROUP:${NC}"
echo "$RESOURCE_GROUP"
echo ""
echo -e "${GREEN}DATABASE_URL:${NC}"
echo "$CONNECTION_STRING"
echo ""
echo -e "${GREEN}SECRET_KEY:${NC}"
echo "$SECRET_KEY"
echo ""
echo -e "${GREEN}JWT_SECRET_KEY:${NC}"
echo "$JWT_SECRET_KEY"
echo ""
echo -e "${GREEN}AZURE_KEYVAULT_URL:${NC}"
echo "https://${KEYVAULT_NAME}.vault.azure.net/"
echo ""
echo -e "${GREEN}AZURE_CLIENT_ID:${NC}"
echo "$(echo $SP_CREDS | jq -r '.clientId')"
echo ""
echo -e "${GREEN}AZURE_CLIENT_SECRET:${NC}"
echo "$(echo $SP_CREDS | jq -r '.clientSecret')"
echo ""
echo -e "${GREEN}AZURE_TENANT_ID:${NC}"
echo "$(echo $SP_CREDS | jq -r '.tenantId')"
echo ""
echo -e "${YELLOW}📋 Prossimi passi:${NC}"
echo "1. 🔑 Aggiungi i GitHub Secrets sopra al tuo repository"
echo "2. 🚀 Push del codice per avviare il deployment automatico"
echo "3. 🔍 Testa l'API: https://${WEBAPP_NAME}.azurewebsites.net/api/health"
echo ""
echo -e "${GREEN}✅ Azure App Service setup completato!${NC}"
