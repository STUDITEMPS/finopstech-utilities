#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

PROJECT_DIR="$(dirname "$0")"
USAGE='
  heroku-psql-upgrade.sh [--debug] [-h|--help] [--add-follower] [--upgrade-existing-follower] [--confirm] [app_name ...]"

  Upgrades Postgres Databases for passed apps. App will be put into maintenance mode and all dynos shut off before upgrading.

  ================================== OPTIONS ==================================
  --debug                       Enables xtrace option, echoing all commands as
                                they are executed.
  --help|-h                     Display this message.
  --add-follower                Add a follower after upgrading the database.
  --upgrade-existing-follower   Upgrades an existing follower instead of
                                creating a blank new database and copying the
                                old database to it and then upgrading it.
  --confirm                     automatically confirm all destructive actions'

ADD_FOLLOWER=false
USE_COPY=true
AUTO_CONFIRM=false
APPS=()
PASS_THROUGH_OPTIONS=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) set -o xtrace; PASS_THROUGH_OPTIONS+=("--debug"); shift ;;
        -h|--help) echo "$USAGE"; exit 0; shift ;;
        --add-follower) ADD_FOLLOWER=true; shift ;;
        --upgrade-existing-follower) USE_COPY=false; shift ;;
        --confirm) AUTO_CONFIRM=true; PASS_THROUGH_OPTIONS+=("--confirm"); shift ;;
        *) APPS+=($1)
        shift
        ;;
    esac
done

if [[ ${#APPS[@]} == 0 ]]; then
  echo ${USAGE}
  exit 1
fi

for app in ${APPS[@]}; do
  echo "Upgrading postgres database for app: ${app}."
  echo ""
  echo -n "Determine plan ... "
  plan=$(heroku addons:info DATABASE_URL --app $app | grep 'Plan:' | sed -E 's/Plan: +//')
  echo ${plan}
  echo -n "Determine old database additional attachment name ... "
  old_db=$(heroku pg:info DATABASE_URL --app $app | grep '=== DATABASE_URL,' | sed -E 's/=== DATABASE_URL, +//')
  echo ${old_db}
  if $USE_COPY; then
    new_db_name=$(heroku addons:create $plan --app $app | grep -oE 'postgresql-[^ ]+' | head -n1)
    heroku pg:wait --app $app
    new_db=$(heroku addons:info $new_db_name | grep -oE 'HEROKU_POSTGRESQL_.+$')

    ${PROJECT_DIR}/enter-maintenance-mode.sh ${PASS_THROUGH_OPTIONS[@]} $app

    echo "Will copy ${old_db} to ${new_db} ..."
    if $AUTO_CONFIRM; then
      heroku pg:copy DATABASE_URL $new_db --app $app --confirm $app
    else
      heroku pg:copy DATABASE_URL $new_db --app $app
    fi
    heroku pg:promote $new_db --app $app || true
  else
    followers_string=$(heroku pg:info DATABASE_URL --app $app | grep 'Followers:' | sed -E 's/Followers: +//')
    followers=(${followers_string//,/})
    follower=${followers[0]}
    ${PROJECT_DIR}/enter-maintenance-mode.sh ${PASS_THROUGH_OPTIONS[@]} $app
    echo "Will upgrade & promote ${follower} and thereby demote ${old_db} ..."
    if $AUTO_CONFIRM; then
      heroku pg:upgrade $follower --app $app --confirm $app || true
    else  
      heroku pg:upgrade $follower --app $app || true
    fi
    heroku pg:wait --app $app
    heroku pg:promote $new_db --app $app || true
  fi
  
  ${PROJECT_DIR}/leave-maintenance-mode.sh ${PASS_THROUGH_OPTIONS[@]} $app

  if ${ADD_FOLLOWER}; then
    echo "Adding follower..."
    heroku addons:create $plan --follow DATABASE_URL --app $app
  fi

  echo "Destroy old database ${old_db} ..."
  followers_of_old_db_string=$(heroku pg:info $old_db --app $app | grep 'Followers:' | sed -E 's/Followers: +//')
  if $AUTO_CONFIRM; then
    heroku addons:destroy $old_db --app $app --confirm $app
  else
    heroku addons:destroy $old_db --app $app
  fi

  followers_of_old_db=(${followers_of_old_db_string//,/})
  echo "Also destroy followers ${followers_of_old_db[@]} ..."
  for follower in ${followers_of_old_db[@]}; do
      heroku addons:destroy $follower --app $app
    done
done
