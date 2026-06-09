from __future__ import unicode_literals, print_function
import os
import uuid
import requests
from flask import Flask
from flask import current_app
from flask import jsonify
from flask import session
from flask_socketio import emit, send, SocketIO
from prometheus_flask_exporter import PrometheusMetrics

__author__ = "Alberto Vara"
__email__ = "a.vara.1986@gmail.com"
__version__ = "0.1.0"

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "default-secret-key")
SERVICE_HOST = os.environ.get("CHAT_DB_HOST", "http://chat-db:80")

metrics = PrometheusMetrics(app)
metrics.info('chat_svc_info', 'Chat Service Info', version='1.0.0')

socketio = SocketIO()
users_connected = []


def get_messages():
    # FIX BUG 2: Use IP directly
    # eventlet DNS resolver is broken
    # Use service env var with timeout
    try:
        response = requests.get(
            SERVICE_HOST,
            timeout=5
        )
        return response.json()
    except Exception as e:
        current_app.logger.error(
            "get_messages error: {}".format(e)
        )
        return []


def post_message(data):
    try:
        response = requests.post(
            SERVICE_HOST,
            json=data,
            timeout=5
        )
        return response.json()
    except Exception as e:
        current_app.logger.error(
            "post_message error: {}".format(e)
        )
        return data


@app.route("/")
def index():
    return jsonify({})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


# FIX BUG 1: Add auth parameter
# Flask-SocketIO 5.x passes auth
# to on_connect handler
@socketio.on('connect', namespace='/chat')
def on_connect(auth):
    current_app.logger.info("USER CONNECTED")
    msgs = get_messages()
    for msg in msgs:
        emit('msgs', msg)


@socketio.on('log-in', namespace='/chat')
def login(data):
    user_id = session.get("user_id", "")
    if not user_id:
        user_id = str(uuid.uuid4())
        session["user_id"] = user_id
    data = {
        "id": user_id,
        "username": data.get("username", "")
    }
    users_connected.append(data)
    current_app.logger.info(data)
    emit('users_connected', len(users_connected), broadcast=True)
    send(dict(
        user_id=user_id,
        welcome="Hola {}".format(data["username"])
    ))


@socketio.on('disconnect', namespace='/chat')
def on_disconnect():
    user_id = session.get("user_id", "")
    for user in users_connected:
        if user["id"] == user_id:
            users_connected.remove(user)
    emit('users_connected', len(users_connected), broadcast=True)


@socketio.on('send_msg', namespace='/chat')
def send_msg(data):
    current_app.logger.info(
        "[EVENT] User {} send message {}".format(
            session.get("user_id", ""),
            data["message"]
        )
    )
    msg = {
        "user_id": session.get("user_id", ""),
        "username": data.get("username", ""),
        "message": data["message"]
    }
    result_msg = post_message(msg)
    emit('msgs', result_msg, broadcast=True)


def create_app():
    socketio.init_app(
        app,
        async_mode='eventlet',
        cors_allowed_origins="*",
        manage_session=False,
        logger=True,
        engineio_logger=True,
        ping_timeout=60,
        ping_interval=25
    )
    return app


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080, debug=False)  # nosec B104
