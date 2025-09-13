# Azure Configuration Files

Questa cartella contiene tutti i file di configurazione per il deploy su Azure.

## Struttura

- `bicep/` - Template Bicep per Infrastructure as Code
  - `main.bicep` - Template principale con tutte le risorse
  - `parameters.dev.json` - Parametri per ambiente development
  - `parameters.prod.json` - Parametri per ambiente production

## Risorse Create

Il template Bicep crea le seguenti risorse:

### App Services
- **Backend App Service**: Hosting dell'API
- **Frontend App Service**: Hosting dell'applicazione web
- **App Service Plan**: Piano condiviso per entrambe le app

### Database
- **Azure SQL Server**: Server database
- **Azure SQL Database**: Database dell'applicazione

### Storage
- **Storage Account**: Per file statici e blob storage

### Security & Monitoring
- **Key Vault**: Gestione sicura dei segreti
- **Application Insights**: Monitoring e telemetria

## Environment Variables

### Backend
- `NODE_ENV`: Environment (dev/prod)
- `DATABASE_URL`: Connection string al database (da Key Vault)
- `AZURE_STORAGE_CONNECTION_STRING`: Connection string storage (da Key Vault)

### Frontend
- `NODE_ENV`: Environment (dev/prod)
- `REACT_APP_API_URL`: URL dell'API backend

## Deploy

Utilizza lo script `/scripts/deploy.sh` per il deploy automatico.
