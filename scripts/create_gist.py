# scripts/create_gist.py
# Reads all .luau files under the Explorer/ folder and creates a private Gist
# Requires: Python 3 and the "requests" package
# Expects GH_PAT to be provided in the environment

import os
import json
import sys
import requests

token = os.environ.get("GH_PAT")
if not token:
    print("ERROR: GH_PAT secret not found. Set it in repo secrets (name: GH_PAT).")
    sys.exit(2)

root = os.environ.get("ROOT", "Explorer")
if not os.path.isdir(root):
    print(f"ERROR: root folder '{root}' not found in repo root.")
    sys.exit(3)

files_payload = {}
count = 0

for dirpath, _, filenames in os.walk(root):
    for fname in filenames:
        if not fname.lower().endswith(".luau"):
            continue
        filepath = os.path.join(dirpath, fname)
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read()
        except Exception as e:
            print(f"Warning: could not read {filepath}: {e}")
            continue
        # Replace path separators so gist filenames are unique and path-preserving
        gist_name = filepath.replace(os.sep, "__")
        files_payload[gist_name] = {"content": content}
        count += 1

if count == 0:
    print("No .luau files found under", root)
    sys.exit(0)

payload = {
    "description": os.environ.get("GIST_DESCRIPTION", "RizzCity .luau snapshot"),
    "public": False,
    "files": files_payload
}

headers = {
    "Accept": "application/vnd.github+json",
    "Authorization": f"token {token}",
    "X-GitHub-Api-Version": "2022-11-28"
}

resp = requests.post("https://api.github.com/gists", headers=headers, data=json.dumps(payload))
try:
    resp_json = resp.json()
except Exception:
    print("Error: non-JSON response from GitHub API")
    print(resp.text)
    sys.exit(1)

if resp.status_code not in (200,201):
    print("Failed to create gist:", resp.status_code)
    print(json.dumps(resp_json, indent=2))
    sys.exit(1)

html_url = resp_json.get("html_url")
files_map = resp_json.get("files", {})
print(f"Created gist: {html_url}")
print(f"Gist contains {len(files_map)} files")
for k,v in files_map.items():
    raw_url = v.get("raw_url")
    print(f"FILE: {k} RAW: {raw_url}")
gist_id = resp_json.get("id")
print(f"GIST_ID={gist_id}")
