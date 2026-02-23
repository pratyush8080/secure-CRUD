import os
import time
import logging
from datetime import datetime
from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import OperationalError

# ── Logging ──────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ── App & DB init ─────────────────────────────────────────────────────────
app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///tasks.db")
app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-key")

db = SQLAlchemy(app)


# ── Model ─────────────────────────────────────────────────────────────────
class Task(db.Model):
    __tablename__ = "tasks"

    id          = db.Column(db.Integer, primary_key=True)
    title       = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    status      = db.Column(db.String(50), default="pending")   # pending | in-progress | completed
    created_at  = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at  = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id":          self.id,
            "title":       self.title,
            "description": self.description,
            "status":      self.status,
            "created_at":  self.created_at.isoformat() if self.created_at else None,
            "updated_at":  self.updated_at.isoformat() if self.updated_at else None,
        }


# ── DB connection with retry ──────────────────────────────────────────────
def connect_with_retry(retries: int = 10, delay: int = 3):
    for attempt in range(1, retries + 1):
        try:
            with app.app_context():
                db.create_all()
                logger.info("✅ Database connected and tables created.")
            return
        except OperationalError as exc:
            logger.warning(f"⚠️  DB not ready (attempt {attempt}/{retries}): {exc}")
            if attempt == retries:
                raise
            time.sleep(delay)


# ── Routes ────────────────────────────────────────────────────────────────

# Health check (used by Docker health-check & deploy.sh)
@app.route("/health")
def health():
    try:
        db.session.execute(db.text("SELECT 1"))
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except Exception as exc:
        return jsonify({"status": "unhealthy", "error": str(exc)}), 503


# Web UI
@app.route("/")
def index():
    return render_template("index.html")


# ── CRUD API ──────────────────────────────────────────────────────────────

# READ — list all tasks
@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    tasks = Task.query.order_by(Task.created_at.desc()).all()
    return jsonify({"tasks": [t.to_dict() for t in tasks], "total": len(tasks)}), 200


# READ — single task
@app.route("/api/tasks/<int:task_id>", methods=["GET"])
def get_task(task_id):
    task = Task.query.get_or_404(task_id)
    return jsonify(task.to_dict()), 200


# CREATE
@app.route("/api/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True) or {}
    title = data.get("title", "").strip()
    if not title:
        return jsonify({"error": "Title is required"}), 400

    task = Task(
        title=title,
        description=data.get("description", "").strip(),
        status=data.get("status", "pending"),
    )
    db.session.add(task)
    db.session.commit()
    logger.info(f"Created task id={task.id} title='{task.title}'")
    return jsonify(task.to_dict()), 201


# UPDATE
@app.route("/api/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    task = Task.query.get_or_404(task_id)
    data = request.get_json(silent=True) or {}

    if "title" in data:
        title = data["title"].strip()
        if not title:
            return jsonify({"error": "Title cannot be empty"}), 400
        task.title = title

    if "description" in data:
        task.description = data["description"].strip()

    if "status" in data:
        valid = {"pending", "in-progress", "completed"}
        if data["status"] not in valid:
            return jsonify({"error": f"Status must be one of {valid}"}), 400
        task.status = data["status"]

    task.updated_at = datetime.utcnow()
    db.session.commit()
    logger.info(f"Updated task id={task.id}")
    return jsonify(task.to_dict()), 200


# DELETE
@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    task = Task.query.get_or_404(task_id)
    db.session.delete(task)
    db.session.commit()
    logger.info(f"Deleted task id={task_id}")
    return jsonify({"message": f"Task {task_id} deleted successfully"}), 200


# ── Entry point ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    connect_with_retry()
    app.run(host="0.0.0.0", port=5000, debug=False)
else:
    # Called by Gunicorn
    connect_with_retry()
