"""
Database layer for the CloudTwin API.

The connection string comes from the ``DATABASE_URL`` environment variable.
The default points at the docker-compose ``postgres`` service; tests override
the ``get_db`` dependency with an in-memory SQLite database, which this
module also supports.
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL: str = os.getenv(
    "DATABASE_URL",
    "postgresql://cloudtwin:cloudtwin@postgres:5432/cloudtwin",
)

# SQLite (used by the test-suite) needs this flag for threaded TestClient use.
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=_connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """FastAPI dependency yielding a request-scoped database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
