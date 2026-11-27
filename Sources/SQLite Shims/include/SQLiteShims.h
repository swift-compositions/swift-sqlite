#ifndef SQLITE_SHIMS_H
#define SQLITE_SHIMS_H

// The system's SQLite, and what Swift cannot call of it: sqlite3_db_config is variadic.
#include <sqlite3.h>

/// A quoted name that matches no column is an error, not a string literal, in statements and in schema.
/// Returns SQLite's result code.
static inline int sqlite_shims_disable_double_quoted_strings(sqlite3 *connection) {
    int code = sqlite3_db_config(connection, SQLITE_DBCONFIG_DQS_DML, 0, (void *)0);
    if (code != SQLITE_OK) return code;
    return sqlite3_db_config(connection, SQLITE_DBCONFIG_DQS_DDL, 0, (void *)0);
}

#endif
