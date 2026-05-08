from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import os
import re
import urllib.error
import urllib.request

import firebase_admin
from firebase_admin import auth as firebase_auth
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import firestore
from pydantic import BaseModel, Field


app = FastAPI(title="LifeInSync API", version="1.0.0")
_uid_pattern = re.compile(r"^[A-Za-z0-9:_-]{6,128}$")


class UserPreferencesPayload(BaseModel):
    daily_screen_limit_minutes: int | None = Field(default=None, ge=30, le=24 * 60)
    notifications_enabled: bool | None = None
    focus_goal_minutes: int | None = Field(default=None, ge=5, le=600)
    onboarding_completed: bool | None = None
    theme: str | None = None


class UserProfilePayload(BaseModel):
    name: str | None = None
    mobile_number: str | None = None
    avatar_emoji: str | None = None
    timezone: str | None = None
    gender: str | None = None
    age: int | None = Field(default=None, ge=1, le=120)
    role: str | None = None
    preferences: UserPreferencesPayload | None = None

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _parse_day(day: str | None) -> datetime:
    if day is None:
        now = datetime.now(timezone.utc)
        return datetime(now.year, now.month, now.day, tzinfo=timezone.utc)

    try:
        parsed = datetime.strptime(day, "%Y-%m-%d")
        return parsed.replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date format, expected YYYY-MM-DD") from exc


def _get_client() -> firestore.Client:
    credentials = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if not credentials:
        raise HTTPException(
            status_code=503,
            detail="GOOGLE_APPLICATION_CREDENTIALS is not configured",
        )
    return firestore.Client()


def _is_insecure_auth_enabled() -> bool:
    return os.getenv("LIFEINSYNC_ALLOW_INSECURE_AUTH", "false").lower() == "true"


def _get_openai_key() -> str:
    key = os.getenv("OPENAI_API_KEY")
    if not key:
        raise HTTPException(status_code=503, detail="OPENAI_API_KEY is not configured")
    return key


def _call_openai_insights(prompt: str) -> list[str]:
    key = _get_openai_key()
    payload = {
        "model": "gpt-4.1",
        "temperature": 0.6,
        "max_tokens": 220,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a digital wellbeing coach. "
                    "Return a JSON array of 1-3 short recommendations. "
                    "Each item must be <= 120 characters, no emojis, no numbering. "
                    "Return JSON only."
                ),
            },
            {"role": "user", "content": prompt},
        ],
    }

    request = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise HTTPException(status_code=502, detail="OpenAI request failed") from exc
    except urllib.error.URLError as exc:
        raise HTTPException(status_code=502, detail="OpenAI request failed") from exc

    content = (
        data.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "")
        .strip()
    )

    try:
        parsed = json.loads(content)
        if isinstance(parsed, list):
            return [str(item).strip() for item in parsed if str(item).strip()]
    except json.JSONDecodeError:
        pass

    # Fallback: split by line breaks.
    lines = [line.strip("-• \t") for line in content.splitlines() if line.strip()]
    return lines[:3]


def _ensure_firebase_admin_initialized() -> None:
    if firebase_admin._apps:  # pyright: ignore[reportPrivateUsage]
        return
    firebase_admin.initialize_app()


