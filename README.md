# Edoras - Azure Production Setup

Un progetto full-stack moderno con backend Flask e database Azure SQL pronto per la produzione.

## 🏗️ Architettura

```
Edoras/
├── 📁 backend/              # API e servizi backend
│   ├── 📁 src/
│   │   ├── 📁 api/          # Routes, controllers, middleware
│   │   ├── 📁 models/       # Modelli dati
│   │   ├── 📁 services/     # Logica business
│   │   ├── 📁 utils/        # Utilità e helper
│   │   └── 📁 config/       # Configurazioni
│   └── 📁 tests/            # Test backend
│
├── 📁 frontend/             # Applicazione web
│   ├── 📁 src/
│   │   ├── 📁 components/   # Componenti riutilizzabili
│   │   ├── 📁 pages/        # Pagine principali
│   │   ├── 📁 services/     # API client e servizi
│   │   ├── 📁 hooks/        # Custom hooks
│   │   ├── 📁 utils/        # Utilità frontend
│   │   └── 📁 assets/       # Immagini, stili, ecc.
│   ├── 📁 public/           # File statici
│   └── 📁 tests/            # Test frontend
│
├── 📁 azure-config/         # Configurazioni Azure
│   ├── 📁 bicep/           # Template Infrastructure as Code
│   └── 📄 README.md        # Guida Azure
│
├── 📁 scripts/              # Script di automazione
│   ├── 📄 deploy.sh        # Deploy unificato su Azure
│   └── 📄 setup.sh         # Setup ambiente locale
│
└── 📁 docs/                 # Documentazione
    ├── 📄 architecture.md   # Architettura del sistema
    └── 📄 deployment.md     # Guida al deployment
```

## 🚀 Quick Start

### Prerequisiti

- [Node.js](https://nodejs.org/) (versione 18+)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Account Azure attivo

### Setup Locale

1. **Clona e configura il progetto:**
   ```bash
   ./scripts/setup.sh
   ```

2. **Configura le variabili d'ambiente:**
   ```bash
   # Backend
   cp backend/.env.example backend/.env
   
   # Frontend  
   cp frontend/.env.example frontend/.env
   ```

3. **Installa le dipendenze:**
   ```bash
   # Backend
   cd backend && npm install
   
   # Frontend
   cd frontend && npm install
   ```

### Deploy su Azure

1. **Login Azure:**
   ```bash
   az login
   ```

2. **Deploy completo (dev):**
   ```bash
   ./scripts/deploy.sh
   ```

3. **Deploy produzione:**
   ```bash
   ./scripts/deploy.sh --environment prod
   ```

## 📋 Comandi Disponibili

### Script di Deploy

```bash
# Deploy completo ambiente dev
./scripts/deploy.sh

# Deploy produzione
./scripts/deploy.sh --environment prod

# Deploy solo infrastruttura
./scripts/deploy.sh --infrastructure

# Deploy solo applicazioni (senza build)
./scripts/deploy.sh --apps-only --skip-build

# Mostra tutte le opzioni
./scripts/deploy.sh --help
```

### Sviluppo Locale

```bash
# Backend (di solito porta 3001)
cd backend
npm run dev

# Frontend (di solito porta 3000)  
cd frontend
npm start
```

## 🌍 Ambienti

| Ambiente | Descrizione | Resource Group | URL |
|----------|-------------|----------------|-----|
| **dev** | Sviluppo e test | `rg-edoras-dev` | Generato automaticamente |
| **staging** | Pre-produzione | `rg-edoras-staging` | Generato automaticamente |
| **prod** | Produzione | `rg-edoras-prod` | Generato automaticamente |

## ☁️ Risorse Azure

Il deploy crea automaticamente:

- **App Services** (backend + frontend)
- **Azure SQL Database** (database principale)
- **Storage Account** (file e blob)
- **Key Vault** (gestione segreti)
- **Application Insights** (monitoring)

## 🛠️ Tecnologie Supportate

La struttura è progettata per essere flessibile e supportare diverse tecnologie:

### Backend
- Node.js (Express, Fastify, NestJS)
- Python (Django, FastAPI, Flask)
- .NET Core
- Java (Spring Boot)

### Frontend
- React
- Vue.js
- Angular
- Next.js
- Svelte

### Database
- Azure SQL Database
- PostgreSQL
- MongoDB (CosmosDB)
- Redis

## 📖 Documentazione Aggiuntiva

- [Architettura del Sistema](docs/architecture.md)
- [Guida al Deployment](docs/deployment.md)
- [Configurazione Azure](azure-config/README.md)

## 🤝 Contribuzione

1. Fork del progetto
2. Crea un branch feature (`git checkout -b feature/amazing-feature`)
3. Commit delle modifiche (`git commit -m 'Add amazing feature'`)
4. Push del branch (`git push origin feature/amazing-feature`)
5. Apri una Pull Request

## 📄 Licenza

Questo progetto è sotto licenza MIT. Vedi il file `LICENSE` per dettagli.

## 🆘 Supporto

Per problemi o domande:

1. Controlla la [documentazione](docs/)
2. Cerca nei [GitHub Issues](../../issues)
3. Crea un nuovo [Issue](../../issues/new)

---

**Nota:** Questa struttura è un template di partenza. Personalizza in base alle tue esigenze specifiche!
# Test deployment
