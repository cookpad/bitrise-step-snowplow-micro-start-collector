#!/bin/bash
set -e

# Check that collector_config exists
if [ ! -f "$collector_config" ]
then
  echo "Error: collector_config at $collector_config does not exist"
  exit 1
fi

# Check that iglu eixsts
if [ ! -f "$iglu" ]
then
  echo "Error: iglu at $iglu does not exist"
  exit 1
fi

# Resolve the latest version if we need to
echo "Request server version: $micro_version"
if [[ "$micro_version" == "latest" ]]
then
  # See which tag the HTTP request is redirected to (can't use API due to unauthenticated rate limits)
  micro_version=$(curl -I --silent https://github.com/snowplow-incubator/snowplow-micro/releases/latest | grep -iF location: | sed -E 's/\r$//' | sed -E 's/^.*tag\/(.*)$/\1/')

  if [[ "$micro_version" == "" ]];
  then
    echo "Failed to detect latest version of Snowplow Micro"
    exit 1
  else
    echo "Latest version is $micro_version"
  fi
fi

# Create the directory for the server jar files if it doesn't already exist
micro_dir="$HOME/.snowplow/micro"
mkdir -p "$micro_dir"

# Define where the .jar will live for the requested version
jar="$micro_dir/snowplow-$micro_version.jar"

# Download the jar if it does not already exist
if [ ! -f "$jar" ]
then
  echo "Downloading Snowplow Micro to $jar"
  wget --directory-prefix "$micro_dir" "https://github.com/snowplow-incubator/snowplow-micro/releases/download/$micro_version/snowplow-$micro_version.jar"
else
  echo "Found $micro_version at $jar"
fi

# Read the interface and port from the config
# FIXME: Find a better way to read this from the .conf
interface=$(cat "$collector_config" | grep -m 1 'interface =' | sed -E 's/.*"([^"]+)".*/\1/')
port=$(cat "$collector_config" | grep -m 1 'port =' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Read from configuration: interface: $interface, port: $port"

# Start the server
echo "Starting server..."
java -jar "$jar" --collector-config "$collector_config" --iglu "$iglu" &>/dev/null &

# Wait for server to start
echo "Waiting for the server to become available at $interface:$port..."
while ! nc -z "$interface" "$port"; do
  sleep 0.1 # TODO: Add a timeout mechanism?
done

# Test the server
echo "Testing the REST api..."
curl --silent "http://$interface:$port/micro/all"
printf "\n"

# Export collector info
echo "Exporting \$SNOWPLOW_MICRO_COLLECTOR_INTERFACE ($interface) and \$SNOWPLOW_MICRO_COLLECTOR_PORT ($port)"
envman add --key SNOWPLOW_MICRO_COLLECTOR_INTERFACE --value "$interface"
envman add --key SNOWPLOW_MICRO_COLLECTOR_PORT --value "$port"

# Add $micro_dir to the cache
echo "Adding $micro_dir to \$BITRISE_CACHE_INCLUDE_PATHS"
cache_dir="${BITRISE_CACHE_INCLUDE_PATHS}
${micro_dir}"
envman add --key BITRISE_CACHE_INCLUDE_PATHS --value "$cache_dir"
