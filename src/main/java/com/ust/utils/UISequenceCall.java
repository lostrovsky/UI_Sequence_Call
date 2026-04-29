package com.ust.utils;

import io.javalin.Javalin;

import java.io.InputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Long-running HTTP service. Exposes a tiny HTML form (one button) and one
 * API endpoint that returns the next value from a SQL Server sequence object.
 *
 *   GET /                       -> brief plain-text status; form is NOT served here
 *   GET <ui.path>               -> the form (default: /sequence)
 *   GET <api.path>              -> {"value": <long>} (default: /api/next-sequence)
 *
 * Both ui.path and api.path are configurable. The HTML form's fetch URL is
 * rewritten at startup to match api.path so the two stay in sync.
 *
 * CLI args:
 *   --log-output=both|file|console     (default: both)
 *   --port=<n>                          (default: from properties; properties default: 8080)
 *   --ui-path=<path>                    (default: from properties; properties default: /sequence)
 *   --api-path=<path>                   (default: from properties; properties default: /api/next-sequence)
 *   --properties-file=<path>            (default: <jar-dir>/UISequenceCall.properties)
 */
public class UISequenceCall {

    private static final String DEFAULT_LOG_OUTPUT = "both";
    private static final int DEFAULT_PORT = 8080;
    private static final String DEFAULT_UI_PATH = "/sequence";
    private static final String DEFAULT_API_PATH = "/api/next-sequence";
    private static final String DEFAULT_UI_TITLE = "UI Sequence Call";
    private static final String DEFAULT_UI_SUBTITLE = "Click the button to fetch the next value from the configured SQL Server sequence.";
    private static final String DEFAULT_UI_BUTTON_LABEL = "Get Next Sequence Number";
    private static final String FORM_RESOURCE = "/public/sequence.html";

    // Placeholders in sequence.html, replaced at startup.
    private static final String P_API_PATH      = "__API_PATH__";
    private static final String P_UI_TITLE      = "__UI_TITLE__";
    private static final String P_UI_SUBTITLE   = "__UI_SUBTITLE__";
    private static final String P_UI_BTN_LABEL  = "__UI_BUTTON_LABEL__";

    private static Logger logger;
    private static ConfigLoader config;
    private static DBManager dbManager;
    private static Javalin app;

    public static void main(String[] args) {
        try {
            String logOutput = DEFAULT_LOG_OUTPUT;
            Integer cliPort = null;
            String cliUiPath = null;
            String cliApiPath = null;
            String cliPropertiesFile = null;
            for (String arg : args) {
                if (arg.startsWith("--log-output=")) {
                    logOutput = arg.substring("--log-output=".length());
                } else if (arg.startsWith("--port=")) {
                    try {
                        cliPort = Integer.parseInt(arg.substring("--port=".length()));
                    } catch (NumberFormatException e) {
                        System.err.println("Invalid --port value: " + arg);
                        System.exit(1);
                    }
                } else if (arg.startsWith("--ui-path=")) {
                    cliUiPath = arg.substring("--ui-path=".length());
                } else if (arg.startsWith("--api-path=")) {
                    cliApiPath = arg.substring("--api-path=".length());
                } else if (arg.startsWith("--properties-file=")) {
                    cliPropertiesFile = arg.substring("--properties-file=".length());
                }
            }

            initialSetup(logOutput, cliPropertiesFile);

            int port      = cliPort    != null ? cliPort    : parsePort(config.get("http.port"));
            String uiPath  = validatePath(cliUiPath  != null ? cliUiPath  : firstNonBlank(config.get("ui.path"),  DEFAULT_UI_PATH),  "ui.path");
            String apiPath = validatePath(cliApiPath != null ? cliApiPath : firstNonBlank(config.get("api.path"), DEFAULT_API_PATH), "api.path");
            if (uiPath.equals(apiPath)) {
                throw new IllegalArgumentException("ui.path and api.path must differ; both are '" + uiPath + "'");
            }
            String uiTitle    = firstNonBlank(config.get("ui.title"),        DEFAULT_UI_TITLE);
            String uiSubtitle = firstNonBlank(config.get("ui.subtitle"),     DEFAULT_UI_SUBTITLE);
            String uiBtnLabel = firstNonBlank(config.get("ui.button.label"), DEFAULT_UI_BUTTON_LABEL);

            String schema = config.get("sequence.schema");
            String name   = config.get("sequence.name");
            if (schema == null || schema.isBlank()) {
                throw new IllegalArgumentException("sequence.schema not set in properties");
            }
            if (name == null || name.isBlank()) {
                throw new IllegalArgumentException("sequence.name not set in properties");
            }

            dbManager.connect();
            SequenceService sequence = new SequenceService(dbManager, schema, name, logger);

            String formHtml = loadFormHtml(apiPath, uiTitle, uiSubtitle, uiBtnLabel);

            app = Javalin.create(cfg -> {
                cfg.showJavalinBanner = false;
            });

            int    finalPort   = port;
            String finalUiPath = uiPath;
            String finalApiPath = apiPath;

            // Plain-text status at root so a misdirected hit lands on a
            // sign-of-life page rather than the action button.
            app.get("/", ctx -> ctx.contentType("text/plain").result(
                "UI Sequence Call service is running.\n" +
                "  UI:  http://localhost:" + finalPort + finalUiPath + "\n" +
                "  API: http://localhost:" + finalPort + finalApiPath + "\n"));

            app.get(uiPath, ctx -> ctx.contentType("text/html").result(formHtml));

            app.get(apiPath, ctx -> {
                try {
                    long value = sequence.next();
                    ctx.json(Map.of("value", value));
                } catch (Exception e) {
                    logger.log(Level.SEVERE, "Sequence query failed", e);
                    ctx.status(500).json(Map.of("error", e.getMessage()));
                }
            });

            Runtime.getRuntime().addShutdownHook(new Thread(UISequenceCall::shutdown, "ui-sequence-call-shutdown"));

            app.start(port);
            logger.info("UI Sequence Call service started on port " + port);
            logger.info("Form: http://localhost:" + port + uiPath);
            logger.info("API:  http://localhost:" + port + apiPath);
        } catch (Exception e) {
            if (logger != null) {
                logger.log(Level.SEVERE, "Startup failed", e);
            } else {
                System.err.println("Startup failed: " + e.getMessage());
                e.printStackTrace();
            }
            System.exit(1);
        }
    }

