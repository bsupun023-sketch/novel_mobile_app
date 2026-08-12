from pathlib import Path
import logging
from typing import Any

from .database import (
    initialize_database_if_needed,
    run_startup_migrations,
    get_connection,
    USE_SQLITE,
)
from . import mysql_compat

LOGGER = logging.getLogger(__name__)

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
    cursor = connection.cursor()
    inserted = 0
    try:
        from . import database as db_mod

        use_sqlite = db_mod.USE_SQLITE
        for name in DEFAULT_TAGS:
            if use_sqlite:
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


def _apply_runtime_patches() -> None:
    """Patch main module helpers for MySQL safety without full file rewrite."""
    try:
        from . import main as main_mod
        from . import database as db_mod

        def _to_db_query(query: str) -> str:
            return mysql_compat.to_db_query(query, db_mod.USE_SQLITE)

        main_mod._to_db_query = _to_db_query  # type: ignore[attr-defined]

        def _set_story_tags(story_id: int, tag_names: list[str] | None) -> None:
            mysql_compat.set_story_tags(
                story_id,
                tag_names,
                fetch_all=main_mod.fetch_all,
                execute_write=main_mod.execute_write,
            )

        main_mod._set_story_tags = _set_story_tags  # type: ignore[attr-defined]

        try:
            from .tag_routes import register_extra_routes

            serialize = getattr(main_mod, "_serialize_book", None)
            register_extra_routes(
                main_mod.app,
                fetch_all=main_mod.fetch_all,
                fetch_one=main_mod.fetch_one,
                execute_write=main_mod.execute_write,
                serialize_book=serialize,
            )
            LOGGER.info("Registered extra tag/book routes")
        except Exception as route_exc:
            LOGGER.warning("Extra routes not registered: %s", route_exc)

        try:
            mysql_compat.patch_execute_write(main_mod, db_mod.USE_SQLITE)
            LOGGER.info("Patched execute_write for lastrowid recovery")
        except Exception as ew_exc:
            LOGGER.warning("execute_write patch skipped: %s", ew_exc)

        LOGGER.info(
            "Applied runtime patches (db_mode=%s)",
            "sqlite" if db_mod.USE_SQLITE else "mysql",
        )
    except Exception as exc:
        LOGGER.warning("Runtime patches not applied: %s", exc)


def run_startup_tasks() -> dict[str, Any]:
    result: dict[str, Any] = {
        "initialized": False,
        "migrations": {},
        "counts": {},
        "tags_seeded": 0,
        "patches_applied": False,
        "db_mode": "sqlite" if USE_SQLITE else "mysql",
    }

    # Ensure MySQL is reachable when configured; otherwise fall back to SQLite.
    try:
        from . import database as db_mod

        if not db_mod.USE_SQLITE:
            err = db_mod._mysql_probe()
            if err is not None and db_mod.MYSQL_FALLBACK_SQLITE:
                db_mod.activate_sqlite_fallback(str(err))
                result["db_mode"] = "sqlite"
                result["mysql_fallback_reason"] = str(err)
            else:
                result["db_mode"] = "sqlite" if db_mod.USE_SQLITE else "mysql"
    except Exception as probe_exc:
        LOGGER.warning("DB probe skipped: %s", probe_exc)

    initialized = initialize_database_if_needed()
    result["initialized"] = bool(initialized)

    migration_report = run_startup_migrations()
    result["migrations"] = migration_report

    try:
        _apply_runtime_patches()
        result["patches_applied"] = True
    except Exception as exc:
        LOGGER.exception("Patch step failed: %s", exp if False else exc)

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
