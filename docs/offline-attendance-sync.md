# Offline attendance backend contract

Both endpoints require `Authorization: Bearer <accessToken>` with the `INVIGILATOR` authority. The backend resolves the staff identity from authentication; clients cannot choose a staff ID. No frontend changes are included.

## Download

`GET /api/attendance/offline-exam-data`

The usual `{ "success": true, "message": "...", "data": ... }` envelope contains:

- `snapshotId`: server-generated UUID; retain it with every queued scan.
- `staffId`: owning account; keep device queues separated by this identity.
- `generatedAt`: UTC timestamp.
- `assignments`: only the invigilator's published assignments whose examination timetable is published. Each has `examSessionId`, `courseCode`, `examDate`, `startTime`, `endTime`, `academicYear`, `semester`, `examType`, `status`, `venueId`, and `venueName`.
- `students`: only registered students allocated to those exact exam/venue pairs. Fields: `examSessionId`, `venueId`, `computerNumber`, `fullName`, `program`, `photoPath`, and nullable `attendanceStatus`.

`photoPath` uses the existing student lookup photo reference. The app must cache the referenced image while online for offline visual comparison; this endpoint does not embed image bytes or face embeddings. It does not expose examination-pass tokens, national IDs, contact details, or other invigilators' rosters. The response has `Cache-Control: no-store` for intermediary caches; the app explicitly manages its private offline data.

The server retains the snapshot's roster membership. Downloading another snapshot does not invalidate an earlier one. A snapshot is historical evidence of roster membership, not permission to bypass current attendance rules. There is no automatic age-based expiry or cleanup in this migration; any future retention policy must account for unsynced queues and retry guarantees.

## Sync

`POST /api/attendance/sync`

```json
{
  "scans": [
    {
      "scanId": "e85bf5bf-d042-43a2-978e-ab1384d07342",
      "snapshotId": "9f9bd594-dfd4-4c6f-865d-c7f0054d4c53",
      "examSessionId": 5,
      "venueId": 16,
      "computerNumber": "2022004264",
      "verificationMethod": "COMPUTER",
      "capturedAt": "2026-10-01T09:05:20+02:00"
    }
  ]
}
```

Send 1–200 items. Generate `scanId` once on the device when queuing the scan, and reuse it for every retry. `capturedAt` must include a UTC offset, cannot be in the future, and cannot precede snapshot generation. Exam and venue IDs must be positive JSON integers.

Supply `computerNumber` (10 digits), `qrToken`, or both. When both are present, their identities must match. Methods match existing check-in: `COMPUTER`, `QR_CODE`, `FACE_RECOGNITION`, `QR_AND_FACE`, and `QR_AND_FACIAL`. Every QR method requires the captured token. Whenever a token is supplied, it is validated even if the method is `COMPUTER` or `FACE_RECOGNITION`.

QR validation uses the current stored examination pass and selected exam period, including signature, purpose, identity, expiry, and regenerated/revoked-pass checks. Expiry is evaluated at sync time, as in online check-in. Offline decoding/local face comparison does not establish server-side QR validity. Facial verification remains a client-reported method, as in the existing attendance API.

HTTP 200 has `data` as an ordered array of results, one per item:

```json
{
  "scanId": "e85bf5bf-d042-43a2-978e-ab1384d07342",
  "outcome": "ACCEPTED",
  "reason": "RECORDED",
  "message": "Attendance recorded",
  "attendanceId": 123,
  "processedAt": "2026-10-01T07:15:00Z"
}
```

| Outcome | Meaning |
| --- | --- |
| `ACCEPTED` | A new attendance row was committed. |
| `ALREADY_RECORDED` | Another scan/device already recorded attendance for this student/exam; its original row is preserved. |
| `REJECTED` | No attendance was created or changed by this scan. Inspect `reason` and `message`. |

