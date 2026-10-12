"""
CloudTwin API — FastAPI backend.

Serves the task-list REST API used by the CloudTwin frontend, exposes
Prometheus metrics at /metrics, and reports liveness (/health) and
database-backed readiness (/ready) for Kubernetes probes.
"""

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import text
from sqlalchemy.orm import Session

from . import models  # noqa: F401  (registers the Task model on Base)
from .database import Base, engine, get_db
from .schemas import TaskCreate, TaskResponse, TaskUpdate


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup so a fresh database just works.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="CloudTwin API",
    description="Task management API for the CloudTwin Multi-Cloud DevOps Platform.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Expose Prometheus metrics at /metrics (includes http_requests_total).
Instrumentator().instrument(app).expose(app)


# ---------------------------------------------------------------------------
# Probes
# ---------------------------------------------------------------------------
@app.get("/health", tags=["probes"])
def health():
    """Liveness probe — the process is up."""
    return {"status": "ok"}


@app.get("/ready", tags=["probes"])
def ready(db: Session = Depends(get_db)):
    """Readiness probe — the database is reachable."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # pragma: no cover
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="database unavailable",
        ) from exc
    return {"status": "ready"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _get_task_or_404(task_id: int, db: Session) -> models.Task:
    task = db.get(models.Task, task_id)
    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"task {task_id} not found",
        )
    return task


# ---------------------------------------------------------------------------
# Task CRUD
# ---------------------------------------------------------------------------
@app.get("/api/tasks", response_model=list[TaskResponse], tags=["tasks"])
def list_tasks(db: Session = Depends(get_db)):
    """List all tasks, oldest first."""
    return db.query(models.Task).order_by(models.Task.id).all()


@app.post(
    "/api/tasks",
    response_model=TaskResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["tasks"],
)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)):
    """Create a new task."""
    task = models.Task(
        title=payload.title,
        description=payload.description,
        completed=payload.completed,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@app.get("/api/tasks/{task_id}", response_model=TaskResponse, tags=["tasks"])
def get_task(task_id: int, db: Session = Depends(get_db)):
    """Fetch a single task by id."""
    return _get_task_or_404(task_id, db)


@app.put("/api/tasks/{task_id}", response_model=TaskResponse, tags=["tasks"])
def update_task(task_id: int, payload: TaskUpdate, db: Session = Depends(get_db)):
    """Partially update a task (only supplied fields change)."""
    task = _get_task_or_404(task_id, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    db.commit()
    db.refresh(task)
    return task


@app.delete("/api/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["tasks"])
def delete_task(task_id: int, db: Session = Depends(get_db)):
    """Delete a task."""
    task = _get_task_or_404(task_id, db)
    db.delete(task)
    db.commit()
    return None
