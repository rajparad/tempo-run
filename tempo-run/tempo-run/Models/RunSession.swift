//
//  RunSession.swift
//  tempo-run
//
//  Created by Sanya Chawla on 5/2/25.
//

import Foundation

struct PlayedSong: Codable {
    let song: Song
    let paceBefore: Double
    let paceDuring: Double
}

struct RunSession: Identifiable, Codable {
    let id: String = UUID().uuidString
    let mode: RunMode
    let targetPace: Double?
    let startTime: Date
    let duration: TimeInterval
    let distance: Double
    let songsPlayed: [PlayedSong]  
}
