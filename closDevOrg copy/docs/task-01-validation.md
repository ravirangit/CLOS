# Task 01 validation and deployment evidence

Date: 2026-09-27. Target alias: `closDevOrg` (authenticated default Developer Edition org). Source/API version: 67.0. No production org or unrelated sandbox was targeted.

## Final results

| Operation | Job ID | Result |
|---|---|---|
| Check-only core deployment | `0Afbm00000hEcFxCAK` | Succeeded, 248/248 components, 0 errors; completed 10:36:46 UTC |
| Core deployment | `0Afbm00000hEWvKCAW` | Succeeded, 248/248 components, 0 errors; completed 10:38:40 UTC |
| Separate reference taxonomy deployment | `0Afbm00000hEcr3CAC` | Succeeded, 4/4 components, 0 errors; completed 10:38:59 UTC |
| Reference hierarchy import | Composite Tree API | Succeeded, 15 records, including 4 sample branches |
| Local contract suite | Python unittest | 6 tests passed |
| Read-only deployed-org verification | CLI describe / SOQL / Tooling API | Passed at 10:40:58 UTC |

Apex/LWC test execution: not applicable; no Apex classes, triggers or LWC bundles exist in the Task 01 source. Salesforce deployment used `NoTestRun` in the development org and reports zero Apex tests executed. The Python checks are metadata contract tests, not Apex runtime/security tests.

## Commands used

```sh
python3 scripts/validation/validate_foundation.py
sf project deploy start --source-dir force-app --target-org closDevOrg --dry-run --test-level NoTestRun --wait 10 --json
sf project deploy start --source-dir force-app --target-org closDevOrg --test-level NoTestRun --wait 10 --json
sf project deploy start --source-dir reference-data/metadata --target-org closDevOrg --test-level NoTestRun --wait 10 --json
sf org assign permset --name LOS_Platform_Admin --target-org closDevOrg --json
sf data import tree --files reference-data/organization-tree.json --target-org closDevOrg --json
python3 scripts/validation/verify_deployed.py --target-org closDevOrg --expect-reference-data --output docs/org-verification.json
```

Deployment command JSON was redirected to temporary files during execution; this document records the job IDs and results without credentials. The initial org discovery needed macOS Keychain access outside the execution sandbox. The authenticated development user received `LOS_Platform_Admin` explicitly to satisfy the sample import's field permissions; no other users received permission assignments.

## Verified in Salesforce

The reproducible verifier describes every object/type and checks every source custom field exists. It queries the stage codes/order/active/terminal flags, all directed transitions with reason/validation flags, and application types. Tooling API EntityDefinition confirms Private internal and external sharing on all nine core objects. ObjectPermissions confirms all 18 permission rows across the two sets and no Delete, View All or Modify All grants. Lending users cannot write membership/team/history/TAT data. Organization queries compare all 15 fixture codes, unit types and parents against the source fixture inventory.

See [machine-readable verification](org-verification.json) and [verification script](../scripts/validation/verify_deployed.py). No org credentials or access tokens are persisted in these artifacts.

## Metadata inventory

| Kind | Count |
|---|---:|
| Custom Metadata Types | 9 |
| Core custom objects | 9 |
| Configuration fields | 81 |
| Core custom fields | 84 |
| Validation rules | 20 |
| Core configuration records | 25 |
| Layouts | 18 |
| Permission sets | 2 |
| Total core metadata components | 248 |

The 25 core configuration records comprise nine stages, 13 transitions (seven Forward, one Approval, five Rework), and three application types. Reference data is separate: four organization-type metadata records and 15 organization units. The single package directory remains `force-app`.

Core custom field counts exclude standard fields such as Name, OwnerId, CreatedDate and LastModifiedDate:

| Core object | Custom fields |
|---|---:|
| Organization Unit | 6 |
| User Org Assignment | 7 |
| Relationship | 9 |
| Credit Application | 19 |
| Application Team | 7 |
| Lifecycle History | 9 |
| Stage TAT | 12 |
| Assignment TAT | 8 |
| TAT Pause | 7 |

## Validation failures corrected

Earlier check-only jobs failed before the successful final validation. No requirement was discarded to obtain success. Corrections were:

- Serialize subscriber control using `fieldManageability`.
- Enforce required User lookups through four validation rules and required layout fields. Salesforce rejects restrict-delete User lookups and also rejects native required lookups without that constraint; the User fields remain mandatory at save time.
- Include standard Custom Metadata layout fields `IsProtected` (Edit) and `NamespacePrefix` (Readonly).
- Use stage record developer names as Custom Metadata relationship values, without duplicating the type prefix.

The first short CLI wait timed out while its check-only job continued; its final failure was retrieved before correction. One validation was already in flight when the remaining layout/reference fixes were applied; the final validation and actual deployment used the corrected source.

The first fixture import failed field-level security. Assigning the supplied admin permission set to the development user resolved the problem; the subsequent import inserted exactly 15 units and verification confirmed their hierarchy. No object/field permission requirement was removed.

The CLI emitted an update-available notice (installed 2.126.4, advertised 2.151.7); updating the CLI was outside task scope and unnecessary for successful validation/deployment.

## Architectural limits and assumptions

- Source API names use `LOS_`, not reserved `LOS__`. The package namespace remains unregistered/empty and separate from this logical prefix.
- A managed package version was not created or installed. Namespace registration, package creation, install/upgrade validation and security review remain release work. All product metadata was validated and deployed together from one package directory.
- History updates are blocked; supplied permission sets deny deletes. Absolute delete prevention against administrators/other grants requires later enforcement and is not claimed here.
- Application organization values are stored snapshots and do not follow later Relationship edits. Automatic capture and approved-record write protection are deferred.
- Queue keys, type/persona/stage/access codes, longer hierarchy/lineage cycles and approved-application eligibility need later service validation. No execution or sharing engine exists yet.
- Monitoring is the reference terminal origination stage; its TAT flag is disabled. Renewal and Modification have editable baseline-required flags. No SLA target, authority, persona or workspace section is invented.

## Files and Git summary

Task changes: 262 new artifact files, plus updates to existing `README.md` and `manifest/package.xml`. New files comprise 248 core metadata XML files, seven reference fixture/documentation files, two validation scripts and five documentation/report files. See [complete file inventory](task-01-files.md) and [data dictionary](data-dictionary.md).

The Git root is the parent `CLOS` directory. This entire `closDevOrg` project was already untracked when work began; therefore a normal `git diff --stat` has no tracked baseline for these changes. No files were staged or committed, and unrelated parent-repository content was not changed. The counts above describe this task's file changes rather than claiming a tracked Git diff.

Task 01 is complete for architecture review. No LifecycleService, triggers, Flows or LWC development was started.
