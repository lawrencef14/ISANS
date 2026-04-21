# Org object verification — `vscodeOrg`

CLI snapshot against the Salesforce org pinned in this repo (`.sf/config.json` → `target-org: vscodeOrg`). Instance URL `https://storm-f2e38d8c037830.my.salesforce.com`. Re-run the queries below after enabling new products, updating permission sets, or switching orgs.

## Org identity (non-secret)

| Field | Value |
|--------|--------|
| **CLI alias** | `vscodeOrg` |
| **Username** | `lfontillas.cursortest@salesforce.com` |
| **Org Id** | `00DHu00000yvSgTMAU` |
| **API version** | 66.0 |
| **Edition** | Enterprise Edition |
| **Sandbox** | No |
| **Org name** | Salesforce Trial Org Request & Manage |

## Important — Tooling API required to see NPC objects

Regular `sf data query` on `EntityDefinition` **does not return** the Nonprofit Cloud entities in this org even after the permission set update, but **`sf data query --use-tooling-api`** does. Use the `--use-tooling-api` flag for all NPC entity checks below.

## ISANS canvas objects — existence check (post permission-set update)

| Planned API name | Present? | Key prefix | Notes |
|------------------|----------|------------|--------|
| `Account` | Yes | — | |
| `Case` | Yes | — | Confirm Case → Person Account for ISANS in Schema Builder. |
| `Program` | **Yes** | `11W` | NPC Program container present. |
| `Benefit` | **Yes** | `0ji` | |
| `BenefitSchedule` | **Yes** | `1Bs` | |
| `BenefitSession` | **Yes** | `2Bs` | |
| `ProgramEnrollment` | **Yes** | `11X` | |
| `ProgramEnrlEligibilityCrit` | **Yes** | `20b` | “The Gate” junction for program-level eligibility. |
| `EnrollmentEligibilityCriteria` | **Yes** | — | Rule library. |
| `AssessmentQuestion` | **Yes** | — | |
| `BenefitEnrollment` | **No** | — | Wildcard `%BenefitEnroll%` returns **0 rows**. Plan currently assumes benefit-level enrollment exists as a standard object; decide whether to **model benefit participation via `BenefitSession` participants / custom object** or confirm the object name for your NPC release. |
| `AssessmentResponse` (canvas term) | **No (use `AssessmentQuestionResponse`)** | — | `AssessmentResponse` not present; response store in this org is **`AssessmentQuestionResponse`**. Spec should be updated to read responses from that object. |
| `AssessmentQuestionSourceDocument` | **No** | — | Wildcard `%SourceDocument%` returns 0 rows. Plan’s “Source Document” requirement needs either a different object on this org (look for a DF source-authority object under another name) or a custom object. |
| `Benefit_Enrollment_Eligibility_Criteria__c` | **No** | — | Custom — to be created in phase 2. |
| `Eligibility_Question_Mapping__c` | **No** | — | Custom — to be created in phase 2. |
| `Delivery_Site__c` | **No** | — | Custom — to be created in phase 2. |
| `Funder_Seat_Allocation__c` | **No** | — | Custom — to be created in phase 2. |

## Implications for the ISANS plan

1. **Main NPC stack is usable** on `vscodeOrg`: `Program`, `Benefit`, `BenefitSchedule`, `BenefitSession`, `ProgramEnrollment`, eligibility objects all exist.
2. **Two canvas names need correction before build:**
   - Replace **`AssessmentResponse`** with **`AssessmentQuestionResponse`** throughout Apex, Flow, and docs.
   - Remove or remap **`AssessmentQuestionSourceDocument`** (either find the actual source-document object in this org's Discovery Framework, or introduce a custom object).
3. **`BenefitEnrollment` does not exist** here. The plan either needs to:
   - Model benefit-level enrollment as attendance/participation on **`BenefitSession`** (or similar), **or**
   - Introduce a **custom object** (e.g. `BenefitEnrollment__c`) and adjust Apex accordingly.

## Commands to reproduce

Standard API (limited visibility on this org):

```bash
sf data query --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName IN ('Program','Benefit','BenefitSchedule','BenefitSession','ProgramEnrollment','BenefitEnrollment','EnrollmentEligibilityCriteria','ProgramEnrlEligibilityCrit','AssessmentQuestion','AssessmentQuestionResponse','AssessmentResponse','AssessmentQuestionSourceDocument')" --target-org vscodeOrg
```

**Tooling API (use this to see NPC objects):**

```bash
sf data query --use-tooling-api --query "SELECT QualifiedApiName, Label, KeyPrefix FROM EntityDefinition WHERE QualifiedApiName IN ('Program','Benefit','BenefitSchedule','BenefitSession','ProgramEnrollment','BenefitEnrollment','EnrollmentEligibilityCriteria','ProgramEnrlEligibilityCrit')" --target-org vscodeOrg
```

Describe a specific NPC object:

```bash
sf sobject describe --sobject Program --use-tooling-api --target-org vscodeOrg
```
