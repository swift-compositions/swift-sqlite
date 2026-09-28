public import SQL

extension Collation where Self == NamedCollation {
  public static var binary: Self { Self("BINARY") }

  public static var nocase: Self { Self("NOCASE") }

  public static var rtrim: Self { Self("RTRIM") }
}
