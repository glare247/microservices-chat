import os
from flask import Flask
from project.models.init_db import db
from prometheus_flask_exporter import PrometheusMetrics

__author__ = "Alberto Vara"
__email__ = "a.vara.1986@gmail.com"
__version__ = "0.1.0"


def create_app():
    """Initialize Flask app with SQLAlchemy database.
    Reads config from environment variables.
    No py-ms dependency — uses Flask directly.

    :return: Flask app
    """
    app = Flask(__name__)

    app.secret_key = os.environ.get(
        "SECRET_KEY",
        "default-secret-key"
    )
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
        "SQLALCHEMY_DATABASE_URI",
        "sqlite:///chat.db"
    )
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)

    # Initialize Prometheus metrics
    # Creates /metrics endpoint automatically
    # Tracks all HTTP requests to chat_db
    # Must be initialized after app is created
    metrics = PrometheusMetrics(app)
    metrics.info(
        'chat_db_info',
        'Chat DB Application Info',
        version='1.0.0'
    )

    with app.app_context():
        db.create_all()

    from project.views import messages_bp
    app.register_blueprint(messages_bp)

    @app.route("/health")
    def health():
        return {"status": "healthy"}, 200

    return app
