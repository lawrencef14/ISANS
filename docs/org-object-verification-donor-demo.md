# Org object verification — `donor-demo`

This file documents **`donor-demo`** (`trailsignup.8a8fedae16cffe@salesforce.com`, Org Id `00DHs00000S4Vl1MAF`, API 66.0)—the connected org where **Nonprofit-style `Program`** and related objects **are** present.

If your IDE shows Programs but earlier notes said “no Program,” the project default was likely **`vscodeOrg`** instead of this alias. For ISANS work, pin the project with:

```bash
sf config set target-org donor-demo
```

## ISANS canvas objects — quick existence check

Queried via `EntityDefinition` (exact `IN` list) unless noted.

| API name | Present? |
|----------|-----------|
| `Program` | **Yes** |
| `Benefit` | **Yes** |
| `BenefitSchedule` | **Yes** |
| `BenefitSession` | **Yes** |
| `ProgramEnrollment` | **Yes** |
| `EnrollmentEligibilityCriteria` | **Yes** |
| `ProgramEnrlEligibilityCrit` | **Yes** |
| `BenefitEnrollment` | **No** (exact name not found; search `LIKE '%BenefitEnroll%'` returned 0—confirm benefit-level enrollment object name in **Schema Builder** for this org/version.) |

Custom objects from the plan (`Benefit_Enrollment_Eligibility_Criteria__c`, `Eligibility_Question_Mapping__c`, `Delivery_Site__c`, `Funder_Seat_Allocation__c`) were not re-listed here; add them when you create metadata or retrieve from the org.

## Reproduce

```bash
sf data query --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName IN ('Program','Benefit','BenefitSchedule','BenefitSession','ProgramEnrollment','BenefitEnrollment','EnrollmentEligibilityCriteria','ProgramEnrlEligibilityCrit')" --target-org donor-demo
```
