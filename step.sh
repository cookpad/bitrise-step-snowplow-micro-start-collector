#!/bin/bash
set -e

schema="https"
interface="staging-collector-snowplow-micro-ios-uitest.cookpad.com/data"
port="9090"

# Wait for server to start
echo "Waiting for the server to become available at $interface:$port..."
while ! nc -z "$interface" "$port"; do
  sleep 1 # TODO: Add a timeout mechanism?
done

# Test the server
echo "Resting the Snowplow Microcollector at $httpschema://$interface:$port/micro/reset..."
result=$(curl --silent "$httpschema://$interface:$port/micro/reset")

# Parse the results
total=$(jq -r '.total' <<< "$result")

# Check if there are any active events 
if [[ $total -gt 0 ]]
then
  echo "The Snowplow micro failed to reset."
  exit 1
fi

# Export collector info
echo "Exporting \$SNOWPLOW_MICRO_COLLECTOR_URL $httpschema://$interface:$port"
envman add --key SNOWPLOW_MICRO_COLLECTOR_URL --value "$httpschema://$interface:$port"

# Add $micro_dir to the cache
echo "Adding $micro_dir to \$BITRISE_CACHE_INCLUDE_PATHS"
cache_dir="${BITRISE_CACHE_INCLUDE_PATHS}
${SNOWPLOW_MICRO_COLLECTOR_URL}"
envman add --key BITRISE_CACHE_INCLUDE_PATHS --value "$cache_dir"
