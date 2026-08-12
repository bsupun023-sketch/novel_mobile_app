from collections import defaultdict
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
try:
    import mysql.connector as mysql_connector
except ModuleNotFoundError:
    mysql_connector = None
from pydantic import BaseModel

from .database import (
    get_connection,
    USE_SQLITE,
)

DB_INIT_EXCEPTIONS = (sqlite3.Error, FileNotFoundError, OSError, ValueError)
if mysql_connector is not None:
    DB_INIT_EXCEPTIONS = (mysql_connector.Error, sqlite3.Error, FileNotFoundError, OSError, ValueError)

app = FastAPI(title="Novel Mobile Backend")
LOGGER = logging.getLogger(__name__)
UPLOAD_ROOT = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-key-change-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin_Supun")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "Ux3@f=7x2")
ADMIN_TOKEN_EXPIRES_HOURS = int(os.getenv("ADMIN_TOKEN_EXPIRES_HOURS", "24"))
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_IDS = [s.strip() for s in os.getenv("GOOGLE_CLIENT_IDS", GOOGLE_CLIENT_ID).split(",") if s.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure uploads directory exists and is served
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_ROOT)), name="uploads")

# Minimal stubs so server starts - FULL routes will be restored in follow-up
@app.get("/api/content/version")
def content_version():
    return {"version": "1", "content_version": "1"}

@app.get("/health")
def health():
    return {"ok": True}

@app.on_event("startup")
def on_startup():
    try:
        from .startup_tasks import run_all_startup_tasks
        run_all_startup_tasks()
    except Exception as e:
        LOGGER.warning("Startup tasks failed: %s", e)

print("WARNING: This is a temporary minimal main.py - full routes need restore")
