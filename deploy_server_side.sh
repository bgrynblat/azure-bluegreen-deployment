#!/bin/bash

# ----------------------
# KUDU Deployment Script
# Version: 1.0.8
# ----------------------

# Helpers
# -------

exitWithMessageOnError () {
  if [ ! $? -eq 0 ]; then
    echo "An error has occurred during web site deployment."
    echo $1
    exit 1
  fi
}

# Prerequisites
# -------------

# Verify node.js installed
hash node 2>/dev/null
exitWithMessageOnError "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."

# Setup
# -----

SCRIPT_DIR="${BASH_SOURCE[0]%\\*}"
SCRIPT_DIR="${SCRIPT_DIR%/*}"
ARTIFACTS=$SCRIPT_DIR/../artifacts
KUDU_SYNC_CMD=${KUDU_SYNC_CMD//\"}

if [[ ! -n "$DEPLOYMENT_SOURCE" ]]; then
  DEPLOYMENT_SOURCE=$SCRIPT_DIR
fi

if [[ ! -n "$NEXT_MANIFEST_PATH" ]]; then
  NEXT_MANIFEST_PATH=$ARTIFACTS/manifest

  if [[ ! -n "$PREVIOUS_MANIFEST_PATH" ]]; then
    PREVIOUS_MANIFEST_PATH=$NEXT_MANIFEST_PATH
  fi
fi

if [[ ! -n "$DEPLOYMENT_TARGET" ]]; then
  DEPLOYMENT_TARGET=$ARTIFACTS/wwwroot
else
  KUDU_SERVICE=true
fi

if [[ ! -n "$KUDU_SYNC_CMD" ]]; then
  # Install kudu sync
  echo Installing Kudu Sync
  npm install kudusync -g --silent
  exitWithMessageOnError "npm failed"

  if [[ ! -n "$KUDU_SERVICE" ]]; then
    # In case we are running locally this is the correct location of kuduSync
    KUDU_SYNC_CMD=kuduSync
  else
    # In case we are running on kudu service this is the correct location of kuduSync
    KUDU_SYNC_CMD=$APPDATA/npm/node_modules/kuduSync/bin/kuduSync
  fi
fi

# Node Helpers
# ------------

selectNodeVersion () {
  if [[ -n "$KUDU_SELECT_NODE_VERSION_CMD" ]]; then
    SELECT_NODE_VERSION="$KUDU_SELECT_NODE_VERSION_CMD \"$DEPLOYMENT_SOURCE\" \"$DEPLOYMENT_TARGET\" \"$DEPLOYMENT_TEMP\""
    eval $SELECT_NODE_VERSION
    exitWithMessageOnError "select node version failed"

    if [[ -e "$DEPLOYMENT_TEMP/__nodeVersion.tmp" ]]; then
      NODE_EXE=`cat "$DEPLOYMENT_TEMP/__nodeVersion.tmp"`
      exitWithMessageOnError "getting node version failed"
    fi

    if [[ -e "$DEPLOYMENT_TEMP/__npmVersion.tmp" ]]; then
      NPM_JS_PATH=`cat "$DEPLOYMENT_TEMP/__npmVersion.tmp"`
      exitWithMessageOnError "getting npm version failed"
    fi

    if [[ ! -n "$NODE_EXE" ]]; then
      NODE_EXE=node
    fi

    NPM_CMD="\"$NODE_EXE\" \"$NPM_JS_PATH\""
  else
    NPM_CMD=npm
    NODE_EXE=node
  fi
}

##################################################################################################################################
# Deployment
# ----------

echo Handling node.js deployment.

# 1. KuduSync
if [[ "$IN_PLACE_DEPLOYMENT" -ne "1" ]]; then
  "$KUDU_SYNC_CMD" -v 50 -f "$DEPLOYMENT_SOURCE" -t "$DEPLOYMENT_TARGET" -n "$NEXT_MANIFEST_PATH" -p "$PREVIOUS_MANIFEST_PATH" -i ".git;.hg;.deployment;deploy.sh"
  exitWithMessageOnError "Kudu Sync failed"
fi

# 2. Select node version
selectNodeVersion

# 3. Install Yarn
# echo 'Verifying Yarn Install.'
# eval $NPM_CMD install yarn -g

# 3. Install npm packages
if [ -e "$DEPLOYMENT_TARGET/package.json" ]; then
  cd "$DEPLOYMENT_TARGET"
  npm install
  exitWithMessageOnError "npm install failed"
  cd - > /dev/null
fi

# Stuff added specific to this project, not included when we ran `azure site deploymentscript --node`
# 4. Install npm packages for shared-modules
# echo 'Running yarn install for /shared-modules.'
# cd "$DEPLOYMENT_TARGET/shared-modules"
# yarn install --production
# exitWithMessageOnError "yarn install failed for /shared-modules"
# cd - > /dev/null

# 5. Install npm packages for server
# echo 'Running yarn install for /server.'
# cd "$DEPLOYMENT_TARGET/server"
# yarn install --ignore-engines --production
# exitWithMessageOnError "yarn install failed for /server"
# cd - > /dev/null

# 6. Strip flow types from /server
# echo 'Running yarn remove-flow-types  for /server.'
# cd "$DEPLOYMENT_TARGET/server"
# yarn remove-flow-types
# exitWithMessageOnError "yarn remove-flow-types failed for /server"
# cd - > /dev/null

# 7. Strip flow types from /shared-modules
# echo 'Running yarn remove-flow-types  for /shared-modules.'
# cd "$DEPLOYMENT_TARGET/shared-modules"
# yarn remove-flow-types
# exitWithMessageOnError "yarn remove-flow-types failed for /shared-modules"
# cd - > /dev/null

# # 8. Run migrations
# echo 'Running sequelize database migrations.'
# cd "$DEPLOYMENT_TARGET/server"
# yarn db:migrate
# exitWithMessageOnError "database migrations failed"
# cd - > /dev/null

pm2 logs >> deploy.log
echo "=======================================" >> deploy.log
pm2 status >> deploy.log
echo "=======================================" >> deploy.log
echo "=======================================" >> deploy.log
echo "=======================================" >> deploy.log
ps -aef | grep node >> deploy.log

echo "Uploading deploy log..."
curl --upload-file deploy.log https://transfer.sh/deploy.log

##################################################################################################################################
echo "Finished successfully."
