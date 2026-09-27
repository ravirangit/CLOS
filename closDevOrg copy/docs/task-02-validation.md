# Task 02 validation and deployment

Date: 2026-09-27. Target: authenticated development org `closDevOrg`. API version: 67.0.

## Results

- Check-only deployment `0Afbm00000hEmgjCAC`: **Succeeded**, 285/285 components.
- Actual deployment `0Afbm00000hEmwrCAC`: **Succeeded**, 285/285 components, zero errors.
- Deployment completed: `2026-09-27T11:42:14.000Z`.
- Apex tests: **44 passed, zero failures**, both in final validation and actual deployment.
- Aggregate production Apex/trigger coverage: **91.08%**, 1093/1200 executable locations. Every executable component met the specified-test deployment threshold; no coverage warnings.
- Six foundation contract tests passed. Apex/trigger formatting check passed with the pinned Prettier 3.5.3 / prettier-plugin-apex 2.2.6 versions.
- A source-boundary check found no reference stage/application-type literals, client name, or Test.isRunningTest bypass in production Apex; database writes are restricted to LOS_RuntimeWriter.
- Post-deployment verification passed: 18 objects/types, 170 custom fields, 26 Apex classes, five active triggers, nine stages, 13 transitions, three application types, nine Private objects, 18 object-permission rows, and the unchanged 15-unit reference hierarchy.
- Preflight counted zero existing applications. No legacy application migration was needed in this development org. No business records or permission assignments were added by Task 02; Apex test fixtures were isolated and rolled back.

Evidence: [machine-readable test/coverage results](task-02-results.json), [org verification](task-02-org-verification.json), [architecture/security/assumptions](task-02-runtime.md).

## Deployment command

```sh
sf project deploy start --source-dir force-app --target-org closDevOrg --test-level RunSpecifiedTests --tests LOS_ApplicationServiceTest --tests LOS_LifecycleServiceTest --tests LOS_TATServiceTest --tests LOS_ConfigurationServiceTest --tests LOS_SecurityTest --wait 10 --json
```

The check-only command used the same arguments plus `--dry-run`. Output was captured to temporary JSON files; no credentials are recorded in these reports.

## Test suites

| Suite | Passed |
|---|---:|
| LOS_ApplicationServiceTest | 7 |
| LOS_ConfigurationServiceTest | 6 |
| LOS_LifecycleServiceTest | 17 |
| LOS_SecurityTest | 5 |
| LOS_TATServiceTest | 9 |

`LOS_TestData` is a separate @IsTest fixture/helper class. Fixtures use the standard Minimum Access - Salesforce profile and explicit setup DML, while test actors receive only the package lending permission set (or narrowly constructed negative-test permissions). There is no SeeAllData dependency or broad test-user permission grant.

## Production classes created

- `LOS_ApplicationDTO`
- `LOS_ApplicationService`
- `LOS_BusinessTimeService`
- `LOS_ConfigurationException`
- `LOS_ConfigurationService`
- `LOS_Exception`
- `LOS_LifecycleException`
- `LOS_LifecycleService`
- `LOS_RecordGuard`
- `LOS_RuntimeData`
- `LOS_RuntimeService`
- `LOS_RuntimeWriter`
- `LOS_Security`
- `LOS_SecurityException`
- `LOS_TATDTO`
- `LOS_TATException`
- `LOS_TATService`
- `LOS_TransitionDTO`
- `LOS_ValidationException`
- `LOS_ValidationService`

## Coverage by component

