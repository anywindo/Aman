//
//  PcapPacket.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


import Foundation

struct PcapPacket: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let length: Int
    let proto: String
    let src: String
    let dst: String
}
