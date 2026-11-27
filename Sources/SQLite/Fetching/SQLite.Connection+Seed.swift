public import ISO_9075_Call_Level_Interface
public import SQL
public import SQLite_SQL

extension SQLite.Connection {
    /// Inserts the rows `build` lists, in order.
    public borrowing func seed(@SeedsBuilder _ build: () -> [Seed]) throws(ISO.`9075`.Error) {
        for insert in Seeds(build) {
            try insert.execute(self)
        }
    }
}
