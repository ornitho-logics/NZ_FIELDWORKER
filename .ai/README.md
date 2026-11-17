# AI workspace

Shared agent instructions, reviewed handoffs, sanitized logs, and validator
exports live here. Start with [AGENTS.md](AGENTS.md). The root AGENTS.md keeps
automatic agent discovery working.

Personal additions are ignored. Use `.ai/local/` for new private work. Existing
private proposal artifacts stay ignored beside their reviewed handoffs. Never
put credentials or confidential field records into tracked files.

The tracked `.gitignore.MV` is activated only for this checkout with:

```sh
git config --local core.excludesFile "$(pwd)/.gitignore.MV"
```

Other collaborators do not inherit that Git setting. It ignores new files in
this folder, while existing tracked files remain shared. To intentionally add
a reviewed shared file here while this setting is active, use `git add -f`
with that exact file path.

To stop using the personal rules, run:

```sh
git config --local --unset core.excludesFile
```

Historical archive manifests retain their original paths for checksum and
restore compatibility. The empty, environment-managed `.agents/` and `.codex/`
folders stay at the root; they contain no project artifacts to consolidate.
