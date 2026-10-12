"""
API tests for the CloudTwin backend.

The production ``get_db`` dependency is overridden with an in-memory SQLite
database so the full CRUD surface can be exercised without a live Postgres.
"""

import sys
from pathlib import Path

# Make the ``backend`` package importable regardless of how pytest is invoked.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.database import Base, get_db
from backend.main import app

# Single shared in-memory SQLite DB (StaticPool keeps one connection alive
# across the threaded TestClient calls).
_test_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)
Base.metadata.create_all(bind=_test_engine)


def _override_get_db():
    db = _TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def _clean_db():
    """Empty the tasks table before every test for full isolation."""
    db = _TestingSessionLocal()
    db.execute(Base.metadata.tables["tasks"].delete())
    db.commit()
    db.close()


def _create(title="Write tests", description="Cover the API", completed=False):
    resp = client.post(
        "/api/tasks",
        json={"title": title, "description": description, "completed": completed},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


# ---------------------------------------------------------------------------
# Probes
# ---------------------------------------------------------------------------
def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_ready():
    resp = client.get("/ready")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ready"}


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------
def test_create_task():
    task = _create()
    assert task["id"] > 0
    assert task["title"] == "Write tests"
    assert task["description"] == "Cover the API"
    assert task["completed"] is False
    assert "created_at" in task


def test_create_task_defaults_completed_false():
    resp = client.post("/api/tasks", json={"title": "No completed flag"})
    assert resp.status_code == 201
    assert resp.json()["completed"] is False


def test_create_task_missing_title():
    resp = client.post("/api/tasks", json={"description": "no title"})
    assert resp.status_code == 422


def test_create_task_empty_title():
    resp = client.post("/api/tasks", json={"title": ""})
    assert resp.status_code == 422


def test_create_task_title_too_long():
    resp = client.post("/api/tasks", json={"title": "x" * 201})
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# List / read
# ---------------------------------------------------------------------------
def test_list_tasks_empty():
    resp = client.get("/api/tasks")
    assert resp.status_code == 200
    assert resp.json() == []


def test_list_tasks():
    _create(title="Task one")
    _create(title="Task two")
    resp = client.get("/api/tasks")
    assert resp.status_code == 200
    titles = [t["title"] for t in resp.json()]
    assert titles == ["Task one", "Task two"]


def test_get_task_by_id():
    task = _create()
    resp = client.get(f"/api/tasks/{task['id']}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "Write tests"


def test_get_task_not_found():
    resp = client.get("/api/tasks/9999")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
def test_update_task_title():
    task = _create()
    resp = client.put(f"/api/tasks/{task['id']}", json={"title": "Updated title"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["title"] == "Updated title"
    assert body["description"] == "Cover the API"  # untouched field preserved


def test_toggle_completed():
    task = _create()
    assert task["completed"] is False
    resp = client.put(f"/api/tasks/{task['id']}", json={"completed": True})
    assert resp.status_code == 200
    assert resp.json()["completed"] is True
    # And back off again.
    resp = client.put(f"/api/tasks/{task['id']}", json={"completed": False})
    assert resp.status_code == 200
    assert resp.json()["completed"] is False


def test_update_task_not_found():
    resp = client.put("/api/tasks/9999", json={"title": "ghost"})
    assert resp.status_code == 404


def test_update_task_invalid_title_rejected():
    task = _create()
    resp = client.put(f"/api/tasks/{task['id']}", json={"title": "y" * 250})
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------
def test_delete_task():
    task = _create()
    resp = client.delete(f"/api/tasks/{task['id']}")
    assert resp.status_code == 204
    assert client.get(f"/api/tasks/{task['id']}").status_code == 404
    assert client.get("/api/tasks").json() == []


def test_delete_task_not_found():
    resp = client.delete("/api/tasks/9999")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------
def test_metrics_endpoint():
    client.get("/api/tasks")  # generate some traffic first
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "http_requests_total" in resp.text