def _require_authenticated_uid(authorization: str | None = Header(default=None)) -> str:
    if _is_insecure_auth_enabled():
        return "insecure-debug-user"

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty bearer token")

    try:
        _ensure_firebase_admin_initialized()
        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Firebase token") from exc

    uid = str(decoded.get("uid", ""))
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=403, detail="Invalid uid in token")

    return uid


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/users/{uid}/daily-metrics")
def get_daily_metrics(
    uid: str,
    date: str | None = Query(default=None),
    authenticated_uid: str = Depends(_require_authenticated_uid),
) -> dict[str, int | bool | str]:
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=400, detail="Invalid uid format")

    if not _is_insecure_auth_enabled() and authenticated_uid != uid:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")

    day_start = _parse_day(date)
    day_end = day_start + timedelta(days=1)

    client = _get_client()

    focus_docs = list(
        client.collection("focusSessions")
        .document(uid)
        .collection("sessions")
        .where("completed", "==", True)
        .where("completedAt", ">=", day_start)
        .where("completedAt", "<", day_end)
        .stream()
    )

    habits_docs = list(
        client.collection("habitLogs")
        .document(uid)
        .collection("logs")
        .where("completed", "==", True)
        .where("date", ">=", day_start)
        .where("date", "<", day_end)
        .stream()
    )

    return {
        "uid": uid,
        "date": day_start.strftime("%Y-%m-%d"),
        "focus_sessions_completed": len(focus_docs),
        "habits_completed": len(habits_docs),
        "has_focus_session_today": len(focus_docs) > 0,
    }


@app.get("/users/{uid}/profile")
def get_user_profile(
    uid: str,
    authenticated_uid: str = Depends(_require_authenticated_uid),
) -> dict:
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=400, detail="Invalid uid format")

    if not _is_insecure_auth_enabled() and authenticated_uid != uid:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")

    client = _get_client()
    doc = client.collection("users").document(uid).get()
    data = doc.to_dict() or {}
    prefs = data.get("preferences") or {}

    return {
        "uid": uid,
        "name": data.get("name") or "",
        "email": data.get("email") or "",
        "mobile_number": data.get("mobileNumber") or "",
        "avatar_emoji": data.get("avatarEmoji") or "🙂",
        "timezone": data.get("timezone") or "UTC",
        "gender": data.get("gender") or "",
        "age": int(data.get("age") or 0),
        "role": data.get("role") or "",
        "preferences": {
            "daily_screen_limit_minutes": int(prefs.get("dailyScreenLimitMinutes") or 180),
            "notifications_enabled": bool(prefs.get("notificationsEnabled", True)),
            "focus_goal_minutes": int(prefs.get("focusGoalMinutes") or 60),
            "onboarding_completed": bool(prefs.get("onboardingCompleted", False)),
            "theme": str(prefs.get("theme") or "light"),
        },
    }


@app.put("/users/{uid}/profile")
def upsert_user_profile(
    uid: str,
    payload: UserProfilePayload,
    authenticated_uid: str = Depends(_require_authenticated_uid),
) -> dict:
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=400, detail="Invalid uid format")

    if not _is_insecure_auth_enabled() and authenticated_uid != uid:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")

    updates: dict = {"updatedAt": firestore.SERVER_TIMESTAMP}

    if payload.name is not None:
        updates["name"] = payload.name.strip()
    if payload.mobile_number is not None:
        updates["mobileNumber"] = payload.mobile_number.strip()
    if payload.avatar_emoji is not None:
        updates["avatarEmoji"] = payload.avatar_emoji
    if payload.timezone is not None:
        updates["timezone"] = payload.timezone
    if payload.gender is not None:
        updates["gender"] = payload.gender
    if payload.age is not None:
        updates["age"] = payload.age
    if payload.role is not None:
        updates["role"] = payload.role

    if payload.preferences is not None:
        prefs: dict = {}
        if payload.preferences.daily_screen_limit_minutes is not None:
            prefs["dailyScreenLimitMinutes"] = payload.preferences.daily_screen_limit_minutes
        if payload.preferences.notifications_enabled is not None:
            prefs["notificationsEnabled"] = payload.preferences.notifications_enabled
        if payload.preferences.focus_goal_minutes is not None:
            prefs["focusGoalMinutes"] = payload.preferences.focus_goal_minutes
        if payload.preferences.onboarding_completed is not None:
            prefs["onboardingCompleted"] = payload.preferences.onboarding_completed
        if payload.preferences.theme is not None:
            prefs["theme"] = payload.preferences.theme
        if prefs:
            updates["preferences"] = prefs

    client = _get_client()
    client.collection("users").document(uid).set(updates, merge=True)

    return {"status": "ok", "uid": uid}


