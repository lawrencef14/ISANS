#!/usr/bin/env bash
# Seed ISANS demo programs, benefits, schedules, and sessions alongside existing NPC demo data.
# Idempotent: skips if any Program named "ISANS - *" already exists (use --force to seed anyway).
#
# Usage:
#   ./scripts/seed-isans-programs.sh [--force] [--target-org ALIAS]
#
# Requires: sf CLI, jq, python3
#
# If you ever need to remove seeded Programs, delete related ProgramRecommendationRule
# rows first (the org may auto-create them), then delete Program records.

set -euo pipefail

FORCE=0
TARGET_ORG="${SFDX_DEFAULTUSERNAME:-vscodeOrg}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --target-org) TARGET_ORG="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

sf_query_json() {
  local q="$1"
  sf data query --query "$q" --target-org "$TARGET_ORG" --json 2>/dev/null \
    | python3 -c 'import sys,json; r=sys.stdin.read(); i=r.find("{"); sys.stdout.write(json.dumps(json.loads(r[i:])))'
}

jq_id() {
  jq -r '.result.records[0].Id // empty' 2>/dev/null
}

create_id() {
  # stdin: full sf json output with .result.id
  jq -r '.result.id // empty'
}

existing_isans() {
  sf_query_json "SELECT COUNT(Id) cnt FROM Program WHERE Name LIKE 'ISANS -%'" | jq -r '.result.records[0].cnt // 0'
}

if [[ "$(existing_isans)" != "0" && "$FORCE" -ne 1 ]]; then
  echo "Programs matching 'ISANS -%' already exist (count=$(existing_isans)). Nothing to do."
  echo "Re-run with --force to insert duplicates anyway."
  exit 0
fi

echo "Resolving BenefitType Ids on $TARGET_ORG..."
BT_INSTR=$(sf_query_json "SELECT Id FROM BenefitType WHERE Name = 'Instructor Led Learning' LIMIT 1" | jq_id)
BT_SESS=$(sf_query_json "SELECT Id FROM BenefitType WHERE Name = 'Sessions' LIMIT 1" | jq_id)
BT_APP=$(sf_query_json "SELECT Id FROM BenefitType WHERE Name = 'Application Assistance' LIMIT 1" | jq_id)
BT_COACH=$(sf_query_json "SELECT Id FROM BenefitType WHERE Name = 'Personalized Coaching Time' LIMIT 1" | jq_id)

for v in BT_INSTR BT_SESS BT_APP BT_COACH; do
  if [[ -z "${!v}" ]]; then
    echo "Missing BenefitType for $v — check BenefitType names in this org." >&2
    exit 1
  fi
done

echo "Creating Programs..."
P_LINC=$(sf data create record --sobject Program --values "Name='ISANS - LINC' Status=Active StartDate=2026-01-15" --target-org "$TARGET_ORG" --json | create_id)
P_SETT=$(sf data create record --sobject Program --values "Name='ISANS - Settlement Services' Status=Active StartDate=2026-01-15" --target-org "$TARGET_ORG" --json | create_id)
P_EMP=$(sf data create record --sobject Program --values "Name='ISANS - Employment & Career' Status=Active StartDate=2026-01-15" --target-org "$TARGET_ORG" --json | create_id)
echo "  LINC Program Id:        $P_LINC"
echo "  Settlement Program Id:  $P_SETT"
echo "  Employment Program Id:  $P_EMP"

create_benefit() {
  local program_id="$1" name="$2" type_id="$3"
  sf data create record --sobject Benefit \
    --values "ProgramId=$program_id Name='$name' BenefitTypeId=$type_id" \
    --target-org "$TARGET_ORG" --json | create_id >/dev/null
}

create_schedule() {
  local benefit_id="$1" name="$2" start="$3" end="$4"
  sf data create record --sobject BenefitSchedule \
    --values "BenefitId=$benefit_id Name='$name' DefaultBenefitQuantity=1 FirstSessionStartDateTime=$start FirstSessionEndDateTime=$end" \
    --target-org "$TARGET_ORG" --json | create_id >/dev/null
}

create_session() {
  local schedule_id="$1" name="$2" start="$3" end="$4"
  sf data create record --sobject BenefitSession \
    --values "BenefitScheduleId=$schedule_id Name='$name' StartDateTime=$start EndDateTime=$end Status=Scheduled" \
    --target-org "$TARGET_ORG" --json | create_id >/dev/null
}

