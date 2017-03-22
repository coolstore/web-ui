#!/bin/bash
set -e


################################################################################
# BASE CONFIGURATION                                                           #
################################################################################
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
SCRIPT_NAME=$(basename $0)
BASE_DIR=$(cd $SCRIPT_DIR/.. && pwd)
MODULE_NAME=web-ui

if [ ! -f ${BASE_DIR}/common/common.sh ]; then
  echo "Missing file ../common/common.sh. Please make sure that all required modules are downloaded or run the download.sh script from $BASE_DIR."
  exit
fi

source ${BASE_DIR}/common/common.sh





################################################################################
# FUNCTIONS                                                                    #
################################################################################

function build_local() {
  pushd src > /dev/null
  echo_header "Creating the build configuration and image stream"
  
  oc get bc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A build config for $MODULE_NAME already exists, skipping" || { oc new-build openshift/nodejs:4 --name=$MODULE_NAME --binary > /dev/null; }

  echo_header "Starting build"
  if oc get build 2>/dev/null | grep "^$MODULE_NAME" | grep -q Complete; then
    echo "Existing complete build exists"
    if $REBUILD; then
      echo "Rebuilding since the rebuild flag is set"
      npm install
      oc start-build $MODULE_NAME --from-dir=. > /dev/null;
    fi
  else
    npm install
    oc start-build $MODULE_NAME --from-dir=. > /dev/null;
  fi  

  popd > /dev/null
  # wait_while_empty "$MODULE_NAME starting build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | grep Running"
  # wait_while_empty "$MODULE_NAME build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | tail -1 | grep -v Running" 

}

function create_service_and_route() {
  
  if ! $BUILD_ONLY; then
    sleep 2 # Make sure that builds are started
    echo_header "Checking that build is done..."
    # First check that there is a build
    #wait_while_empty "$MODULE_NAME build exists" 600 "oc get builds 2>/dev/null | grep \"^$MODULE_NAME\"" 
    # Then check that it's Complete
    #wait_while_empty "$MODULE_NAME build" 600 "oc get builds 2>/dev/null | grep \"^$MODULE_NAME\" | tail -1 | grep -v Complete" 
    
    # echo_header "Creating application"
    # oc get svc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A service named $MODULE_NAME already exists, skipping" || { oc new-app $MODULE_NAME -e COOLSTORE_GW_ENDPOINT=${COOLSTORE_GW_ENDPOINT} > /dev/null; }

    # echo_header "Exposing the route"
    # oc get route/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A route named $MODULE_NAME already exists, skipping" || { oc expose service $MODULE_NAME > /dev/null; }

    if ! oc get build 2>/dev/null | grep "^$MODULE_NAME"| grep -q Complete || $REBUILD; then

      local _PARAMS=() #an empty array
      if [ ! -z ${COOLSTORE_GW_ENDPOINT} ]; then
        _PARAMS=(${_PARAMS[@]} "-v" "COOLSTORE_GW_ENDPOINT=${COOLSTORE_GW_ENDPOINT}")
      fi

      if [ ! -z ${SSO_URL} ]; then
          _PARAMS=(${_PARAMS[@]} "-v" "SSO_ENABLED=true" "-v" "SSO_URL=${SSO_URL}")
      fi
    
      if oc get svc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME"; then
        oc process -f main-template.yaml | oc delete -f -
      fi

      oc process -f main-template.yaml ${_PARAMS[@]} | oc create -f -
    fi
    
  fi
}

function configure_sso_client {
  if [ ! -z $SSO_URL ]; then 
    echo_header "Adding web-ui SSO client"
    oc get configmaps 2>/dev/null | grep -q "^sso-client-config-files" && echo "A configmap with named sso-client-config-files already exists, skipping" || oc create configmap sso-client-config-files --from-file=config
    oc get pods -a | grep -q config-sso-webui && echo "A config-sso-webui pod already exists, skipping" || oc process -f config-sso.yaml COOLSTORE_WEB_URI=$MODULE_NAME-$HOST_SUFFIX SSO_SERVICE_URL=${SSO_URL}| oc create -f -
  fi
}

pushd $SCRIPT_DIR > /dev/null

build_local

configure_sso_client

create_service_and_route

popd  > /dev/null

















