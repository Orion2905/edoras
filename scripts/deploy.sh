#!/bin/bash

# Edoras Project - Azure Deploy Script
# Questo script esegue il deploy completo di backend e frontend su Azure

set -e  # Exit on any error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
PROJECT_NAME="edoras"
RESOURCE_GROUP_PREFIX="rg-edoras"
AZURE_REGION="westeurope"

# Funzioni di utility
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

# Funzione per verificare prerequisiti
check_prerequisites() {
    log_info "Verifico i prerequisiti..."
    
    # Verifica Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI non trovato. Installa Azure CLI prima di continuare."
        exit 1
    fi
    
    # Verifica login Azure
    if ! az account show &> /dev/null; then
        log_error "Non sei loggato su Azure. Esegui 'az login' prima di continuare."
        exit 1
    fi
    
        # Verifica Node.js per frontend
    if [ -f "frontend/package.json" ]; then
        if ! command -v node &> /dev/null; then
            log_error "Node.js non trovato. Installa Node.js prima di continuare."
            exit 1
        fi
        NODE_VERSION=$(node --version)
        log_info "Node.js version: $NODE_VERSION"
    fi
    
    # Verifica Python per Flask
    if [ -f "backend/requirements.txt" ]; then
        if ! command -v python3 &> /dev/null; then
            log_error "Python3 non trovato. Installa Python3 prima di continuare."
            exit 1
        fi
        PYTHON_VERSION=$(python3 --version)
        log_info "Python version: $PYTHON_VERSION"
    fi
    
    # Verifica npm/yarn per frontend
    if [ -f "frontend/package.json" ]; then
        if ! command -v npm &> /dev/null && ! command -v yarn &> /dev/null; then
            log_error "npm o yarn non trovati. Installa npm o yarn prima di continuare."
            exit 1
        fi
    fi
    
    log_success "Tutti i prerequisiti sono soddisfatti"
}

# Funzione per mostrare l'help
show_help() {
    echo "Edoras Deploy Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment ENV    Ambiente di deploy (dev|staging|prod) [default: dev]"
    echo "  -g, --resource-group RG  Nome del resource group [default: rg-edoras-ENV]"
    echo "  -r, --region REGION      Regione Azure [default: westeurope]"
    echo "  -s, --skip-build         Salta il processo di build"
    echo "  -i, --infrastructure     Deploy solo infrastruttura"
    echo "  -a, --apps-only         Deploy solo applicazioni"
    echo "  -h, --help              Mostra questo help"
    echo ""
    echo "Esempi:"
    echo "  $0                                    # Deploy completo ambiente dev"
    echo "  $0 -e prod                           # Deploy completo ambiente prod"
    echo "  $0 -e staging -i                     # Deploy solo infrastruttura staging"
    echo "  $0 -e prod -a --skip-build          # Deploy app prod senza build"
}

# Parsing parametri
ENVIRONMENT="dev"
RESOURCE_GROUP=""
SKIP_BUILD=false
INFRASTRUCTURE_ONLY=false
APPS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -r|--region)
            AZURE_REGION="$2"
            shift 2
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -i|--infrastructure)
            INFRASTRUCTURE_ONLY=true
            shift
            ;;
        -a|--apps-only)
            APPS_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Parametro sconosciuto: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validazione ambiente
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Ambiente non valido: $ENVIRONMENT. Usa: dev, staging, prod"
    exit 1
fi

# Impostazione resource group se non specificato
if [ -z "$RESOURCE_GROUP" ]; then
    RESOURCE_GROUP="${RESOURCE_GROUP_PREFIX}-${ENVIRONMENT}"
fi

# Header del deploy
echo "=================================================="
echo "    EDORAS PROJECT - AZURE DEPLOY SCRIPT"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Region: $AZURE_REGION"
echo "Skip Build: $SKIP_BUILD"
echo "Infrastructure Only: $INFRASTRUCTURE_ONLY"
echo "Apps Only: $APPS_ONLY"
echo "=================================================="
echo ""

# Verifica prerequisiti
check_prerequisites

