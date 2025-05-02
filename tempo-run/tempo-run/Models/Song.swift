//
//  Song.swift
//  tempo-run
//
//  Created by Sanya Chawla on 5/2/25.
//

import Foundation
struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    var bpm: Double?
    var genre: String?
    var paces: [Double] = []

    var averagePace: Double {
        paces.isEmpty ? 0 : paces.reduce(0, +) / Double(paces.count)
    }
}

