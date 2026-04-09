//
//  ClearKeyContentKeyProviding.swift
//  Pods
//
//  Created by 立宣于 on 2026/4/8.
//

public protocol ClearKeyContentKeyProviding: Sendable {
  func loadContentKey(from keyURL: URL) async throws -> (key: Data, iv: Data)
}