# Funzione per creare o aggiornare resource group
setup_resource_group() {
    log_info "Configurazione Resource Group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Resource Group $RESOURCE_GROUP già esistente"
    else
        log_info "Creazione Resource Group: $RESOURCE_GROUP"
        az group create --name "$RESOURCE_GROUP" --location "$AZURE_REGION"
        log_success "Resource Group creato"
    fi
}

# Funzione per deploy infrastruttura
deploy_infrastructure() {
    log_info "Deploy infrastruttura con Bicep..."
    
    cd azure-config/bicep
    
    # Deploy del template Bicep
    log_info "Esecuzione template Bicep..."
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters "@parameters.${ENVIRONMENT}.json" \
        --verbose
    
    log_success "Infrastruttura deployata"
    
    # Mostra informazioni database
    log_info "Informazioni database:"
    
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
    
    log_info "Database Server: $DATABASE_SERVER"
    log_info "Database Name: $DATABASE_NAME"
    
    cd ../..
}

# Funzione per build backend
build_backend() {
    if [ "$SKIP_BUILD" = true ]; then
        log_warning "Skipping backend build"
        return
    fi
    
    log_info "Build del backend Flask..."
    cd backend
    
    # Verifica se è un progetto Python (Flask)
    if [ -f "requirements.txt" ]; then
        log_info "Progetto Python Flask rilevato"
        
        # Verifica se esiste virtual environment
        if [ ! -d "venv" ]; then
            log_info "Creazione virtual environment..."
            python3 -m venv venv
        fi
        
        # Attiva virtual environment
        source venv/bin/activate
        
        # Aggiorna pip
        pip install --upgrade pip
        
        # Installa dipendenze
        pip install -r requirements.txt
        
        # Verifica struttura Flask
        if [ -f "app.py" ]; then
            log_info "Verifica configurazione Flask..."
            python -c "from src.app import create_app; app = create_app('production'); print('Flask app configured successfully')" || log_warning "Flask configuration check failed"
        fi
        
        # Deattiva virtual environment
        deactivate
        
    elif [ -f "package.json" ]; then
        log_info "Progetto Node.js rilevato"
        # Installa dipendenze Node.js
        if command -v yarn &> /dev/null; then
            yarn install --frozen-lockfile
            yarn build 2>/dev/null || log_warning "Comando build non trovato, skippo"
        else
            npm ci
            npm run build 2>/dev/null || log_warning "Comando build non trovato, skippo"
        fi
    else
        log_warning "Tipo di progetto backend non riconosciuto"
    fi
    
    cd ..
    log_success "Backend build completato"
}

# Funzione per build frontend
build_frontend() {
    if [ "$SKIP_BUILD" = true ]; then
        log_warning "Skipping frontend build"
        return
    fi
    
    log_info "Build del frontend..."
    cd frontend
    
    # Installa dipendenze e build
    if [ -f "package.json" ]; then
        if command -v yarn &> /dev/null; then
            yarn install --frozen-lockfile
            yarn build 2>/dev/null || log_warning "Comando build non trovato, skippo"
        else
            npm ci
            npm run build 2>/dev/null || log_warning "Comando build non trovato, skippo"
        fi
    else
        log_warning "package.json non trovato nel frontend"
    fi
    
    cd ..
    log_success "Frontend build completato"
}

# Funzione per deploy backend
deploy_backend() {
    log_info "Deploy del backend Flask..."
    
    # Ottieni il nome dell'app backend
    BACKEND_APP_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.backendUrl.value" \
        --output tsv | sed 's|https://||' | sed 's|\.azurewebsites\.net||')
    
    if [ -z "$BACKEND_APP_NAME" ]; then
        log_error "Nome app backend non trovato. Assicurati che l'infrastruttura sia stata deployata."
        exit 1
    fi
    
    log_info "Deploy su app: $BACKEND_APP_NAME"
    
    cd backend
    
    # Deploy Flask application
    if [ -f "requirements.txt" ]; then
        log_info "Deploy applicazione Flask..."
        
        # Crea zip escludendo virtual environment e cache
        zip -r "../backend-deploy.zip" . \
            -x "venv/*" "__pycache__/*" "*.pyc" "*.pyo" \
            -x "tests/*" "*.md" ".pytest_cache/*" \
            -x ".env" ".env.*" "instance/*"
        
        cd ..
        
        # Deploy tramite zip
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$BACKEND_APP_NAME" \
            --src "backend-deploy.zip"
        
        # Configura startup command per Flask
        az webapp config set \
            --resource-group "$RESOURCE_GROUP" \
            --name "$BACKEND_APP_NAME" \
            --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
        
        rm -f backend-deploy.zip
        
    elif [ -f "package.json" ]; then
        log_info "Deploy applicazione Node.js..."
        # Deploy tramite zip per Node.js
        zip -r "../backend-deploy.zip" . -x "node_modules/*" "tests/*" "*.md"
        cd ..
        
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$BACKEND_APP_NAME" \
            --src "backend-deploy.zip"
        
        rm -f backend-deploy.zip
    else
        cd ..
        log_warning "Tipo di progetto non riconosciuto, creando deploy generico"
        
        cd backend
        zip -r "../backend-deploy.zip" .
        cd ..
        
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$BACKEND_APP_NAME" \
            --src "backend-deploy.zip"
        
        rm -f backend-deploy.zip
    fi
    
    log_success "Backend deployato"
}

