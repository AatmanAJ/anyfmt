import Foundation

// Owned by lane D (Image + PDF).
public enum ImageEngines {
    public static let all: [any ConversionEngine] = [
        ImageIOEngine(),
        FFmpegImageEngine(),
        ResvgEngine(),
        PDFKitEngine(),
    ]
}
