import ISO_9075_Foundation
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Item {
    let id: Int
    var price: Double
}

@Suite(.timeLimit(.minutes(5))) struct `The SQLite dialect` {
    @Test func `spells an unbounded limit as -1`() throws {
        #expect(try SQLite().render(Item.offset(10).select(\.id).query).sql.hasSuffix("LIMIT -1 OFFSET ?"))
    }

    @Test func `rounds a real as it is`() throws {
        #expect(try SQLite().render(Item.select { $0.price.round(2) }.query).sql.hasPrefix(#"SELECT round("item"."price", ?)"#))
        #expect(try SQLite().render(Item.select { $0.price.round() }.query).sql.hasPrefix(#"SELECT round("item"."price")"#))
    }
}
