"""
Pydantic v2 request/response schemas for the CloudTwin API.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TaskBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    completed: bool = False


class TaskCreate(TaskBase):
    """Payload for POST /api/tasks."""


class TaskUpdate(BaseModel):
    """Payload for PUT /api/tasks/{id}; every field is optional."""

    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    description: Optional[str] = None
    completed: Optional[bool] = None


class TaskResponse(TaskBase):
    """Task as returned by the API."""

    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