# Funzione per deploy frontend
deploy_frontend() {
    log_info "Deploy del frontend..."
    
    # Ottieni il nome dell'app frontend
    FRONTEND_APP_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.frontendUrl.value" \
        --output tsv | sed 's|https://||' | sed 's|\.azurewebsites\.net||')
    
    if [ -z "$FRONTEND_APP_NAME" ]; then
        log_error "Nome app frontend non trovato. Assicurati che l'infrastruttura sia stata deployata."
        exit 1
    fi
    
    log_info "Deploy su app: $FRONTEND_APP_NAME"
    
    cd frontend
    
    # Deploy frontend
    if [ -d "build" ] || [ -d "dist" ]; then
        # Deploy della build directory
        BUILD_DIR="build"
        [ -d "dist" ] && BUILD_DIR="dist"
        
        cd "$BUILD_DIR"
        zip -r "../../frontend-deploy.zip" .
        cd ../..
        
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$FRONTEND_APP_NAME" \
            --src "frontend-deploy.zip"
        
        rm -f frontend-deploy.zip
    else
        # Deploy dell'intera cartella frontend
        zip -r "../frontend-deploy.zip" . -x "node_modules/*" "tests/*" "*.md"
        cd ..
        
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$FRONTEND_APP_NAME" \
            --src "frontend-deploy.zip"
        
        rm -f frontend-deploy.zip
    fi
    
    log_success "Frontend deployato"
}

# Funzione per setup database
setup_database_if_needed() {
    log_info "Verifica setup database..."
    
    # Verifica se è necessario configurare il database
    read -p "Vuoi configurare il database ora? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Esecuzione setup database..."
        
        # Esegui script di setup database
        chmod +x scripts/setup-database.sh
        ./scripts/setup-database.sh "$ENVIRONMENT"
        
        log_success "Setup database completato"
    else
        log_warning "Setup database saltato. Puoi eseguirlo manualmente con:"
        log_warning "./scripts/setup-database.sh $ENVIRONMENT"
    fi
}
show_urls() {
    log_info "Recupero URLs delle applicazioni..."
    
    BACKEND_URL=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.backendUrl.value" \
        --output tsv 2>/dev/null || echo "Non disponibile")
    
    FRONTEND_URL=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "main" \
        --query "properties.outputs.frontendUrl.value" \
        --output tsv 2>/dev/null || echo "Non disponibile")
    
    echo ""
    echo "=================================================="
    echo "           DEPLOY COMPLETATO CON SUCCESSO!"
    echo "=================================================="
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo "Environment:  $ENVIRONMENT"
    echo "=================================================="
}

# Main execution flow
main() {
    # Setup resource group
    setup_resource_group
    
    # Deploy infrastruttura (se richiesto)
    if [ "$APPS_ONLY" = false ]; then
        deploy_infrastructure
    fi
    
    # Deploy applicazioni (se richiesto)
    if [ "$INFRASTRUCTURE_ONLY" = false ]; then
        # Build
        build_backend
        build_frontend
        
        # Deploy
        deploy_backend
        deploy_frontend
        
        # Setup database dopo deploy backend
        setup_database_if_needed
    fi
    
    # Mostra risultati finali
    show_urls
}

# Esegui il main
main
