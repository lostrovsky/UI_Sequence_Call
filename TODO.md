# TODO / Enhancements

## Pending
- [ ] Decide on auth: currently no auth -- bind to localhost only or front with reverse proxy if exposed beyond the host
- [ ] Add health endpoint (`/health` -> `{"status":"ok"}`) once usage justifies it
- [ ] Connection pooling: current SequenceService uses the single shared DBManager connection guarded by synchronized; swap for HikariCP if concurrent traffic grows
- [ ] Audit log of who pulled which sequence value (request IP, timestamp) -- nice for traceability if values are tied to external records

## Completed
- [x] Initial project scaffold (pom.xml, properties, src tree, HTML form)
- [x] `SequenceService` with schema/name validation and pre-built SQL string
- [x] `UISequenceCall` main: CLI args, Javalin setup, shutdown hook
- [x] Static HTML form with one button + JS fetch
- [x] SLF4J -> JUL bridge so Javalin/Jetty logs land in our log file
- [x] Configurable port (`http.port` + `--port=`) and URL paths (`ui.path` + `api.path`, with `--ui-path=` / `--api-path=` overrides). API path injected into HTML at startup via `__API_PATH__` placeholder.
- [x] Configurable UI copy: `ui.title`, `ui.subtitle`, `ui.button.label`. HTML-escaped at startup so &, <, >, etc. are safe.
- [x] Default page (`/`) returns plain-text status with discovery URLs; the form is at `ui.path` (default `/sequence`), not at root.
- [x] Windows service install via Task Scheduler -- no third-party tools. `deploy/register_task.ps1` + `unregister_task.ps1` + `INSTALL.txt`. Auto-start at boot, restart-on-crash, runs as SYSTEM, stdout/stderr captured.
- [x] Drop `deploy/install.ps1` -- it was over-engineered for a single-jar service. Release zip now ships a flat layout (jar + properties + `run.cmd` + `deploy/` scripts) that the operator extracts directly to their install directory. No copy step.
- [x] `ui.subtitle` allows raw HTML (links, `<br>`, `<strong>`, etc.); `ui.title` and `ui.button.label` remain HTML-escaped.
- [x] Stop leaking DB exception messages to clients. API now returns generic `{"error":"Internal error -- see server log"}` on failure; full stack traces (including SQL error text) only land in `UISequenceCall.log`.
- [x] Per-IP rate limit on the API endpoint via Javalin's `NaiveRateLimit`. Default 10 req/min, configurable via `api.rate_limit.per_minute` (set to 0 to disable). Other endpoints (form, root status) are not rate-limited.
