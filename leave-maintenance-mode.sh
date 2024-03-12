#! /usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

USAGE='leave-maintenance-mode.sh [--debug] [-h|--help] [--add-dyno-type type=count ...] [--confirm] [app_name ...]"

  leave maintenance mode for provided apps. Will also scale all web dynos for those apps to one.
  Passing --add-dyno-type will assume direct control over which dyno types to scale up and to what number.

  ================================== OPTIONS ==================================
  --debug                     Enables xtrace option, echoing all commands as
                              they are executed.
  --help|-h                   Display this message.
  --add-dyno-type type=count  Instead of scaling the web dyno to 1 (default) we
                              can pass this option to assume direct control
                              over what dyno types to up and to what number.
                              This flag can be passed repeatedly.
  --confirm                   automatically confirm entering maintenance mode'

APPS=()
DYNO_TYPE_CONFIGS=()
CONFIRM=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) set -o xtrace; shift ;;
        -h|--help) echo "$USAGE"; exit 0; shift ;;
        --add-dyno-type)
          shift
          if [[ "$1" == *"="* ]]; then
            DYNO_TYPE_CONFIGS+=($1)
          else
            echo "Error: --add-dyno-type must specify dyno type and scale target like this web=2"
            exit 1
          fi
          shift
          ;;
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

disable_maintenance() {
  app=${1:?'Must pass app to disable maintenace on'}
  echo "Waiting for ${app} to be available..."
  heroku ps:wait --app ${app}
  echo "Disabling maintenance mode of ${app}"
  heroku maintenance:off --app ${app}
}

declare -a DEFAULT_APPS=("arbeitnehmerverwaltung-prod" "arbeitsentgelt-production" "freigabe-production" "rechnungsstellung-production" "sv-einordnung-production")
if [ ${#APPS[@]} -eq 0 ]; then
  APPS=${DEFAULT_APPS[@]}
fi
if [ ${#DYNO_TYPE_CONFIGS[@]} -eq 0 ]; then
  DYNO_TYPE_CONFIGS=('web=1')
fi

if ! ${CONFIRM}; then
  read -p "Leave maintenance mode for ${APPS[*]}? (y/n)" -n 1 -r
  >&2 echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    exit 1
  fi
fi

for app in "${APPS[@]}"; do
  for dyno_type_config in ${DYNO_TYPE_CONFIGS[@]}; do
    heroku ps:scale ${dyno_type_config} --app ${app}
  done
  disable_maintenance ${app} &
done

# wait for subprocesses to finish
wait $(jobs -p)