@app.get("/users/{uid}/analytics")
def get_analytics_snapshot(
    uid: str,
    period: str = Query(default="daily"),
    key: str | None = Query(default=None),
    authenticated_uid: str = Depends(_require_authenticated_uid),
) -> dict:
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=400, detail="Invalid uid format")

    if not _is_insecure_auth_enabled() and authenticated_uid != uid:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")

    if period not in {"daily", "weekly", "monthly"}:
        raise HTTPException(status_code=400, detail="period must be one of daily|weekly|monthly")

    client = _get_client()
    ref = client.collection("analytics").document(uid).collection(period)

    if key:
      doc = ref.document(key).get()
      if not doc.exists:
          raise HTTPException(status_code=404, detail="Analytics snapshot not found")
      return {"uid": uid, "period": period, "key": key, "data": doc.to_dict() or {}}

    docs = list(ref.order_by("updatedAt", direction=firestore.Query.DESCENDING).limit(1).stream())
    if not docs:
        return {"uid": uid, "period": period, "key": None, "data": {}}

    doc = docs[0]
    return {"uid": uid, "period": period, "key": doc.id, "data": doc.to_dict() or {}}


@app.get("/users/{uid}/ai-insights")
def get_ai_insights(
    uid: str,
    date: str | None = Query(default=None),
    authenticated_uid: str = Depends(_require_authenticated_uid),
) -> dict:
    if not _uid_pattern.match(uid):
        raise HTTPException(status_code=400, detail="Invalid uid format")

    if not _is_insecure_auth_enabled() and authenticated_uid != uid:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")

    day_start = _parse_day(date)
    day_end = day_start + timedelta(days=1)
    day_key = day_start.strftime("%Y-%m-%d")

    client = _get_client()

    user_doc = client.collection("users").document(uid).get()
    user_data = user_doc.to_dict() or {}
    prefs = user_data.get("preferences") or {}
    daily_limit = int(prefs.get("dailyScreenLimitMinutes") or 180)

    usage_doc = (
        client.collection("analytics")
        .document(uid)
        .collection("live")
        .document("usage")
        .get()
    )
    usage_data = usage_doc.to_dict() or {}

    fatigue_doc = (
        client.collection("fatigueHistory")
        .document(uid)
        .collection("logs")
        .document(day_key)
        .get()
    )
    fatigue_data = fatigue_doc.to_dict() or {}
    fatigue_score = int(fatigue_data.get("score") or 0)

    focus_docs = list(
        client.collection("focusSessions")
        .document(uid)
        .collection("sessions")
        .where("completed", "==", True)
        .where("completedAt", ">=", day_start)
        .where("completedAt", "<", day_end)
        .stream()
    )

    habit_docs = list(
        client.collection("habitLogs")
        .document(uid)
        .collection("logs")
        .where("completed", "==", True)
        .where("date", ">=", day_start)
        .where("date", "<", day_end)
        .stream()
    )

    total_minutes = int(usage_data.get("totalScreenMinutesToday") or 0)
    top_apps = usage_data.get("topApps") or []
    top_summary = [
        f"{app.get('appName') or app.get('packageName')}:{int(app.get('usageMinutes') or 0)}"
        for app in top_apps[:5]
    ]

    prompt = (
        "Generate 1-3 short, practical wellbeing recommendations for today. "
        "Inputs: total_minutes={total}, daily_limit={limit}, fatigue_score={fatigue}, "
        "focus_sessions={focus}, habits_completed={habits}, top_apps={apps}."
    ).format(
        total=total_minutes,
        limit=daily_limit,
        fatigue=fatigue_score,
        focus=len(focus_docs),
        habits=len(habit_docs),
        apps=", ".join(top_summary) if top_summary else "none",
    )

    insights = _call_openai_insights(prompt)

    return {
        "uid": uid,
        "date": day_key,
        "insights": insights[:3],
    }
