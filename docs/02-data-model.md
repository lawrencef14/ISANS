# ISANS — Data model (verified against `vscodeOrg`)

Authoritative on-org facts used by the rest of the spec. All checks performed via **Tooling API** against instance `storm-f2e38d8c037830.my.salesforce.com`. Reproduce commands are in [org-object-verification-vscodeOrg.md](org-object-verification-vscodeOrg.md).

## 1. Objects confirmed present

| API name | Key prefix | Role in ISANS design |
|----------|-----------|-----------------------|
| `Program` | `11W` | Top-level program container (e.g., LINC). |
| `Benefit` | `0ji` | Specific offering within a program (e.g., LINC Basics). Lookup to `Program` via `ProgramId`. |
| `BenefitSchedule` | `1Bs` | Recurring cadence linked MD to `Benefit`. |
| `BenefitSession` | `2Bs` | Individual occurrences linked MD to `BenefitSchedule`. |
| `ProgramEnrollment` | `11X` | Client enrollment record. Has **both** `AccountId` and `ContactId` — either wiring works. |
| `ProgramEnrlEligibilityCrit` | `20b` | Junction: Program ↔ EnrollmentEligibilityCriteria. |
| `EnrollmentEligibilityCriteria` | — | **Rule definition** — links to an Expression Set (see §3). |
| `AssessmentQuestion`, `AssessmentQuestionResponse` | — | Discovery Framework Q&A pair. Use `AssessmentQuestionResponse` wherever the canvas says `AssessmentResponse`. |

## 2. Objects missing vs canvas — decisions required

| Planned in canvas | Reality on `vscodeOrg` | Recommended decision |
|--------------------|-------------------------|------------------------|
| `BenefitEnrollment` | **Not present.** Benefit-level participation is already modeled via attendance / disbursement rollups (see §4). | Do **not** create a custom `BenefitEnrollment__c`. Use the existing attendance/disbursement pattern. (Pending confirmation.) |
| `AssessmentResponse` | Org uses `AssessmentQuestionResponse`. | Rename in Apex, Flow, docs. |
| `AssessmentQuestionSourceDocument` | Not present. | Add custom `Assessment_Source_Document__c` referenced from `EnrollmentEligibilityCriteria` **or** a custom field on `ProgramEnrlEligibilityCrit` (`Source_Document__c`). Pending decision. |
| `Benefit_Enrollment_Eligibility_Criteria__c` | Not present. | Create custom object (plan §phase 2). |
| `Eligibility_Question_Mapping__c` | Not present. | Create custom object (plan §phase 2). |
| `Delivery_Site__c` | Not present. | Create custom object (plan §phase 2). |
| `Funder_Seat_Allocation__c` | Not present. | Create custom object (plan §phase 2). |

## 3. Critical finding — eligibility uses **Expression Set**, not row-based comparison

The canvas assumed `EnrollmentEligibilityCriteria` carries `Logic_Operator__c`, `Target_Value__c`, `Data_Type__c` and that the Apex waterfall would compare those values to assessment responses.

**Actual fields on `EnrollmentEligibilityCriteria`:**

| Field | Type |
|--------|------|
| `Name` | Text(255) |
| `Description` | Long Text |
| `Status` | Picklist |
| **`ExecutionProcedureId`** | **Lookup(Expression Set)** |
| `IsLocked`, `MayEdit` | System |
| `PublishedBy`, `SourceSystem`, `SourceSystemIdentifier` | Provenance |
| `CurrencyIsoCode` | Picklist |

**Implication:** NPC evaluates eligibility by **invoking an Expression Set** (Business Rules Engine). The ISANS engine does **not** need a custom AND/OR-group row evaluator — it needs to (a) run the Expression Set referenced by each criterion's `ExecutionProcedureId` with the client record as input, and (b) aggregate results.

**What must change in the spec**
- Replace the “Logic_Operator__c / Target_Value__c / Data_Type__c / Logic_Group__c” section with a call-Expression-Set flow (see **[03-eligibility-engine.md](03-eligibility-engine.md)** when written).
- `Eligibility_Question_Mapping__c` may become unnecessary if each rule is already self-contained in an Expression Set. Keep only if multiple mappings of questions to the same rule are needed and cannot be expressed in the Expression Set's input resolution.
- `ProgramEnrlEligibilityCrit` **has no `Failure_Message__c` or `Source_Document__c` out of the box.** Either add custom fields to it, or surface failure messages from the Expression Set result structure if available.

