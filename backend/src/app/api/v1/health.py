# Health Check Endpoints

from datetime import datetime
from flask import jsonify, current_app
from sqlalchemy import text
from ...extensions import db
from utils.keyvault import get_keyvault_client
from . import api_v1_bp


@api_v1_bp.route('/health', methods=['GET'])
def health_check():
    """
    Health check dell'applicazione.
    
    Returns:
        JSON response con lo status dell'applicazione
    """
    return jsonify({
        'status': 'healthy',
        'service': 'edoras-backend',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@api_v1_bp.route('/health/detailed', methods=['GET'])
def detailed_health_check():
    """
    Health check dettagliato - verifica database, Key Vault, ecc.
    
    Returns:
        JSON con stato dettagliato dei componenti
    """
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'Edoras API',
        'version': '1.0.0',
        'environment': current_app.config.get('ENV', 'unknown'),
        'components': {}
    }
    
    overall_healthy = True
    
    # Check Database
    try:
        with db.engine.connect() as connection:
            result = connection.execute(text('SELECT 1'))
            result.fetchone()
        
        health_status['components']['database'] = {
            'status': 'healthy',
            'message': 'Database connection successful'
        }
    except Exception as e:
        health_status['components']['database'] = {
            'status': 'unhealthy',
            'message': f'Database connection failed: {str(e)}'
        }
        overall_healthy = False
    
    # Check Key Vault
    try:
        kv_client = get_keyvault_client()
        kv_health = kv_client.health_check()
        health_status['components']['keyvault'] = kv_health
        
        if kv_health['status'] != 'healthy':
            overall_healthy = False
    except Exception as e:
        health_status['components']['keyvault'] = {
            'status': 'unhealthy',
            'message': f'Key Vault check failed: {str(e)}'
        }
        overall_healthy = False
    
    # Check Configuration
    config_issues = []
    
    if not current_app.config.get('SECRET_KEY'):
        config_issues.append('SECRET_KEY not configured')
    
    if not current_app.config.get('JWT_SECRET_KEY'):
        config_issues.append('JWT_SECRET_KEY not configured')
    
    if config_issues:
        health_status['components']['configuration'] = {
            'status': 'unhealthy',
            'message': f'Configuration issues: {", ".join(config_issues)}'
        }
        overall_healthy = False
    else:
        health_status['components']['configuration'] = {
            'status': 'healthy',
            'message': 'All required configuration present'
        }
    
    # Set overall status
    if not overall_healthy:
        health_status['status'] = 'unhealthy'
    
    # Return appropriate HTTP status code
    status_code = 200 if overall_healthy else 503
    
    return jsonify(health_status), status_code


@api_v1_bp.route('/health/db', methods=['GET'])
def database_health():
    """
    Health check del database.
    
    Returns:
        JSON response con lo status del database
    """
    try:
        # Test connessione database
        db.session.execute(db.text('SELECT 1'))
        db.session.commit()
        
        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'timestamp': db.func.current_timestamp().scalar().isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'error': str(e),
            'timestamp': db.func.current_timestamp().scalar().isoformat()
        }), 503
