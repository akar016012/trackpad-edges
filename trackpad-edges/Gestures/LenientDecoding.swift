/**
 Reads one value, and holds nil when this version of the app cannot read it.

 Settings saved by a newer version can hold values that an older one does not know, such as a
 new edge action. Reading each value through this type means that only that value falls back,
 where a plain read would refuse the whole set of settings.
 */
nonisolated struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

nonisolated extension KeyedDecodingContainer {
    /// Returns the value for a key, or nil when it is missing or cannot be read.
    func lenient<Value: Decodable>(_ key: Key) -> Value? {
        (try? decodeIfPresent(Lenient<Value>.self, forKey: key))?.value
    }

    /// Returns the items of a list that can be read, or nil when the list itself is missing.
    func lenientList<Element: Decodable>(_ key: Key) -> [Element]? {
        let list: [Lenient<Element>]? = lenient(key)
        return list?.compactMap(\.value)
    }

    /**
     Returns the pairs of a dictionary that can be read. A dictionary whose keys are not plain
     strings is saved as one list that alternates keys and values, so this walks that list.
     */
    func lenientPairs<Name: Decodable & Hashable, Value: Decodable>(_ key: Key) -> [Name: Value] {
        guard var list = try? nestedUnkeyedContainer(forKey: key) else { return [:] }
        var pairs: [Name: Value] = [:]
        while !list.isAtEnd {
            guard let name = try? list.decode(Lenient<Name>.self), !list.isAtEnd,
                let value = try? list.decode(Lenient<Value>.self)
            else { break }
            if let name = name.value, let value = value.value { pairs[name] = value }
        }
        return pairs
    }
}

nonisolated extension ClosedRange where Bound: BinaryFloatingPoint {
    /// Returns a number held to this range, or nil for one that is missing or not finite.
    func holding(_ value: Bound?) -> Bound? {
        guard let value, value.isFinite else { return nil }
        return Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
