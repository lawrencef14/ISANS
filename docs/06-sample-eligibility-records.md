# ISANS — Sample eligibility records (on-org)

This documents the **sample** `EnrollmentEligibilityCriteria` and `ProgramEnrlEligibilityCrit` pattern from the coordinated-enrollment design ([03-eligibility-engine.md](03-eligibility-engine.md)).

## What was created

| Object | Purpose |
|--------|---------|
| `EnrollmentEligibilityCriteria` | One row named **`ISANS Sample - LINC age gate (demo rule)`** with `Status = Active`, a short `Description`, and **`ExecutionProcedureId`** pointing at the org’s existing **`Repair Eligibility`** Expression Set. |
| `ProgramEnrlEligibilityCrit` | Junction linking that criteria row to **`ISANS - LINC`** with **`IsRequired = true`**. |

The **`Repair Eligibility`** Expression Set is **not** ISANS business logic; it is a small org demo asset used only so the `ExecutionProcedureId` lookup is populated and UI/API paths can be exercised. In Milestone 1, create an ISANS-specific Expression Set and update `ExecutionProcedureId` (or create a new `EnrollmentEligibilityCriteria` and repoint the junction).

## Reproduce in another org

From the repo root:

```bash
chmod +x scripts/seed-isans-eligibility-sample.sh   # once
./scripts/seed-isans-eligibility-sample.sh
# or:
./scripts/seed-isans-eligibility-sample.sh --target-org yourAlias
```

Prerequisites:

1. `ISANS - LINC` program exists (run `./scripts/seed-isans-programs.sh` first).
2. An `ExpressionSet` named **`Repair Eligibility`** exists (this demo org includes it). If your org uses a different name, edit `EXPR_NAME` in [`scripts/seed-isans-eligibility-sample.sh`](../scripts/seed-isans-eligibility-sample.sh).

## Verify

```bash
sf data query --query "SELECT Id, Name, Status, ExecutionProcedure.Name FROM EnrollmentEligibilityCriteria WHERE Name = 'ISANS Sample - LINC age gate (demo rule)'" --target-org vscodeOrg

sf data query --query "SELECT Id, Program.Name, EnrollmentEligibilityCrit.Name, IsRequired FROM ProgramEnrlEligibilityCrit WHERE EnrollmentEligibilityCrit.Name = 'ISANS Sample - LINC age gate (demo rule)'" --target-org vscodeOrg
```

## Remove (optional)

Delete the junction first, then the criteria (order may matter if other references exist):

```bash
# look up Ids, then:
sf data delete record --sobject ProgramEnrlEligibilityCrit --record-id <PEC_ID> --target-org vscodeOrg
sf data delete record --sobject EnrollmentEligibilityCriteria --record-id <EEC_ID> --target-org vscodeOrg
```
