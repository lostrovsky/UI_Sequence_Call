# UI Sequence Call

A small Java/Javalin HTTP service that exposes a one-button HTML form and returns the next value from a SQL Server sequence object on each click. Single-jar deploy, browser-only client.

## Endpoints

| Path | Returns |
|---|---|
| `/` | plain-text status with discovery URLs |
| `/sequence` (configurable via `ui.path`) | the HTML form |
| `/api/next-sequence` (configurable via `api.path`) | `{"value": <long>}` |

## Configuration

Everything is in `UISequenceCall.properties` next to the jar. Editable knobs:

- **DB:** `db.url`, `db.user`, `db.password`
- **HTTP:** `http.port`
- **URL paths:** `ui.path`, `api.path`
- **UI copy** (HTML-escaped at startup): `ui.title`, `ui.subtitle`, `ui.button.label`
- **Sequence target:** `sequence.schema`, `sequence.name`

Each can also be overridden via CLI: `--port=`, `--ui-path=`, `--api-path=`, `--log-output=`, `--properties-file=`.

## Build

```bash
mvn clean package -DskipTests
```

Produces `target/ui-sequence-call-1.0.0-jar-with-dependencies.jar` plus a `target/UISequenceCall.properties` copy alongside it.

## Run

```bash
cd target
java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar
```

Then open `http://localhost:8080/sequence` in a browser.

## Deploy on Windows

The release zip (see [Releases](https://github.com/lostrovsky/UI_Sequence_Call/releases)) bundles installer scripts for two modes:

- **Manual:** `install.ps1` copies jar + properties to a target dir, generates a `run.cmd` for double-click console launch.
- **Service:** `register_task.ps1` registers a Windows Task Scheduler task that auto-starts at boot, restarts on crash, runs as SYSTEM, and captures stdout/stderr to log files. **No third-party tools required** — pure Task Scheduler.

Full step-by-step in `deploy/INSTALL.txt` (bundled in the release zip).

## Stack

Java 21, Maven, Javalin 6.3.0 (embedded Jetty), [ust-utils-core](https://github.com/lostrovsky/UST_Utils_Core) for `DBManager` / `ConfigLoader` / `LoggerFactory`, mssql-jdbc, Jackson, slf4j-jdk14 (SLF4J → java.util.logging bridge so Javalin/Jetty logs land in the same file as application logs).
