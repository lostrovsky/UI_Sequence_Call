# Claude Session Notes - UI Sequence Call

## Project Overview

Long-running HTTP service that serves a small HTML form (one button) and one API endpoint backed by a SQL Server sequence object. Browser hits the form, clicks the button, JS fetches `/api/next-sequence`, displays the value returned. The service does the SQL `SELECT NEXT VALUE FOR dbo.seq_UI_Test` on each call.

Built on the UST utils Java template (com.ust.utils package, ust-utils-core for ConfigLoader/DBManager/LoggerFactory) plus Javalin for HTTP + static file serving (embedded Jetty).

## Stack

- Java 21, Maven
- ust-utils-core 1.0.0 (DBManager, ConfigLoader, LoggerFactory)
- Javalin 6.3.0 (embedded Jetty HTTP server, static file serving, JSON)
- mssql-jdbc 13.2.1.jre11 (SQL Server driver)
- Jackson 2.17.2 (JSON serialization, used by Javalin)
- slf4j-jdk14 2.0.13 (routes Javalin/Jetty SLF4J output through java.util.logging so it ends up in the LoggerFactory log file)

## Layout

```
UI_Sequence_Call/
├── pom.xml
├── UISequenceCall.properties              <- copied to target/ at package time
├── CLAUDE.md, CLAUDE_NOTES.md, TODO.md
├── .claude/settings.local.json
├── .gitignore
└── src/main/
    ├── java/com/ust/utils/
    │   ├── UISequenceCall.java            <- main class: parses CLI args, sets up logger/config/DB, starts Javalin, blocks
    │   └── SequenceService.java           <- DB layer: SELECT NEXT VALUE FOR <schema>.<name>
    └── resources/
        └── public/
            └── index.html                 <- form + JS, served at /index.html
```

## Endpoints

| Method | Path | Returns |
|---|---|---|
| GET | `/` | brief plain-text status with discovery URLs (form NOT served here, by design) |
| GET | `/sequence` | 302 redirect to `/sequence.html` |
| GET | `/sequence.html` | the HTML form (served by Javalin static-files from `src/main/resources/public/sequence.html`) |
| GET | `/api/next-sequence` | `{"value": <long>}` on success; `{"error": "<msg>"}` with HTTP 500 on failure |

## Configuration (UISequenceCall.properties)

| Key | Default | Notes |
|---|---|---|
| `db.url` | `jdbc:sqlserver://localhost:1433;databaseName=INTEGRATION_PLUS_DB;...` | DBManager picks this up |
| `db.user` | `cpp` | |
| `db.password` | `HPS@UST022025` | |
| `http.port` | `8080` | Override at runtime via `--port=<n>` |
| `sequence.schema` | `dbo` | Validated against `^[a-zA-Z_][a-zA-Z0-9_]*$` before SQL concat |
| `sequence.name` | `seq_UI_Test` | Same validation |

## CLI

```bash
java -jar target/ui-sequence-call-1.0.0-jar-with-dependencies.jar
java -jar target/ui-sequence-call-1.0.0-jar-with-dependencies.jar --log-output=both --port=8081
java -jar target/ui-sequence-call-1.0.0-jar-with-dependencies.jar --properties-file=C:\custom\path\UISequenceCall.properties
```

CLI args:
- `--log-output=both|file|console` (default: both)
- `--port=<n>` (overrides http.port from properties)
- `--properties-file=<path>` (overrides default jar-relative location)

## Build

```bash
cd C:\Users\lostrovsky\VSCode_Projects\UI_Sequence_Call
mvn clean package -DskipTests
# Produces:
#   target/ui-sequence-call-1.0.0.jar               (thin jar -- not used for run)
#   target/ui-sequence-call-1.0.0-jar-with-dependencies.jar  (fat jar -- this one)
#   target/UISequenceCall.properties                (copied at package phase)
```

## Run

From the `target/` directory (so the jar finds `UISequenceCall.properties` next to it):

```bash
cd target
java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar
```

Then open `http://localhost:8080/sequence` in a browser. (Hitting `/` returns a plain-text status page with discovery URLs -- by design, the form is not served at the root.) Ctrl-C to stop (the JVM shutdown hook closes Javalin and the DB connection cleanly).

## Database

Sequence object expected at `dbo.seq_UI_Test` in `INTEGRATION_PLUS_DB`. Already created. Verify:

```sql
SELECT s.name AS schema_name, o.name AS sequence_name, NEXT VALUE FOR dbo.seq_UI_Test
FROM sys.sequences o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.name = 'seq_UI_Test';
```

## Conventions (from global CLAUDE.md)

- SQL injection prevention: schema and sequence name validated at construction in `SequenceService` against `^[a-zA-Z_][a-zA-Z0-9_]*$`. Stored as final fields. Reused in pre-built `sql` string.
- Use ust-utils-core classes (DBManager, ConfigLoader, LoggerFactory) -- never reimplement.
- Properties file named after the main class (`UISequenceCall.properties`), copied to `target/` via maven-resources-plugin at package phase.
- Logging: java.util.logging only; `--log-output=console|file|both` CLI flag. Javalin/Jetty use SLF4J -- routed to JUL via `slf4j-jdk14` so it shows up in the same log file.
- Single shared `DBManager` connection guarded by `synchronized (dbManager)` in `SequenceService.next()`. Fine for low-traffic local service; revisit pooling if concurrent load grows.

## Service Mode (Windows, no third-party tools)

Uses Task Scheduler. Achieves auto-start at boot, restart-on-crash, runs as SYSTEM, stdout/stderr captured. Not technically a Windows service (won't show in services.msc), but delivers all the practical benefits.

`deploy/` contains:
- `install.ps1` -- interactive installer; copies jar + properties to a target dir, generates `run.cmd` for manual launches, optionally chains into `register_task.ps1` (`-RegisterTask` flag). Idempotent: existing UISequenceCall.properties is preserved on re-install.
- `register_task.ps1` -- registers the scheduled task. Generates a small `service_run.cmd` wrapper in the install dir that handles stdout/stderr redirection, then registers a Task Scheduler task pointed at it. Settings: AtStartup trigger, RunAsUser=SYSTEM (configurable), RestartCount=999 / RestartInterval=1m, ExecutionTimeLimit=Zero (no time limit). Resolves java.exe via PATH or $env:JAVA_HOME unless `-JavaPath` is passed. Requires elevation.
- `unregister_task.ps1` -- stop + Unregister-ScheduledTask. Doesn't delete install dir or logs (operator's job).
- `INSTALL.txt` -- step-by-step user guide.

Three log files end up in the install dir at runtime:
- `UISequenceCall.log` -- java.util.logging output (app + Javalin + Jetty via SLF4J->JUL bridge). The most useful one for debugging.
- `service_stdout.log` -- catches anything the JVM writes to stdout (mostly empty in normal operation).
- `service_stderr.log` -- catches early JVM errors (OOM, ClassNotFoundException, etc.) before java.util.logging is initialized.

## State at Time of Notes

Initial scaffold + configurable port/url paths/UI copy + Windows Task Scheduler service install scripts complete. Service verified running on :8080 with default config. Install scripts dry-run-verified against sandbox dir (jar + properties copy correctly; properties preserved on re-install).
