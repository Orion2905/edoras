#!/bin/bash

# Quick Start Script per Edoras Azure Setup
# Questo script esegue tutto il setup necessario in un comando

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Banner
echo "=================================================="
echo "    🚀 EDORAS AZURE QUICK START 🚀"
echo "=================================================="
echo "Questo script configura l'intera infrastruttura"
echo "Azure per Edoras in un comando singolo."
echo "=================================================="

# Configurazione
ENVIRONMENT=${1:-"prod"}
LOCATION=${2:-"West Europe"}

echo "Environment: $ENVIRONMENT"
echo "Location: $LOCATION"
echo ""

# Verifica prerequisiti
log_step "1/6 - Verifica Prerequisiti"

if ! command -v az &> /dev/null; then
    log_error "Azure CLI non trovato. Installa con: brew install azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    log_error "Non sei loggato su Azure. Esegui: az login"
    exit 1
fi

log_success "Prerequisiti verificati"

# Step 1: Deploy Infrastructure
log_step "2/6 - Deploy Infrastruttura Azure"
log_info "Creazione risorse: Resource Group, SQL Server, App Services, Key Vault, Storage..."

if ./scripts/deploy.sh "$ENVIRONMENT"; then
    log_success "Infrastruttura Azure deployata"
else
    log_error "Errore nel deploy dell'infrastruttura"
    exit 1
fi

# Step 2: Setup Key Vault
log_step "3/6 - Configurazione Key Vault"
log_info "Configurazione segreti per produzione..."

if ./scripts/setup-keyvault.sh "$ENVIRONMENT"; then
    log_success "Key Vault configurato"
else
    log_error "Errore nella configurazione Key Vault"
    exit 1
fi

# Step 3: Setup Database
log_step "4/6 - Setup Database"
log_info "Inizializzazione database e migrazioni..."

if ./scripts/setup-database.sh "$ENVIRONMENT"; then
    log_success "Database configurato"
else
    log_error "Errore nel setup database"
    exit 1
fi

# Step 4: Deploy Backend
log_step "5/6 - Deploy Backend Flask"
log_info "Deploy applicazione backend..."

RESOURCE_GROUP="rg-edoras-${ENVIRONMENT}"
BACKEND_APP="edoras-${ENVIRONMENT}-backend"

cd backend

# Crea archivio per deploy
if [ ! -f "../backend-deploy.zip" ]; then
    log_info "Creazione archivio backend per deploy..."
    zip -r ../backend-deploy.zip . -x "venv/*" "__pycache__/*" "*.pyc" "node_modules/*" ".git/*"
fi

# Deploy backend
log_info "Deploy backend su Azure App Service..."
az webapp deploy \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_APP" \
    --src-path "../backend-deploy.zip" \
    --type zip

cd ..

log_success "Backend deployato"

# Step 5: Configurazioni finali
log_step "6/6 - Configurazioni Finali"

# Restart app service per assicurare che prenda le nuove configurazioni
log_info "Restart App Service per applicare configurazioni..."
az webapp restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_APP"

# Test health check
log_info "Test health check..."
BACKEND_URL=$(az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_APP" \
    --query "defaultHostName" \
    --output tsv)

# Aspetta che il servizio si avvii
sleep 30

if curl -f -s "https://${BACKEND_URL}/api/v1/health" > /dev/null; then
    log_success "Health check passed!"
else
    log_warning "Health check fallito, potrebbe essere necessario del tempo per l'avvio"
fi

# Ottieni informazioni finali
KEYVAULT_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "main" \
    --query "properties.outputs.keyVaultName.value" \
    --output tsv)

DB_SERVER=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "main" \
    --query "properties.outputs.sqlServerFqdn.value" \
    --output tsv)

DB_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "main" \
    --query "properties.outputs.databaseName.value" \
    --output tsv)

# Output finale
echo ""
echo "=================================================="
echo "         ✅ SETUP COMPLETATO CON SUCCESSO!"
echo "=================================================="
echo ""
echo "🌐 URLs:"
echo "   Backend:  https://${BACKEND_URL}"
echo "   Health:   https://${BACKEND_URL}/api/v1/health"
echo ""
echo "🗄️ Database:"
echo "   Server:   $DB_SERVER"
echo "   Database: $DB_NAME"
echo ""
echo "🔐 Key Vault:"
echo "   Name:     $KEYVAULT_NAME"
echo ""
echo "📱 API Endpoints:"
echo "   Health:       GET  /api/v1/health"
echo "   Auth Login:   POST /api/v1/auth/login"
echo "   Auth Register:POST /api/v1/auth/register"
echo "   Users:        GET  /api/v1/users"
echo ""
echo "🔧 Utili Commands:"
echo "   Logs:         az webapp log tail --name $BACKEND_APP --resource-group $RESOURCE_GROUP"
echo "   Restart:      az webapp restart --name $BACKEND_APP --resource-group $RESOURCE_GROUP"
echo ""
echo "=================================================="
echo "Il tuo ambiente Edoras $ENVIRONMENT è pronto! 🎉"
echo "=================================================="

# Cleanup
rm -f backend-deploy.zip

log_success "Quick start completato!"
