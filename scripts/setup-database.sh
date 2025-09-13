#!/bin/bash

# Script per setup iniziale database Azure SQL
# Questo script inizializza il database con le tabelle necessarie

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
ENVIRONMENT=${1:-"dev"}
RESOURCE_GROUP="rg-edoras-${ENVIRONMENT}"

echo "=================================================="
echo "    EDORAS DATABASE SETUP SCRIPT"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "=================================================="

# Funzione per ottenere informazioni database
get_database_info() {
    log_info "Recupero informazioni database..."
    
    # Ottieni outputs dal deployment
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
    
    if [ -z "$DATABASE_SERVER" ] || [ -z "$DATABASE_NAME" ]; then
        log_error "Impossibile ottenere informazioni database. Assicurati che l'infrastruttura sia stata deployata."
        exit 1
    fi
    
    log_info "Database Server: $DATABASE_SERVER"
    log_info "Database Name: $DATABASE_NAME"
}

# Funzione per inizializzare database con Flask-Migrate
init_database_with_flask() {
    log_info "Inizializzazione database con Flask-Migrate..."
    
    cd backend
    
    # Verifica se virtual environment esiste
    if [ ! -d "venv" ]; then
        log_info "Creazione virtual environment..."
        python3 -m venv venv
    fi
    
    # Attiva virtual environment
    source venv/bin/activate
    
    # Installa dipendenze se necessario
    if [ ! -f "venv/lib/python*/site-packages/Flask*" ]; then
        log_info "Installazione dipendenze..."
        pip install -r requirements.txt
    fi
    
    # Configura environment per Azure database
    export FLASK_APP=app.py
    export FLASK_ENV=$ENVIRONMENT
    export DATABASE_URL="mssql+pyodbc://edorasadmin:EdorasSecure123!@${DATABASE_SERVER}/${DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server"
    
    log_info "Inizializzazione Flask-Migrate..."
    
    # Inizializza migrations se non esistono
    if [ ! -d "migrations" ]; then
        flask db init
        log_success "Flask-Migrate inizializzato"
    fi
    
    # Crea migration iniziale
    flask db migrate -m "Initial migration - Users table"
    log_success "Migration creata"
    
    # Applica migration al database
    flask db upgrade
    log_success "Migration applicata al database"
    
    # Deattiva virtual environment
    deactivate
    cd ..
}

# Funzione per creare utente admin iniziale
create_admin_user() {
    log_info "Creazione utente admin iniziale..."
    
    cd backend
    source venv/bin/activate
    
    # Script Python per creare admin
    python3 << EOF
import os
import sys
sys.path.append('src')

from app import create_app
from app.models.user import User
from app.extensions import db

# Configura database URL
os.environ['DATABASE_URL'] = "mssql+pyodbc://edorasadmin:EdorasSecure123!@${DATABASE_SERVER}/${DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server"

app = create_app('$ENVIRONMENT')

with app.app_context():
    # Verifica se admin esiste già
    admin = User.query.filter_by(email='admin@edoras.com').first()
    
    if not admin:
        # Crea utente admin
        admin = User(
            email='admin@edoras.com',
            username='admin',
            first_name='Admin',
            last_name='Edoras',
            is_admin=True,
            is_active=True,
            email_verified=True
        )
        admin.set_password('AdminSecure123!')
        admin.save()
        print("Utente admin creato con successo!")
        print("Email: admin@edoras.com")
        print("Password: AdminSecure123!")
    else:
        print("Utente admin già esistente")
EOF
    
    deactivate
    cd ..
    log_success "Setup utente admin completato"
}

# Funzione per verificare connessione database
test_database_connection() {
    log_info "Test connessione database..."
    
    cd backend
    source venv/bin/activate
    
    python3 << EOF
import os
import sys
sys.path.append('src')

try:
    from app import create_app
    from app.extensions import db
    
    # Configura database URL
    os.environ['DATABASE_URL'] = "mssql+pyodbc://edorasadmin:EdorasSecure123!@${DATABASE_SERVER}/${DATABASE_NAME}?driver=ODBC+Driver+17+for+SQL+Server"
    
    app = create_app('$ENVIRONMENT')
    
    with app.app_context():
        # Test connessione
        db.session.execute(db.text('SELECT 1'))
        db.session.commit()
        print("✅ Connessione database OK")
        
        # Conta utenti
        from app.models.user import User
        user_count = User.query.count()
        print(f"✅ Utenti nel database: {user_count}")
        
except Exception as e:
    print(f"❌ Errore connessione database: {e}")
    sys.exit(1)
EOF
    
    deactivate
    cd ..
    log_success "Test connessione completato"
}

# Main execution
main() {
    # Verifica prerequisiti
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI non trovato"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 non trovato"
        exit 1
    fi
    
    # Ottieni informazioni database
    get_database_info
    
    # Inizializza database
    init_database_with_flask
    
    # Crea utente admin
    create_admin_user
    
    # Test connessione
    test_database_connection
    
    echo ""
    echo "=================================================="
    echo "         DATABASE SETUP COMPLETATO!"
    echo "=================================================="
    echo "Database Server: $DATABASE_SERVER"
    echo "Database Name: $DATABASE_NAME"
    echo "Admin User: admin@edoras.com"
    echo "Admin Password: AdminSecure123!"
    echo ""
    echo "Il database è pronto per l'uso!"
    echo "=================================================="
}

# Esegui main
main
