# ISANS — “Eligibility Lite” for the demo (simpler than NPC + Expression Sets)

## Why this exists

Authoring **Program Enrollment Eligibility Criteria** + **Expression Sets** + correct **inputs / versions / activation** is powerful but **slow and error-prone** for a **demo**, especially when you need **age** and **income** (and maybe **AND/OR**) without fighting org-specific BRE screens and record mismatches.

This document describes a **deliberately simpler** pattern: **custom, data-driven rules** that end users (or power users) maintain in normal Salesforce records, and a **single evaluation entry point** (Flow or Apex) that case workers run from a Case or Program context.

> **Scope:** Demo and pilot UX. It does **not** replace Salesforce’s native NPC eligibility engine for a full production legal/compliance posture. You can keep NPC programs/benefits for delivery and use **Eligibility Lite** only for “can we enroll this client?” until you are ready to invest in Expression Sets again.

---

## What “simpler” means here

| Native NPC + BRE | Eligibility Lite (demo) |
|------------------|-------------------------|
| Expression Set builder, versions, activation | **No** Expression Set required for the demo path |
| `EnrollmentEligibilityCriteria` + junction wiring | **Optional** — you can ignore them for demo checks |
| Hard for casual admins | **List views + simple fields** on a custom object (or Screen Flow “Add rule”) |

---

## Suggested data model (minimal)

**1. `ISANS_Program_Eligibility_Rule__c`** (custom object)

| Field | Type | Purpose |
|-------|------|---------|
| `Program__c` | Lookup → `Program` | Which program this rule applies to (e.g. `ISANS - LINC`). |
| `Rule_Type__c` | Picklist | e.g. `Maximum age (exclusive)`, `Minimum age (inclusive)`, `Maximum annual income`. |
| `Threshold_Number__c` | Number(16,2) | e.g. `12` means “under 12” for max-age-exclusive; `50000` for max income. |
| `Sequence__c` | Number | Order of evaluation (lower first). |
| `Is_Active__c` | Checkbox | Soft-disable without delete. |
| `Failure_Message__c` | Text(255) | What the worker sees if this rule fails. |

**Combination logic (keep v1 dead simple):**

- **v1:** All **active** rules for the program are **AND**’d: every rule must pass. (Covers “age **and** income”.)
- **v2 (if you need OR):** add `Rule_Group__c` (Number): rules in the **same group** are OR’d together; **groups** are AND’d. (Implement when needed.)

**2. Client data the evaluator reads**

- **Age:** `Account.PersonBirthdate` on the **Person Account** (already your org pattern).
- **Income:** not standard on Account — add **`ISANS_Annual_Household_Income__c`** (Currency) on **Account** (or Person Account) for the demo, *or* a tiny **`ISANS_Client_Profile__c`** (1:1 with Account) if you prefer not to touch Account.

---

## Evaluation (single front door)

**Invocable Apex** (or **Autolaunched Flow** + subflow) e.g. `ISANS_EligibilityLite.evaluate(programId, accountId)`:

1. Load active `ISANS_Program_Eligibility_Rule__c` rows for `programId`, order by `Sequence__c`.
2. Load `Account` (PersonBirthdate + income field).
3. Compute age in years from `PersonBirthdate` to today (null-safe).
4. For each rule, compare against `Threshold_Number__c` per `Rule_Type__c`.
5. Return a **DTO** to the LWC: `overallPass`, `List<{ruleName, pass, message}>`.

**Case worker UX:** one **LWC** on **Case** (or a **Quick Action** launching a Screen Flow) that shows green/red per rule and the first failure message — no need to open Expression Sets or junction objects.

**Admin UX:** create rules in a **list view** or a small **Screen Flow** “Add eligibility rule” that inserts `ISANS_Program_Eligibility_Rule__c` rows — **on the fly** without metadata deploys.

---

## How this sits next to what you already built

- **Programs / Benefits / Sessions** — unchanged; still the real program catalog.
- **Sample `EnrollmentEligibilityCriteria` / junction** — can remain for documentation, or you stop using them for the demo narrative.
- **Expression Set docs (03, 07, 08)** — remain the **production direction**; this file is the **demo shortcut**.

---

## Tradeoffs (be explicit)

| Pro | Con |
|-----|-----|
| Fast to build and demo | Not Salesforce’s native NPC eligibility engine |
| End users edit rules as data | You own validation, messaging, and edge cases in code |
| Easy to add “income band” later (new picklist value + branch in evaluator) | Duplicates *some* concepts BRE would give you for free long-term |

---

## Recommended next step

1. Agree on **v1 = AND all rules** (sufficient for “age **and** income”).  
2. Add **`ISANS_Program_Eligibility_Rule__c`** + **income field** (Account or child object).  
3. Implement **`ISANS_EligibilityLite`** invocable + **thin LWC** on Case.  
4. Optional: **Screen Flow** “New rule” for non–list-view admins.

If you want this in the repo next, say **“scaffold Eligibility Lite”** and we add the metadata + Apex + a one-page admin guide (still no change to your commitment to NPC programs for delivery).
