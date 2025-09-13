# Edoras Frontend

Frontend application per il progetto Edoras.

## Struttura

```
frontend/
├── src/
│   ├── components/          # Componenti UI riutilizzabili
│   │   ├── common/         # Button, Input, Modal, ecc.
│   │   └── layout/         # Header, Footer, Sidebar
│   ├── pages/              # Pagine principali dell'app
│   ├── services/           # API client e HTTP calls
│   ├── hooks/              # Custom React hooks
│   ├── utils/              # Helper functions
│   └── assets/             # Stili, immagini, font
├── public/                 # File statici
└── tests/                  # Test suite
```

## Setup

1. **Installa dipendenze:**
   ```bash
   npm install
   ```

2. **Configura environment:**
   ```bash
   cp .env.example .env
   # Modifica .env con le tue configurazioni
   ```

3. **Start development server:**
   ```bash
   npm start
   ```

4. **Open browser:**
   Apri [http://localhost:3000](http://localhost:3000)

## Scripts Disponibili

```bash
# Development server
npm start

# Build per produzione
npm run build

# Run tests
npm test

# Eject (non reversibile)
npm run eject
```

## Testing

```bash
# Run tutti i test
npm test

# Run test in watch mode
npm test -- --watch

# Run test con coverage
npm test -- --coverage
```

## Build

```bash
npm run build
```

Crea la build ottimizzata per produzione nella cartella `build/`.

## Tecnologie Suggerite

- **Framework**: React, Vue.js, o Angular
- **State Management**: Redux Toolkit, Zustand, o Pinia
- **Styling**: Tailwind CSS, Styled Components, o CSS Modules
- **Testing**: Jest, React Testing Library
- **Build Tool**: Vite, Create React App, o Webpack

## Struttura Componenti

### Common Components
- `Button` - Pulsanti riutilizzabili
- `Input` - Input forms
- `Modal` - Modali e dialog
- `Loading` - Indicatori di caricamento

### Layout Components  
- `Header` - Header dell'applicazione
- `Footer` - Footer dell'applicazione
- `Sidebar` - Menu laterale
- `Layout` - Layout principale

### Pages
- `Home` - Homepage
- `Login` - Pagina di login
- `Dashboard` - Dashboard utente
- `Settings` - Impostazioni
