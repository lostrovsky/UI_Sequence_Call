# Claude Code -- Project Bootstrap

On every new conversation, read these files to establish full project context:

1. `CLAUDE_NOTES.md` -- Architecture, run/build, deployment notes
2. `TODO.md` -- Pending and completed work items

Also read memory files for user preferences and cross-session context:
- `~/.claude/projects/c--Users-lostrovsky-VSCode-Projects-UI-Sequence-Call/memory/MEMORY.md`

## What this project is

Long-running HTTP service (embedded Jetty via Javalin). Serves a one-button HTML form at `/` and exposes a single API endpoint `/api/next-sequence` that returns the next value from a SQL Server sequence object (`dbo.seq_UI_Test` by default).

Single self-contained jar. Client requirement: web browser only.

## Sibling projects (UST utils style)

- `Claim_Provider_Data_Extractor`, `Generic_HRP_WS_Call`, `Claim_Provider_Data_Pipeline` -- reference for pom.xml structure, ust-utils-core usage patterns, and conventions.
