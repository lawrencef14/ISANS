#!/usr/bin/env bash
# Create (or repair) one sample EnrollmentEligibilityCriteria + ProgramEnrlEligibilityCrit
# for ISANS - LINC, wired to the org's existing "Repair Eligibility" Expression Set.
# That Expression Set is unrelated to ISANS logic — it exists only to validate the
# ExecutionProcedureId plumbing. Replace with a real ISANS rule in Milestone 1.
#
# Usage:
#   ./scripts/seed-isans-eligibility-sample.sh [--target-org ALIAS]
#
# Requires: sf CLI, jq, python3

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

sf_query_json() {
  local q="$1"
  sf data query --query "$q" --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); sys.stdout.write(json.dumps(json.loads(r[i:])))'
}

command -v jq >/dev/null 2>&1 || die "jq not found"
command -v python3 >/dev/null 2>&1 || die "python3 not found"

EEC_NAME="ISANS Sample - LINC age gate (demo rule)"
EXPR_NAME="Repair Eligibility"
PROG_NAME="ISANS - LINC"

PROG_ID=$(sf_query_json "SELECT Id FROM Program WHERE Name = '${PROG_NAME}' LIMIT 1" | jq -r '.result.records[0].Id // empty')
[[ -n "$PROG_ID" ]] || die "Program '${PROG_NAME}' not found. Run ./scripts/seed-isans-programs.sh first."

EXPR_ID=$(sf_query_json "SELECT Id FROM ExpressionSet WHERE Name = '${EXPR_NAME}' LIMIT 1" | jq -r '.result.records[0].Id // empty')
[[ -n "$EXPR_ID" ]] || die "ExpressionSet '${EXPR_NAME}' not found. Pick another Expression Set in this org and edit this script."

EEC_ID=$(sf_query_json "SELECT Id FROM EnrollmentEligibilityCriteria WHERE Name = '${EEC_NAME}' LIMIT 1" | jq -r '.result.records[0].Id // empty')

if [[ -z "$EEC_ID" ]]; then
  echo "Creating EnrollmentEligibilityCriteria..."
  EEC_ID=$(sf data create record --sobject EnrollmentEligibilityCriteria \
    --values "Name='${EEC_NAME}' Status=Active Description='Sample row from ISANS repo scripts. Expression Set is org demo plumbing only; replace with ISANS-specific rule.' ExecutionProcedureId=${EXPR_ID}" \
    --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); print(json.loads(r[i:])["result"]["id"])')
  echo "  EnrollmentEligibilityCriteria Id: $EEC_ID"
else
  echo "EnrollmentEligibilityCriteria already exists: $EEC_ID"
fi

PEC_ID=$(sf_query_json "SELECT Id FROM ProgramEnrlEligibilityCrit WHERE ProgramId = '${PROG_ID}' AND EnrollmentEligibilityCritId = '${EEC_ID}' LIMIT 1" | jq -r '.result.records[0].Id // empty')

if [[ -z "$PEC_ID" ]]; then
  echo "Creating ProgramEnrlEligibilityCrit..."
  PEC_ID=$(sf data create record --sobject ProgramEnrlEligibilityCrit \
    --values "ProgramId=${PROG_ID} EnrollmentEligibilityCritId=${EEC_ID} IsRequired=true" \
    --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); print(json.loads(r[i:])["result"]["id"])')
  echo "  ProgramEnrlEligibilityCrit Id: $PEC_ID"
else
  echo "ProgramEnrlEligibilityCrit already exists: $PEC_ID"
fi

echo "Done."