## 4. Benefit attendance / disbursement model (already on org)

`Benefit`, `BenefitSession`, and `ProgramEnrollment` all carry attendance / disbursement counters, indicating the installed package (there are `NGO_CaseMan_*` custom formula/rollup fields) already models "participation" as **attendance** per `BenefitSession`, rolled up to `Benefit` and `ProgramEnrollment`.

Notable custom fields already present:

| Object | Field | Type |
|--------|--------|------|
| `Benefit` | `NGO_CaseMan_isSessionBenefit__c` | Checkbox |
| `Benefit` | `NGO_CaseMan_Total_Enrolled__c` | Roll-Up (Benefit Schedule) |
| `Benefit` | `NGO_CaseMan_Total_Attended__c` | Roll-Up |
| `Benefit` | `NGO_CaseMan_Total_Unattended__c` | Roll-Up |
| `Benefit` | `NGO_CaseMan_Attendance_Rate__c` | Formula |
| `BenefitSession` | `NGO_CaseMan_Total_Enrolled__c`, `_Total_Attended__c`, `_Total_Unattended__c`, `_Attendance_Rate__c`, `_Attendance_Summary__c` | Roll-ups/Formulas |
| `ProgramEnrollment` | `Number_of_Absent_Benefit_Disbursements__c`, `Number_of_Attended_Benefit_Disbursements__c`, `External_Id__c` | NGO extensions |

**Implication:** A client “enrolling” in a benefit is expressed as `ProgramEnrollment` + per-session attendance rows — not a separate `BenefitEnrollment` object. Seat assignment and funder tracking from the canvas must be modeled as custom fields on `ProgramEnrollment` (or on a lighter custom join) rather than a new top-level object.

## 5. Program ↔ Client wiring

- `ProgramEnrollment.AccountId` (Lookup to Account) and `ProgramEnrollment.ContactId` (Lookup to Contact) both exist.
- `Program` itself has **no** client lookup — clients are only linked through `ProgramEnrollment`.
- **Person Accounts: ENABLED.** `Account.IsPersonAccount = true` on 6,573 of 6,752 Accounts on `vscodeOrg`; the remaining 179 are business Accounts.
- **Observed convention in existing data:** all 3,004 `ProgramEnrollment` records use `AccountId` (pointing to a Person Account), and **zero** use `ContactId`. We MUST honor this pattern — the client identity is the **Person Account**.
- **Case → client decision (resolved):** wire `Case.AccountId` to the Person Account. `Case.ContactId` can be populated (Person Account auto-creates a linked Contact) but the Account is canonical.
- Practical consequence: no new "ISANS client" wrapper object is needed. An ISANS client = a Person Account. Any client-level extension fields go on Account (or a custom `ISANS_Client_Profile__c` with a Master-Detail to Account).

## 6. Relationship map (verified)

```mermaid
flowchart TB
  Program[Program 11W]
  Benefit[Benefit 0ji]
  BenefitSchedule[BenefitSchedule 1Bs]
  BenefitSession[BenefitSession 2Bs]
  ProgramEnrollment[ProgramEnrollment 11X]
  EnrollmentEligibilityCriteria[EnrollmentEligibilityCriteria]
  ProgramEnrlEligibilityCrit[ProgramEnrlEligibilityCrit 20b]
  ExpressionSet[Expression Set]
  Account[Account]
  Contact[Contact]

  Benefit -->|ProgramId Lookup| Program
  BenefitSchedule -->|BenefitId MD| Benefit
  BenefitSession -->|BenefitScheduleId MD| BenefitSchedule
  ProgramEnrollment -->|ProgramId MD| Program
  ProgramEnrollment -->|AccountId| Account
  ProgramEnrollment -->|ContactId| Contact
  ProgramEnrlEligibilityCrit -->|ProgramId MD| Program
  ProgramEnrlEligibilityCrit -->|EnrollmentEligibilityCritId Lookup| EnrollmentEligibilityCriteria
  EnrollmentEligibilityCriteria -->|ExecutionProcedureId Lookup| ExpressionSet
```

## 7. Open questions — status

