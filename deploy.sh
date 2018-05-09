#!/bin/bash

function failed_deployment(){
  red="\033[01;31m"
  reset="\033[00m"
  echo
  echo -e "${red}"
  echo "Deployment failed or cancelled on line $1"
  echo -e "${reset}"
  echo
  git checkout $current_branch
}

function section_subheading() {
  green="\033[01;32m"
  reset="\033[00m"

  echo
  echo -e "${green}"
  echo "$[SECONDS]s: $1"
  echo -e "${reset}"
  echo
}

function echo_in_red() {
  red="\033[01;31m"
  reset="\033[00m"

  echo -e "${red}$1${reset}"
}

set -e

SECONDS=0
echo "$[SECONDS]s: Deploying to production at time $(date) from host $(hostname)"
echo "$[SECONDS]s: DO NOT make any changes to the code or perform any git operations until deployment has finished"

current_branch="$(git rev-parse --abbrev-ref HEAD)"

cd $(dirname "${0}")

trap 'failed_deployment $LINENO' ERR SIGHUP SIGINT SIGTERM

# Set up deploy branch
section_subheading "Creating deploy branch from master..."
git branch -D deploy 2> /dev/null || true
git branch deploy master
git checkout deploy

# No need to build server files - webpack doesn't require them...

# section_subheading "Building frontend..."
# # Build modules files
# cd shared-modules
# yarn --ignore-engines
# cd ..

# # Build client files
# cd client
# yarn
# rm -rf public/
# yarn build
# cd ..

# rsync -rvP ./client/build/ ./public/

# section_subheading "Uploading source maps to Bugsnag..."

# # Upload source maps for bugsnag, since the files on the server are not public, so bugsnag can't get them
# minified_file=`ls client/build | grep -E 'app-.*.js$'`
# source_map_file=`ls client/build | grep -E 'app-.*.js.map$'`

# curl https://upload.bugsnag.com/ \
#    -F apiKey=4c04c0410c58e3e2aea6d051294e4989 \
#    -F minifiedUrl="https://nswedubiclusterplanning.azurewebsites.net/${minified_file}" \
#    -F sourceMap=@"client/build/${source_map_file}" \
#    -F minifiedFile=@"client/build/${minified_file}" \
#    -F overwrite=true

# section_subheading "Making commit..."
# git add -f public
# git commit --no-verify -m "Deployment"

section_subheading "Pushing to Azure..."
git push -f azure-production deploy:master

section_subheading "Removing deploy branch..."

git checkout $current_branch
git branch -D deploy 2> /dev/null || true


commit_hash=`git rev-parse HEAD`

# section_subheading "Notifying bugsnag server project of deploy ${commit_hash}..."

# curl https://notify.bugsnag.com/deploy \
#    -F apiKey=4ef08b48433720e532c1e3cf43f707c7 \
#    -F repository=git@github.com:smallmultiples/doe-cluster-planning.git \
#    -F revision=${commit_hash}

# section_subheading "Notifying bugsnag client project of deploy ${commit_hash}..."

# curl https://notify.bugsnag.com/deploy \
#    -F apiKey=4c04c0410c58e3e2aea6d051294e4989 \
#    -F repository=git@github.com:smallmultiples/doe-cluster-planning.git \
#    -F revision=${commit_hash}

section_subheading "Deployment finished. Check the output from 'Pushing to Azure' to ensure it was successful."

