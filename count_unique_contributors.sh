#!/bin/bash

# A shell script to count the total number of UNIQUE contributors
# across one or more GitHub repositories and list their usernames.
#
# It saves the raw JSON response for EACH page of contributors to a
# local "./tmp" directory for validation.
#
# Usage (Option 1: Command-line arguments):
#   ./count_unique_contributors.sh <owner1>/<repo1> <owner2>/<repo2> ...
#
# Usage (Option 2: From a file):
#   cat repos.txt | ./count_unique_contributors.sh
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

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: 'curl' and 'jq' are required. Please install them to continue.${NC}"
  exit 1
fi

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
  echo -e "\n${YELLOW}This script calculates and lists the UNIQUE contributors across all repos.${NC}"
}

# This function fetches ALL contributors for a single repository by following
# pagination links and appends their logins to a master file.
# @param $1 - The repository string "owner/repo".
# @param $2 - The path to the temporary file for all logins.
# @param $3 - The path to a temporary file for headers.
# @param $4 - The path to the persistent output directory for JSON files.
function fetch_all_contributors_for_repo() {
  local repo_full_name=$1
  local master_login_file=$2
  local header_file=$3
  local output_dir=$4

  if [[ ! "$repo_full_name" == */* ]]; then
    echo -e "-> ${YELLOW}Skipping invalid format:${NC} ${repo_full_name}. Should be 'owner/repo'."
    return
  fi

  echo -e "Fetching all contributors for ${CYAN}${repo_full_name}${NC}..."

  local owner=$(echo "$repo_full_name" | cut -d'/' -f1)
  local repo=$(echo "$repo_full_name" | cut -d'/' -f2)
  local file_safe_name=$(echo "${owner}-${repo}" | tr / -)
  local api_url="https://api.github.com/repos/${owner}/${repo}/contributors"

  local next_url="${api_url}?per_page=100&anon=1"
  local page_num=1

  while [[ -n "$next_url" ]]; do
    local body_file="${output_dir}/${file_safe_name}.page-${page_num}.json"

    # Fetch the current page, saving headers to a temp file and body to a persistent file
    local http_status=$(curl -s -w "%{http_code}" -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${PAT}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -D "${header_file}" \
      -o "${body_file}" \
      "${next_url}")

    if [[ "$http_status" != "200" || ! -s "$body_file" ]]; then
        local error_message=$(jq -r '.message' < "${body_file}" 2>/dev/null)
        echo -e "   ${RED}Error:${NC} Failed to fetch page ${page_num} for ${repo_full_name}. Status: ${http_status}. Message: '${error_message:-N/A}'"
        break # Stop processing this repo on error
    fi

    # Append contributor logins from the saved file to the master list
    jq -r '.[] | .login' < "${body_file}" >> "${master_login_file}"

    # Find the URL for the 'next' page
    next_url=$(grep -i '^link:' "${header_file}" | grep 'rel="next"' | sed -n 's/.*<\(.*\)>; rel="next".*/\1/p')

    if [[ -n "$next_url" ]]; then
        echo -n "." # Progress indicator
    fi
    page_num=$((page_num + 1))
  done
  echo # Newline after finishing a repo
}

# --- Script Entry Point ---

# Define the persistent output directory
OUTPUT_DIR="./tmp"
mkdir -p "$OUTPUT_DIR"

# Create temporary files that will be cleaned up on script exit
LOGIN_FILE=$(mktemp -t github-logins-XXXXXX)
HEADER_FILE=$(mktemp -t github-headers-XXXXXX)
trap "rm -f '$LOGIN_FILE' '$HEADER_FILE'" EXIT # Cleanup temp files, but not the ./tmp dir

declare -a repos_to_process

if [ $# -gt 0 ]; then
  repos_to_process=("$@")
elif [ ! -t 0 ]; then
  while IFS= read -r repo_string; do
    [[ -n "$repo_string" ]] && repos_to_process+=("$repo_string")
  done
else
  print_usage
  exit 1
fi

echo "Starting contributor fetch for ${#repos_to_process[@]} repositories..."
echo "This may take a while. JSON responses will be saved in ${OUTPUT_DIR}/"
echo "------------------------------------------------------------"

for repo_string in "${repos_to_process[@]}"; do
  fetch_all_contributors_for_repo "${repo_string}" "${LOGIN_FILE}" "${HEADER_FILE}" "${OUTPUT_DIR}"
done

echo "------------------------------------------------------------"
echo "All repositories processed. Calculating unique contributors..."

if [[ ! -s "$LOGIN_FILE" ]]; then
    echo -e "${YELLOW}No contributors found or all repositories failed.${NC}"
    exit 0
fi

# Sort the master list of logins, find unique entries, and store them
UNIQUE_LOGINS=$(sort -u "${LOGIN_FILE}")
UNIQUE_COUNT=$(echo "${UNIQUE_LOGINS}" | wc -l | xargs)

# --- Beautiful Print Output ---
echo -e "\n✅ ${GREEN}Analysis Complete!${NC}"
echo -e "Total unique contributors across all provided repositories: ${YELLOW}${UNIQUE_COUNT}${NC}"
echo "============================================================"
echo -e "${CYAN}Unique Contributor Logins (alphabetical):${NC}"
echo "${UNIQUE_LOGINS}" # Print the list of unique logins
echo "============================================================"
echo -e "Raw JSON responses are saved in the ${YELLOW}${OUTPUT_DIR}/${NC} directory."