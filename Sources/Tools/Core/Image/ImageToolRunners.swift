import Foundation

// Lane G1: image tools 1–11 and metadata tools 23–24. Implementations live in
// the sibling folders; this list is what `ToolRunners.all` ships.
public enum ImageToolRunners {
    public static let all: [any ToolRunner] = [
        CompressImageRunner(),
        ResizeImageRunner(),
        CropImageRunner(),
        AdjustImageRunner(),
        AnnotateImageRunner(),
        RedactImageRunner(),
        RemoveBackgroundRunner(),
        AddBackgroundRunner(),
        CollageRunner(),
        ImagesToPDFRunner(),
        ReadCodesRunner(),
        EditMetadataRunner(),
        StripMetadataRunner(),
    ]
}
