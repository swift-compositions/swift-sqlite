public import ISO_9075_Foundation

extension ISO_9075.Fragment {
    package func compiled(statementType: String) -> Self {
        do {
            return Self(try SQLite().inline(self))
        } catch {
            preconditionFailure("A '\(statementType)' statement cannot inline \(error.description)")
        }
    }
}
