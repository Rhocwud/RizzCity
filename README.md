# RizzCity
Rizz City Live Code

- `GH_PAT` (Personal Access Token) is stored only as a GitHub repository secret (name: `GH_PAT`). It must have the following scopes:
- `gist` (create private gists) — if the automation posts gists
- `repo` (repo: read/write) — to commit `docs/ProjectInventory.csv` and push PRs/branches
- Optionally `workflow` if the organization requires it to dispatch workflows
- Token lifetime: the current token expires 2026-09-06. Rotate/replace the token before expiry. Do not paste tokens in chat.
- Permissions: repo-level Actions permissions must allow the workflows to push/PR. If PR creation fails, check repo Settings → Actions → Workflow permissions (set to Read & write and allow PR creation).
- Backup & auditing: `docs/ProjectInventory.csv` is the canonical audit artifact. Store it in `docs/` and optionally upload artifacts per run for long-term snapshots.

Recommended developer tasks (one-time)
1. Add `.gitattributes` with `*.luau text eol=lf` to the repo root.  
2. Add `scripts/create_gist_and_inventory.py` and `.github/workflows/publish-and-inventory.yml` (see repository `scripts/` and `.github/workflows/` for exact files).  
3. Ensure `GH_PAT` secret exists and has required scopes.  
4. Run the workflow manually once and confirm `docs/ProjectInventory.csv` is created and committed.

If something is inconsistent
- If `ProjectFileLinks.txt` and `ProjectInventory.csv` disagree on files or URLs, prefer `ProjectInventory.csv` for metadata and `ProjectFileLinks.txt` for raw URLs. Flag the difference in a PR comment when committing fixes.

Contact & ownership
- Owner: Tyler (Rhocwud Games). The assistant acts as an external collaborator and will only fetch / read files from raw URLs or public endpoints, or via the snapshot Gist / Inventory CSV produced by the workflows. The assistant will never request the PAT in chat.

