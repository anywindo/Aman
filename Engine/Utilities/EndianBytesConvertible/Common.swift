extension FixedWidthInteger {
    static var isExactlyByteRepresentable: Bool {
        0 <= bitWidth && bitWidth.isMultiple(of: 8)
    }
}
