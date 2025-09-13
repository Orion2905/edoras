# Edoras Flask Application Entry Point

import os
from src.app import create_app

# Ottieni la configurazione dall'environment
config_name = os.getenv('FLASK_ENV', 'development')

# Crea l'app Flask
app = create_app(config_name)

if __name__ == '__main__':
    # Development server
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=app.config.get('DEBUG', False)
    )
