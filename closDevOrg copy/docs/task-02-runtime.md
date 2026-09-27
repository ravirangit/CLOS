# Task 02 — LOS core runtime

Task 02 implements application creation, configured lifecycle transitions, rework, gross stage timing, pause/resume, validation hooks, and server-side write protection. It adds no LWC, Flow, lending module, approval process or booking integration.

## Service responsibilities

| Class | Responsibility |
|---|---|
| LOS_ConfigurationService | Sole Custom Metadata repository. Lazy transaction caches and immutable typed Config wrappers for all nine catalogs. Resolves active codes, initial stage, scoped transitions, pause rules and SLA rules. |
| LOS_ApplicationService | Creation facade; single remote action and bulk Apex request list. Accepts relationship ID, application type code, and optional approved baseline ID. |
| LOS_LifecycleService | Available actions and stage transitions. Accepts a transition code and expected version; never a destination stage. |
| LOS_TATService | Parent-authorized current-TAT DTO, pause/resume facades, and pure start/close/measurement builders. Start/close builders do not persist records and are not remote endpoints. |
| LOS_BusinessTimeService | UTC clock, interval validation, duration arithmetic, whole-minute rounding and CalendarCalculator interface. GrossOnly returns null for business minutes. |
| LOS_ValidationService | Basic context/reason/length validation and a trusted, transaction-local hook registry. Results contain severity, code, message and blocking. |
| LOS_RuntimeService | Locks applications, checks expected versions, coordinates atomic batches, and owns the private one-use write authorization. |
| LOS_RuntimeData | Bulk reads of service-owned children and actor SLA context. Explicitly rechecks parent edit access; organization context is re-read from stored applications. |
| LOS_RuntimeWriter | Restricted system-mode DML for four runtime-owned object types. Cannot grant write authorization; direct calls fail record guards. |
| LOS_Security | Runtime custom permission, application CRUD, native edit access, user-mode reads, and ordered response projection. |
| LOS_RecordGuard | Bulk trigger handler enforcing runtime-only insert/update and rejecting delete/undelete. History also rejects every update. |
| LOS_ApplicationDTO / LOS_TransitionDTO / LOS_TATDTO | Typed remote responses, including version and expected interval/pause identifiers. |
| LOS_Exception and Configuration / Validation / Lifecycle / TAT / Security subclasses | Stable domain errors. Remote facades return sanitized AuraHandledException messages. Validation exceptions also carry structured results for Apex callers. |

Five thin triggers cover Credit Application, Lifecycle History, Stage TAT, TAT Pause and Assignment TAT. Assignment timing remains deferred; its records are guarded against direct writes in this phase.

## Supported commands

Single-record remote methods:

```text
LOS_ApplicationService.createApplication(relationshipId, applicationTypeCode, baselineApplicationId)
LOS_LifecycleService.getAvailableTransitions(applicationId)
LOS_LifecycleService.transitionApplication(applicationId, transitionCode, expectedVersion, reason, comments)
LOS_TATService.getCurrentTAT(applicationId)
LOS_TATService.pauseTAT(applicationId, expectedStageTATId, reasonCode, comments)
LOS_TATService.resumeTAT(applicationId, expectedPauseId)
```

`createApplications`, `transitionApplications`, `pauseTATs`, and `resumeTATs` accept 1–200 typed requests. Each batch is all-or-none and preserves request order in its response. Duplicate application IDs within a transition/pause/resume batch are rejected. Call a bulk method rather than looping over single-record facades in Apex.

No REST resource or Flow invocable is supplied. Future adapters must call these services rather than write records directly. Public package helpers are not remote APIs; there are no global Apex declarations or caller-accessible write-bypass flags.

Creation has no idempotency key: each successful creation command creates a distinct application. Lifecycle commands are conflict-safe, rather than returning cached success for a replay. An expected version is mandatory even when an example client presents only a transition code.

## Configuration dependencies

