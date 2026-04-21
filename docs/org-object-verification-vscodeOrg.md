# Org object verification — `vscodeOrg`

CLI snapshot against the Salesforce org pinned in this repo (`.sf/config.json` → `target-org: vscodeOrg`). Re-run the queries below after enabling new products or switching orgs.

## Org identity (non-secret)

| Field | Value |
|--------|--------|
| **CLI alias** | `vscodeOrg` |
| **Username** | `lfontillas.cursortest@salesforce.com` |
| **Org Id** | `00DHu00000yvSgTMAU` |
| **API version** | 66.0 |
| **Edition** | Enterprise Edition |
| **Sandbox** | No (`IsSandbox = false`) |
| **Trial expiration** | 2026-10-14 (from `Organization`) |
| **Org name** | Salesforce Trial Org Request & Manage |

## ISANS canvas objects — existence check

Exact-name checks use `EntityDefinition` unless noted.

| Planned API name | Present in `vscodeOrg`? | Notes |
|------------------|-------------------------|--------|
| `Account` | Yes | |
| `Case` | Yes | Confirm Case → Person Account for ISANS in Schema Builder. |
| `Program` | **No** | Core NPC Program Management container not present. |
| `Benefit` | Yes | Org also has **Benefit Assignment / Benefit Type** style objects; confirm this is **NPC Program Management** “Benefit” vs another Cloud’s object before designing flows. |
| `BenefitSchedule` | **No** | |
| `BenefitSession` | **No** | |
| `ProgramEnrollment` | **No** | `LIKE '%ProgramEnrollment%'` returns **Care Program** enrollment card types only, not `ProgramEnrollment`. |
| `BenefitEnrollment` | **No** | No exact-name row in `EntityDefinition`. |
| `EnrollmentEligibilityCriteria` | Yes | |
| `ProgramEnrlEligibilityCrit` | **No** | No `LIKE '%ProgramEnrl%'` rows. |
| `AssessmentQuestion` | Yes | |
| `AssessmentResponse` (plan / some docs) | **No** (exact) | Org has **`AssessmentQuestionResponse`** — likely the response store for this Discovery-style stack; confirm in Schema Builder and adjust spec/Apex. |
| `AssessmentQuestionSourceDocument` | **No** (exact) | No `EntityDefinition` rows matching `%SourceDocument%` in a quick scan; may use a different authority object or not be provisioned in this trial. |
| `Benefit_Enrollment_Eligibility_Criteria__c` | **No** | Custom — to be created in phase 2 if still required by design. |
| `Eligibility_Question_Mapping__c` | **No** | Custom — same as above. |
| `Delivery_Site__c` | **No** | Custom — same as above. |
| `Funder_Seat_Allocation__c` | **No** | Custom — same as above. |

## Interpretation

**`vscodeOrg` does not currently match the Nonprofit Cloud Program / Benefit / session / enrollment data model** described in [ISANS-coordinated-enrollment-plan.md](ISANS-coordinated-enrollment-plan.md). Several **standard** program-enrollment types are missing; all **ISANS-specific custom** objects are absent (expected until you build them).

**Practical options**

1. **Use a different target org** — NPC (or equivalent) org with **Program Management** (or the exact product bundle your ISANS design assumes), then re-run this verification and replace this file or add `org-object-verification-<alias>.md`.
2. **Stay on this org** — Treat the canvas as a **logical** design and remap to what exists (e.g. Health Cloud **Care Program** patterns), which is a **major** scope and spec change — not a rename-only exercise.

## Commands to reproduce

Pin (already set in this repo):

```bash
sf config set target-org vscodeOrg
```

Org row:

```bash
sf data query --query "SELECT Name, OrganizationType, InstanceName, IsSandbox, TrialExpirationDate FROM Organization LIMIT 1" --target-org vscodeOrg
```

Planned standard objects (batch):

```bash
sf data query --query "SELECT QualifiedApiName, Label FROM EntityDefinition WHERE QualifiedApiName IN ('Program','Benefit','BenefitSchedule','BenefitSession','ProgramEnrollment','BenefitEnrollment','EnrollmentEligibilityCriteria','ProgramEnrlEligibilityCrit','AssessmentQuestion','AssessmentQuestionSourceDocument','AssessmentResponse','Case','Account')" --target-org vscodeOrg
```

Custom objects from the plan (one at a time if needed):

```bash
sf data query --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName = 'Delivery_Site__c'" --target-org vscodeOrg
```

Discovery-style assessment objects (sample):

```bash
sf data query --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName LIKE 'Assessment%'" --target-org vscodeOrg
```
