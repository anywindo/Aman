import Foundation

struct PcapPacket: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let length: Int
    let proto: String
    let src: String
    let dst: String
}
