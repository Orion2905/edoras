# Users Management Endpoints

from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from marshmallow import ValidationError

from ...models.user import User
from ...schemas.user import user_schema, users_schema, user_update_schema, password_change_schema
from ...extensions import db
from . import api_v1_bp


@api_v1_bp.route('/users/me', methods=['GET'])
@jwt_required()
def get_my_profile():
    """
    Ottieni il profilo dell'utente corrente.
    
    Headers:
        Authorization: Bearer <access_token>
        
    Returns:
        JSON response con i dati del profilo
    """
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
    
    return jsonify({
        'user': user_schema.dump(user)
    }), 200


@api_v1_bp.route('/users/me', methods=['PUT'])
@jwt_required()
def update_my_profile():
    """
    Aggiorna il profilo dell'utente corrente.
    
    Headers:
        Authorization: Bearer <access_token>
        
    Body:
        first_name (str, optional): Nome
        last_name (str, optional): Cognome
        avatar_url (str, optional): URL avatar
        
    Returns:
        JSON response con i dati aggiornati
    """
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
    
    try:
        # Valida i dati in input
        data = user_update_schema.load(request.json)
    except ValidationError as err:
        return jsonify({'errors': err.messages}), 400
    
    # Aggiorna i campi dell'utente
    for field, value in data.items():
        setattr(user, field, value)
    
    user.save()
    
    return jsonify({
        'message': 'Profile updated successfully',
        'user': user_schema.dump(user)
    }), 200


@api_v1_bp.route('/users/me/password', methods=['PUT'])
@jwt_required()
def change_password():
    """
    Cambia la password dell'utente corrente.
    
    Headers:
        Authorization: Bearer <access_token>
        
    Body:
        current_password (str): Password attuale
        new_password (str): Nuova password
        
    Returns:
        JSON response di conferma
    """
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
    
    try:
        # Valida i dati in input
        data = password_change_schema.load(request.json)
    except ValidationError as err:
        return jsonify({'errors': err.messages}), 400
    
    # Verifica password attuale
    if not user.check_password(data['current_password']):
        return jsonify({'message': 'Current password is incorrect'}), 400
    
    # Aggiorna password
    user.set_password(data['new_password'])
    user.save()
    
    return jsonify({
        'message': 'Password changed successfully'
    }), 200


@api_v1_bp.route('/users/me', methods=['DELETE'])
@jwt_required()
def delete_my_account():
    """
    Elimina l'account dell'utente corrente.
    
    Headers:
        Authorization: Bearer <access_token>
        
    Returns:
        JSON response di conferma
    """
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'message': 'User not found'}), 404
    
    # Elimina l'utente
    user.delete()
    
    return jsonify({
        'message': 'Account deleted successfully'
    }), 200


@api_v1_bp.route('/users', methods=['GET'])
@jwt_required()
def get_users():
    """
    Ottieni lista di tutti gli utenti (solo admin).
    
    Headers:
        Authorization: Bearer <access_token>
        
    Query Parameters:
        page (int): Numero di pagina (default: 1)
        per_page (int): Elementi per pagina (default: 20, max: 100)
        
    Returns:
        JSON response con lista paginata degli utenti
    """
    current_user_id = get_jwt_identity()
    current_user = User.query.get(current_user_id)
    
    if not current_user or not current_user.is_admin:
        return jsonify({'message': 'Admin access required'}), 403
    
    # Parametri di paginazione
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)
    
    # Query paginata
    users_paginated = User.query.paginate(
        page=page,
        per_page=per_page,
        error_out=False
    )
    
    return jsonify({
        'users': users_schema.dump(users_paginated.items),
        'pagination': {
            'page': page,
            'pages': users_paginated.pages,
            'per_page': per_page,
            'total': users_paginated.total,
            'has_next': users_paginated.has_next,
            'has_prev': users_paginated.has_prev
        }
    }), 200