- Every active application type needs an active, nonterminal `LOS_Initial_Stage__c`. The three reference types point to the single existing Draft record. New types and different initial stages require metadata changes only.
- Status is initially and subsequently the configured stage code. A separate client status mapping is not invented.
- Configured stage codes identify transaction state. Changing or disabling a used code requires a deliberate migration/configuration plan; runtime does not silently substitute a stage.
- Active transition code resolution prefers an application-type-specific record over the global record. Codes must be unique within that scope. Inactive records are ignored; disabling a scoped record therefore allows an active global fallback. To disable a shared action, disable the applicable global configuration too.
- Transition types are the engine protocol vocabulary Forward, Rework and Approval. No stage, graph edge, product, persona or hierarchy level is embedded in production Apex. `Initial` is a creation audit event, not a graph edge or lifecycle stage.
- Active workspace/persona/unit-type catalogs are retrieved centrally. Workspace rendering, action execution and authorization-policy interpretation are deferred.
- Pause codes may have global, type, stage, or combined scope. The most specific match wins; equal top specificity fails closed. Count Toward SLA is copied to the pause at creation, so later configuration edits do not rewrite history.
- SLA matching uses type, stage, stored organization-unit type and the acting user's active/effective unit memberships and application-team personas. Persona codes must also be active in metadata. No persona or organizational context comes from the request.
- Effective SLA and membership dates are evaluated against the operation's UTC date. Highest SLA priority wins; ties at the winning priority fail closed. Invalid applicable targets, warning thresholds, or date ranges fail closed. Warning thresholds are validated but warning classification is deferred.
- Target minutes and business-hours key are captured on the stage interval. With no applicable SLA rule, the target is null. No SLA value, pause reason or persona is shipped as a business default.
- Validation policy keys resolve only through trusted Apex `registerHook` registrations. Blank policy with Requires Validation runs the basic checks. An unknown nonblank policy fails closed. Hooks may query data but must not perform DML or callouts; detected side effects fail and roll back the operation. Hook context is a copy, so changing it cannot change the pending application.

`Config` wrappers have private setters. Returning a fresh list protects the cached collection. Test-only in-memory metadata overrides replace catalogs without inserting Custom Metadata records or bypassing production security. Real metadata is queried once per requested category per Apex transaction, including long-text fields.

## Creation sequence

```mermaid
sequenceDiagram
    actor Caller
    participant App as ApplicationService
    participant Runtime as RuntimeService
    participant Config as ConfigurationService
    participant DB as Salesforce
    Caller->>App: relationship ID, type code, optional baseline
    App->>Runtime: createApplications(requests)
    Runtime->>DB: Savepoint; check permission and CRUD
    Runtime->>DB: Read Relationship and baseline in USER_MODE
    Runtime->>Config: Active type and explicit initial stage
    Runtime->>Runtime: Validate active relationship; copy stored context
    Runtime->>DB: Guarded application insert
    Runtime->>DB: Guarded initial history insert
    Runtime->>Config: Select applicable SLA
    Runtime->>DB: Guarded initial TAT insert if enabled
    Runtime->>DB: USER_MODE response read
    Runtime-->>Caller: Application DTO including version 0
    Note over Runtime,DB: Any failure rolls back to the savepoint
```

The caller cannot submit BU, segment, branch, organization unit, primary RM, actor, stage, status or rework counters. All organization attributes come from the accessible active Relationship. They are stored values, not formulas; later Relationship edits do not rewrite application context. All application updates are guarded, which also prevents direct edits to those snapshots.

Renewal and Modification retain Task 01's editable baseline-required flags. A supplied baseline must be accessible, have an Approved Date, and belong to the same relationship. Its ID is stored as both baseline and previous approved application. Automatic latest-approved selection is deferred. Task 02 does not set Approved Date; creating a type that requires a baseline therefore requires an approved historical application supplied by a future approval/migration capability.

## Lifecycle and transaction sequence

```mermaid
sequenceDiagram
    actor Caller
    participant Life as LifecycleService
    participant Runtime as RuntimeService
    participant Config as ConfigurationService
    participant Validation as ValidationService
    participant DB as Salesforce
    Caller->>Life: application, transition code, expected version, reason
    Life->>Runtime: transitionApplications(requests)
    Runtime->>DB: Savepoint; permission/CRUD/USER_MODE/edit-access checks
    Runtime->>DB: Lock applications FOR UPDATE
    Runtime->>Runtime: Active application and expected version checks
    Runtime->>Config: Resolve active source, transition and destination
    Runtime->>Validation: Basic checks and configured hook
    Validation-->>Runtime: Structured results; block on errors
    Runtime->>DB: Read current TAT and pause records
    Runtime->>Runtime: Require matching context and no active pause
    Runtime->>DB: Close old TAT; clear unique open key
    Runtime->>DB: Update stage/status/version and rework if applicable
    Runtime->>DB: Insert immutable lifecycle event
    Runtime->>DB: Start destination TAT if enabled
    Runtime-->>Caller: Updated Application DTO
    Note over Runtime,DB: Any error, including late DML/SLA failure, rolls back the entire batch
```

