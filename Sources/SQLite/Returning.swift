public import ISO_9075_Foundation
public import SQL

extension Delete {
  public func returning<each QueryValue: QueryRepresentable>(
    _ selection: (From.TableColumns) -> (repeat TableColumn<From, each QueryValue>)
  ) -> Delete<From, (repeat each QueryValue)> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in repeat each selection(From.columns) {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }

  @_documentation(visibility: private)
  public func returning(
    _ selection: (From.TableColumns) -> From.TableColumns
  ) -> Delete<From, From> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in From.TableColumns.allColumns {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }
}

extension Insert {
  public func returning<each QueryValue: QueryRepresentable>(
    _ selection: (Into.TableColumns) -> (repeat TableColumn<Into, each QueryValue>)
  ) -> Insert<Into, (repeat each QueryValue)> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in repeat each selection(Into.columns) {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }

  @_documentation(visibility: private)
  public func returning(
    _ selection: (Into.TableColumns) -> Into.TableColumns
  ) -> Insert<Into, Into> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in Into.TableColumns.allColumns {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }
}

extension Update {
  public func returning<each QueryValue: QueryRepresentable>(
    _ selection: (From.TableColumns) -> (repeat TableColumn<From, each QueryValue>)
  ) -> Update<From, (repeat each QueryValue)> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in repeat each selection(From.columns) {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }

  @_documentation(visibility: private)
  public func returning(
    _ selection: (From.TableColumns) -> From.TableColumns
  ) -> Update<From, From> {
    var returning: [ISO_9075.Fragment] = []
    for resultColumn in From.TableColumns.allColumns {
      returning.append(resultColumn.returningFragment)
    }
    return self.returning(fragments: returning)
  }
}
