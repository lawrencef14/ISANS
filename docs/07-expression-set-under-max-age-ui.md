# ISANS — Expression Set (UI only): “under max age” (e.g. younger than 12)

This guide is for **authoring in the Salesforce UI** (no metadata retrieve). It implements: **eligible when the client’s age in full years is strictly less than a maximum** (example: **12** → only ages **0–11** pass).

> **Product context:** `EnrollmentEligibilityCriteria.ExecutionProcedureId` points at an **Expression Set**. The criteria row does not hold the math; the Expression Set does. See [03-eligibility-engine.md §1.1](03-eligibility-engine.md).

## Before you start

- Confirm you can open **OmniStudio** or **Expression Sets** (Business Rules Engine). If you do not see them, your user needs the **OmniStudio Designer** permission set license (and related permissions) assigned — same family of access as other OmniStudio tools.
- **Person Accounts:** birth date is usually on the Account as **`PersonBirthdate`**. Your future Apex/Flow caller will pass that date into the Expression Set as an **input** (recommended), so the rule does not have to query the database inside the builder.

## Flexibility (pick one pattern)

| Pattern | What you change when policy changes | Best for |
|--------|----------------------------------------|----------|
| **A — Input parameter `MaximumAgeYears`** | Change the value **at runtime** (Flow/Apex passes `12`, later `14`) without republishing the rule logic. You can still set a **default** of `12` in the definition. | **Most flexible** — one Expression Set, many programs/ages. |
| **B — Constant in the rule** | Open the Expression Set, edit the literal **12** in the condition, save/publish a new version. | Simplest if only admins edit policy and you rarely change age. |

Below uses **Pattern A** in the structure; if your builder version does not support a numeric input default, use **Pattern B** (hard-code `12` in the condition) until you add Apex that passes `MaximumAgeYears`.

---

## Part 1 — Create the Expression Set

1. **App Launcher** → open **OmniStudio** (or use **Setup** → Quick Find → **Expression Sets** / **Expression Set Definitions** — your org’s label may differ).
2. Open **Expression Sets** (or **Expression Set Builder** / **New Expression Set** — follow the entry point your org shows).
3. Click **New** (or **New Expression Set**).
4. Fill in:
   - **Name:** e.g. `ISANS Under Max Age`
   - **API Name:** accept the default or use something like `ISANS_Under_Max_Age` (no spaces).
   - **Usage type:** **Default** (unless your org requires another type).
5. **Save** so you have a definition shell, then open it to add a **version** (some UIs create **Version 1** automatically).

Use Salesforce’s guided material if any screen differs: [Optimize Business Rules with Expression Sets](https://trailhead.salesforce.com/content/learn/modules/business-rules-engine/orchestrate-rules-with-expression-sets) and [Set Up an Expression Set](https://trailhead.salesforce.com/content/learn/modules/advanced-rules-with-business-rules-engine/set-up-an-expression-set).

---

## Part 2 — Define inputs (Pattern A)

In the **version** editor, add **inputs** (names may be “Variables”, “Parameters”, or “Inputs” depending on version):

| Suggested API name | Type | Required | Default | Purpose |
|-------------------|------|----------|---------|---------|
| `ClientBirthdate` | **Date** | Yes | — | Client’s date of birth (from `Account.PersonBirthdate` when you wire Apex/Flow). |
| `MaximumAgeYears` | **Number** (integer) | No | **12** | Pass **12** for “under 12”; change at runtime without editing the rule. |

If the builder does not allow defaults on inputs, make `MaximumAgeYears` required and always pass it from the caller.

---

## Part 3 — Compute age and evaluate “under max age”

Exact element names (**Calculation**, **Condition**, **Branch**, **Assignment**) vary slightly by release. The logic you want is:

1. **Compute age in whole years** from `ClientBirthdate` to **today’s date** (use the builder’s date/months functions — many orgs expose something equivalent to months-between divided by 12, or a dedicated age helper).  
   - Store the result in a **working variable**, e.g. `AgeYears`.
2. **Condition / Branch:**  
   - **Eligible path:** `AgeYears < MaximumAgeYears`  
   - Interpretation: for `MaximumAgeYears = 12`, ages **0–11** pass; **12+** do not.  
   - If your product language uses “less than or equal” for a different policy, adjust the operator and threshold accordingly.
3. **Outputs** (so callers and NPC can consume a clear result):  
   - e.g. `IsEligible` (Boolean) = true on the eligible branch, false otherwise.  
   - Optional: `FailureReason` (Text) on the ineligible branch, e.g. `Age must be under the program maximum.`

For branching patterns, see also: [Add a Branch and Test an Expression Set](https://trailhead.salesforce.com/content/learn/modules/advanced-rules-with-business-rules-engine/add-a-branch-and-test-expression-set).

---

## Part 4 — Activate / publish

1. **Validate** the version in the builder if a **Validate** or **Check** action exists.
2. **Activate** or **Publish** the version (wording varies). Ineligible/inactive versions will not run from `EnrollmentEligibilityCriteria`.

---

## Part 5 — Point your eligibility criteria at this Expression Set

1. Open your **`EnrollmentEligibilityCriteria`** record (or create a new one).
2. Set **Execution Procedure** (or **Expression Set**) to **`ISANS Under Max Age`** (the Expression Set you just created).
3. Ensure **`ProgramEnrlEligibilityCrit`** links the right **Program** to that criteria row.

---

## Part 6 — Test in the UI

Use the builder’s **Preview / Simulation / Test** (label varies) if available:

- `ClientBirthdate` = date for an **11-year-old** → expect **eligible** (`IsEligible` true when `MaximumAgeYears` = 12).  
- `ClientBirthdate` for a **12-year-old** → expect **not eligible**.  
- Change **`MaximumAgeYears`** to **13** in the test panel → **12-year-olds** become eligible (sanity check that your input drives flexibility).

---

## Wiring from Person Account (later, not UI-only)

When you add Apex or Flow, pass:

- `ClientBirthdate` = `Account.PersonBirthdate` (null-check if unknown DOB).  
- `MaximumAgeYears` = `12` (or read from **Custom Metadata** in Apex and pass the number — that gives admin-editable thresholds without opening the Expression Set).

---

## If you get stuck

- Screens differ by **Salesforce release** and **OmniStudio** version; Trailhead modules above stay closest to the product.  
- Your org’s **Repair Eligibility** Expression Set is only a **reference** that something is configured — open it read-only to see how **inputs / branches / outputs** are named in *your* tenant, then mirror that style for `ISANS Under Max Age`.
