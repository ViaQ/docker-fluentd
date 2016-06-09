#!/bin/bash

# This is the most basic test. If container did not start correctly then print out logs and exit.

set -ev

# Give the container some room to start up
sleep 5 
docker ps -a

CONTAINER_ID=$(docker ps -aq)
STATUS=$(docker inspect -f {{.State.Running}} $CONTAINER_ID)

if [ "$STATUS" == "false" ]; then
  echo "CRITICAL - $CONTAINER_ID is not running. Check logs:"
  docker logs $CONTAINER_ID
  exit 2
fi

curl localhost:24220/api/plugins.json | jq