| # | Question | Status | Answer / next step |
|---|----------|--------|---------------------|
| 1 | Case → client wiring | **Resolved** | Person Accounts ENABLED (6,573 Person, 179 business). Existing 3,004 enrollments use `ProgramEnrollment.AccountId` exclusively. Wire `Case.AccountId` to the Person Account. |
| 2 | Benefit-level enrollment model | Open | No `ProgramEnrollment` or `Benefit` records exist yet on `vscodeOrg`. Attendance/disbursement pattern from §4 is viable; still need user call on whether to add a dedicated join for seat+funder. |
| 3 | Source-document authority | Open | Decision deferred — proposing `Assessment_Source_Document__c` (master) + `Source_Document__c` lookup on `ProgramEnrlEligibilityCrit` in [03-eligibility-engine.md](03-eligibility-engine.md). |
| 4 | Expression Set input contract | Open | The 2 ExpressionSet records on org (`Repair Eligibility`, `Cirrus - Commerce Default Pricing Procedure`) are demo assets, not ISANS rules. Input contract must be **defined by us** when we author the first ISANS rule. See [03-eligibility-engine.md](03-eligibility-engine.md). |
| 5 | `NGO_CaseMan_*` package | **Resolved** | Fields have `NamespacePrefix = null` — they are **unpackaged, org-local** custom fields, not from a managed package. No upgrade/deploy risk; we own them. |
| 6 | `CGC_Program__c` | **Resolved** | Unrelated demo object. Fields include `Completed_Exercises__c`, `Completed_Milestones__c`, `Milestone_Icon_Type__c`, rollup of "Demo Section". Safe to ignore. |
| 7 | Data API access to NPC objects | **Resolved** | Root cause was missing **Permission Set Licenses**, not object-level Read. Fix deployed in this repo as [`force-app/main/default/permissionsets/ISANS_Case_Worker.permissionset-meta.xml`](../force-app/main/default/permissionsets/ISANS_Case_Worker.permissionset-meta.xml). Required PSLs assigned to the CLI user: `BenefitManagementPermissionSetLicense`, `IndustriesAssessmentPsl`, `ProgramManagementPsl`, `Salesforce_org_NonprofitCloudCaseManagementPsl`. Required standard permission sets assigned: `AdvancedProgramManagement`, `BenefitManagementPermissionSetLicense`, `IndustriesAssessmentPermissionSet`. Verified with `SELECT COUNT() FROM Program` → 5 records. |

## 8. Existing data on `vscodeOrg` (revealed after the PSL fix)

The org is not empty — it is a generic NPC demo with **pre-populated records** we must design alongside (or consciously displace):

| Entity | Count | Notes |
|--------|-------|-------|
| `Program` | 5 | `Community Nutrition`, `Default Benefits Program`, `Financial IQ`, `Food Access`, `Job Placement`. None are ISANS-specific (no LINC, no settlement). |
| `Benefit` | 22 | e.g. `Food Distribution`, `Financial Foundations`, `Interview Prep`, `Budgeting 1:1 Coaching`. |
| `BenefitSchedule` | 5 | |
| `BenefitSession` | 106 | |
| `ProgramEnrollment` | 3,004 | ~1,001 enrollments each in Financial IQ / Food Access / Job Placement, 1 in Community Nutrition. All wired to `AccountId` (Person Accounts). |
| `EnrollmentEligibilityCriteria` | 0 | No rules configured — greenfield for §3. |
| `ProgramEnrlEligibilityCrit` | 0 | No criteria linked to programs yet. |
| `AssessmentQuestion` | 39 | Existing Discovery Framework library. Needs catalog review before ISANS questions are added. |
| `AssessmentQuestionResponse` | 3 | Minimal sample responses. |
| `Account` (Person) | 6,573 | Existing client pool we can reuse. |

**Decision (Milestone-1 footprint):** **(A) Add alongside** — new ISANS programs (e.g., LINC, settlement services) are created in addition to the five generic demo programs. Existing enrollments, benefits, and sessions are left intact so we can validate coexistence and attendance rollups without destructive cleanup.

**Seeded ISANS footprint:** repeatable CLI seed in [`scripts/seed-isans-programs.sh`](../scripts/seed-isans-programs.sh). It inserts three programs (`ISANS - LINC`, `ISANS - Settlement Services`, `ISANS - Employment & Career`), nine benefits, nine schedules, and twelve sessions (Feb–Mar 2026 placeholder datetimes). Idempotent on `Name LIKE 'ISANS -%'` unless `--force`. If you delete those programs later, remove any `ProgramRecommendationRule` children first — the org may auto-create them and block `Program` delete.
