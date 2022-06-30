#!/bin/bash
set -e

httpschema="https"
interface="snowplow-micro-ios.production.data.global-services.ckpd.co"

# Test the server
echo "Resting the Snowplow Microcollector at $httpschema://$interface/micro/reset..."
result=$(curl --silent "$httpschema://$interface/micro/reset")

# Parse the results
total=$(jq -r '.total' <<< "$result")

# Check if there are any active events 
if [[ $total -gt 0 ]]
then
  echo "The Snowplow micro failed to reset."
  exit 1
else
  echo "Snowplow Micro started, currently there are $total events"
fi

# Export collector info
echo "Exporting \$CP_BITRISE_SNOWPLOW_MICRO_COLLECTOR_URL $httpschema://$interface"
envman add --key CP_BITRISE_SNOWPLOW_MICRO_COLLECTOR_URL --value "$httpschema://$interface"

# Add $micro_dir to the cache
echo "Adding $micro_dir to \$BITRISE_CACHE_INCLUDE_PATHS"
cache_dir="${BITRISE_CACHE_INCLUDE_PATHS}
${SNOWPLOW_MICRO_COLLECTOR_URL}"
envman add --key BITRISE_CACHE_INCLUDE_PATHS --value "$cache_dir"