Clear rejection codes include `NOT_IN_SNAPSHOT`, `INVALID_SNAPSHOT`, `ALLOCATION_CHANGED`, `NOT_ASSIGNED`, `EXAM_NOT_PUBLISHED`, `EXAM_COMPLETED`, `NOT_ELIGIBLE`, `INVALID_QR`, `IDENTITY_MISMATCH`, `ATTENDANCE_CONFLICT`, `INVALID_CAPTURE_TIME`, `INVALID_STUDENT_NUMBER`, `INVALID_VERIFICATION_METHOD`, and `INVALID_SCAN`. Missing or malformed UUIDs return `INVALID_SCAN_ID` with null `scanId`; such items cannot be persisted under an idempotency key. A UUID owned by another account returns `SCAN_ID_OWNED_BY_ANOTHER_USER` without exposing that account's result.

Malformed individual items, including invalid field types, are rejected without blocking siblings. Malformed JSON or an invalid batch envelope/size rejects the request. Infrastructure failures may end the request after earlier items committed: retry the entire batch with the same UUIDs.

## Validation, retries, and audit

Sync reuses the online check-in rules for published assignment, published exam, eligibility, exam completion, allocated venue, and verification method. The existing allowance for check-in before an exam starts is preserved. A completed exam rejects new scans even if their captured time was before completion. Absent records are never silently converted to present.

Every valid scan UUID's terminal outcome, including rejection, is persisted atomically with any attendance insert. Repeating it under the same account returns the original fields, timestamp, and outcome, even if the payload or roster has changed. A rejected scan does not become accepted on retry. Resolve the issue explicitly before making a genuinely new scan with a new UUID; do not automatically generate new UUIDs to bypass rejections.

PostgreSQL transaction-level advisory locks serialize concurrent retries across server instances. The existing unique student/exam constraint handles different scan UUIDs and online/offline races. Each item uses its own transaction. Current exam, assignment, allocation, and eligibility rows are protected against concurrent changes during sync validation.

Migration `V40__offline_attendance_sync.sql` adds persisted snapshot membership, the scan outcome ledger, `attendance.client_scan_id`, and `attendance.processed_at`. For accepted offline scans, `check_in_time` is the captured instant converted into the configured institution timezone, following the existing local-timestamp schema. `processed_at` and result `processedAt` record server processing time in UTC. Existing historical processing timestamps remain null because they cannot be reconstructed; future online inserts receive a database default. No QR token is retained in the scan outcome ledger.

## Authentication expiry and durable queues

Use the existing `POST /api/auth/refresh` with `{ "refreshToken": "..." }` to obtain a new access/refresh pair. Refresh tokens rotate: persist both returned tokens before retrying. Download authorization does not authorize later sync without a valid access token.

If access authentication expires, keep the queue and refresh, then resend the same scan UUIDs. The current security configuration may respond with 403 for unauthenticated access; do not assume every 403 means expiry—assignment/role failures also require attention. If refresh fails, prompt for `POST /api/auth/login` using the existing email/password flow. Preserve the local queue through login, and resume only for its original `staffId`. Switching accounts must not submit or display another account's cached roster/queue. Mark a queue item as acknowledged only after a terminal per-item response, retaining rejected items and their reasons for review. Network errors and timeouts must not discard queued scans.

## Backend verification

Existing attendance and authorization tests:

```sh
./mvnw -Dtest=AttendanceServiceTest,CheckInRequestValidationTest,OfflineAttendanceAuthorizationTest test
```

Database tests use a disposable PostgreSQL instance on `127.0.0.1:55440`, with the current OS username and trust authentication. They create/drop uniquely named databases and apply V40 to a minimal attendance schema. Repository test adapters read real database state into the production shared validator.

```sh
/usr/lib/postgresql/18/bin/initdb -D /tmp/attendance-offline-pg -A trust --no-locale -E UTF8
/usr/lib/postgresql/18/bin/pg_ctl -D /tmp/attendance-offline-pg -l /tmp/attendance-offline-pg.log -o '-p 55440 -h 127.0.0.1 -k /tmp' start
./mvnw -Dattendance.it=true -Dtest=OfflineAttendancePostgresTest test
/usr/lib/postgresql/18/bin/pg_ctl -D /tmp/attendance-offline-pg stop
```
