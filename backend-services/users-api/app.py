from flask import Flask
import os

app = Flask(__name__)

ENV = os.getenv("APP_ENV", "dev")
GIT_SHA = os.getenv("GIT_SHA", "unknown")
DEPLOYED_BY = os.getenv("DEPLOYED_BY", "unknown")
DEPLOY_TIME = os.getenv("DEPLOY_TIME", "unknown")

@app.route(f"/{ENV}/")
@app.route(f"/{ENV}")
def home():
    return {
        "status": "Backend API Running",
        "environment": ENV,
        "version": GIT_SHA,
        "deployed_by": DEPLOYED_BY,
        "deployed_at": DEPLOY_TIME
    }

@app.route(f"/{ENV}/health")
def health():
    return "OK"

@app.route(f"/{ENV}/users")
def users():
    return {"env": ENV, "users": []}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
