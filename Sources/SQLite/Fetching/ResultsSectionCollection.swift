import SQLite_SQL

public struct ResultsSectionCollection<Element, SectionName: Hashable> {
    private(set) var elements: [Element]

    /// The sections' names, in the order each first appears in the rows.
    public private(set) var sectionNames: [SectionName]
    /// The indices of each section's elements, in the order of `sectionNames`.
    private var elementIndices: [ElementIndices]
    private var sectionIndexByName: [SectionName: Int]

    public init() {
        elements = []
        sectionNames = []
        elementIndices = []
        sectionIndexByName = [:]
    }

    init(elements: [Element], sectionName: SectionName) {
        self.elements = elements
        sectionNames = elements.isEmpty ? [] : [sectionName]
        elementIndices = elements.isEmpty ? [] : [ElementIndices(range: elements.indices)]
        sectionIndexByName = elements.isEmpty ? [:] : [sectionName: 0]
    }

    /// The rows of a sectioned statement, each with the name of its section: a section is every row of one name,
    /// in the rows' order, and the sections are in the order their names first appear.
    init(sectioned rows: some Sequence<(Element, SectionName)>) {
        self.init()
        var elements: [Element] = []
        for (element, name) in rows {
            let index = elements.count
            if let section = sectionIndexByName[name] {
                elementIndices[section].append(index)
            } else {
                sectionIndexByName[name] = sectionNames.count
                sectionNames.append(name)
                elementIndices.append(ElementIndices(range: index..<index + 1))
            }
            elements.append(element)
        }
        self.elements = elements
    }

    public subscript(sectionName name: SectionName) -> ResultsSection<Element, SectionName>? {
        sectionIndexByName[name].map { self[$0] }
    }

    public func contains(sectionName name: SectionName) -> Bool {
        sectionIndexByName[name] != nil
    }

    public func index(ofSectionNamed name: SectionName) -> Int? {
        sectionIndexByName[name]
    }
}

extension ResultsSectionCollection: RandomAccessCollection {
    public var startIndex: Int { 0 }

    public var endIndex: Int { sectionNames.count }

    public subscript(position: Int) -> ResultsSection<Element, SectionName> {
        ResultsSection(name: sectionNames[position], base: elements, elementIndices: elementIndices[position])
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
