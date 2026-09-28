public import ISO_9075_Foundation
public import Time
public import SQL

public protocol _DateTimeModifiable<QueryValue>: QueryExpression
where QueryValue: _SQLiteDateRepresentation {}

extension TableColumn: _DateTimeModifiable where Value: _SQLiteDateRepresentation {}
extension GeneratedColumn: _DateTimeModifiable where Value: _SQLiteDateRepresentation {}
extension SQLQueryExpression: _DateTimeModifiable where QueryValue: _SQLiteDateRepresentation {}
extension AggregateFunctionExpression: _DateTimeModifiable
where QueryValue: _SQLiteDateRepresentation {}
extension CoalesceFunction: _DateTimeModifiable where QueryValue: _SQLiteDateRepresentation {}
extension _ModifiedDate: _DateTimeModifiable {}

extension _DateTimeModifiable {
  public func callAsFunction(_ modifier: DateTimeModifier) -> _ModifiedDate<QueryValue> {
    _ModifiedDate(base: timeValueArguments, modifier: modifier)
  }
}

extension QueryExpression where QueryValue: _SQLiteDateRepresentation {
  public func strftime(_ format: String) -> some QueryExpression<String?> {
    SQLQueryExpression("strftime(\(bind: format), \(timeValueArguments.joined(separator: ", ")))")
  }

  public var year: some QueryExpression<Int> { component("%Y") }

  public var month: some QueryExpression<Int> { component("%m") }

  public var day: some QueryExpression<Int> { component("%d") }

  public var hour: some QueryExpression<Int> { component("%H") }

  public var minute: some QueryExpression<Int> { component("%M") }

  public var second: some QueryExpression<Int> { component("%S") }

  public var fractionalSecond: some QueryExpression<Double> { component("%f") }

  public var weekday: some QueryExpression<Int> { component("%w") }

  public var dayOfYear: some QueryExpression<Int> { component("%j") }

  fileprivate var timeValueArguments: [ISO_9075.Fragment] {
    (self as? any TimeValue)?.timeValueArguments
      ?? [queryFragment] + QueryValue._timeValueModifiers
  }
  private func component<T: Numeric & SQLiteType>(
    _ format: ISO_9075.Fragment
  ) -> SQLQueryExpression<T> {
    SQLQueryExpression(
      """
      CAST(strftime('\(format)', \(timeValueArguments.joined(separator: ", "))) \
      AS \(T.typeAffinity.rawValue))
      """
    )
  }
}

extension QueryExpression where Self == _ModifiedDate<Time.Instant> {
  public static var now: Self { Self() }
}

extension QueryExpression where Self == _ModifiedDate<Time.Instant.UnixTimeRepresentation> {
  public static var now: Self { Self() }
}

extension QueryExpression where Self == _ModifiedDate<Time.Instant.JulianDayRepresentation> {
  public static var now: Self { Self() }
}

@dynamicMemberLookup
public struct DateTimeModifier: Sendable {
  var fragments: [ISO_9075.Fragment] = []

  public enum Overflow: Sendable {
    case ceiling

    case floor

    fileprivate var fragment: ISO_9075.Fragment {
      switch self {
      case .ceiling: "'ceiling'"
      case .floor: "'floor'"
      }
    }
  }

  public static func years(_ count: Int) -> Self { Self().years(count) }

  public static func years(_ count: Int, _ overflow: Overflow) -> Self {
    Self().years(count, overflow)
  }

  public static func months(_ count: Int) -> Self { Self().months(count) }

  public static func months(_ count: Int, _ overflow: Overflow) -> Self {
    Self().months(count, overflow)
  }

  public static func days(_ count: Int) -> Self { Self().days(count) }

  public static func hours(_ count: Int) -> Self { Self().hours(count) }

  public static func minutes(_ count: Int) -> Self { Self().minutes(count) }

  public static func seconds(_ count: Double) -> Self { Self().seconds(count) }

  public static func milliseconds(_ count: Int) -> Self { Self().milliseconds(count) }

  public static var startOfDay: Self { Self().startOfDay }

