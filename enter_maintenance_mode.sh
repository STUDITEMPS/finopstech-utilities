#! /usr/bin/env sh

declare -a default_apps=("arbeitnehmerverwaltung" "arbeitsentgelt-production" "freigabe-production" "rechnungsstellung-production" "sv-einordnung-production")
# run with default apps or apps provided via command-line arguments
apps=("${@:-${default_apps[@]}}")

# Confirm user wants to do this
while true; do
  read -p "Enter maintenance mode for ${apps[*]}? (y/n)" choice
  case "${choice}" in
    [Yy]* ) break;;
    [Nn]* ) echo "Aborting..."; exit 0;;
    * ) echo "Please answer yes or no.";;
  esac
done

for app in "${apps[@]}"; do
  echo "Putting ${app} in maintenance mode"
  heroku maintenance:on --app ${app}
  heroku ps:scale web=0 --app ${app}
done
