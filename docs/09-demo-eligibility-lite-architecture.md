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

## What is in the repo now (scaffolded)

| Piece | Location |
|-------|----------|
| Custom object **`ISANS_Program_Eligibility_Rule__c`** | `force-app/main/default/objects/ISANS_Program_Eligibility_Rule__c/` |
| Account field **`ISANS_Annual_Household_Income__c`** | `force-app/main/default/objects/Account/fields/` |
| **`ISANS_EligibilityLiteService`** | `@AuraEnabled` `evaluate`, `listProgramsForPicker`, `@InvocableMethod` `evaluateInvocable` |
| LWC **`isansEligibilityLite`** | Case record page — pick program, run check against **Case.AccountId** |
| Sample rules on org | Run [`scripts/seed-isans-eligibility-lite-rules.sh`](../scripts/seed-isans-eligibility-lite-rules.sh) after deploy (under-12 + 50k income for **ISANS - LINC**). |
| Permissions | **`ISANS_Case_Worker`** includes Account, Contact (read), custom object CRUD, income field, Apex class access. |

### Add the LWC to a Case page (Nonprofit / IDO orgs included)

You are not editing the **Program** or **Expression Set** here. You are only choosing **where the little “Eligibility Lite” panel appears** when someone opens a **Case** in Lightning.

**Prerequisites:** The metadata is **deployed** to this org, and your user can use **Lightning App Builder** (often **Customize Application** or a profile that allows editing Lightning pages).

#### Path A — Fastest (from an open Case)

1. In Lightning, open **any Case** (the same way case workers would: Cases tab, list view, or from a related record).
2. Click the **gear icon** (⚙️) in the top-right → **Edit Page**.  
   - If you do **not** see **Edit Page**, you may lack permission: use **Path B** with a System Administrator, or ask an admin to assign **Lightning Experience** page editing rights.
3. You are now in **Lightning App Builder** on the **Case Record Page** for the app you came from (e.g. Service Console, Nonprofit, or your IDO app — the name does not matter; the **object** is Case).
4. On the **left**, scroll the component list to **Custom** (or use the search box at the top of the palette).
5. Find **ISANS Eligibility Lite** and **drag** it into a region (e.g. right column or a new tab). Resize if prompted.
6. Click **Save**, then **Activate** (or **Assign as Org Default** / **Assign to this app only** — pick what your org’s dialog offers so the page is the one users actually see for Cases in that app).

#### Path B — From Setup (if you prefer the menu)

1. Click the **gear** → **Setup**.
2. Quick Find box: type **`Lightning App Builder`** → open it.
3. Click **New** → **Record Page** → **Next**.
4. **Object** = **Case** → give the page a label (e.g. `Case ISANS Eligibility`) → **Next** → choose a template (e.g. **Header and Right Sidebar**) → **Finish**.
5. Drag **ISANS Eligibility Lite** from **Custom** onto the layout → **Save** → **Activate** and assign it to the **app** where your team works (e.g. your Nonprofit / IDO Lightning app) and **form factor** (Desktop).

#### If you cannot find “ISANS Eligibility Lite” in the palette

- Confirm deploy: **Setup** → **Custom Code** → **Lightning Components** and search `isans` / **ISANS Eligibility Lite**.
- Confirm the component’s target is **Case** (it is in metadata). It will **not** appear on Account or Contact pages.
- Try **refresh** the App Builder tab after deploy.

#### After it is on the page

1. Open a Case whose **Account** is a **Person Account** with **Birthdate** filled (and **ISANS Annual Household Income** if you use income rules).
2. In the panel: choose a **Program** (defaults to names starting with `ISANS` if any exist), then **Run eligibility check**.

---

### If you are on a Screen Flow (no “Edit Page”)

**Screen Flow** runs in a **Flow** runtime UI. There is **no** Lightning **gear → Edit Page** there — that menu exists only on **standard Lightning record pages** (and similar record experiences).

You have **two** options:

#### Option A — Edit the real Case record page (no Flow change)

1. Leave the Screen Flow (finish or cancel, or open a new browser tab).
2. Go to the **Cases** tab (or global search for **Cases**), open the **same** Case from a **list** so you see the **normal Case record** (tabs like Details, Related — not a big Flow wizard filling the whole screen).
3. Now use **gear → Edit Page** as in **Path A** above.  
   *If your org always deep-links Cases into a Flow and you never see the standard Case page, use **Option B** or ask an admin which Lightning app still uses the standard Case layout.*

#### Option B — Put the component **inside** your Screen Flow (recommended if Cases = Flow)

The LWC **`isansEligibilityLite`** is also exposed to **Flow** as a screen component.

1. **Setup** → Quick Find **Flows** → open the Flow that runs when you “see” the Case (or create a test Flow).
2. Add or edit a **Screen** element.
3. On that screen, add component **ISANS Eligibility Lite** (under **Custom** / **Screen components**).
4. Set **Case Id** to your Flow’s Case variable (e.g. `Case.Id` from a Get Records, or the `{!recordId}` from a record-triggered flow, depending on how your Flow is built).
5. **Optional — Add Participant:** If your demo uses **Add Participant** and stores the chosen **Person Account Id** in a Flow variable (e.g. `{!Participant_Account.Id}`), set the component’s **Participant Account Id (optional)** to that variable. When set, the check uses **that** account’s birthdate and income fields instead of **Case.Account** (so the demo matches “participant just added”).
6. **Save** and **Activate** the Flow.

After redeploy, Flow Builder shows **Case Id** and **Participant Account Id (optional)** on the component.

### Seed sample rules (CLI)

```bash
./scripts/seed-isans-eligibility-lite-rules.sh --target-org vscodeOrg
```

Requires **`ISANS - LINC`** from `./scripts/seed-isans-programs.sh`.

---

## Recommended next steps (optional polish)

1. **Screen Flow** “Add eligibility rule” for admins who prefer wizards over list views.  
2. **Custom Metadata** for default thresholds if you want zero-code tuning without touching rule rows.  
3. **Rule_Group__c** when you need OR-within-groups (see §2 of this doc).
