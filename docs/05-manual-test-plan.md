# ISANS — Manual test plan (after automated verify)

Run the automated script first (works from any directory; defaults to org alias `vscodeOrg` or `SFDX_DEFAULTUSERNAME`):

```bash
./scripts/verify-isans-setup.sh
# optional:
./scripts/verify-isans-setup.sh --target-org vscodeOrg
```

Requires **Salesforce CLI**, **jq**, and **python3**.

When it prints **All automated checks passed**, use this checklist in the Salesforce UI.

## 1. Programs

1. Log in to the same org the CLI uses (`sf org display`).
2. Open the **App Launcher** and search for **Programs** (or go to the Nonprofit / Program Management app your org exposes).
3. Confirm you see **three** programs whose names start with **`ISANS -`**:
   - `ISANS - LINC`
   - `ISANS - Settlement Services`
   - `ISANS - Employment & Career`
4. Open **`ISANS - LINC`** and confirm related **Benefits** list shows at least three benefits (e.g. LINC Basics, LINC Plus, Conversation Circles).

## 2. Benefits and sessions

1. From a benefit under an ISANS program, open **Related** (or the benefit record) and locate **Benefit Schedules**.
2. Open one schedule and confirm **Benefit Sessions** exist with **Status** = `Scheduled` and plausible **Start** / **End** datetimes (seed uses placeholder dates in 2026).

## 3. Coexistence with generic demo

1. In the Programs list, confirm the **original five** generic programs still exist (e.g. Community Nutrition, Financial IQ) — add-alongside footprint.
2. Optionally open **Program Enrollment** for a generic program vs an ISANS program to confirm both program families are visible (no accidental replacement).

## 4. Client / enrollment pattern (Person Account)

1. Open **Object Manager → Program Enrollment** or use a list view.
2. Sample a few **Program Enrollment** records: confirm **Account** is populated (Person Account model for this org).
3. Open one linked **Account** and confirm **Person Account** is checked (or equivalent Person Account UI).

## 5. Eligibility (sample row + Expression Set plumbing)

A **sample** criteria row and junction may already exist (created in-org or via `./scripts/seed-isans-eligibility-sample.sh`). Details: [06-sample-eligibility-records.md](06-sample-eligibility-records.md).

1. **Setup → Object Manager → Enrollment Eligibility Criteria** (or App Launcher / list views if exposed) — open **`ISANS Sample - LINC age gate (demo rule)`** and confirm **`Execution Procedure`** points at **`Repair Eligibility`** (demo Expression Set only).
2. Open **`Program Enrollment Eligibility Criteria`** (API `ProgramEnrlEligibilityCrit`) for **`ISANS - LINC`** and confirm it links to that criteria row with **Required** checked if your layout shows `IsRequired`.
3. When `EligibilityService` Apex exists, add Apex tests and extend `./scripts/verify-isans-setup.sh` if you add new invariants.

## 6. GitHub (CI optional)

1. Confirm `main` on GitHub matches local: `git fetch origin && git log -1 --oneline origin/main`.
2. If you add CI later, wire `sf project deploy validate` or scratch-org validation to this repo.
