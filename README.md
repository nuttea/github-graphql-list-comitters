# GitHub Contributor Counter

A robust shell script to count the number of contributors in one or more GitHub repositories using the GitHub API. It is designed to be efficient, user-friendly, and practical for bulk operations.

This script saves the raw API JSON responses and headers to a local `./tmp` directory, allowing for easy validation and further data processing.

## Features

-   **Count Contributors**: Accurately counts contributors for any public or private repository you have access to.
-   **Bulk Processing**: Process a list of repositories provided as command-line arguments or piped from a file.
-   **Efficient**: Uses an intelligent pagination check to quickly count contributors in large repositories without downloading the entire list, saving time and API rate-limit quota.
-   **Validation Output**: Saves the full JSON response and HTTP headers for each repository to a local `./tmp` directory for manual verification.
-   **User-Friendly**: Provides clear, color-coded output for successes and errors.
-   **Dependency Checks**: Ensures required tools (`curl`, `jq`) are installed before running.

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
    Save the script's code into a file named `count_contributors.sh`.

2.  **Make it Executable**
    Open your terminal and grant execute permissions to the script:
    ```sh
    chmod +x count_contributors.sh
    ```

3.  **Set Your GitHub Personal Access Token (PAT)**
    The script requires a GitHub PAT to authenticate with the API. This provides you with a much higher rate limit and allows access to private repositories.

    -   [Create a PAT here](https://github.com/settings/tokens). Give it the `repo` scope if you need to access private repositories.
    -   Export the token as an environment variable named `PAT`:
        ```sh
        export PAT="ghp_YourPersonalAccessTokenHere"
        ```
    -   **Tip**: To make this setting permanent, add the `export` line to your shell's startup file (e.g., `~/.bashrc`, `~/.zshrc`, or `~/.profile`) and then restart your terminal or run `source ~/.bashrc`.

## Usage

You can run the script in several ways.

#### Option 1: Provide Repositories as Command-Line Arguments

Pass one or more repositories in `owner/repo` format directly to the script.

**Syntax:**
```sh
./count_contributors.sh <owner1>/<repo1> <owner2>/<repo2> ...
```

**Example:**
```sh
./count_contributors.sh torvalds/linux microsoft/vscode facebook/react
```

#### Option 2: Provide Repositories from a File

Create a text file (e.g., `repos.txt`) with one `owner/repo` per line. Then, pipe this file into the script using `cat`.

1.  Create `repos.txt`:
    ```
    docker/compose
    ansible/ansible
    hashicorp/terraform
    ```

2.  Run the script:
    ```sh
    cat repos.txt | ./count_contributors.sh
    ```

### Example Output

When you run the script, you will see output similar to this:

```
Processing torvalds/linux...
   Success: Found 22894 contributors.
Processing microsoft/vscode...
   Success: Found 2231 contributors.
Processing facebook/react...
   -> Skipping invalid format: facebook/react. Should be 'owner/repo'.
Processing actions/checkout...
   Success: Found 185 contributors.

Done.
Raw JSON responses and headers have been saved in the ./tmp/ directory.
This directory is not automatically cleaned up.
```

## How It Works

The script is designed for efficiency, especially for repositories with thousands of contributors.

1.  **Initial API Call**: For each repository, the script makes an initial API call to the contributors endpoint, but with a special parameter: `per_page=1`. This tells GitHub to only return the first contributor.
2.  **Header Inspection**: The script doesn't look at the JSON body of this first response. Instead, it inspects the HTTP **headers**.
3.  **Pagination Check**:
    -   If the repository has more than one page of contributors, the `Link` header will contain an entry for the `rel="last"` page (e.g., `...&page=22894>; rel="last"`). The script simply extracts this page number, which is the total number of contributors. This is extremely fast.
    -   If there is no `rel="last"` link, it means all contributors fit on a single page. Only then does the script make a second API call to get the full list and counts the items using `jq`.

This method avoids downloading potentially thousands of records just to get a count, making the script fast and respectful of the GitHub API rate limits.

## Output Files for Validation

For every repository processed, the script creates two files inside a `./tmp` directory:

-   `./tmp/<owner>-<repo>.body.json`: The raw JSON response from the GitHub API.
-   `./tmp/<owner>-<repo>.headers.txt`: The full HTTP headers from the API response.

You can use these files to validate the results or for further analysis.

**Example: Inspecting the output for `torvalds/linux`**

```sh
# List the files in the tmp directory
ls -1 ./tmp

# You will see:
# torvalds-linux.body.json
# torvalds-linux.headers.txt
# ... and files for other repos

# View the headers to see the pagination links
cat ./tmp/torvalds-linux.headers.txt

# Pretty-print the JSON body using jq
cat ./tmp/torvalds-linux.body.json | jq .
```

---