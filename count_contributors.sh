#!/bin/bash

# A shell script to count contributors in one or more GitHub repositories.
#
# It saves the raw JSON API response to a local "./tmp" directory for validation.
# This output directory is NOT cleaned up automatically.
#
# Usage (Option 1: Command-line arguments):
#   ./count_contributors_pro.sh <owner1>/<repo1> <owner2>/<repo2> ...
#   Example: ./count_contributors_pro.sh octocat/Hello-World torvalds/linux
#
# Usage (Option 2: From a file):
#   cat repos.txt | ./count_contributors_pro.sh
#   (where repos.txt contains one "owner/repo" per line)
#
# Requires:
# - The 'PAT' environment variable set to your GitHub Personal Access Token.
# - 'curl' and 'jq' to be installed.

# --- Configuration ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Pre-flight Checks ---

# 1. Check for dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: 'curl' and 'jq' are required. Please install them to continue.${NC}"
  exit 1
fi

# 2. Check for Personal Access Token (PAT)
if [[ -z "$PAT" ]]; then
  echo -e "${RED}Error: The 'PAT' environment variable is not set.${NC}"
  echo -e "Please set it with: ${YELLOW}export PAT=\"ghp_YourTokenHere\"${NC}"
  exit 1
fi

# --- Helper Functions ---

function print_usage() {
  echo -e "${YELLOW}Usage:${NC}"
  echo "  Provide repositories as arguments:"
  echo "    $0 <owner1>/<repo1> <owner2>/<repo2>"
  echo -e "\n  Or pipe a list of repositories (one per line):"
  echo "    cat path/to/repos.txt | $0"
  echo -e "\n${YELLOW}Requires the 'PAT' environment variable to be set.${NC}"
}

# --- Main Processing Function ---

# This function processes a single repository.
# @param $1 - The repository string in "owner/repo" format.
# @param $2 - The directory to save output files.
function process_repo() {
  local repo_full_name=$1
  local output_dir=$2

  # Validate the "owner/repo" format
  if [[ ! "$repo_full_name" == */* ]]; then
    echo -e "-> ${YELLOW}Skipping invalid format:${NC} ${repo_full_name}. Should be 'owner/repo'."
    return
  fi

  local owner=$(echo "$repo_full_name" | cut -d'/' -f1)
  local repo=$(echo "$repo_full_name" | cut -d'/' -f2)

  echo -e "Processing ${CYAN}${repo_full_name}${NC}..."

  local api_url="https://api.github.com/repos/${owner}/${repo}/contributors"
  # Sanitize name for use in a filename
  local file_safe_name=$(echo "${owner}-${repo}" | tr / -)
  local header_file="${output_dir}/${file_safe_name}.headers.txt"
  local body_file="${output_dir}/${file_safe_name}.body.json"

  # Use -D to dump headers to a file and -o to dump body to another
  # We still use per_page=1 for the initial check to be fast.
  local http_status=$(curl -s -w "%{http_code}" -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${PAT}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -D "${header_file}" \
    -o "${body_file}" \
    "${api_url}?per_page=1&anon=1") # anon=1 includes anonymous contributors

  if [[ "$http_status" != "200" ]]; then
    local error_message=$(jq -r '.message' < "${body_file}" 2>/dev/null)
    echo -e "   ${RED}Error:${NC} Failed with status ${http_status}. Message: '${error_message:-N/A}'"
    return
  fi

  # Efficiently check for pagination using the saved header file
  local last_page_link=$(grep -i '^link:' "${header_file}" | grep 'rel="last"')

  local contributor_count
  if [[ -n "$last_page_link" ]]; then
    # Pagination exists. The 'last' page number is the count.
    contributor_count=$(echo "$last_page_link" | sed -n 's/.*page=\([0-9]*\).*/\1/p')
  else
    # No pagination. Count items from the full response body.
    # We must re-fetch, as the first call only got one item.
    curl -s -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${PAT}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -o "${body_file}" \
      "${api_url}?per_page=100&anon=1" # Get up to 100 per page

    contributor_count=$(jq 'length' < "${body_file}")
  fi

  if [[ -n "$contributor_count" && "$contributor_count" -ge 0 ]]; then
      echo -e "   ${GREEN}Success:${NC} Found ${contributor_count} contributors."
  else
      echo -e "   ${RED}Error:${NC} Could not determine the contributor count."
  fi
}

# --- Script Entry Point ---

# Define the output directory in the current working directory
OUTPUT_DIR="./tmp"

# Create the output directory if it doesn't exist.
# Note: This directory will NOT be automatically cleaned up.
mkdir -p "$OUTPUT_DIR"

# Check if input is from command-line arguments or from a pipe/stdin
if [ $# -gt 0 ]; then
  # Loop through all command-line arguments
  for repo_string in "$@"; do
    process_repo "${repo_string}" "${OUTPUT_DIR}"
  done
elif [ ! -t 0 ]; then
  # Read from stdin, line by line
  while IFS= read -r repo_string; do
    # Ignore empty lines
    [[ -n "$repo_string" ]] && process_repo "${repo_string}" "${OUTPUT_DIR}"
  done
else
  print_usage
  exit 1
fi

echo -e "\n${GREEN}Done.${NC}"
echo -e "Raw JSON responses and headers have been saved in the ${YELLOW}${OUTPUT_DIR}/${NC} directory."
echo "This directory is not automatically cleaned up."