The parent application is the mutex for lifecycle, pause and resume operations. Child reads and writes occur after the parent lock. Salesforce holds the lock until the enclosing transaction ends. The service releases its savepoint after success/failure; releasing a savepoint is not a commit. A successful Apex call can still be rolled back by its enclosing caller transaction.

The runtime version increments only on a successful lifecycle transition. A duplicate click, stale request or request from before a rework round trip fails after locking, even if its source stage happens to match again. The caller must refresh; the server does not silently retry a business command. Lock timeouts and unexpected platform failures return a sanitized retry message.

Apex tests simulate conflicting requests sequentially and verify that stale versions cannot create extra history/TAT records. They do not simulate simultaneous database sessions. Native row locking and unique indexes provide the cross-transaction enforcement; live concurrent-session/load testing remains a release check.

## Rework sequence

```mermaid
sequenceDiagram
    actor Caller
    participant Life as LifecycleService
    participant App as Credit Application
    participant Audit as History and TAT
    Caller->>Life: Configured Rework edge, expected version, reason
    Life->>App: Lock; validate configured edge
    Life->>App: Rework Count + 1; Current Rework Number = count
    Life->>Audit: Event and new interval carry the same number
    Caller->>Life: Subsequent configured Forward edge
    Life->>App: Change stage/version; retain rework number
    Life->>Audit: Event and interval retain current rework number
```

The five Task 01 rework edges remain unchanged. A later Rework transition increments again; forward transitions within that iteration do not. Rework is never represented by an extra stage.

## TAT and pause sequence

```mermaid
sequenceDiagram
    actor Caller
    participant TAT as TATService
    participant Runtime as RuntimeService
    participant DB as Salesforce
    Caller->>TAT: getCurrentTAT(application)
    TAT-->>Caller: Expected stage TAT ID and active pause ID
    Caller->>TAT: pause(application, expected TAT, configured reason)
    TAT->>Runtime: Authorize and lock parent
    Runtime->>DB: Check matching open interval; reject overlapping pause
    Runtime->>DB: Insert pause with captured SLA counting flag
    Runtime-->>Caller: Pause ID
    Caller->>TAT: resume(application, expected pause ID)
    TAT->>Runtime: Authorize and lock parent
    Runtime->>DB: End that active pause; clear unique open key
    Runtime->>DB: Recalculate accumulated paused/gross minutes
    Caller->>Runtime: Later lifecycle transition
    Runtime->>DB: Reject if paused; otherwise close interval and measure
```

There is at most one open stage interval per application, stronger than one per stage/rework combination. A unique text key contains the application ID while the interval is open and becomes null on close. A pause uses the same pattern keyed by Stage TAT ID. Parent locks serialize operations; database uniqueness provides a second enforcement layer. Trigger guards prevent callers from clearing/manufacturing these keys.

A transition while paused is rejected. The caller must resume explicitly, preserving pause attribution and avoiding silent truncation. Resume does not depend on the pause rule still being active; it uses the captured counting policy. Expected interval/pause IDs prevent stale requests from affecting a different stage entry or pause.

Durations are accumulated in milliseconds. Whole minute fields are rounded down only after accumulation, so two 40-second pauses total one stored minute. Paused Minutes includes every completed pause. Preliminary SLA comparison subtracts only pauses whose captured Count Toward SLA is false and compares unrounded milliseconds against the captured target.

SLA status codes are technical measurement states: `Not_Configured`, `Preliminary_Within_Target`, `Preliminary_Exceeded`, and `Pending_Calendar`. A nonblank calendar key produces Pending Calendar, not a claim that business time has been calculated. Business Minutes remains null with the GrossOnly adapter. No workweek, region, holiday or time-zone calendar is assumed.

## Security model

