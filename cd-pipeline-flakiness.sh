#!/usr/bin/env bash

set -o nounset
set -o pipefail

USAGE='
  cd-pipeline-flakiness.sh [-h|--help] [--days N] [--org ORG] [repo ...]

  Reports the failure rate of the "Continuous Deployment Pipeline" GitHub
  Actions workflow (.github/workflows/deploy_pipeline.yml) per repository.

  Flakiness rate := runs with conclusion "failure" / all runs of that workflow.

  For each repo it prints the rate over three windows: all-time, last 90 days,
  and a configurable short window (--days, default 30), plus an aggregate row.

  ================================== OPTIONS ==================================
  --days N        Short window in days for the third column (default: 30).
  --org ORG       GitHub org/owner (default: STUDITEMPS).
  --help|-h       Display this message.
  repo ...        One or more repo names to inspect. If omitted, the default
                  FinOpsTech app set is used.

  Requires: gh (authenticated, scope: repo), jq is not needed (uses gh --jq).

  NOTE: This measures the CD *failure rate*, which conflates genuine failures
  with flakes. It is NOT strict flakiness (failed-then-green-on-retry).
'

ORG="STUDITEMPS"
SHORT_DAYS=30
WF_PATH=".github/workflows/deploy_pipeline.yml"

# Default FinOpsTech app set (override by passing repo names as arguments).
DEFAULT_REPOS=(
  arbeitsentgelt
  arbeitnehmerverwaltung
  freigabe
  rechnungsstellung
  zvoove-rechnungsstellung
  sv-einordnung
  lohnfortzahlung
)

REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) echo "$USAGE"; exit 0 ;;
    --days)    SHORT_DAYS="$2"; shift 2 ;;
    --org)     ORG="$2"; shift 2 ;;
    --*)       echo "Unknown option: $1" >&2; echo "$USAGE" >&2; exit 1 ;;
    *)         REPOS+=("$1"); shift ;;
  esac
done
[ ${#REPOS[@]} -eq 0 ] && REPOS=("${DEFAULT_REPOS[@]}")

# Portable "N days ago" as YYYY-MM-DD (BSD/macOS date first, then GNU date).
days_ago() {
  date -v-"$1"d +%Y-%m-%d 2>/dev/null || date -d "-$1 days" +%Y-%m-%d
}
SINCE90=$(days_ago 90)
SINCE_SHORT=$(days_ago "$SHORT_DAYS")

# total_count of runs for a workflow, optional status + created filters.
count() { # $1=repo $2=workflow_id $3=query-suffix
  gh api "repos/$ORG/$1/actions/workflows/$2/runs?per_page=1$3" --jq '.total_count' 2>/dev/null
}
rate() { awk "BEGIN{ if(${2:-0}>0) printf \"%.1f\", 100*${1:-0}/${2:-0}; else print \"-\" }"; }

hdr=$(printf "%-28s %7s %6s %7s   %7s %6s %7s   %7s %6s %7s" \
  "repo" "runs" "fail" "rate%" "runs90" "fail90" "rate90%" "runs${SHORT_DAYS}" "fail${SHORT_DAYS}" "rate${SHORT_DAYS}%")
echo "$hdr"
printf '%.0s-' $(seq 1 ${#hdr}); echo

# Aggregate accumulators: (all) sum_t/sum_f, (90d) sum_t90/sum_f90, (short) sum_ts/sum_fs
sum_t=0; sum_f=0; sum_t90=0; sum_f90=0; sum_ts=0; sum_fs=0
for r in "${REPOS[@]}"; do
  wf=$(gh api "repos/$ORG/$r/actions/workflows" \
        --jq ".workflows[] | select(.path==\"$WF_PATH\") | .id" 2>/dev/null | head -1)
  if [ -z "$wf" ]; then
    printf "%-28s %7s\n" "$r" "no-CD"
    continue
  fi
  t=$(count "$r" "$wf" "");                                             t=${t:-0}
  f=$(count "$r" "$wf" "&status=failure");                             f=${f:-0}
  t90=$(count "$r" "$wf" "&created=%3E%3D$SINCE90");                   t90=${t90:-0}
  f90=$(count "$r" "$wf" "&status=failure&created=%3E%3D$SINCE90");    f90=${f90:-0}
  ts=$(count "$r" "$wf" "&created=%3E%3D$SINCE_SHORT");                 ts=${ts:-0}
  fs=$(count "$r" "$wf" "&status=failure&created=%3E%3D$SINCE_SHORT");  fs=${fs:-0}
  printf "%-28s %7s %6s %7s   %7s %6s %7s   %7s %6s %7s\n" \
    "$r" "$t" "$f" "$(rate "$f" "$t")" "$t90" "$f90" "$(rate "$f90" "$t90")" "$ts" "$fs" "$(rate "$fs" "$ts")"
  sum_t=$((sum_t+t));   sum_f=$((sum_f+f))
  sum_t90=$((sum_t90+t90)); sum_f90=$((sum_f90+f90))
  sum_ts=$((sum_ts+ts));    sum_fs=$((sum_fs+fs))
done

printf '%.0s-' $(seq 1 ${#hdr}); echo
printf "%-28s %7s %6s %7s   %7s %6s %7s   %7s %6s %7s\n" \
  "TOTAL (pooled)" "$sum_t" "$sum_f" "$(rate "$sum_f" "$sum_t")" \
  "$sum_t90" "$sum_f90" "$(rate "$sum_f90" "$sum_t90")" \
  "$sum_ts" "$sum_fs" "$(rate "$sum_fs" "$sum_ts")"
