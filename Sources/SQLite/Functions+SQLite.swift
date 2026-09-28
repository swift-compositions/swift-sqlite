// moved from swift-sql AggregateFunctions.swift

    public func groupConcat(
        _ separator: (some QueryExpression)? = String?.none,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression(
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
        AggregateFunctionExpression(
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
        AggregateFunctionExpression(
            "group_concat",
            isDistinct: isDistinct,
            [queryFragment],
            filter: filter?.queryFragment
        )
    }

    public func groupConcat(
        distinct isDistinct: Bool,
        order: some QueryExpression,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<String?> {
        AggregateFunctionExpression(
            "group_concat",
            isDistinct: isDistinct,
            [queryFragment],
            order: order.queryFragment,
            filter: filter?.queryFragment
        )
    }

    public func total(
        distinct isDistinct: Bool = false,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> some QueryExpression<Double> {
        AggregateFunctionExpression<Double>(
            "total",
            isDistinct: isDistinct,
            [queryFragment],
            filter: filter?.queryFragment
        )
    }
// moved from swift-sql Operators.swift

    public func glob(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        BinaryOperator(lhs: self, operator: "GLOB", rhs: "\(pattern)")
    }
// moved from swift-sql ScalarFunctions.swift

    public func ifnull<W>(
        _ other: some QueryExpression<W>
    ) -> some QueryExpression<W> where W == QueryValue.Wrapped {
        QueryFunction("ifnull", self, other)
    }

    public func ifnull(
        _ other: some QueryExpression<QueryValue>
    ) -> some QueryExpression<QueryValue> {
        QueryFunction("ifnull", self, other)
    }

    public func instr(_ occurrence: some QueryExpression<QueryValue>) -> some QueryExpression<Int> {
        QueryFunction("instr", self, occurrence)
    }

    public func quote() -> some QueryExpression<QueryValue> {
        QueryFunction("quote", self)
    }

    public func hex() -> some QueryExpression<String> {
        QueryFunction("hex", self)
    }
