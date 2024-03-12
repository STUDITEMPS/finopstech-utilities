#! /usr/bin/env sh

set -o nounset
set -o errexit
set -o pipefail

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
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) set -o xtrace; shift ;;
        -h|--help) echo "$USAGE"; exit 0; shift ;;
        --add-dyno-type) shift; DYNO_TYPES+=($1); shift ;;
        --confirm) shift;
          case $1 in
            true|1|yes) CONFIRM=true ;;
            false|0|no) CONFIRM=false ;;
          esac
          shift
          ;;
        *) APPS+=($1); shift ;;
    esac
done

declare -a DEFAULT_APPS=("arbeitnehmerverwaltung-prod" "arbeitsentgelt-production" "freigabe-production" "rechnungsstellung-production" "sv-einordnung-production")
if [ ${#APPS[@]} -eq 0 ]; then
  APPS=${DEFAULT_APPS[@]}
fi
if [ ${#DYNO_TYPES[@]} -eq 0 ]; then
  DYNO_TYPES=('web')
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
  for dyno_type in ${DYNO_TYPES[@]}; do
    heroku ps:scale ${dyno_type}=0 --app ${app}
  done
done
