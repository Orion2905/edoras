#!/bin/bash

# Script per setup automatico Azure Container Apps deployment
# Edoras Backend API - Deploy Setup

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
RESOURCE_GROUP="rg-edoras-2025"
LOCATION="West Europe"
CONTAINER_REGISTRY="edorasregistry2025"
CONTAINER_ENV="edoras-container-env"
CONTAINER_APP="edoras-backend-api"
KEYVAULT_NAME="edoras-keyvault-2025"

echo -e "${BLUE}🚀 Setup Azure Container Apps per Edoras Backend API${NC}"
echo "=================================================="

# 1. Verifica login Azure
echo -e "${YELLOW}📝 Verificando login Azure...${NC}"
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}❌ Non sei loggato in Azure. Esegui: az login${NC}"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✅ Login Azure OK - Subscription: $SUBSCRIPTION_ID${NC}"

# 2. Creare Resource Group
echo -e "${YELLOW}📦 Creando Resource Group...${NC}"
az group create \
    --name $RESOURCE_GROUP \
    --location "$LOCATION" \
    --output table

echo -e "${GREEN}✅ Resource Group creato${NC}"

# 3. Creare Container Registry
echo -e "${YELLOW}🐳 Creando Container Registry...${NC}"
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_REGISTRY \
    --sku Basic \
    --admin-enabled true \
    --output table

echo -e "${GREEN}✅ Container Registry creato${NC}"

# 4. Creare Container Apps Environment
echo -e "${YELLOW}🌍 Creando Container Apps Environment...${NC}"
az containerapp env create \
    --name $CONTAINER_ENV \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --output table

echo -e "${GREEN}✅ Container Apps Environment creato${NC}"

# 5. Creare Key Vault (se non esiste)
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

# 6. Ottenere credenziali ACR
echo -e "${YELLOW}🔑 Ottenendo credenziali Container Registry...${NC}"
ACR_CREDS=$(az acr credential show --name $CONTAINER_REGISTRY)
ACR_USERNAME=$(echo $ACR_CREDS | jq -r '.username')
ACR_PASSWORD=$(echo $ACR_CREDS | jq -r '.passwords[0].value')

echo -e "${GREEN}✅ Credenziali Container Registry ottenute${NC}"

# 7. Creare Service Principal per GitHub Actions
echo -e "${YELLOW}👤 Creando Service Principal per GitHub Actions...${NC}"
SP_NAME="edoras-github-deploy"
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

# 8. Output finale con informazioni per GitHub Secrets
echo -e "\n${BLUE}🎯 SETUP COMPLETATO!${NC}"
echo "============================="
echo ""
echo -e "${YELLOW}📋 GitHub Secrets da configurare:${NC}"
echo ""
echo -e "${GREEN}ACR_USERNAME:${NC}"
echo "$ACR_USERNAME"
echo ""
echo -e "${GREEN}ACR_PASSWORD:${NC}"
echo "$ACR_PASSWORD"
echo ""
echo -e "${GREEN}AZURE_CREDENTIALS:${NC}"
echo "$SP_CREDS"
echo ""
echo -e "${YELLOW}📋 Prossimi passi:${NC}"
echo "1. 🔑 Aggiungi i GitHub Secrets sopra al tuo repository"
echo "2. 🔐 Configura le variabili d'ambiente nel Key Vault:"
echo "   - DATABASE_URL"
echo "   - SECRET_KEY"
echo "   - JWT_SECRET_KEY"
echo "   - AZURE_CLIENT_ID"
echo "   - AZURE_CLIENT_SECRET"
echo "   - AZURE_TENANT_ID"
echo "3. 🚀 Push del codice per avviare il deployment automatico"
echo ""
echo -e "${GREEN}✅ Azure Container Apps setup completato!${NC}"