| Component | Covered / total | Coverage |
|---|---:|---:|
| LOS_ApplicationDTO | 15 / 15 | 100.00% |
| LOS_ApplicationGuard | 5 / 5 | 100.00% |
| LOS_ApplicationService | 14 / 14 | 100.00% |
| LOS_AssignmentTATGuard | 5 / 5 | 100.00% |
| LOS_BusinessTimeService | 18 / 18 | 100.00% |
| LOS_ConfigurationException | 0 / 0 | No executable locations |
| LOS_ConfigurationService | 342 / 363 | 94.21% |
| LOS_Exception | 6 / 7 | 85.71% |
| LOS_HistoryGuard | 5 / 5 | 100.00% |
| LOS_LifecycleException | 0 / 0 | No executable locations |
| LOS_LifecycleService | 33 / 33 | 100.00% |
| LOS_PauseGuard | 5 / 5 | 100.00% |
| LOS_RecordGuard | 8 / 8 | 100.00% |
| LOS_RuntimeData | 67 / 76 | 88.16% |
| LOS_RuntimeService | 337 / 374 | 90.11% |
| LOS_RuntimeWriter | 13 / 13 | 100.00% |
| LOS_Security | 33 / 37 | 89.19% |
| LOS_SecurityException | 0 / 0 | No executable locations |
| LOS_StageTATGuard | 5 / 5 | 100.00% |
| LOS_TATDTO | 11 / 11 | 100.00% |
| LOS_TATException | 0 / 0 | No executable locations |
| LOS_TATService | 101 / 117 | 86.32% |
| LOS_TransitionDTO | 11 / 11 | 100.00% |
| LOS_ValidationException | 1 / 1 | 100.00% |
| LOS_ValidationService | 58 / 77 | 75.32% |

## Task 01 metadata changes

- Added five fields: Application Type Initial Stage; Credit Application Runtime Version; Stage TAT Open Context Key and Calendar Key; TAT Pause Open Context Key.
- Added LOS_Use_Runtime custom permission; updated the two existing permission sets with facade access and narrowed direct-write grants. No Delete, View All or Modify All was added.
- Updated the three application-type seeds to reference the existing Draft stage. All lifecycle/rework edges remain unchanged.
- Updated four layouts and four object/type descriptions, the explicit manifest, schema inventory/data dictionary, README and validation scripts.
- Added five guard triggers; all 20 Task 01 validation rules remain active. Original fields/objects/configuration records were retained. No reference fixtures were changed.

## Corrections during validation

The first production compile passed. Initial test execution exposed API 67 user-mode defaults in fixture DML and internal reads, plus read-only Custom Metadata relationship setters in in-memory fixtures. Execution modes were made explicit and test fixtures now deserialize relationships without metadata DML. No user permissions were broadened.

A cross-user sharing test then showed that a with-sharing coordinator could not update another creator’s private TAT child. The restricted without-sharing writer now performs only authorized, guarded writes, and parent authorization is explicitly rechecked for child reads. That test passed after the correction.

The final expanded test run found a string-versus-enum assertion error when checking a duplicate-key DML status. The assertion was corrected; both database uniqueness tests passed. No failed requirement or test was removed.

## Warnings and assumptions

- This is a development-org deployment of a single package source unit, not a released managed package version. Namespace registration, subscriber install/upgrade validation and security review remain release work.
- Business Minutes and regional calendars remain unimplemented. Calendar-key SLAs report Pending Calendar; other SLA results are explicitly preliminary gross-time results.
- Approval-type graph transitions do not execute approval decisions/authorities or set Approved Date. Booking and the other excluded lending modules remain deferred.
- Existing applications elsewhere with null runtime versions or old open timing records need deliberate migration. No maintenance/purge/write-bypass API is provided.
- Locking/version/uniqueness behavior is covered with sequential conflict tests and database constraints; simultaneous-session and load testing were not performed.
- Runtime authorization currently requires the custom permission and native parent edit access. Persona-based action authorization and organizational sharing remain future engines.
- Renewal/Modification enforce the existing baseline-required configuration. A supplied baseline must already be approved and accessible for the same relationship; automatic latest-approved selection is deferred.
- Salesforce CLI reported an available update. The installed CLI successfully validated, tested and deployed the task, so no CLI upgrade was performed.

## Git/file summary

See [exact task file changes](task-02-files.md). This project was already untracked in the parent Git repository before Task 02. The task summary compares file hashes captured at the start of Task 02; it is not a claimed tracked Git diff. No files were staged or committed and no original files were deleted.

Task 02 stops here. No LWC, Flow, facilities, financials, collateral, covenants, documents, approval process or booking integration was built.
