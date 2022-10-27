#!/usr/bin/env bash


app=${1:?'Must provide heroku application name on which attached pg databases should be upgraded'}

plan=$(heroku addons:info DATABASE_URL --app $app | grep 'Plan:' | sed -E 's/Plan: +//')
set -o xtrace


new_db_name$(heroku addons:create $plan --app $app | grep -oE 'postgresql-[^ ]+')
new_db=$(heroku addons:info $new_db_name | grep -oE 'HEROKU_POSTGRESQL_.+$')
heroku pg:wait --app $app
heroku maintenance:on --app $app
heroku pg:copy DATABASE_URL $new_db --app $app
old_db=$(heroku pg:promote $new_db --app $app | grep -oE 'HEROKU_POSTGRESQL_.+$')
set +o xtrace
echo ""
echo "Maybe add followers via:"
echo "heroku addons:create $plan --follow DATABASE_URL --app $app"
echo ""
set -o xtrace
heroku maintenance:off --app $app
heroku addons:detach $new_db --app $app
heroku addons:destroy $old_db --app $app
echo "also find and destroy any followers of $old_db"