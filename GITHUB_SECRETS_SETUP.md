# 🔐 GitHub Secrets Setup per Azure Deployment

## Come configurare i GitHub Secrets

### 1. Vai alle impostazioni GitHub Secrets

1. Apri il tuo repository: https://github.com/Orion2905/edoras
2. Clicca su **Settings** (in alto a destra)
3. Nel menu laterale sinistro, clicca su **Secrets and variables** > **Actions**

### 2. Aggiungi il Secret AZURE_WEBAPP_PUBLISH_PROFILE

1. Clicca su **New repository secret**
2. Nel campo **Name** inserisci esattamente: `AZURE_WEBAPP_PUBLISH_PROFILE`
3. Nel campo **Secret** copia tutto il contenuto del file `publish-profile.xml`

**IMPORTANTE**: Il contenuto deve essere copiato TUTTO, inclusi i tag XML `<publishData>` e `</publishData>`

### 3. Contenuto del Secret

Il secret deve contenere esattamente questo (con i tuoi dati reali al posto di userName e userPWD):

```xml
<publishData>
  <publishProfile 
    profileName="edoras-backend-api - Web Deploy" 
    publishMethod="MSDeploy" 
    publishUrl="edoras-backend-api.scm.azurewebsites.net:443" 
    msdeploySite="edoras-backend-api" 
    userName="$edoras-backend-api" 
    userPWD="[password-generata-da-azure]" 
    destinationAppUrl="https://edoras-backend-api.azurewebsites.net" 
    SQLServerDBConnectionString="" 
    mySQLDBConnectionString="" 
    hostingProviderForumLink="" 
    controlPanelLink="https://portal.azure.com" 
    webSystem="WebSites">
    <databases />
  </publishProfile>
  <!-- più profili FTP e ZipDeploy -->
</publishData>
```

### 4. Come ottenere il contenuto corretto

Esegui questo comando nel terminale e copia tutto l'output:

```bash
cat publish-profile.xml
```

### 5. Verifica

Dopo aver salvato il secret:
- Il nome deve essere esattamente: `AZURE_WEBAPP_PUBLISH_PROFILE`
- Il valore deve iniziare con `<publishData>` e finire con `</publishData>`
- Non ci devono essere spazi extra all'inizio o alla fine

### 6. Triggera il Deployment

Una volta configurato il secret:
1. Fai un piccolo cambiamento al codice
2. Committa e pusha su `main`
3. Il workflow GitHub Actions si attiverà automaticamente
4. Controlla il deployment su: https://github.com/Orion2905/edoras/actions

## 🚀 URL Finali

Dopo il deployment riuscito:
- **API**: https://edoras-backend-api.azurewebsites.net/api/v1
- **Health**: https://edoras-backend-api.azurewebsites.net/health
- **Docs**: https://edoras-backend-api.azurewebsites.net/docs
