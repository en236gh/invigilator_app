# Phase 7 Frontend Actor Integration

Import [phase_7_admin_invigilator_assignment.postman_collection.json](phase_7_admin_invigilator_assignment.postman_collection.json) into Postman.

## Setup

1. Ensure the Phase 5, Phase 6, Phase 7, and Phase 8 Supabase SQL scripts have been applied.
2. Start the backend and set the collection variable `baseUrl`.
3. Set `adminEmail` and `adminPassword` to an administrator account.
4. Run `Shared Authentication > Login as Administrator`.
5. The collection stores `accessToken` and `refreshToken` automatically.

The frontend should send `Authorization: Bearer <accessToken>` on every administrator assignment request. When the access token expires, call refresh and replace both stored tokens because refresh-token rotation is enabled.

## Administrator

This is the only actor with new Phase 7 APIs. The recommended workflow is:

1. `GET /api/admin/invigilator-assignments/exam-sessions/{examSessionId}/staffing` to show, per venue, the allocated student count, required/assigned invigilator counts, `staffingStatus`, named `assignedInvigilators` with their `assignmentStatus`, and named `remainingInvigilators`. Each venue row also includes `totalActiveInvigilatorCount`, `totalAssignedInvigilatorCount`, and `totalRemainingInvigilatorCount` for the examination overall.
2. `POST /api/admin/invigilator-assignments/exam-sessions/{examSessionId}/auto-assign` to generate eligible assignments. The response includes `assignments`, `createdDraftAssignments`, and any `understaffedVenueIds`.
3. `GET /api/admin/invigilator-assignments?examSessionId={examSessionId}` to review all assignments and their statuses.
4. Optionally use `POST /api/admin/invigilator-assignments` for a manual draft or `POST /api/admin/invigilator-assignments/{examSessionId}/{venueId}/{staffId}/cancel` to remove an assignment from consideration. Cancelling a `DRAFT` assignment deletes its database row; cancelling a published assignment records it as `CANCELLED`.
5. `POST /api/admin/invigilator-assignments/exam-sessions/{examSessionId}/publish` after review. Only then are draft assignments published for operational use.

Automatic assignment selects active staff with the `INVIGILATOR` role, excludes time clashes, prefers lower active workload, and never creates published assignments directly.

## Invigilator

No new invigilator API was added. Existing assignment and attendance screens continue using the existing `/api/invigilator` endpoints. A newly generated assignment remains invisible operationally until an administrator publishes it.

## Student

No new student API was added. Student authentication, profile, examination pass, and attendance flows remain unchanged.

## Error handling

- `401`: access token is missing or expired; refresh tokens and retry once.
- `403`: the authenticated account does not have the `ADMINISTRATOR` authority.
- `400` or `409`: invalid venue/staff, duplicate assignment, completed examination, or a scheduling conflict. Show the returned message to the administrator and refresh staffing data.
