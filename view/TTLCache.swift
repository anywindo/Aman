//
//  TTLCache.swift
//  Aman
//
//  Simple in-memory TTL cache using an actor for thread safety.
//

import Foundation

actor TTLCache<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let expiry: Date
    }

    private var storage: [Key: Entry] = [:]

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if Date() <= entry.expiry {
            return entry.value
        } else {
            storage.removeValue(forKey: key)
            return nil
        }
    }

    func set(_ key: Key, value: Value, ttl: TimeInterval) {
        let expiry = Date().addingTimeInterval(ttl)
        storage[key] = Entry(value: value, expiry: expiry)
    }

    func clear() {
        storage.removeAll()
    }
}
