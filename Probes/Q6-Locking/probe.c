// Question 6 of swift-sqlite#24: what of SQLite's own locking can be switched off, per connection and per process,
// and what does each setting need from its user? Built by run.sh against the system library and against three
// vendored builds of the amalgamation (SQLITE_THREADSAFE=1, 2 and 0).
#define _GNU_SOURCE
#include <pthread.h>
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static const char *path;

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static const char *name(int rc) {
    switch (rc) {
    case SQLITE_OK: return "SQLITE_OK";
    case SQLITE_ERROR: return "SQLITE_ERROR";
    case SQLITE_MISUSE: return "SQLITE_MISUSE";
    default: return "other";
    }
}

// Runs `body` in a child process, because sqlite3_config works only before the library is initialized.
static void child(void (*body)(void)) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) { body(); fflush(stdout); _exit(0); }
    int status;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status)) printf("    the process died: signal %d\n", WTERMSIG(status));
}

static int option;  // a SQLITE_CONFIG_* threading mode, or 0 for the process default

static void configBeforeInitialize(void) {
    printf("%s ", name(sqlite3_config(option)));
}

static void configAfterInitialize(void) {
    sqlite3_initialize();
    printf("  sqlite3_config(SQLITE_CONFIG_MULTITHREAD) after sqlite3_initialize: %s\n",
           name(sqlite3_config(SQLITE_CONFIG_MULTITHREAD)));
}

static void perConnection(void) {
    if (option) sqlite3_config(option);
    struct { const char *label; int flags; } opens[] = {
        {"no mutex flag        ", 0}, {"SQLITE_OPEN_NOMUTEX  ", SQLITE_OPEN_NOMUTEX}, {"SQLITE_OPEN_FULLMUTEX", SQLITE_OPEN_FULLMUTEX}};
    for (int i = 0; i < 3; i++) {
        sqlite3 *db;
        int rc = sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | opens[i].flags, NULL);
        if (rc != SQLITE_OK) { printf("    %s: open failed (%d)\n", opens[i].label, rc); continue; }
        sqlite3_stmt *statement;
        sqlite3_prepare_v2(db, "SELECT 1", -1, &statement, NULL);
        int steps = 2000000;
        double start = now();
        for (int n = 0; n < steps; n++) { sqlite3_step(statement); sqlite3_reset(statement); }
        double each = (now() - start) / steps * 1e9;
        printf("    %s: connection mutex %s, step+reset %.0f ns\n", opens[i].label,
               sqlite3_db_mutex(db) ? "present" : "absent ", each);
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

// One thread per connection, all on one file in WAL mode: a writer and three readers, with SQLITE_OPEN_NOMUTEX.
static int failures;

static void *work(void *argument) {
    long index = (long)argument;
    sqlite3 *db;
    if (sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, NULL) != SQLITE_OK) {
        __sync_fetch_and_add(&failures, 1);
        return NULL;
    }
    sqlite3_busy_timeout(db, 10000);
    for (int n = 0; n < 3000; n++) {
        char *message = NULL;
        const char *sql = index == 0 ? "INSERT INTO item (name) VALUES ('x')" : "SELECT count(*), sum(length(name)) FROM item";
        if (sqlite3_exec(db, sql, NULL, NULL, &message) != SQLITE_OK) {
            __sync_fetch_and_add(&failures, 1);
            sqlite3_free(message);
        }
    }
    sqlite3_close(db);
    return NULL;
}

static void threads(void) {
    if (option) sqlite3_config(option);
    sqlite3 *db;
    unlink(path);
    sqlite3_open(path, &db);
    sqlite3_exec(db, "PRAGMA journal_mode=WAL; CREATE TABLE item (id INTEGER PRIMARY KEY, name TEXT)", NULL, NULL, NULL);
    sqlite3_close(db);
    pthread_t thread[4];
    for (long i = 0; i < 4; i++) pthread_create(&thread[i], NULL, work, (void *)i);
    for (int i = 0; i < 4; i++) pthread_join(thread[i], NULL);
    sqlite3_open(path, &db);
    sqlite3_stmt *statement;
    sqlite3_prepare_v2(db, "SELECT count(*) FROM item", -1, &statement, NULL);
    sqlite3_step(statement);
    int rows = sqlite3_column_int(statement, 0);
    sqlite3_finalize(statement);
    sqlite3_prepare_v2(db, "PRAGMA integrity_check", -1, &statement, NULL);
    sqlite3_step(statement);
    printf("    rows %d of 3000, statements that failed %d, integrity_check: %s\n", rows, failures,
           (const char *)sqlite3_column_text(statement, 0));
    sqlite3_finalize(statement);
    sqlite3_close(db);
}

int main(int argc, char **argv) {
    path = argc > 1 ? argv[1] : "/tmp/q6-locking.sqlite";
    printf("SQLite %s, sqlite3_threadsafe() = %d, compiled with THREADSAFE=%s\n", sqlite3_libversion(), sqlite3_threadsafe(),
           sqlite3_compileoption_used("THREADSAFE=0") ? "0" : sqlite3_compileoption_used("THREADSAFE=2") ? "2" : "1");

    struct { const char *label; int option; } modes[] = {
        {"process default", 0}, {"SQLITE_CONFIG_MULTITHREAD", SQLITE_CONFIG_MULTITHREAD},
        {"SQLITE_CONFIG_SERIALIZED", SQLITE_CONFIG_SERIALIZED}, {"SQLITE_CONFIG_SINGLETHREAD", SQLITE_CONFIG_SINGLETHREAD}};

    printf("  sqlite3_config before sqlite3_initialize (MULTITHREAD, SERIALIZED, SINGLETHREAD): ");
    for (int i = 1; i < 4; i++) { option = modes[i].option; child(configBeforeInitialize); }
    printf("\n");
    child(configAfterInitialize);

    for (int i = 0; i < 4; i++) {
        option = modes[i].option;
        printf("  %s, per connection:\n", modes[i].label);
        child(perConnection);
    }
    for (int i = 0; i < 4; i += 3) {
        option = modes[i].option;
        printf("  %s, one thread per connection (1 writer, 3 readers, WAL, NOMUTEX), 3 runs:\n", modes[i].label);
        for (int run = 0; run < 3; run++) child(threads);
    }
    unlink(path);
    return 0;
}
