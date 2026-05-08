from __future__ import annotations

import sys

import firebase_admin
from firebase_admin import firestore


def main() -> int:
    try:
        if not firebase_admin._apps:  # pyright: ignore[reportPrivateUsage]
            firebase_admin.initialize_app()

        db = firestore.client()
        users_ref = db.collection("users")

        docs = list(users_ref.stream())
        if not docs:
            print("No user documents found.")
            return 0

        updated = 0
        skipped = 0
        batch = db.batch()
        ops = 0

        for doc in docs:
            data = doc.to_dict() or {}
            if "role" not in data:
                skipped += 1
                continue

            batch.set(
                doc.reference,
                {
                    "role": firestore.DELETE_FIELD,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )
            updated += 1
            ops += 1

            if ops >= 400:
                batch.commit()
                batch = db.batch()
                ops = 0

        if ops > 0:
            batch.commit()

        print(f"Done. Updated: {updated}, skipped(no role): {skipped}, total users: {len(docs)}")
        return 0
    except Exception as exc:
        print(f"Migration failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
