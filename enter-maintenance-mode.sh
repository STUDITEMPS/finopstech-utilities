#! /usr/bin/env sh

set -o nounset
set -o errexit
set -o pipefail

function require() {
  cmd=${1:?"Must pass program name"}
  if ! command -v $cmd &> /dev/null; then
      echo "$cmd could not be found, please install"
      exit 1
  fi
}

require heroku
require jq

USAGE='enter-maintenance-mode.sh [--debug] [-h|--help] [--add-dyno-type type ...] [--confirm boolean] [app_name ...]"

  Enter maintenance mode for provided apps. Will also scale all web dynos for those apps to zero.
  Passing --add-dyno-type will assume direct control over which dyno types to scale down.

  ================================== OPTIONS ==================================
  --debug                     Enables xtrace option, echoing all commands as
                              they are executed.
  --help|-h                   Display this message.
  --add-dyno-type type        Instead of scaling the web dyno (default) we can
                              pass this option to assume direct control over
                              what dyno types to scale down. This flag can be
                              passed repeatedly.
  --confirm boolean           automatically confirm entering maintenance mode'

APPS=()
DYNO_TYPES=()
CONFIRM=false
ALL_DYNO_TYPES=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) set -o xtrace; shift ;;
        -h|--help) echo "$USAGE"; exit 0; shift ;;
        --add-dyno-type) shift; DYNO_TYPES+=($1); shift ;;
        --confirm) CONFIRM=true; shift ;;
        *) APPS+=($1); shift ;;
    esac
done

declare -a DEFAULT_APPS=("arbeitnehmerverwaltung-prod" "arbeitsentgelt-production" "freigabe-production" "rechnungsstellung-production" "sv-einordnung-production")
if [ ${#APPS[@]} -eq 0 ]; then
  APPS=${DEFAULT_APPS[@]}
fi
if [ ${#DYNO_TYPES[@]} -eq 0 ]; then
  ALL_DYNO_TYPES=true
fi

if ! ${CONFIRM}; then
  read -p "Enter maintenance mode for ${APPS[*]}? (y/n)" -n 1 -r
  >&2 echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    exit 1
  fi
fi

for app in "${APPS[@]}"; do
  echo "Putting ${app} in maintenance mode"
  heroku maintenance:on --app ${app}
  heroku ps --app ${app} --json | jq --raw-output 'map(.type)|group_by(.)[]|.[0] + "=" + (length|tostring)' > ".heroku_dyno_scales_before_for_${app}"
  if ${ALL_DYNO_TYPES}; then
    cat ".heroku_dyno_scales_before_for_${app}" \
    | cut -d= -f1 \
    | xargs -I{} heroku ps:scale {}=0 --app ${app}
  else
    for dyno_type in ${DYNO_TYPES[@]}; do
      heroku ps:scale ${dyno_type}=0 --app ${app}
    done
    scaled_dynos=$(printf '%s\n' "${DYNO_TYPES[@]}" | grep -f - ".heroku_dyno_scales_before_for_${app}")
    echo "${scaled_dynos}" > ".heroku_dyno_scales_before_for_${app}"
  fi
done
