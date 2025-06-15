//
//  TabFocusError.swift
//  Stinsen
//
//  Created by Yousef Mohamed on 15/06/2025.
//

import Foundation

// MARK: - Tab Focus Error Types
public enum TabFocusError: Error, LocalizedError {
    case tabNotFound
    case invalidCast(expected: Any.Type, actual: Any.Type)
    case notInitialized
    case coordinatorDeallocated

    public var errorDescription: String? {
        switch self {
        case .tabNotFound:
            return "The requested tab could not be found"
        case .invalidCast(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .notInitialized:
            return "Tab coordinator is not initialized"
        case .coordinatorDeallocated:
            return "Coordinator has been deallocated"
        }
    }
}
