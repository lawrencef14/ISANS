#!/usr/bin/env bash
#
# Step-by-step verification that your machine + Salesforce org are ready to exercise
# the ISANS coordinated-enrollment footprint (NPC Data API, seeded programs, etc.).
#
# Usage:
#   ./scripts/verify-isans-setup.sh [--target-org ALIAS]
#
# Requires: sf CLI, jq, python3
#
# Exit codes: 0 = all automated checks passed; non-zero = first failure

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TARGET_ORG="${SFDX_DEFAULTUSERNAME:-vscodeOrg}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org) TARGET_ORG="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

die() { echo "FAIL: $*" >&2; exit 1; }
ok()  { echo "OK:   $*"; }

# sf prints pretty-printed JSON to stdout (may be preceded by other lines in some versions).
sf_dq_json() {
  local q="$1"
  sf data query --query "$q" --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); sys.stdout.write(json.dumps(json.loads(r[i:])))'
}

command -v jq >/dev/null 2>&1 || die "jq not found (brew install jq)"

step() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "STEP $1 — $2"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# --- STEP 1 ---
step 1 "Salesforce CLI and org authentication"
command -v sf >/dev/null 2>&1 || die "sf CLI not found. Install Salesforce CLI v2."
sf org display --target-org "$TARGET_ORG" >/dev/null || die "Cannot read org '$TARGET_ORG'. Run: sf org login web --alias $TARGET_ORG"
INSTANCE_URL=$(sf org display --target-org "$TARGET_ORG" --json 2>/dev/null | jq -r '.result.instanceUrl // empty')
[[ -n "$INSTANCE_URL" ]] || die "Could not read instanceUrl for $TARGET_ORG"
ok "Connected to $TARGET_ORG ($INSTANCE_URL)"

# --- STEP 2 ---
step 2 "NPC Program stack visible via Data API (permission / PSL check)"
OUT=$(sf_dq_json "SELECT Id FROM Program LIMIT 1") || die "SOQL query failed"
[[ -n "$OUT" ]] || die "Empty response from Program query"
echo "$OUT" | jq -e '.status == 0' >/dev/null 2>&1 || die "Program query returned error: $OUT"
echo "$OUT" | jq -e '.result.totalSize >= 1' >/dev/null 2>&1 || die "Program object not queryable (totalSize). Assign ISANS_Case_Worker + NPC PSLs — see README / docs/02-data-model.md."
ok "Program is queryable on Data API"

# --- STEP 3 ---
step 3 "Seeded ISANS programs present (run ./scripts/seed-isans-programs.sh if missing)"
CNT=$(sf_dq_json "SELECT COUNT(Id) c FROM Program WHERE Name LIKE 'ISANS -%'" | jq -r '.result.records[0].c // 0')
[[ "$CNT" -ge 3 ]] || die "Expected at least 3 Programs named 'ISANS - *', found $CNT. Run: ./scripts/seed-isans-programs.sh"
ok "Found $CNT Program(s) matching 'ISANS -%'"

# --- STEP 4 ---
step 4 "Seeded benefits, schedules, and sessions"
B=$(sf_dq_json "SELECT COUNT(Id) c FROM Benefit WHERE Program.Name LIKE 'ISANS -%'" | jq -r '.result.records[0].c')
SCH=$(sf_dq_json "SELECT COUNT(Id) c FROM BenefitSchedule WHERE Benefit.Program.Name LIKE 'ISANS -%'" | jq -r '.result.records[0].c')
SES=$(sf_dq_json "SELECT COUNT(Id) c FROM BenefitSession WHERE BenefitSchedule.Benefit.Program.Name LIKE 'ISANS -%'" | jq -r '.result.records[0].c')
[[ "$B" -ge 9 ]]  || die "Expected >= 9 ISANS-tagged Benefits, found $B"
[[ "$SCH" -ge 9 ]] || die "Expected >= 9 ISANS-tagged BenefitSchedules, found $SCH"
[[ "$SES" -ge 12 ]] || die "Expected >= 12 ISANS-tagged BenefitSessions, found $SES"
ok "Benefits=$B, Schedules=$SCH, Sessions=$SES"

# --- STEP 5 ---
step 5 "Person Accounts + enrollments pattern (sample)"
PA=$(sf_dq_json "SELECT COUNT(Id) c FROM Account WHERE IsPersonAccount = true" | jq -r '.result.records[0].c')
[[ "$PA" -ge 1 ]] || die "No Person Accounts found — unexpected for this demo org."
ok "Person Accounts present (count=$PA)"
PE=$(sf_dq_json "SELECT COUNT(Id) c FROM ProgramEnrollment WHERE AccountId != null" | jq -r '.result.records[0].c')
[[ "$PE" -ge 1 ]] || die "No ProgramEnrollment with AccountId — check org data."
ok "ProgramEnrollment rows with AccountId: $PE"

# --- STEP 6 ---
step 6 "Eligibility configuration (counts; optional sample from docs)"
EEC=$(sf_dq_json "SELECT COUNT(Id) c FROM EnrollmentEligibilityCriteria" | jq -r '.result.records[0].c // 0')
PEC=$(sf_dq_json "SELECT COUNT(Id) c FROM ProgramEnrlEligibilityCrit" | jq -r '.result.records[0].c // 0')
SAMPLE=$(sf_dq_json "SELECT COUNT(Id) c FROM EnrollmentEligibilityCriteria WHERE Name = 'ISANS Sample - LINC age gate (demo rule)'" | jq -r '.result.records[0].c // 0')
ok "EnrollmentEligibilityCriteria=$EEC; ProgramEnrlEligibilityCrit=$PEC (optional doc sample rows: $SAMPLE; see docs/06-sample-eligibility-records.md)"

# --- STEP 7 ---
step 7 "Optional: permission set metadata in repo (local file check)"
[[ -f "force-app/main/default/permissionsets/ISANS_Case_Worker.permissionset-meta.xml" ]] || die "Missing ISANS_Case_Worker.permissionset-meta.xml in repo"
ok "Repo contains ISANS_Case_Worker permission set metadata"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All automated checks passed."
echo "Next: open the org in Lightning and manually confirm Programs / Benefits / Sessions"
echo "      (see docs/05-manual-test-plan.md)."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
