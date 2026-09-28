public import Byte
public import ISO_9075_Foundation
public import SQL

extension QueryExpression
where QueryValue: _OptionalPromotable, QueryValue._Optionalized.Wrapped == String {
    public func groupConcat(
        _ separator: (some QueryExpression)? = String?.none,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression<String?>(
            "group_concat",
            separator.map { [queryFragment, $0.queryFragment] } ?? [queryFragment],
            filter: filter?.queryFragment
        )
    }

    public func groupConcat(
        _ separator: (some QueryExpression)? = String?.none,
        order: some QueryExpression,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression<String?>(
            "group_concat",
            separator.map { [queryFragment, $0.queryFragment] } ?? [queryFragment],
            order: order.queryFragment,
            filter: filter?.queryFragment
        )
    }

    public func groupConcat(
        distinct isDistinct: Bool,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression<String?>(
            "group_concat",
            distinct: isDistinct,
            [queryFragment],
            filter: filter?.queryFragment
        )
    }

    public func groupConcat(
        distinct isDistinct: Bool,
        order: some QueryExpression,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression<String?>(
            "group_concat",
            distinct: isDistinct,
            [queryFragment],
            order: order.queryFragment,
            filter: filter?.queryFragment
        )
    }
}

extension QueryExpression
where QueryValue: _OptionalPromotable, QueryValue._Optionalized.Wrapped: Numeric {
    public func total(
        distinct isDistinct: Bool = false,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<Double> {
        AggregateFunctionExpression<Double>(
            "total",
            distinct: isDistinct,
            [queryFragment],
            filter: filter?.queryFragment
        )
    }
}

extension QueryExpression where QueryValue == String {
    public func glob(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        BinaryOperator<Bool>(lhs: self, operator: "GLOB", rhs: "\(pattern)")
    }

    public func instr(_ occurrence: some QueryExpression<QueryValue>) -> some QueryExpression<Int> {
        QueryFunction<Int>("instr", self, occurrence)
    }
}

extension QueryExpression where QueryValue: SQL::_OptionalProtocol {
    public func ifnull<W>(
        _ other: some QueryExpression<W>
    ) -> some QueryExpression<W> where W == QueryValue.Wrapped {
        QueryFunction<W>("ifnull", self, other)
    }

    public func ifnull(
        _ other: some QueryExpression<QueryValue>
    ) -> some QueryExpression<QueryValue> {
        QueryFunction<QueryValue>("ifnull", self, other)
    }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
    public func quote() -> some QueryExpression<QueryValue> {
        QueryFunction<QueryValue>("quote", self)
    }
}

extension QueryExpression where QueryValue == [Byte] {
    public func hex() -> some QueryExpression<String> {
        QueryFunction<String>("hex", self)
    }
}
