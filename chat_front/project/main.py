import os
from flask import Flask
from flask import url_for
from flask import render_template

__author__ = "Alberto Vara"
__email__ = "a.vara.1986@gmail.com"
__version__ = "0.1.0"

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "default-secret-key")
SERVICE_HOST = os.environ.get("CHAT_SVC_HOST", "http://chat-svc:80")


@app.route("/")
def index():
    return render_template(
        'index.html',
        **{"service_host": SERVICE_HOST}
    )


@app.route("/health")
def health():
    return {"status": "healthy"}, 200


@app.context_processor
def override_url_for():
    return dict(url_for=dated_url_for)


def dated_url_for(endpoint, **values):
    if endpoint == 'static':
        filename = values.get('filename', None)
        if filename:
            file_path = os.path.join(
                app.root_path,
                endpoint,
                filename
            )
            values['q'] = int(os.stat(file_path).st_mtime)
    return url_for(endpoint, **values)


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080, debug=False)  # nosec B104
