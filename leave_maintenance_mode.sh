#! /usr/bin/env sh

declare -a default_apps=("arbeitnehmerverwaltung" "arbeitsentgelt-production" "freigabe-production" "rechnungsstellung-production" "sv-einordnung-production")
# run with default apps or apps provided via command-line arguments
apps=("${@:-${default_apps[@]}}")

# Confirm user wants to do this
while true; do
  read -p "Leave maintenance mode for ${apps[*]}? (y/n)" choice
  case "${choice}" in
    [Yy]* ) break;;
    [Nn]* ) echo "Aborting..."; exit 0;;
    * ) echo "Please answer yes or no.";;
  esac
done

disable_maintenance() {
  app=${1:?'Must pass app to disable maintenace on'}
  echo "Waiting for ${app} to be available..."
  heroku ps:wait --app ${app}
  echo "Disabling maintenance mode of ${app}"
  heroku maintenance:off --app ${app}
}

for app in "${apps[@]}"; do
  echo ""
  echo "Starting ${app}..."
  heroku ps:scale web=1 --app ${app}
  # run in background:
  disable_maintenance ${app} &
done

# wait for subprocesses to finish
wait $(jobs -p)
