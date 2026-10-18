import Foundation
import CoreGraphics
import CoreImage
import Vision

/// Subject masks from Vision (research/PLATFORM_RESEARCH.md §D):
/// macOS 14+ uses `VNGenerateForegroundInstanceMaskRequest` (any subject);
/// macOS 13 only has `VNGeneratePersonSegmentationRequest`, so non-people
/// images get a clear error instead of a bad cut-out.
public enum SubjectMasker {
    public enum Method: Sendable { case automatic, personOnly }

    /// Soft mask (white = subject) with the image's extent.
    public static func mask(for image: CGImage, method: Method = .automatic) throws -> CIImage {
        if method == .automatic, #available(macOS 14.0, *) {
            return try foregroundMask(image)
        }
        return try personMask(image)
    }

    @available(macOS 14.0, *)
    private static func foregroundMask(_ image: CGImage) throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch {
            throw ConversionError.other(L("Background removal isn’t available right now."), detail: "Vision foreground: \(error)")
        }
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ConversionError.other(L("\(Brand.name) couldn’t find a subject to cut out in this image."), detail: "no foreground instances")
        }
        let buffer: CVPixelBuffer
        do {
            buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        } catch {
            throw ConversionError.other(L("Background removal isn’t available right now."), detail: "scaled mask: \(error)")
        }
        return fit(CIImage(cvPixelBuffer: buffer), to: image)
    }

    private static func personMask(_ image: CGImage) throws -> CIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch {
            throw ConversionError.other(L("Background removal isn’t available right now."), detail: "Vision person: \(error)")
        }
        guard let buffer = request.results?.first?.pixelBuffer else { throw noPerson }
        let mask = fit(CIImage(cvPixelBuffer: buffer), to: image)
        // Reject masks with (almost) no person in them.
        guard coverage(of: mask) > 0.01 else { throw noPerson }
        return mask
    }

    private static var noPerson: ConversionError {
        .other(L("\(Brand.name) couldn’t find a person in this image. On macOS 13, background removal works for people only; macOS 14 or later can cut out any subject."),
               detail: "person segmentation found no person")
    }

    /// Scales a (possibly lower-resolution) mask to the image, smoothly.
    private static func fit(_ mask: CIImage, to image: CGImage) -> CIImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let ext = mask.extent
        guard ext.width > 0, ext.height > 0 else { return mask }
        var m = mask.transformed(by: CGAffineTransform(translationX: -ext.minX, y: -ext.minY))
        if abs(ext.width - w) > 0.5 || abs(ext.height - h) > 0.5 {
            let f = CIFilter(name: "CILanczosScaleTransform")
            f?.setValue(m.clampedToExtent(), forKey: kCIInputImageKey)
            f?.setValue(h / ext.height, forKey: kCIInputScaleKey)
            f?.setValue((w / ext.width) / (h / ext.height), forKey: kCIInputAspectRatioKey)
            m = f?.outputImage ?? m
        }
        return m.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    }

    private static func coverage(of mask: CIImage) -> Double {
        let f = CIFilter(name: "CIAreaAverage")
        f?.setValue(mask, forKey: kCIInputImageKey)
        f?.setValue(CIVector(cgRect: mask.extent), forKey: kCIInputExtentKey)
        guard let out = f?.outputImage else { return 0 }
        var px = [UInt8](repeating: 0, count: 4)
        ImageSupport.managedContext.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                           format: .RGBA8, colorSpace: nil)
        return Double(px[0]) / 255
    }

    /// The subject on transparency. Edges are feathered by about a pixel
    /// (relative to image size) so cut-outs don't look jagged.
    public static func cutout(_ image: CGImage, method: Method = .automatic) throws -> CGImage {
        let mask = try mask(for: image, method: method)
        let feather = max(0.6, Double(min(image.width, image.height)) / 1600)
        let soft = mask.clampedToExtent().applyingGaussianBlur(sigma: feather).cropped(to: mask.extent)
        let input = CIImage(cgImage: image)
        let f = CIFilter(name: "CIBlendWithMask")
        f?.setValue(input, forKey: kCIInputImageKey)
        f?.setValue(CIImage(color: .clear).cropped(to: input.extent), forKey: kCIInputBackgroundImageKey)
        f?.setValue(soft, forKey: kCIInputMaskImageKey)
        guard let out = f?.outputImage else {
            throw ConversionError.other(L("Background removal isn’t available right now."), detail: "CIBlendWithMask")
        }
        return try ImageSupport.render(out.cropped(to: input.extent), width: image.width, height: image.height,
                                       colorSpace: ImageSupport.colorSpace(of: image), like: image, opaque: false)
    }
}

/// Tool 7: Remove background → PNG with alpha.
struct RemoveBackgroundRunner: ToolRunner {
    let id = ToolIDs.removeBackground
    var method: SubjectMasker.Method = .automatic

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        try await PixelToolPipeline(request: request, context: context).run(outputFormat: Formats.png) { decoded in
            try SubjectMasker.cutout(decoded.image, method: method)
        }
    }
}