echo "Creating Benefits, Schedules, and Sessions for ISANS - LINC..."
B1=$(create_benefit "$P_LINC" "LINC Basics" "$BT_INSTR")
B2=$(create_benefit "$P_LINC" "LINC Plus" "$BT_INSTR")
B3=$(create_benefit "$P_LINC" "Conversation Circles" "$BT_SESS")
S1=$(create_schedule "$B1" "LINC Basics - Winter Cohort" "2026-02-03T14:00:00.000Z" "2026-02-03T16:30:00.000Z")
S2=$(create_schedule "$B2" "LINC Plus - Winter Cohort" "2026-02-04T14:00:00.000Z" "2026-02-04T16:30:00.000Z")
S3=$(create_schedule "$B3" "Conversation Circles - Weekly" "2026-02-05T18:00:00.000Z" "2026-02-05T19:30:00.000Z")
create_session "$S1" "2026-02-03 Session 1" "2026-02-03T14:00:00.000Z" "2026-02-03T16:30:00.000Z"
create_session "$S1" "2026-02-10 Session 2" "2026-02-10T14:00:00.000Z" "2026-02-10T16:30:00.000Z"
create_session "$S2" "2026-02-04 Session 1" "2026-02-04T14:00:00.000Z" "2026-02-04T16:30:00.000Z"
create_session "$S3" "2026-02-05 Week 1" "2026-02-05T18:00:00.000Z" "2026-02-05T19:30:00.000Z"
create_session "$S3" "2026-02-12 Week 2" "2026-02-12T18:00:00.000Z" "2026-02-12T19:30:00.000Z"

echo "Creating Benefits, Schedules, and Sessions for ISANS - Settlement Services..."
B4=$(create_benefit "$P_SETT" "Information & Orientation" "$BT_APP")
B5=$(create_benefit "$P_SETT" "Housing Navigation" "$BT_APP")
B6=$(create_benefit "$P_SETT" "School Readiness" "$BT_APP")
S4=$(create_schedule "$B4" "Orientation - Intake Block A" "2026-02-02T15:00:00.000Z" "2026-02-02T17:00:00.000Z")
S5=$(create_schedule "$B5" "Housing - Drop-in Hours" "2026-02-06T16:00:00.000Z" "2026-02-06T18:00:00.000Z")
S6=$(create_schedule "$B6" "School Readiness Workshop" "2026-02-07T14:00:00.000Z" "2026-02-07T16:00:00.000Z")
create_session "$S4" "2026-02-02 Orientation" "2026-02-02T15:00:00.000Z" "2026-02-02T17:00:00.000Z"
create_session "$S5" "2026-02-06 Housing Drop-in" "2026-02-06T16:00:00.000Z" "2026-02-06T18:00:00.000Z"
create_session "$S6" "2026-02-07 School Readiness" "2026-02-07T14:00:00.000Z" "2026-02-07T16:00:00.000Z"

echo "Creating Benefits, Schedules, and Sessions for ISANS - Employment & Career..."
B7=$(create_benefit "$P_EMP" "Job Search Workshop" "$BT_INSTR")
B8=$(create_benefit "$P_EMP" "Resume & Interview Coaching" "$BT_COACH")
B9=$(create_benefit "$P_EMP" "Employer Connection Event" "$BT_SESS")
S7=$(create_schedule "$B7" "Job Search - February Series" "2026-02-11T17:00:00.000Z" "2026-02-11T19:00:00.000Z")
S8=$(create_schedule "$B8" "Coaching - Biweekly Slots" "2026-02-12T19:00:00.000Z" "2026-02-12T20:00:00.000Z")
S9=$(create_schedule "$B9" "Employer Fair - Spring" "2026-03-15T15:00:00.000Z" "2026-03-15T19:00:00.000Z")
create_session "$S7" "2026-02-11 Workshop 1" "2026-02-11T17:00:00.000Z" "2026-02-11T19:00:00.000Z"
create_session "$S7" "2026-02-18 Workshop 2" "2026-02-18T17:00:00.000Z" "2026-02-18T19:00:00.000Z"
create_session "$S8" "2026-02-12 Coaching Block" "2026-02-12T19:00:00.000Z" "2026-02-12T20:00:00.000Z"
create_session "$S9" "2026-03-15 Employer Fair" "2026-03-15T15:00:00.000Z" "2026-03-15T19:00:00.000Z"

echo ""
echo "Done. Summary:"
sf data query --query "SELECT Id, Name FROM Program WHERE Name LIKE 'ISANS -%' ORDER BY Name" --target-org "$TARGET_ORG" 2>/dev/null
echo -n "Benefits: "
sf data query --query "SELECT COUNT(Id) c FROM Benefit WHERE Program.Name LIKE 'ISANS -%'" --target-org "$TARGET_ORG" --json 2>/dev/null | jq -r '.result.records[0].c'
echo -n "BenefitSchedules: "
sf data query --query "SELECT COUNT(Id) c FROM BenefitSchedule WHERE Benefit.Program.Name LIKE 'ISANS -%'" --target-org "$TARGET_ORG" --json 2>/dev/null | jq -r '.result.records[0].c'
echo -n "BenefitSessions: "
sf data query --query "SELECT COUNT(Id) c FROM BenefitSession WHERE BenefitSchedule.Benefit.Program.Name LIKE 'ISANS -%'" --target-org "$TARGET_ORG" --json 2>/dev/null | jq -r '.result.records[0].c'
