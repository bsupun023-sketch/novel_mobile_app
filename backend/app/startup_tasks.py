from pathlib import Path
import logging
from typing import Any

from .database import (
    initialize_database_if_needed,
    run_startup_migrations,
    get_connection,
    USE_SQLITE,
)

LOGGER = logging.getLogger(__name__)

# Admin-managed hashtags (authors may only attach these; max 3 per book)
DEFAULT_TAGS = [
    "Romance",
    "Love",
    "Romance/Drama",
    "Love Story",
    "Fantasy",
    "Dark",
    "Alpha Male",
    "Werewolves",
    "Paranormal",
    "Erotica",
    "Mystery",
    "Thriller",
    "Young Adult",
    "Adventure",
    "Horror",
    "SciFi",
    "Drama",
    "Humor",
]


def _query_count(connection, table: str) -> int:
    cursor = connection.cursor()
    try:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        row = cursor.fetchone()
        return int(row[0]) if row is not None else 0
    except Exception:
        return 0
    finally:
        cursor.close()


def _seed_tags(connection) -> int:
    """Idempotently seed admin hashtags. Returns number of tags inserted."""
    cursor = connection.cursor()
    inserted = 0
    try:
        for name in DEFAULT_TAGS:
            if USE_SQLITE:
                cursor.execute("SELECT id FROM tags WHERE name=? LIMIT 1", (name,))
                if cursor.fetchone() is None:
                    cursor.execute("INSERT INTO tags (name) VALUES (?)", (name,))
                    inserted += 1
            else:
                cursor.execute("SELECT id FROM tags WHERE name=%s LIMIT 1", (name,))
                if cursor.fetchone() is None:
                    cursor.execute("INSERT INTO tags (name) VALUES (%s)", (name,))
                    inserted += 1
        connection.commit()
    except Exception as exc:
        LOGGER.warning("Tag seed skipped or partial: %s", exc)
        try:
            connection.rollback()
        except Exception:
            pass
    finally:
        cursor.close()
    return inserted


def run_startup_tasks() -> dict[str, Any]:
    """Run idempotent startup tasks: initialize DB schema, run migrations/seeds,
    and return a small summary so callers (and logs) can verify seeds applied.
    """
    result: dict[str, Any] = {
        "initialized": False,
        "migrations": {},
        "counts": {},
        "tags_seeded": 0,
    }

    initialized = initialize_database_if_needed()
    result["initialized"] = bool(initialized)

    migration_report = run_startup_migrations()
    result["migrations"] = migration_report

    try:
        conn = get_connection()
        result["tags_seeded"] = _seed_tags(conn)
        for tbl in (
            "menu_items",
            "achievements",
            "reading_lists",
            "profiles",
            "write_screen",
            "tags",
        ):
            result["counts"][tbl] = _query_count(conn, tbl)
        conn.close()
    except Exception as exc:
        LOGGER.exception("Failed to query counts after migrations: %s", exc)

    LOGGER.info("Startup tasks finished: %s", result)
    return result
