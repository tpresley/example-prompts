#!/bin/bash

# Check if both arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <api_key> <agent_id>"
  exit 1
fi

API_KEY=$1
AGENT_ID=$2

# Set base URL
BASE_URL="https://api.kindo.ai/v1"

# Function to get run ID from the response
get_run_id() {
  echo "$1" | grep -o '"runId":"[^"]*"' | cut -d'"' -f4
}

# Function to poll for run results
poll_run_results() {
  local run_id=$1
  local attempt=0
  local max_attempts=60
  
  echo "Waiting"
  
  while [ $attempt -lt $max_attempts ]; do
    # Get run status
    response=$(curl -s -H "x-api-key: $API_KEY" "$BASE_URL/runs/$run_id")
    status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    # Print dots while waiting
    if [ "$status" == "in_progress" ]; then
      echo -n "."
      sleep 2
      ((attempt++))
    elif [ "$status" == "success" ]; then
      # Print result on success
      result=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
      echo -e "\nAgent run completed successfully.\n\nResult:\n\n$result\n\n"
      return
    else
      # Print error for other statuses
      echo -e "\nError: Run status is $status. Exiting polling."
      return
    fi
  done
  
  # Timeout message
  echo -e "\nError: Timeout. No results found after 120 seconds."
}

# Find config files
config_files=""
for file in *.bck *.tcp *.conf *.BCK *.TCP *.CONF; do
  if [ -f "$file" ]; then
    config_files="$config_files\n\n#######$file#######\n\n$(cat $file)"
  fi
done

# Run agent
run_response=$(curl -s -X POST \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"agentId\":\"$AGENT_ID\",\"inputs\":[{\"name\":\"Configurations\",\"value\":\"$config_files\"}]}" \
  "$BASE_URL/agents/runs")

run_id=$(get_run_id "$run_response")
if [ -z "$run_id" ]; then
  echo "Error: Run ID not returned in response."
  exit 1
fi

echo "Agent run initiated. Run ID: $run_id"

# Poll for results
poll_run_results "$run_id"
