# LifeInSync usage fixes - manual test plan

## Device setup
1. Ensure Usage Access permission is granted for LifeInSync.
2. Sign in with an existing account (email/password flow unchanged).
3. Open the Screen Time tab once to allow initial sync.

## Repro & validation steps

### 1) Foreground-only usage accuracy
- Open Instagram for 10 minutes (foreground).
- Open Screen Time -> verify Instagram shows about 10 minutes (+/- 1 min).

### 2) Background audio policy
- Open Spotify and play music.
- Return to the home screen and keep music playing for 20 minutes.
- Expected: Spotify should only count when the app is foreground.

### 3) Cross-midnight split
- At 23:50, open any app and use it until 00:10.
- Open Screen Time -> verify 10 minutes assigned to the previous day
  and 10 minutes to the new day.

### 4) Digital score updates
- Use the phone for about 30 minutes.
- Return to the app (Dashboard) and wait for sync.
- Expected: the digital score (wellbeing) changes from the previous value.

### 5) Previous week selector
- Open Screen Time -> switch to "Last week".
- Expected: weekly chart updates and day taps show per-day app usage.

### 6) Debug view (debug builds only)
- On Screen Time, tap the bug icon.
- Verify it shows event counts, session counts, and top apps.

## Notes
- The usage aggregation is based on Android usage events (foreground sessions).
- If events are missing, re-open the app and re-check permission.
