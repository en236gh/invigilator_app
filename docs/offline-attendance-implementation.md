# Offline attendance in the Flutter app

Open **Sync** or **Use downloaded roster / offline capture** from verification.
A successful login automatically starts downloading the assigned subset. A status
bar remains visible across authenticated screens, showing overall progress from
0–100%: roster transfer (0–30%), photo attempts (30–90%), and SQLite commit
(90–100%). This is staged preparation progress, not a total-byte estimate. If the
server omits the roster content length, that stage advances when its response
arrives. Only a completed SQLite transaction reaches 100%; photo failures are
reported separately. Failed downloads retain the previous snapshot and offer Retry.
Manual refresh remains available in Sync.

Select a cached exam/venue, enter a computer number,
compare the student with the cached photo/identification, and save a pending scan.
QR capture retains the exact token; enter the student's number for local lookup.
Neither local lookup nor selecting a facial method establishes server verification.
Facial methods must only report a comparison actually completed separately.

The existing online verification endpoints and workflow remain available.

## Storage and identity

The app uses its existing `sqflite` database, migrated from schema 1 to 2 without
removing existing tables. Snapshots, photo bytes and scan history are scoped by
staff ID. Passwords are never placed in SQLite. Tokens and the active staff ID
remain in Flutter Secure Storage. SQLite uses the platform's app-private storage;
it is not an encrypted database. Android backup is disabled for this private data.

Login only needs the access/refresh tokens. It does not require a user object or
assume a login user ID is a staff ID. The initial roster request uses the bearer
token; the server-returned snapshot `staffId` establishes offline ownership.
That verified owner is persisted in secure storage as `offlineStaffId` and used
for SQLite lookup, photos and queued sync. Until the server resolves ownership,
no previously cached account data is loaded, but download/retry remains enabled.

Each download is tied to the initiating login session, independently of token
rotation. Account changes block old requests and retries; late roster responses
cannot bind ownership to a new login. New login/sign-out clears the active binding
without deleting any SQLite data. Existing installations with only the legacy
`staffId` key must sign in again once to establish a server-verified binding.

An active secure-storage identity can reopen its cached roster after an app restart
without network access. Explicit sign-out removes that access and authentication
credentials, but leaves all queues and history in SQLite. Signing into the same
staff account restores access; another account cannot view or submit those rows.
The bootstrap request carries an expected login session; subsequent photo and sync
requests also carry the expected owner. These are checked against a consistent
credential read immediately before sending, including after token refresh.

Downloading a new snapshot replaces the current lookup roster, never queued payloads.
Previously queued scans retain their original snapshot IDs. Rejections remain in
history; creating a new scan requires explicit confirmation that the issue was
resolved. There is no automatic expiry, deletion, or replacement of rejected UUIDs.

## Sync and failures

Offline attendance capture is available under `/offline-attendance`. Saved scans
remain pending until the user presses Sync to server under `/sync`. That screen
shows pending and synced students during the upload, then completion or retry
results. Uploads do not start automatically after capture, login, download, or resume.

Batches contain at most 200 immutable payloads. Every terminal response is validated
and persisted separately; missing or malformed results stay pending. A request
failure leaves unacknowledged scans eligible for retry using exactly the same UUIDs.
Counts and history distinguish pending, accepted, already recorded and rejected items.

Token refresh is serialized across callers. Both rotated tokens are persisted before
request replay; refresh outages preserve credentials and all SQLite data. A 401 can
refresh once; a 403 is shown as access denied and is not blindly treated as expiry.
Credential writes and logout are serialized, and late refreshes cannot overwrite a
new login. Sign in again with the original account when authentication is required.

Photos resolve relative to the configured API base URL and use its bearer client.
Only the same origin is accepted and redirects are disabled to avoid disclosing
credentials to another host. Missing, external, or failed photos are counted and
local capture remains available. The existing app had no other photo-fetching
implementation to reuse. Device acceptance must confirm the server's actual paths.

## Validation and platform limits

Run:

```sh
dart format lib/features/offline lib/features/sync/presentation/sync_status_screen.dart test/*offline* test/auth*test.dart
flutter analyze
flutter test
```

Tests exercise real SQLite files through the FFI test adapter, including reopening
storage, account isolation, photo storage, roster lookup, QR requirements, immutable
retry payloads, 200-item batching, independent results and rejection retention.
Authentication tests cover rotated-token persistence, single-flight refresh, outage
preservation, 401 replay, 403 handling, token-only login/download, server-derived ownership, rejecting late
responses after account changes, and blocking cross-account submission.

Physical-device camera, photo rendering, platform secure storage, live API acceptance
and airplane-mode transitions still require device acceptance testing. Production
storage uses the existing sqflite-supported mobile platforms; no web or Windows/Linux
production SQLite adapter has been added. The FFI adapter is a test-only dependency.
