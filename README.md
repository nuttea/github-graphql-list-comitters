# GitHub Unique Contributor Counter & Lister

A powerful shell script to calculate the total number of **unique** contributors across one or more GitHub repositories. It aggregates contributor lists, de-duplicates them, and then provides both a final count and a complete, alphabetized list of every unique contributor's login.

For validation and further analysis, the script saves the raw JSON response for **every page** of API results to a local `./tmp` directory.

## Features

-   **Unique Count & List**: Calculates the total number of unique individuals and prints their usernames in a clean, alphabetized list.
-   **Detailed JSON Output**: Saves the raw JSON response for every paginated API call to `./tmp` for full transparency and validation.
-   **Bulk Processing**: Accepts multiple repositories as command-line arguments or from a file via a pipe.
-   **Handles Pagination**: Automatically follows the `Link` headers in the GitHub API to fetch all pages of contributors for any given repository.
-   **User-Friendly**: Provides clear, color-coded output, including a progress indicator for long-running fetches.
-   **Robust**: Includes pre-flight checks for required tools (`curl`, `jq`) and ensures a GitHub Personal Access Token is set.

## Important Note on Performance and API Usage

This script's goal is to find *unique* contributors. To do this, it **must** fetch the complete list of contributors for **every repository** you provide.

-   **Performance**: This process can be **slow** if you are analyzing repositories with thousands of contributors (e.g., `torvalds/linux` or `kubernetes/kubernetes`).
-   **API Rate Limit**: Fetching full lists consumes your GitHub API rate limit quota more quickly than just counting. A Personal Access Token is essential.
-   **Disk Space**: Saving the JSON responses will use disk space, especially for large repositories with many pages of contributors.

Please be patient when running it on large repositories.

## Prerequisites

Before using this script, you need to have the following installed on your system (Linux, macOS, or Windows Subsystem for Linux):

1.  **`curl`**: A command-line tool for transferring data with URLs.
    ```sh
    # On Debian/Ubuntu
    sudo apt-get update && sudo apt-get install curl

    # On macOS (using Homebrew)
    brew install curl
    ```

2.  **`jq`**: A lightweight and flexible command-line JSON processor.
    ```sh
    # On Debian/Ubuntu
    sudo apt-get install jq

    # On macOS (using Homebrew)
    brew install jq
    ```

## Setup

1.  **Download the Script**
    Save the script's code into a file named `count_unique_contributors.sh`.

2.  **Make it Executable**
    Open your terminal and grant execute permissions to the script:
    ```sh
    chmod +x count_unique_contributors.sh
    ```

3.  **Set Your GitHub Personal Access Token (PAT)**
    The script requires a GitHub PAT to authenticate with the API for a higher rate limit and access to private repositories.

    -   [Create a PAT here](https://github.com/settings/tokens). The `repo` scope is needed for private repos.
    -   Export the token as an environment variable named `PAT`:
        ```sh
        export PAT="ghp_YourPersonalAccessTokenHere"
        ```
    -   **Tip**: To make this setting permanent, add the `export` line to your shell's startup file (e.g., `~/.bashrc`, `~/.zshrc`) and then restart your terminal or run `source ~/.bashrc`.

## Usage

You can run the script by providing a list of repositories either on the command line or from a file.

#### Option 1: Provide Repositories as Command-Line Arguments

Pass one or more repositories in `owner/repo` format directly to the script.

**Syntax:**
```sh
./count_unique_contributors.sh <owner1>/<repo1> <owner2>/<repo2> ...
```

**Example:**
```sh
./count_unique_contributors.sh actions/checkout actions/setup-node
```

#### Option 2: Provide Repositories from a File

Create a text file (e.g., `my-org-repos.txt`) with one `owner/repo` per line. Then, pipe this file into the script using `cat`.

1.  Create `my-org-repos.txt`:
    ```
    expressjs/express
    visionmedia/supertest
    tj/commander.js
    ```

2.  Run the script:
    ```sh
    cat my-org-repos.txt | ./count_unique_contributors.sh
    ```

### Example Output

The script provides rich output, including the count and the full list of unique usernames.

```
Starting contributor fetch for 2 repositories...
This may take a while. JSON responses will be saved in ./tmp/
------------------------------------------------------------
Fetching all contributors for actions/checkout...
..
Fetching all contributors for actions/setup-node...
.
------------------------------------------------------------
All repositories processed. Calculating unique contributors...

✅ Analysis Complete!
Total unique contributors across all provided repositories: 215
============================================================
Unique Contributor Logins (alphabetical):
actions-bot
alice
aliscott
bob
bryanmacfarlane
...
(list continues)
...
xavier
ycomp
============================================================
Raw JSON responses are saved in the ./tmp/ directory.
```
*(Note: The dots `.` indicate progress as the script fetches each page of contributors from the API.)*

## Output Files for Validation

A key feature of this script is the detailed log of API responses. Inside the `./tmp` directory, you will find files for each page of results for each repository. This directory is created in the location where you run the script and is not automatically deleted.

The naming convention is: `./tmp/<owner>-<repo>.page-<N>.json`

**Example:**
If you analyze `actions/checkout`, which has 2 pages of contributors (at 100 per page), the script will create:
-   `./tmp/actions-checkout.page-1.json`
-   `./tmp/actions-checkout.page-2.json`

You can inspect these files to see exactly what data the script processed:
```sh
# Pretty-print the JSON for the first page of contributors
cat ./tmp/actions-checkout.page-1.json | jq .
```

## How It Works

The script follows a systematic process to ensure accuracy:

1.  **Initialize**: It creates a persistent `./tmp` directory for JSON output and a temporary file to serve as a "master list" for all contributor logins.
2.  **Iterate Repositories**: The script loops through each repository you provide.
3.  **Fetch All Contributors**: For each repository, it makes an initial API call to the `contributors` endpoint.
    - It uses a `while` loop to check for a `rel="next"` page link in the API response headers.
    - As long as a "next" page exists, it continues fetching pages, saving each JSON response to its own file in `./tmp`.
4.  **Aggregate Logins**: From each page's saved JSON file, it uses `jq` to extract only the `login` (username) of each contributor and appends these logins to the master list file.
5.  **De-duplicate and Count**: After processing all repositories, the script runs a final command chain on the master list file:
    ```sh
    UNIQUE_LOGINS=$(sort -u "${LOGIN_FILE}")
    UNIQUE_COUNT=$(echo "${UNIQUE_LOGINS}" | wc -l)
    ```
    -   `sort -u`: This sorts the list of all logins and the `-u` flag removes every duplicate entry, creating a unique, alphabetized list of names.
    -   `wc -l`: This counts the number of lines in the unique list, giving the final total.
6.  **Cleanup**: The temporary file containing the master list is automatically deleted when the script exits. The `./tmp` directory remains for your review.