  public static var startOfMonth: Self { Self().startOfMonth }

  public static var startOfYear: Self { Self().startOfYear }

  public static func weekday(_ day: Int) -> Self { Self().weekday(day) }

  public func years(_ count: Int) -> Self { appending("'\(raw: count) years'") }

  public func years(_ count: Int, _ overflow: Overflow) -> Self {
    years(count).appending(overflow.fragment)
  }

  public func months(_ count: Int) -> Self { appending("'\(raw: count) months'") }

  public func months(_ count: Int, _ overflow: Overflow) -> Self {
    months(count).appending(overflow.fragment)
  }

  public func days(_ count: Int) -> Self { appending("'\(raw: count) days'") }

  public func hours(_ count: Int) -> Self { appending("'\(raw: count) hours'") }

  public func minutes(_ count: Int) -> Self { appending("'\(raw: count) minutes'") }

  public func seconds(_ count: Double) -> Self {
    precondition(count.isFinite, "Cannot convert a non-finite number of seconds to a modifier")
    return appending("'\(raw: count) seconds'")
  }

  public func milliseconds(_ count: Int) -> Self {
    let sign = count < 0 ? "-" : ""
    let fraction = String(count.magnitude % 1000 + 1000).dropFirst()
    return appending("'\(raw: sign)\(raw: count.magnitude / 1000).\(raw: fraction) seconds'")
  }

  public var startOfDay: Self { appending("'start of day'") }

  public var startOfMonth: Self { appending("'start of month'") }

  public var startOfYear: Self { appending("'start of year'") }

  public func weekday(_ day: Int) -> Self { appending("'weekday \(raw: day)'") }

  public subscript(dynamicMember keyPath: KeyPath<Self.Type, Self>) -> Self {
    Self(fragments: fragments + Self.self[keyPath: keyPath].fragments)
  }

  private func appending(_ fragment: ISO_9075.Fragment) -> Self {
    Self(fragments: fragments + [fragment])
  }
}

public protocol _SQLiteDateRepresentation: QueryRepresentable where QueryOutput == Time.Instant {
  static var _timeValueModifiers: [ISO_9075.Fragment] { get }
  static func _dateStorage(_ arguments: [ISO_9075.Fragment]) -> ISO_9075.Fragment
}

private protocol TimeValue {
  var timeValueArguments: [ISO_9075.Fragment] { get }
}

public struct _ModifiedDate<QueryValue: _SQLiteDateRepresentation>: QueryExpression, TimeValue {
  fileprivate var base: [ISO_9075.Fragment] = ["'now'"]
  fileprivate var modifier = DateTimeModifier()

  fileprivate var timeValueArguments: [ISO_9075.Fragment] {
    base + modifier.fragments
  }

  public var queryFragment: ISO_9075.Fragment {
    QueryValue._dateStorage(timeValueArguments)
  }
}

extension Time.Instant: _SQLiteDateRepresentation {
  public static var _timeValueModifiers: [ISO_9075.Fragment] { [] }
  public static func _dateStorage(_ arguments: [ISO_9075.Fragment]) -> ISO_9075.Fragment {
    subsecDateTime(arguments)
  }
}

func subsecDateTime(_ arguments: [ISO_9075.Fragment] = []) -> ISO_9075.Fragment {
  return "datetime(\((arguments + ["'subsec'"]).joined(separator: ", ")))"
}

extension Time.Instant.UnixTimeRepresentation: _SQLiteDateRepresentation {
  public static var _timeValueModifiers: [ISO_9075.Fragment] { ["'unixepoch'"] }
  public static func _dateStorage(_ arguments: [ISO_9075.Fragment]) -> ISO_9075.Fragment {
    "unixepoch(\(arguments.joined(separator: ", ")))"
  }
}

extension Time.Instant.JulianDayRepresentation: _SQLiteDateRepresentation {
  public static var _timeValueModifiers: [ISO_9075.Fragment] { [] }
  public static func _dateStorage(_ arguments: [ISO_9075.Fragment]) -> ISO_9075.Fragment {
    "julianday(\(arguments.joined(separator: ", ")))"
  }
}
