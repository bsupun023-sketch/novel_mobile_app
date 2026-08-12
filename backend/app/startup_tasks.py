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
    "LGBTQ+",
    "Boyxboy",
    "Omegaverse",
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


def _ensure_mysql_extra_tables(connection) -> int:
    """Create tags / book_tags / reviews / follows if missing (MySQL)."""
    from . import database as db_mod

    if db_mod.USE_SQLITE:
        return 0

    cursor = connection.cursor()
    added = 0
    statements = [
        (
            "tags",
            """
            CREATE TABLE IF NOT EXISTS tags (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(80) NOT NULL UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """,
        ),
        (
            "book_tags",
            """
            CREATE TABLE IF NOT EXISTS book_tags (
                book_id INT NOT NULL,
                tag_id INT NOT NULL,
                PRIMARY KEY (book_id, tag_id),
                CONSTRAINT fk_bt_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                CONSTRAINT fk_bt_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            )
            """,
        ),
        (
            "book_reviews",
            """
            CREATE TABLE IF NOT EXISTS book_reviews (
                id INT AUTO_INCREMENT PRIMARY KEY,
                book_id INT NOT NULL,
                user_id INT NOT NULL,
                rating TINYINT NOT NULL DEFAULT 5,
                body TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_review_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """,
        ),
        (
            "author_follows",
            """
            CREATE TABLE IF NOT EXISTS author_follows (
                id INT AUTO_INCREMENT PRIMARY KEY,
                author_user_id INT NOT NULL,
                follower_user_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_follow (author_user_id, follower_user_id)
            )
            """,
        ),
    ]
    try:
        for name, sql in statements:
            cursor.execute(f"SHOW TABLES LIKE '{name}'")
            if cursor.fetchone() is None:
                cursor.execute(sql)
                added += 1
                LOGGER.info("Created missing table: %s", name)
        connection.commit()
    except Exception as exc:
        LOGGER.warning("ensure_mysql_extra_tables failed: %s", exc)
        try:
            connection.rollback()
        except Exception:
            pass
    finally:
        cursor.close()
    return added


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

        def _fetch_one(query: str, params=None):
            rows = main_mod.fetch_all(query, params)
            return rows[0] if rows else None

        try:
            from .tag_routes import register_extra_routes

            serialize = getattr(main_mod, "_serialize_book", None)
            register_extra_routes(
                main_mod.app,
                fetch_all=main_mod.fetch_all,
                fetch_one=_fetch_one,
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
        "tables_ensured": 0,
        "patches_applied": False,
        "db_mode": "sqlite" if USE_SQLITE else "mysql",
    }

    try:
        from . import database as db_mod
        from . import db_runtime

        probe_info = db_runtime.apply_mysql_fallback_if_needed(db_mod)
        result["db_mode"] = probe_info.get("db_mode", result["db_mode"])
        if probe_info.get("mysql_fallback_reason"):
            result["mysql_fallback_reason"] = probe_info["mysql_fallback_reason"]
    except Exception as probe_exc:
        LOGGER.warning("DB probe skipped: %s", probe_exc)

    initialized = initialize_database_if_needed()
    result["initialized"] = bool(initialized)

    migration_report = run_startup_migrations()
    result["migrations"] = migration_report

    try:
        conn = get_connection()
        result["tables_ensured"] = _ensure_mysql_extra_tables(conn)
        result["tags_seeded"] = _seed_tags(conn)
        for tbl in (
            "menu_items",
            "achievements",
            "reading_lists",
            "profiles",
            "write_screen",
            "tags",
            "books",
        ):
            result["counts"][tbl] = _query_count(conn, tbl)
        conn.close()
    except Exception as exc:
        LOGGER.exception("Failed after migrations: %s", exc)

    try:
        _apply_runtime_patches()
        result["patches_applied"] = True
    except Exception as exc:
        LOGGER.exception("Patch step failed: %s", exc)

    LOGGER.info("Startup tasks finished: %s", result)
    return result
