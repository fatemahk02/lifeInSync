# LifeInSync FastAPI Backend

This backend provides daily behavior metrics consumed by the Flutter app.

All user endpoints expect a Firebase ID token in `Authorization: Bearer <token>`.

## Endpoints

- `GET /health`
- `GET /users/{uid}/daily-metrics?date=YYYY-MM-DD`

Response example:

```json
{
  "uid": "abc123",
  "date": "2026-04-01",
  "focus_sessions_completed": 2,
  "habits_completed": 4,
  "has_focus_session_today": true
}
```

## Local Run

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
set GOOGLE_APPLICATION_CREDENTIALS=E:\path\to\service-account.json
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Optional local-only bypass for backend auth checks:

```bash
set LIFEINSYNC_ALLOW_INSECURE_AUTH=true
```

Do not enable this in staging or production.

## Flutter Integration

Run Flutter with:

```bash
flutter run --dart-define=FASTAPI_BASE_URL=http://10.0.2.2:8000
```

For a physical Android device, replace `10.0.2.2` with your machine LAN IP.
