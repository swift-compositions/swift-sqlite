#include "SQLiteShims.h"

// Apple platforms have SQLite in the operating system. Elsewhere this target compiles the amalgamation in sqlite/,
// so the package needs no system library and builds with Swift's static Linux SDK.
#if !defined(__APPLE__)
#include "sqlite/sqlite3.c"
#endif
