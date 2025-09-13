# User Schemas

from marshmallow import Schema, fields, validate, post_load
from ..models.user import User


class UserSchema(Schema):
    """Schema per la serializzazione degli utenti."""
    
    id = fields.Integer(dump_only=True)
    email = fields.Email(required=True, validate=validate.Length(max=120))
    username = fields.String(required=True, validate=validate.Length(min=3, max=80))
    first_name = fields.String(validate=validate.Length(max=50), allow_none=True)
    last_name = fields.String(validate=validate.Length(max=50), allow_none=True)
    full_name = fields.String(dump_only=True)
    avatar_url = fields.Url(allow_none=True)
    is_active = fields.Boolean(dump_only=True)
    email_verified = fields.Boolean(dump_only=True)
    last_login = fields.DateTime(dump_only=True)
    created_at = fields.DateTime(dump_only=True)
    updated_at = fields.DateTime(dump_only=True)


class UserRegistrationSchema(Schema):
    """Schema per la registrazione degli utenti."""
    
    email = fields.Email(required=True, validate=validate.Length(max=120))
    username = fields.String(required=True, validate=validate.Length(min=3, max=80))
    password = fields.String(required=True, validate=validate.Length(min=8, max=128))
    first_name = fields.String(validate=validate.Length(max=50), allow_none=True)
    last_name = fields.String(validate=validate.Length(max=50), allow_none=True)


class UserLoginSchema(Schema):
    """Schema per il login degli utenti."""
    
    email = fields.Email(required=True)
    password = fields.String(required=True)


class UserUpdateSchema(Schema):
    """Schema per l'aggiornamento del profilo utente."""
    
    first_name = fields.String(validate=validate.Length(max=50), allow_none=True)
    last_name = fields.String(validate=validate.Length(max=50), allow_none=True)
    avatar_url = fields.Url(allow_none=True)


class PasswordChangeSchema(Schema):
    """Schema per il cambio password."""
    
    current_password = fields.String(required=True)
    new_password = fields.String(required=True, validate=validate.Length(min=8, max=128))


# Istanze degli schema
user_schema = UserSchema()
users_schema = UserSchema(many=True)
user_registration_schema = UserRegistrationSchema()
user_login_schema = UserLoginSchema()
user_update_schema = UserUpdateSchema()
password_change_schema = PasswordChangeSchema()
