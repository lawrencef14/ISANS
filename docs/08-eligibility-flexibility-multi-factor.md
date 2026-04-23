# ISANS — Flexibility beyond a single age check (variables, combinations, UX)

This doc answers: **“What if we stop using age and use another variable, or combine several variables with filtering logic?”**  
Short answer: **yes, that flexibility is exactly what Expression Sets + multiple criteria rows are for.** The [age-only UI walkthrough](07-expression-set-under-max-age-ui.md) is a **minimal example**, not the ceiling of the design.

---

## 1. Where flexibility actually lives (so expectations match the UI)

| Layer | Flexibility you get |
|-------|---------------------|
| **Expression Set (BRE)** | Multiple **inputs** (any mix: dates, numbers, text, booleans). **Branches**, **conditions**, **AND/OR** groups (per product capabilities), intermediate **calculations**, different **outputs** per path. Swapping “age” for “something else” is mostly **changing inputs and rewiring the graph** — still inside this layer. |
| **`EnrollmentEligibilityCriteria`** | One row = **one callable rule** (name, status, which Expression Set). You add **more rows** when you want **more independent rules** (e.g. one ES for age band, another for language, another for funder caps). |
| **`ProgramEnrlEligibilityCrit`** | **Which** rules apply to **which program**, **required vs advisory**, and (once you add custom fields from [03 §6](03-eligibility-engine.md)) **order** / blocking flags. Still not the place for boolean algebra — that stays in the Expression Set. |
| **Case worker UI (future LWC / Flow)** | **Presentation** flexibility: show each rule’s pass/fail, reasons, missing data, “what to fix next” — without stuffing logic onto NPC standard objects. |

So: **combining variables with filtering logic** is **Expression Set authoring** (plus how Apex builds the **input map** from Account, Case, Discovery responses, Custom Metadata, etc.).

---

## 2. Patterns for “age today, something else tomorrow”

| Approach | When to use it |
|----------|----------------|
| **Same Expression Set, new inputs** | Rule family stays one “bundle” (e.g. “LINC gate”). You add inputs like `PrimaryLanguage`, `ImmigrationStatusCode`, `HouseholdIncomeBand` next to `ClientBirthdate`. Conditions use **AND/OR** across them. |
| **New Expression Set + new criteria row** | Rule is **semantically separate** (e.g. “Funder A agreement” vs “Provincial age rule”). Create another `EnrollmentEligibilityCriteria` pointing at the second ES; link both to the program via **two** junction rows. |
| **Runtime parameters** | Thresholds and toggles you do **not** want to republish often: pass as **inputs** (`MaximumAgeYears`, `MinimumLanguageLevel`, …) from Apex, optionally sourced from **Custom Metadata** so admins edit tables in Setup instead of opening the Expression Set. |
| **Waterfall** | Run criteria **in order** (custom `Evaluation_Order__c` on the junction — planned in [03 §6](03-eligibility-engine.md)): stop at first blocking failure, or aggregate all failures for UX. |

“Change from age to another variable” usually means: **stop passing / using one input in the ES**, **add the new input**, **adjust branches** — not a redesign of NPC objects.

---

## 3. Combining multiple variables (filtering logic)

In the **Business Rules Engine / Expression Set** builder (same place as the age guide):

- Use **multiple inputs** on the definition version.
- Use **Condition** / **Branch** elements to model **AND** and **OR** (and nested logic where the product allows).
- Use **Calculation** steps for derived values (e.g. “months since landing”, “benefit utilization %”) before comparing.

Product-specific tutorials (branching, conditions, testing):

- [Optimize Business Rules with Expression Sets](https://trailhead.salesforce.com/content/learn/modules/business-rules-engine/orchestrate-rules-with-expression-sets)
- [Add a Branch and Test an Expression Set](https://trailhead.salesforce.com/content/learn/modules/advanced-rules-with-business-rules-engine/add-a-branch-and-test-expression-set)

If a single Expression Set becomes too large, **split** into multiple sets and attach multiple **`EnrollmentEligibilityCriteria`** rows to the same program — that is also “combination”, just **decomposed** for clarity and reuse.

---

## 4. Where Discovery / assessments fit

Assessment answers should land in the **stable input contract** (see [03 §5](03-eligibility-engine.md) `responses[]` / `clientProfile`). The Expression Set does not need to query `AssessmentQuestionResponse` itself if **Apex (or Flow)** preloads values into **typed inputs** (e.g. `HasCompletedOrientation`, `AssessmentScoreBand`). That keeps the ES simpler and makes **changing which question feeds which input** a smaller change (mapper in code or a small table), not a rewrite of NPC schema.

---

## 5. UX: what case workers see (not limited to standard record pages)

Standard Lightning record pages for `EnrollmentEligibilityCriteria` / `ProgramEnrlEligibilityCrit` are mainly **admin/config** surfaces. For **case workers**, plan a dedicated experience (LWC on **Case** or **Program Enrollment**) that:

- Calls **`EligibilityService.evaluate`** (when built) with `clientAccountId` + `programId`.
- Renders a **list of criteria outcomes** (each row: name, pass/fail, message, link to source document).
- Surfaces **missing inputs** (“Date of birth required”, “Complete language assessment”) so the worker knows what to collect — even when the underlying rule is a multi-variable AND/OR tree.

That UX flexibility is **intentional** in the spec; it does not have to mirror the Expression Set graph 1:1 in Salesforce object fields.

---

## 6. Summary

| Question | Answer |
|----------|--------|
| Can we move off “age” to another variable? | **Yes** — inputs + logic live in the **Expression Set** (and in the **input map** Apex builds). |
| Can we combine variables with filtering logic? | **Yes** — **branches / conditions / AND/OR** inside the Expression Set, and/or **multiple** criteria rows + junction ordering for a waterfall. |
| Is that “considered” in the design? | **Yes** — [03-eligibility-engine.md](03-eligibility-engine.md) assumes **Expression Set invocation** per criterion and an extensible **input contract**; [07](07-expression-set-under-max-age-ui.md) is only a **first** UI recipe. |

When you outgrow point-and-click complexity, teams sometimes **invoke** the same rules from Apex with a richer payload or split rules across sets — still the same architecture.
