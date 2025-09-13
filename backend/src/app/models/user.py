# User Model

from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from ..extensions import db
from .base import BaseModel


class User(BaseModel):
    """Modello per gli utenti dell'applicazione."""
    
    __tablename__ = 'users'
    
    # Campi base
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    username = db.Column(db.String(80), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    
    # Informazioni personali
    first_name = db.Column(db.String(50), nullable=True)
    last_name = db.Column(db.String(50), nullable=True)
    avatar_url = db.Column(db.String(255), nullable=True)
    
    # Status e permessi
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    is_admin = db.Column(db.Boolean, default=False, nullable=False)
    email_verified = db.Column(db.Boolean, default=False, nullable=False)
    
    # Timestamps
    last_login = db.Column(db.DateTime, nullable=True)
    
    def set_password(self, password):
        """Imposta la password dell'utente."""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        """Verifica la password dell'utente."""
        return check_password_hash(self.password_hash, password)
    
    def update_last_login(self):
        """Aggiorna l'ultimo login."""
        self.last_login = datetime.utcnow()
        db.session.commit()
    
    @property
    def full_name(self):
        """Ritorna il nome completo."""
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        return self.username
    
    def to_dict(self, include_sensitive=False):
        """Converte il modello in dizionario."""
        data = {
            'id': self.id,
            'email': self.email,
            'username': self.username,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'full_name': self.full_name,
            'avatar_url': self.avatar_url,
            'is_active': self.is_active,
            'email_verified': self.email_verified,
            'last_login': self.last_login.isoformat() if self.last_login else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if include_sensitive:
            data['is_admin'] = self.is_admin
            
        return data
    
    def __repr__(self):
        return f'<User {self.username}>'
