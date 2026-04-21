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

## Troubleshooting: Lightning “ORG_ADMIN_LOCKED” on `ProgramEnrlEligibilityCrit`

If opening **Program Enrollment Eligibility Criteria** shows a generic error and the technical detail includes **`ORG_ADMIN_LOCKED: admin operation already in progress`**, that is a **temporary Salesforce platform lock** on the org (not a bad field value on the sample row). Common causes:

- A **deployment or validation** is running (**Setup → Deployment Status**).
- **Metadata retrieve/deploy**, change sets, or package installs in another tab or by another admin.
- **Sandbox refresh**, release update, or background **maintenance** Salesforce is applying.

**What to do**

1. Wait **5–15 minutes** and open the record again (often enough).
2. Check **Setup → Deployment Status** and wait until nothing is *In Progress*.
3. Ask whether anyone else is **deploying or running bulk admin** work in the same org.
4. Try a **hard refresh** or another browser session after the wait.
5. If it persists for **hours**, open a case with Salesforce and include the **Error ID** from the message.

You can still **confirm the data** with SOQL or the CLI while the UI is flaky:

```bash
sf data query --query "SELECT Id, Program.Name, EnrollmentEligibilityCrit.Name, IsRequired FROM ProgramEnrlEligibilityCrit WHERE Id = '20bHu0000000049IAA'" --target-org vscodeOrg
```

(Replace the Id if your junction Id differs.)

## Remove (optional)

Delete the junction first, then the criteria (order may matter if other references exist):

```bash
# look up Ids, then:
sf data delete record --sobject ProgramEnrlEligibilityCrit --record-id <PEC_ID> --target-org vscodeOrg
sf data delete record --sobject EnrollmentEligibilityCriteria --record-id <EEC_ID> --target-org vscodeOrg
```
