from flask import Flask, jsonify
import os
import socket
import datetime

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")


@app.route("/")
def home():
    return jsonify({
        "message": "CI/CD Automation Pipeline Demo App",
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "time": datetime.datetime.utcnow().isoformat() + "Z"
    })


@app.route("/health")
def health():
    # Used by Docker HEALTHCHECK and deployment scripts to verify the
    # container is actually serving traffic before old container is killed
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
