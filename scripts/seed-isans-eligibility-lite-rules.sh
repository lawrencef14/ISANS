#!/usr/bin/env bash
# Seed two sample ISANS_Program_Eligibility_Rule__c rows for ISANS - LINC:
#   1) Maximum age (exclusive) threshold 12  (under 12 passes)
#   2) Maximum annual household income 50000
# Idempotent: skips if two or more rules already exist for that program.
#
# Usage: ./scripts/seed-isans-eligibility-lite-rules.sh [--target-org ALIAS]
# Requires: sf CLI, python3

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

sf_query_json() {
  local q="$1"
  sf data query --query "$q" --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); sys.stdout.write(json.dumps(json.loads(r[i:])))'
}

PROG_ID=$(sf_query_json "SELECT Id FROM Program WHERE Name = 'ISANS - LINC' LIMIT 1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['records'][0]['Id'] if d.get('result',{}).get('records') else '')")
[[ -n "$PROG_ID" ]] || { echo "Program 'ISANS - LINC' not found. Run seed-isans-programs.sh first." >&2; exit 1; }

EXIST=$(sf_query_json "SELECT COUNT(Id) c FROM ISANS_Program_Eligibility_Rule__c WHERE Program__c = '${PROG_ID}'" | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result']['records'][0]['c']))")
if [[ "$EXIST" -ge 2 ]]; then
  echo "Program ISANS - LINC already has $EXIST rule(s). Skipping (use UI to edit or delete first)."
  exit 0
fi

echo "Creating Eligibility Lite rules for ISANS - LINC ($PROG_ID)..."

sf data create record --sobject ISANS_Program_Eligibility_Rule__c \
  --values "Program__c=${PROG_ID} Rule_Type__c=Max_Age_Exclusive Threshold_Number__c=12 Sequence__c=10 Is_Active__c=true Failure_Message__c='Client must be under 12 years old.'" \
  --target-org "$TARGET_ORG" >/dev/null

sf data create record --sobject ISANS_Program_Eligibility_Rule__c \
  --values "Program__c=${PROG_ID} Rule_Type__c=Max_Annual_Income Threshold_Number__c=50000 Sequence__c=20 Is_Active__c=true Failure_Message__c='Annual household income must be at or below the program maximum.'" \
  --target-org "$TARGET_ORG" >/dev/null

echo "Done. List rules:"
sf data query --query "SELECT Name, Rule_Type__c, Threshold_Number__c, Sequence__c FROM ISANS_Program_Eligibility_Rule__c WHERE Program__c = '${PROG_ID}' ORDER BY Sequence__c" --target-org "$TARGET_ORG" 2>/dev/null
