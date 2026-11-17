# Project AI workspace

This directory contains the project's shared AI-related material: agent
instructions, reviewed handoffs, sanitized logs, and validator exports. It is
part of the project for all contributors, including those who do not use AI.
Start with [AGENTS.md](AGENTS.md). The root AGENTS.md keeps automatic agent
discovery working.

Reviewed material remains tracked. Drafts, temporary output, and working files
belong in ignored `ai/local/` or the existing ignored proposal folders. The
shared `.gitignore` protects these working files in every checkout. Never put
credentials or confidential field records into tracked files.

The tracked `.gitignore.MV` provides optional additional rules for AI tooling
state. It is currently activated only in this checkout with:

```sh
git config --local core.excludesFile "$(pwd)/.gitignore.MV"
```

Other collaborators do not inherit that Git setting. Shared AI documents remain
versioned regardless of whether the optional rules are active. To add a newly
reviewed shared document, update the shared `.gitignore` allowlist for its exact
path, then stage it explicitly.

To disable the optional checkout-local rules, run:

```sh
git config --local --unset core.excludesFile
```

Historical archive manifests retain their original paths for checksum and
restore compatibility. The empty, environment-managed `.agents/` and `.codex/`
folders stay at the root; they contain no project artifacts to consolidate.
