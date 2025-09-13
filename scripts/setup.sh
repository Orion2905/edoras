#!/bin/bash

# Edoras Project - Setup Script
# Script per configurare l'ambiente di sviluppo locale

set -e

# Colori
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

echo "=================================================="
echo "    EDORAS PROJECT - LOCAL SETUP SCRIPT"
echo "=================================================="

# Verifica Node.js
if ! command -v node &> /dev/null; then
    log_error "Node.js non trovato. Installa Node.js prima di continuare."
    exit 1
fi

NODE_VERSION=$(node --version)
log_info "Node.js version: $NODE_VERSION"

# Setup Backend
log_info "Setup Backend..."
cd backend

if [ ! -f "package.json" ]; then
    log_info "Inizializzazione package.json per backend..."
    npm init -y
    
    # Aggiorna package.json con script di base
    cat > package.json << 'EOF'
{
  "name": "edoras-backend",
  "version": "1.0.0",
  "description": "Edoras Backend API",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "build": "echo 'Backend build completed'"
  },
  "keywords": ["api", "backend", "edoras"],
  "author": "",
  "license": "ISC"
}
EOF
    
    log_success "package.json creato per backend"
fi

# Crea file di esempio se non esistono
if [ ! -f "src/index.js" ]; then
    cat > src/index.js << 'EOF'
// Edoras Backend - Entry Point
console.log('Edoras Backend starting...');

// TODO: Implementare il server express/fastify
// TODO: Configurare database connection
// TODO: Implementare routes
EOF
    log_success "File index.js creato"
fi

if [ ! -f ".env.example" ]; then
    cat > .env.example << 'EOF'
# Edoras Backend Environment Variables
NODE_ENV=development
PORT=3001

# Database
DATABASE_URL=your_database_connection_string

# Azure Storage
AZURE_STORAGE_CONNECTION_STRING=your_storage_connection_string

# JWT
JWT_SECRET=your_jwt_secret_here

# CORS
CORS_ORIGIN=http://localhost:3000
EOF
    log_success "File .env.example creato"
fi

cd ..

# Setup Frontend
log_info "Setup Frontend..."
cd frontend

if [ ! -f "package.json" ]; then
    log_info "Inizializzazione package.json per frontend..."
    npm init -y
    
    # Aggiorna package.json con script di base
    cat > package.json << 'EOF'
{
  "name": "edoras-frontend",
  "version": "1.0.0",
  "description": "Edoras Frontend Application",
  "main": "src/index.js",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "keywords": ["react", "frontend", "edoras"],
  "author": "",
  "license": "ISC",
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF
    
    log_success "package.json creato per frontend"
fi

# Crea file di esempio se non esistono
if [ ! -f "src/index.js" ]; then
    cat > src/index.js << 'EOF'
// Edoras Frontend - Entry Point
console.log('Edoras Frontend starting...');

// TODO: Implementare React app
// TODO: Configurare routing
// TODO: Implementare componenti
EOF
    log_success "File index.js creato"
fi

if [ ! -f ".env.example" ]; then
    cat > .env.example << 'EOF'
# Edoras Frontend Environment Variables
REACT_APP_API_URL=http://localhost:3001/api
REACT_APP_ENVIRONMENT=development
EOF
    log_success "File .env.example creato"
fi

if [ ! -f "public/index.html" ]; then
    cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Edoras Application" />
    <title>Edoras</title>
</head>
<body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
</body>
</html>
EOF
    log_success "File index.html creato"
fi

cd ..

# Crea .gitignore globale
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
*/node_modules/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build outputs
build/
dist/
*.tgz
*.tar.gz

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Azure
*.zip
.azure/

# Temporary files
*.tmp
*.temp
EOF
    log_success "File .gitignore creato"
fi

echo ""
echo "=================================================="
echo "         SETUP COMPLETATO CON SUCCESSO!"
echo "=================================================="
echo "Struttura progetto creata:"
echo "  📁 backend/       - API e servizi backend"
echo "  📁 frontend/      - Applicazione web"
echo "  📁 azure-config/  - Configurazioni Azure"
echo "  📁 scripts/       - Script di utilità"
echo "  📁 docs/          - Documentazione"
echo ""
echo "Prossimi step:"
echo "  1. Copia .env.example in .env in entrambe le cartelle"
echo "  2. Configura le variabili d'ambiente"
echo "  3. Installa le dipendenze del progetto"
echo "  4. Inizia lo sviluppo!"
echo ""
echo "Per il deploy su Azure:"
echo "  ./scripts/deploy.sh --help"
echo "=================================================="
