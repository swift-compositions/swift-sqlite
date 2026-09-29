#if GRDB
    internal import GRDB
    internal import OrderedCollections

    public struct ResultsSectionCollection<Element, SectionName: Hashable> {
      let elements: [Element]
      private let elementIndicesBySectionName: OrderedDictionary<SectionName, ElementIndices>

      public init() {
        elements = []
        elementIndicesBySectionName = [:]
      }

      init(elements: [Element], sectionName: SectionName) {
        self.elements = elements
        self.elementIndicesBySectionName =
          elements.isEmpty ? [:] : [sectionName: ElementIndices(range: elements.indices)]
      }

      public var sectionNames: [SectionName] {
        elementIndicesBySectionName.keys.elements
      }

      public subscript(sectionName name: SectionName) -> ResultsSection<Element, SectionName>? {
        elementIndicesBySectionName[name].map {
          ResultsSection(name: name, base: elements, elementIndices: $0)
        }
      }

      public func contains(sectionName name: SectionName) -> Bool {
        elementIndicesBySectionName.keys.contains(name)
      }

      public func index(ofSectionNamed name: SectionName) -> Int? {
        elementIndicesBySectionName.index(forKey: name)
      }
    }

    extension ResultsSectionCollection {
      init(cursor: QueryCursor<(Element, SectionName)>) throws {
        var elements: [Element] = []
        var elementIndicesBySectionName: OrderedDictionary<SectionName, ElementIndices> = [:]
        while let (element, sectionName) = try cursor.next() {
          let index = elements.count
          elementIndicesBySectionName[sectionName, default: ElementIndices(range: index..<index)]
            .append(index)
          elements.append(element)
        }
        self.elements = elements
        self.elementIndicesBySectionName = elementIndicesBySectionName
      }
    }

    extension ResultsSectionCollection: RandomAccessCollection {
      public var startIndex: Int {
        elementIndicesBySectionName.elements.startIndex
      }

      public var endIndex: Int {
        elementIndicesBySectionName.elements.endIndex
      }

      public subscript(position: Int) -> ResultsSection<Element, SectionName> {
        let (name, elementIndices) = elementIndicesBySectionName.elements[position]
        return ResultsSection(name: name, base: elements, elementIndices: elementIndices)
      }
    }

    extension ResultsSectionCollection: Sendable where Element: Sendable, SectionName: Sendable {}

    extension ResultsSectionCollection: Equatable where Element: Equatable {
      public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elementsEqual(rhs)
      }
    }

    public struct ResultsSection<Element, SectionName: Hashable>: Identifiable {
      public let name: SectionName

      private let base: [Element]
      private let elementIndices: ElementIndices

      fileprivate init(name: SectionName, base: [Element], elementIndices: ElementIndices) {
        self.name = name
        self.base = base
        self.elementIndices = elementIndices
      }

      public var id: SectionName {
        name
      }
    }

    extension ResultsSection: RandomAccessCollection {
      public var startIndex: Int {
        0
      }

      public var endIndex: Int {
        elementIndices.count
      }

      public subscript(position: Int) -> Element {
        base[elementIndices[position]]
      }
    }

    extension ResultsSection: Sendable where Element: Sendable, SectionName: Sendable {}

    extension ResultsSection: Equatable where Element: Equatable {
      public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.elementsEqual(rhs)
      }
    }

    private struct ElementIndices: Sendable {
      var range: Range<Int>
      var overflow: [Int] = []

      var count: Int {
        range.count + overflow.count
      }

      subscript(position: Int) -> Int {
        position < range.count
          ? range.lowerBound + position
          : overflow[position - range.count]
      }

      mutating func append(_ index: Int) {
        if index == range.upperBound {
          range = range.lowerBound..<index + 1
        } else {
          overflow.append(index)
        }
      }
    }

#endif
