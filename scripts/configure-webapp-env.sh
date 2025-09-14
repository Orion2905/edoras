#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurazione esistente
RESOURCE_GROUP="rg-edoras-prod"
WEBAPP_NAME="edoras-backend-api"
KEYVAULT_NAME="edoras-keyvault-2025"
SQL_SERVER_NAME="edoras-sql-2025"
SQL_DATABASE_NAME="edoras-prod-database"

echo -e "${BLUE}🔧 Configurazione Web App Edoras Backend API${NC}"
echo "================================================"

# Verifica login Azure
echo -e "${YELLOW}📝 Verificando login Azure...${NC}"
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Non sei loggato ad Azure${NC}"
    az login
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✅ Login Azure OK - Subscription: $SUBSCRIPTION_ID${NC}"

# Ottieni connection string del database
echo -e "${YELLOW}🔗 Ottenendo connection string database...${NC}"
DB_CONNECTION_STRING=$(az sql db show-connection-string \
    --client ado.net \
    --server $SQL_SERVER_NAME \
    --name $SQL_DATABASE_NAME \
    --output tsv)

# Sostituisci placeholders nella connection string
echo -e "${YELLOW}🔐 Inserisci username del database admin:${NC}"
read -r DB_USERNAME
echo -e "${YELLOW}🔐 Inserisci password del database admin:${NC}"
read -rs DB_PASSWORD

# Modifica la connection string
DB_CONNECTION_STRING=${DB_CONNECTION_STRING//<username>/$DB_USERNAME}
DB_CONNECTION_STRING=${DB_CONNECTION_STRING//<password>/$DB_PASSWORD}

echo -e "${GREEN}✅ Connection string configurata${NC}"

# Configura variabili d'ambiente nella Web App
echo -e "${YELLOW}⚙️ Configurando variabili d'ambiente Web App...${NC}"

az webapp config appsettings set \
    --resource-group $RESOURCE_GROUP \
    --name $WEBAPP_NAME \
    --settings \
        FLASK_ENV=production \
        FLASK_APP=app.py \
        DATABASE_URL="$DB_CONNECTION_STRING" \
        SECRET_KEY="$(openssl rand -hex 32)" \
        JWT_SECRET_KEY="$(openssl rand -hex 32)" \
        AZURE_KEY_VAULT_URL="https://$KEYVAULT_NAME.vault.azure.net/" \
        PYTHONPATH="/home/site/wwwroot" \
        SCM_DO_BUILD_DURING_DEPLOYMENT=true \
        ENABLE_ORYX_BUILD=true \
        POST_BUILD_SCRIPT_PATH="scripts/post-build.sh" \
    --output table

echo -e "${GREEN}✅ Variabili d'ambiente configurate${NC}"

# Configura startup command
echo -e "${YELLOW}🚀 Configurando comando di startup...${NC}"
az webapp config set \
    --resource-group $RESOURCE_GROUP \
    --name $WEBAPP_NAME \
    --startup-file "startup.txt" \
    --output table

echo -e "${GREEN}✅ Comando di startup configurato${NC}"

# Riavvia la web app
echo -e "${YELLOW}🔄 Riavviando Web App...${NC}"
az webapp restart \
    --resource-group $RESOURCE_GROUP \
    --name $WEBAPP_NAME \
    --output table

echo -e "${GREEN}✅ Web App riavviata${NC}"

# Output informazioni finali
echo -e "${BLUE}📋 Deployment Completato!${NC}"
echo "=========================================="
echo -e "${GREEN}🌐 URL Web App: https://$WEBAPP_NAME.azurewebsites.net${NC}"
echo -e "${GREEN}🔗 URL API: https://$WEBAPP_NAME.azurewebsites.net/api/v1${NC}"
echo -e "${GREEN}🏥 Health Check: https://$WEBAPP_NAME.azurewebsites.net/health${NC}"
echo -e "${GREEN}📚 API Docs: https://$WEBAPP_NAME.azurewebsites.net/docs${NC}"
echo ""
echo -e "${YELLOW}📝 Prossimi passi:${NC}"
echo "1. Esegui il workflow GitHub Actions per deployare il codice"
echo "2. Verifica che l'API risponda correttamente"
echo "3. Testa gli endpoint di autenticazione e booking"
echo ""
echo -e "${BLUE}🎉 Setup Azure completato con successo!${NC}"
