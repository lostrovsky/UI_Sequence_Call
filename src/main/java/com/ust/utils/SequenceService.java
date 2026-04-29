package com.ust.utils;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.logging.Logger;
import java.util.regex.Pattern;

/**
 * Returns the next value from a SQL Server sequence object.
 *
 * Schema and name are validated once at construction against
 * ^[a-zA-Z_][a-zA-Z0-9_]*$ before being concatenated into the SQL string,
 * so the runtime SELECT is safe from injection via configuration drift.
 */
public class SequenceService {

    private static final Pattern VALID_NAME_PATTERN = Pattern.compile("^[a-zA-Z_][a-zA-Z0-9_]*$");

    private final DBManager dbManager;
    private final String schema;
    private final String name;
    private final Logger logger;
    private final String sql;

    public SequenceService(DBManager dbManager, String schema, String name, Logger logger) {
        this.dbManager = dbManager;
        this.schema = validate(schema, "sequence.schema");
        this.name = validate(name, "sequence.name");
        this.logger = logger;
        this.sql = "SELECT NEXT VALUE FOR " + this.schema + "." + this.name;
    }

    /**
     * Executes SELECT NEXT VALUE FOR &lt;schema&gt;.&lt;name&gt; and returns the value.
     * Reuses the shared DBManager connection (single connection model -- fine for a
     * low-traffic local service; revisit if concurrent load grows).
     */
    public long next() throws SQLException {
        Connection conn = dbManager.getConnection();
        synchronized (dbManager) {
            try (PreparedStatement pstmt = conn.prepareStatement(sql);
                 ResultSet rs = pstmt.executeQuery()) {
                if (!rs.next()) {
                    throw new SQLException("Sequence query returned no rows");
                }
                long value = rs.getLong(1);
                logger.info("Next sequence value: " + value);
                return value;
            }
        }
    }

    private static String validate(String value, String label) {
        if (value == null || !VALID_NAME_PATTERN.matcher(value).matches()) {
            throw new IllegalArgumentException("Invalid " + label + ": " + value);
        }
        return value;
    }
}
