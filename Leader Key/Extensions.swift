//
//  Extensions.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 28/01/2025.
//

import SwiftUI

// Allow optional strings as values for TextField
func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
  Binding(
    get: { lhs.wrappedValue ?? rhs },
    set: { lhs.wrappedValue = $0 }
  )
}