1. Remote facades use `with sharing` and require `LOS_Use_Runtime`. Application creation requires Read/Create/Edit CRUD; existing-application operations require Read/Edit CRUD and native `UserRecordAccess.HasEditAccess`.
2. Relationship/baseline reads and returned application projections explicitly use `WITH USER_MODE`, enforcing CRUD/FLS, sharing and restriction rules. Current-TAT projection also checks relevant object and field readability and requires parent edit access.
3. Stored stage/status/snapshots, audit and TAT fields are service-owned. Their writes intentionally use system mode after command authorization. Field-level write access is not granted merely to permit those writes. This is a command capability, not a generic field-edit API.
4. `LOS_RuntimeData` checks edit access to the actual parent IDs before system-mode child reads. `scopes` re-reads the stored application unit rather than trusting a supplied sObject's unit. It deliberately ignores child OWD only after parent authorization because lookup children do not inherit parent sharing.
5. `LOS_RuntimeWriter` is `without sharing` solely to persist these authorized children for another user who can edit the parent. It accepts only four runtime object types. Only `LOS_RuntimeService` can create its private write capability. A matching trigger consumes each authorization once; direct writer calls do not bypass guards.
6. Guard triggers reject direct application/audit/TAT insert/update, all deletes and undeletes, and every history update. No administrator/profile exemption, custom-permission bypass, public mutable switch, or `Test.isRunningTest` bypass exists. The Task 01 immutable-history validation rule remains active.
7. Both shipped permission sets grant the runtime custom permission and access to the three remote facade classes. Neither gains Delete, View All or Modify All. Audit and TAT object Create/Edit grants were removed; optional application state fields are read-only. Lending users now have read-only Relationship access; privileged admins maintain relationship context. Native Private OWD and all Task 01 validations remain.
8. Membership/team policies do not grant sharing here. The future Visibility Engine must grant appropriate application and relationship access. Native role hierarchy access remains platform behavior. An authorized parent command does not generally share child records with the user.

API 67 defaults database operations to user mode. Access modes are explicit in production queries/DML, including the deliberate system boundaries. See [Salesforce secure Apex guidance](https://developer.salesforce.com/docs/platform/lwc/guide/apex-security).

Privileged developers can change deployed code/metadata; no Apex package can prevent that. The protections above cover normal runtime and direct-record operations while these components remain enabled. Administrative retention/purge, import/migration and repair pathways are intentionally not supplied.

## Errors and validation

Expected failures use LOS domain exceptions. ValidationException carries the full result list for Apex callers. Remote facades return safe messages through AuraHandledException. Unexpected database/query/locking errors are rolled back and converted to a generic message; raw SOQL, DML messages, stack traces and record values are not returned. No persistent error log containing customer data is created in this phase.

A hook registration is a trusted code change, not caller-selected Apex. Modules must provide safe messages, avoid side effects, and use suitable data access checks. No lending completeness rules are embedded in LifecycleService.

## Task 01 metadata changes

| Change | Purpose |
|---|---|
| Application Type: Initial Stage metadata relationship | Explicit configurable entry stage. Reference New/Renewal/Modification records point to existing Draft. |
| Credit Application: Runtime Version number | Optimistic request token. New applications begin at zero; no default silently migrates historical rows. |
| Stage TAT: Open Context Key unique text | One open interval per application. |
| Stage TAT: Calendar Key text | Snapshot the selected SLA's portable calendar key. |
| TAT Pause: Open Context Key unique text | One open pause per stage interval. |
| LOS_Use_Runtime custom permission | Narrow command capability, assigned by the existing two permission sets. |
| Permission sets and four layouts | Facade class/custom permission access, tighter writes, readable runtime fields and configurable initial stage. |
| Object descriptions and manifest | Reflect implemented behavior and include the complete runtime in the same package directory. |

All original objects, fields, validation rules, stage records, transitions and application types remain. Five custom fields are added, giving 170 total. No new package directory or package namespace assumption is introduced. Reference organization data remains outside package core and is not modified by Task 02.

Existing applications with a null runtime version require a deliberate migration before operations. Existing open TAT/pause records also need populated unique context keys. This task does not silently repair historical state or create artificial audit events.

## Tests and deferred work

Five Apex suites cover creation/context/lineage rejection, all requested forward/rework edges, invalid/inactive transitions, terminal behavior, inactive applications, reason and hook failures, rollback after DML, stale versions including rework round trips, duplicate requests, gross/SLA/pause arithmetic, snapshot policies, actor scope, uniqueness, direct-write guards, CRUD/record access, direct-write guards, and 200-record command batches. A separate test-data class creates isolated fixtures and users; no test relies on existing business records or grants broad permissions to a lending user. Tests read the reference lifecycle metadata and use in-memory overrides for otherwise unconfigured catalogs.

Deferred: LWC/Flow workspace, facilities, financials, collateral, covenants, documents, actual approvals/authorities and booking; assignment TAT execution; regional business calendars and warning classification; Visibility Engine; integration/REST adapters; creation idempotency; migration/repair/retention tools; package namespace registration, install/upgrade testing and concurrent-session/load/security review.

An Approval-type graph edge is a configured lifecycle transition, not an executed Salesforce approval or authorized credit decision. This phase does not populate Approved Date or Booking Date or implement decision authority. Those capabilities must be supplied before treating the runtime as a production approval/booking system.

Stop after Task 02 for architecture review.
