# Salesforce DX Project: Next Steps

**ISANS demo:** Coordinated NPC enrollment (programs, benefits, eligibility, funder seats, support services) is specified in [docs/ISANS-coordinated-enrollment-plan.md](docs/ISANS-coordinated-enrollment-plan.md), with the verified schema in [docs/02-data-model.md](docs/02-data-model.md) and the Expression-Set-based eligibility engine in [docs/03-eligibility-engine.md](docs/03-eligibility-engine.md). **Org vs plan:** [docs/org-object-verification-vscodeOrg.md](docs/org-object-verification-vscodeOrg.md) — pinned org **`vscodeOrg`** has the NPC `Program` stack (after permission-set update). Alternate: [docs/org-object-verification-donor-demo.md](docs/org-object-verification-donor-demo.md).

**Seed demo data (add-alongside):** run `./scripts/seed-isans-programs.sh` (requires `jq` and `python3`; can be run from any directory). It creates three `Program` records named `ISANS - LINC`, `ISANS - Settlement Services`, and `ISANS - Employment & Career`, each with benefits, one `BenefitSchedule` per benefit, and sample `BenefitSession` rows. Re-runs are skipped unless you pass `--force`.

**Verify + test:** run `./scripts/verify-isans-setup.sh` (requires `jq` and `python3`) for automated checks, then follow the UI checklist in [docs/05-manual-test-plan.md](docs/05-manual-test-plan.md).

**Sample eligibility (optional):** `./scripts/seed-isans-eligibility-sample.sh` creates one `EnrollmentEligibilityCriteria` + `ProgramEnrlEligibilityCrit` for `ISANS - LINC` (see [docs/06-sample-eligibility-records.md](docs/06-sample-eligibility-records.md)).

**Expression Set (UI):** step-by-step to build an “under max age” rule (e.g. under 12) with a configurable threshold — [docs/07-expression-set-under-max-age-ui.md](docs/07-expression-set-under-max-age-ui.md). For **multi-factor rules, swapping variables, and UX** — [docs/08-eligibility-flexibility-multi-factor.md](docs/08-eligibility-flexibility-multi-factor.md).

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
