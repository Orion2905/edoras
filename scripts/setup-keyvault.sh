#!/bin/bash

# Script per configurare Azure Key Vault con tutti i segreti necessari
# Questo script popolata il Key Vault con le configurazioni sicure

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Configurazione
ENVIRONMENT=${1:-"prod"}
RESOURCE_GROUP="rg-edoras-${ENVIRONMENT}"

echo "=================================================="
echo "    EDORAS KEY VAULT SETUP SCRIPT"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "=================================================="

# Funzione per ottenere nome Key Vault
get_keyvault_name() {
    log_info "Recupero nome Key Vault..."
    
    KEY_VAULT_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.keyVaultName.value" \
        --output tsv)
    
    if [ -z "$KEY_VAULT_NAME" ]; then
        log_error "Impossibile ottenere nome Key Vault. Assicurati che l'infrastruttura sia stata deployata."
        exit 1
    fi
    
    log_info "Key Vault Name: $KEY_VAULT_NAME"
}

# Funzione per generare password sicura
generate_secure_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Funzione per configurare segreti nel Key Vault
configure_secrets() {
    log_info "Configurazione segreti nel Key Vault..."
    
    # JWT Secret Key
    JWT_SECRET=$(generate_secure_password)
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "jwt-secret" \
        --value "$JWT_SECRET" > /dev/null
    log_success "JWT Secret configurato"
    
    # Flask Secret Key
    FLASK_SECRET=$(generate_secure_password)
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "flask-secret" \
        --value "$FLASK_SECRET" > /dev/null
    log_success "Flask Secret configurato"
    
    # Database Connection String (se necessario)
    if [ "$ENVIRONMENT" = "prod" ]; then
        DATABASE_PASSWORD="EdorasSecure123!"
    else
        DATABASE_PASSWORD="EdorasDevSecure123!"
    fi
    
    DATABASE_SERVER=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.sqlServerFqdn.value" \
        --output tsv)
    
    DATABASE_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.databaseName.value" \
        --output tsv)
    
    DATABASE_URL="mssql+pyodbc://edorasadmin:${DATABASE_PASSWORD}@${DATABASE_SERVER}/${DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server"
    
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "database-url" \
        --value "$DATABASE_URL" > /dev/null
    log_success "Database URL configurato"
    
    # Storage Connection String
    STORAGE_CONNECTION=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.storageConnectionString.value" \
        --output tsv)
    
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "storage-connection-string" \
        --value "$STORAGE_CONNECTION" > /dev/null
    log_success "Storage Connection String configurato"
    
    # API Keys (esempio per servizi esterni)
    API_KEY=$(generate_secure_password)
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "api-key" \
        --value "$API_KEY" > /dev/null
    log_success "API Key configurato"
}

# Funzione per verificare accesso Key Vault
verify_keyvault_access() {
    log_info "Verifica accesso Key Vault..."
    
    # Test lettura di un segreto
    TEST_SECRET=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "jwt-secret" \
        --query "value" \
        --output tsv 2>/dev/null)
    
    if [ -n "$TEST_SECRET" ]; then
        log_success "Accesso Key Vault verificato"
    else
        log_error "Impossibile accedere ai segreti del Key Vault"
        return 1
    fi
}

# Funzione per mostrare segreti configurati
show_configured_secrets() {
    log_info "Segreti configurati nel Key Vault:"
    
    SECRETS=$(az keyvault secret list \
        --vault-name "$KEY_VAULT_NAME" \
        --query "[].name" \
        --output tsv)
    
    for secret in $SECRETS; do
        echo "  ✅ $secret"
    done
}

# Funzione per configurare accesso App Service al Key Vault
configure_app_service_access() {
    log_info "Configurazione accesso App Service al Key Vault..."
    
    # Ottieni App Service identity
    BACKEND_APP_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.backendUrl.value" \
        --output tsv | sed 's|https://||' | sed 's|\.azurewebsites\.net||')
    
    # Abilita System Assigned Identity se non già abilitata
    az webapp identity assign \
        --resource-group "$RESOURCE_GROUP" \
        --name "$BACKEND_APP_NAME" > /dev/null
    
    # Ottieni Principal ID
    PRINCIPAL_ID=$(az webapp identity show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$BACKEND_APP_NAME" \
        --query "principalId" \
        --output tsv)
    
    # Configura access policy
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --object-id "$PRINCIPAL_ID" \
        --secret-permissions get list > /dev/null
    
    log_success "Accesso App Service configurato"
}

# Funzione per creare file di backup configurazione
create_config_backup() {
    log_info "Creazione backup configurazione..."
    
    BACKUP_FILE="keyvault-config-${ENVIRONMENT}-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$BACKUP_FILE" << EOF
{
  "environment": "$ENVIRONMENT",
  "resourceGroup": "$RESOURCE_GROUP",
  "keyVaultName": "$KEY_VAULT_NAME",
  "configuredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "secrets": [
    "jwt-secret",
    "flask-secret", 
    "database-url",
    "storage-connection-string",
    "api-key"
  ],
  "databaseServer": "$DATABASE_SERVER",
  "databaseName": "$DATABASE_NAME"
}
EOF
    
    log_success "Backup configurazione salvato: $BACKUP_FILE"
}

# Main execution
main() {
    # Verifica prerequisiti
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI non trovato"
        exit 1
    fi
    
    # Verifica login Azure
    if ! az account show &> /dev/null; then
        log_error "Non sei loggato su Azure. Esegui 'az login'"
        exit 1
    fi
    
    # Ottieni nome Key Vault
    get_keyvault_name
    
    # Configura segreti
    configure_secrets
    
    # Configura accesso App Service
    configure_app_service_access
    
    # Verifica accesso
    verify_keyvault_access
    
    # Mostra segreti configurati
    show_configured_secrets
    
    # Crea backup configurazione
    create_config_backup
    
    echo ""
    echo "=================================================="
    echo "         KEY VAULT SETUP COMPLETATO!"
    echo "=================================================="
    echo "Key Vault: $KEY_VAULT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Segreti configurati: 5"
    echo ""
    echo "Le App Service possono ora accedere ai segreti"
    echo "usando la sintassi @Microsoft.KeyVault(...)"
    echo "=================================================="
}

# Esegui main
main