    private static void initialSetup(String logOutput, String cliPropertiesFile) throws Exception {
        Path jarPath = Paths.get(getJarLocation());
        Path baseDir = jarPath.getParent() != null ? jarPath.getParent() : Paths.get(".").toAbsolutePath();
        String className = UISequenceCall.class.getSimpleName();
        Path logFile = baseDir.resolve(className + ".log");
        Path propsFile = cliPropertiesFile != null
                ? Paths.get(cliPropertiesFile)
                : baseDir.resolve(className + ".properties");

        logger = LoggerFactory.createLogger(className, logFile.toString(), logOutput);
        config = new ConfigLoader(propsFile.toString());
        dbManager = new DBManager(config.getProperties(), logger);
        logger.info("Properties loaded from: " + propsFile);
    }

    private static URI getJarLocation() throws Exception {
        return UISequenceCall.class.getProtectionDomain().getCodeSource().getLocation().toURI();
    }

    private static int parsePort(String value) {
        if (value == null || value.isBlank()) return DEFAULT_PORT;
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid http.port: " + value);
        }
    }

    private static String firstNonBlank(String a, String b) {
        return (a != null && !a.isBlank()) ? a : b;
    }

    private static String validatePath(String path, String label) {
        if (path == null || path.isBlank() || !path.startsWith("/")) {
            throw new IllegalArgumentException(label + " must start with '/'; got: '" + path + "'");
        }
        return path.trim();
    }

    /**
     * Loads the form HTML from the jar's classpath and substitutes runtime
     * placeholders (api path + UI copy). Cached in memory; served on every
     * UI request without touching disk. UI copy is HTML-escaped so a stray
     * &lt;, &gt;, or &amp; in a property value can't break the page.
     */
    private static String loadFormHtml(String apiPath, String title, String subtitle, String buttonLabel) throws Exception {
        try (InputStream in = UISequenceCall.class.getResourceAsStream(FORM_RESOURCE)) {
            if (in == null) {
                throw new IllegalStateException("Form HTML not found on classpath at " + FORM_RESOURCE);
            }
            String raw = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            return raw
                    .replace(P_API_PATH,     apiPath)               // already path-validated, no escape needed
                    .replace(P_UI_TITLE,     htmlEscape(title))     // <title> tag -- escape (no HTML allowed)
                    .replace(P_UI_SUBTITLE,  subtitle == null ? "" : subtitle) // raw HTML allowed
                    .replace(P_UI_BTN_LABEL, htmlEscape(buttonLabel)); // <button> -- escape
        }
    }

    private static String htmlEscape(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    private static void shutdown() {
        if (logger != null) logger.info("Shutting down UI Sequence Call service...");
        try { if (app != null) app.stop(); } catch (Exception ignored) { }
        try { if (dbManager != null) dbManager.disconnect(); } catch (Exception ignored) { }
    }
}
