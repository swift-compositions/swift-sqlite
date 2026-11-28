// Apple platforms have SQLite in the operating system. Elsewhere this target compiles the amalgamation in sqlite/,
// so the package needs no system library and builds with Swift's static Linux SDK. The amalgamation comes before
// its header: it defines what the header alone only declares.
#if !defined(__APPLE__)
#include "sqlite/sqlite3.c"
#endif

#include "SQLiteShims.h"
