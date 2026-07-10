from flask import Flask, jsonify, request
import socket
import os
import datetime
import platform
import random

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
HOSTNAME = socket.gethostname()
START_TIME = datetime.datetime.utcnow()

quotes = [
    "Keep shipping 🚀",
    "Automate everything ⚙️",
    "CI/CD saves lives 😎",
    "Code. Build. Deploy.",
    "Think twice, deploy once."
]


@app.route("/")
def home():
    return jsonify({
        "application": "CI/CD Demo API",
        "version": APP_VERSION,
        "hostname": HOSTNAME,
        "python": platform.python_version(),
        "status": "Running",
        "time": datetime.datetime.utcnow().isoformat() + "Z"
    })


@app.route("/health")
def health():
    uptime = datetime.datetime.utcnow() - START_TIME
    return jsonify({
        "status": "healthy",
        "uptime_seconds": int(uptime.total_seconds())
    })


@app.route("/info")
def info():
    return jsonify({
        "hostname": HOSTNAME,
        "version": APP_VERSION,
        "os": platform.system(),
        "release": platform.release(),
        "machine": platform.machine()
    })


@app.route("/quote")
def quote():
    return jsonify({
        "quote": random.choice(quotes)
    })


@app.route("/echo", methods=["POST"])
def echo():
    data = request.get_json(force=True)
    return jsonify({
        "received": data,
        "message": "Request received successfully"
    })


@app.route("/metrics")
def metrics():
    uptime = datetime.datetime.utcnow() - START_TIME
    return jsonify({
        "uptime_seconds": int(uptime.total_seconds()),
        "hostname": HOSTNAME,
        "version": APP_VERSION
    })


@app.errorhandler(404)
def not_found(e):
    return jsonify({
        "error": "Endpoint not found"
    }), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
