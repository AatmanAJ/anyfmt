import Foundation
import CoreGraphics
import CoreImage

// MARK: - Resize (tool 2)

/// Target size for the resize tool's options. Shared by the runner and the
/// wheel's options popover ("4032 × 3024 → 1920 × 1440").
public enum ResizePlan {
    public static func targetSize(for source: CGSize, options o: OptionValues) -> CGSize {
        let w = max(1, source.width), h = max(1, source.height)
        switch o.string("mode", default: "percent") {
        case "preset":
            let edge = CGFloat(max(1, o.int("preset", default: 1920)))
            let longest = max(w, h)
            guard longest > edge else { return CGSize(width: w, height: h) } // presets never upscale
            let s = edge / longest
            return CGSize(width: max(1, (w * s).rounded()), height: max(1, (h * s).rounded()))
        case "pixels":
            let tw = CGFloat(max(0, o.int("width", default: 1920))), th = CGFloat(max(0, o.int("height", default: 0)))
            switch (tw > 0, th > 0) {
            case (true, true): return CGSize(width: tw, height: th)
            case (true, false): return CGSize(width: tw, height: max(1, (h * tw / w).rounded()))
            case (false, true): return CGSize(width: max(1, (w * th / h).rounded()), height: th)
            default: return CGSize(width: w, height: h)
            }
        default:
            let s = CGFloat(min(400, max(1, o.int(OptionKey.percent, default: 50)))) / 100
            return CGSize(width: max(1, (w * s).rounded()), height: max(1, (h * s).rounded()))
        }
    }
}

struct ResizeImageRunner: ToolRunner {
    let id = ToolIDs.resizeImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        try await PixelToolPipeline(request: request, context: context).run { decoded in
            let t = ResizePlan.targetSize(for: decoded.size, options: request.options)
            guard Int(t.width) <= 32768, Int(t.height) <= 32768 else { throw ConversionError.invalidOption("width") }
            return try ToolImageSupport.resample(decoded.image, width: Int(t.width), height: Int(t.height))
        }
    }
}

// MARK: - Crop (tool 3)

/// Crop rectangles: normalised "x,y,w,h", origin top-left, plus aspect presets.
public enum CropGeometry {
    public static func parseRect(_ s: String) -> CGRect? {
        let parts = s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    public static func format(_ r: CGRect) -> String {
        func f(_ v: CGFloat) -> String { String(format: "%.5f", Double(v)) }
        return [r.minX, r.minY, r.width, r.height].map(f).joined(separator: ",")
    }

    /// Width / height of an aspect preset ("16:9"), nil for "free".
    public static func ratio(_ aspect: String) -> CGFloat? {
        let p = aspect.split(separator: ":").compactMap { Double($0) }
        guard p.count == 2, p[0] > 0, p[1] > 0 else { return nil }
        return CGFloat(p[0] / p[1])
    }

    /// Clamps `normalized` into the unit square and, with a ratio, shrinks it
    /// around its centre to that pixel aspect. Returns whole pixels.
    public static func pixelRect(_ normalized: CGRect, aspect: String, imageSize: CGSize) -> CGRect {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        var r = normalized.standardized.intersection(unit)
        if r.isNull || r.width <= 0 || r.height <= 0 { r = unit }
        var px = CGRect(x: r.minX * imageSize.width, y: r.minY * imageSize.height,
                        width: r.width * imageSize.width, height: r.height * imageSize.height)
        if let ratio = ratio(aspect) {
            let current = px.width / px.height
            if current > ratio {
                let w = px.height * ratio
                px = CGRect(x: px.midX - w / 2, y: px.minY, width: w, height: px.height)
            } else if current < ratio {
                let h = px.width / ratio
                px = CGRect(x: px.minX, y: px.midY - h / 2, width: px.width, height: h)
            }
        }
        let x0 = max(0, px.minX.rounded()), y0 = max(0, px.minY.rounded())
        let x1 = min(imageSize.width, px.maxX.rounded()), y1 = min(imageSize.height, px.maxY.rounded())
        return CGRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
    }

    /// The largest centred rectangle of `aspect` inside the image, normalised.
    public static func defaultRect(aspect: String, imageSize: CGSize) -> CGRect {
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard ratio(aspect) != nil, imageSize.width > 0, imageSize.height > 0 else { return full }
        let px = pixelRect(full, aspect: aspect, imageSize: imageSize)
        return CGRect(x: px.minX / imageSize.width, y: px.minY / imageSize.height,
                      width: px.width / imageSize.width, height: px.height / imageSize.height)
    }
}

struct CropImageRunner: ToolRunner {
    let id = ToolIDs.cropImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        try await PixelToolPipeline(request: request, context: context).run { decoded in
            let rect = CropGeometry.parseRect(request.options.string("rect", default: "0,0,1,1"))
                ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            let px = CropGeometry.pixelRect(rect, aspect: request.options.string("aspect", default: "free"), imageSize: decoded.size)
            guard let cropped = decoded.image.cropping(to: px) else {
                throw ConversionError.other(L("The crop area is outside the image."), detail: "cropping(to: \(px)) failed")
            }
            return cropped
        }
    }
}

// MARK: - Adjust (tool 4)

/// Exposure / contrast / saturation / warmth, applied with Core Image in a
/// colour-managed context. Shared by the runner and the editor's live preview.
public struct ImageAdjustments: Sendable, Hashable {
    public var exposure: Double   // EV, −2…2
    public var contrast: Double   // 0.5…1.5
    public var saturation: Double // 0…2
    public var warmth: Double     // −1 (cool) … 1 (warm)

    public static let neutral = ImageAdjustments(exposure: 0, contrast: 1, saturation: 1, warmth: 0)

    public init(exposure: Double, contrast: Double, saturation: Double, warmth: Double) {
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.warmth = warmth
    }

    public init(options o: OptionValues) {
        self.init(exposure: min(2, max(-2, o.double("exposure", default: 0))),
                  contrast: min(1.5, max(0.5, o.double("contrast", default: 1))),
                  saturation: min(2, max(0, o.double("saturation", default: 1))),
                  warmth: min(1, max(-1, o.double("warmth", default: 0))))
    }

    public var options: OptionValues {
        OptionValues(["exposure": .double(exposure), "contrast": .double(contrast),
                      "saturation": .double(saturation), "warmth": .double(warmth)])
    }

    public var isNeutral: Bool { self == .neutral }

    /// Applies the adjustments; the extent is unchanged.
    public func apply(to input: CIImage) -> CIImage {
        var img = input
        if exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
            f.setValue(img, forKey: kCIInputImageKey)
            f.setValue(exposure, forKey: kCIInputEVKey)
            img = f.outputImage ?? img
        }
        if warmth != 0, let f = CIFilter(name: "CITemperatureAndTint") {
            // A lower target white point renders warmer (verified on 27.0.1).
            f.setValue(img, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: 6500 - 1950 * warmth, y: 0), forKey: "inputTargetNeutral")
            img = f.outputImage ?? img
        }
        if contrast != 1 || saturation != 1, let f = CIFilter(name: "CIColorControls") {
            // Contrast pivots on mid-grey, which only looks right in a
            // perceptual (gamma-encoded) space; in linear light it crushes
            // shadows to pure primaries. Hop to sRGB-encoded values and back.
            f.setValue(img.applyingFilter("CILinearToSRGBToneCurve"), forKey: kCIInputImageKey)
            f.setValue(contrast, forKey: kCIInputContrastKey)
            f.setValue(saturation, forKey: kCIInputSaturationKey)
            f.setValue(0, forKey: kCIInputBrightnessKey)
            img = f.outputImage?.applyingFilter("CISRGBToneCurveToLinear") ?? img
        }
        return img.cropped(to: input.extent)
    }

    /// Renders `image` with the adjustments in its own colour space.
    public func render(_ image: CGImage) throws -> CGImage {
        guard !isNeutral else { return image }
        let out = apply(to: CIImage(cgImage: image))
        return try ToolImageSupport.render(out, width: image.width, height: image.height, colorSpace: ToolImageSupport.colorSpace(of: image),
                                       like: image, opaque: !ToolImageSupport.hasAlpha(image))
    }
}

struct AdjustImageRunner: ToolRunner {
    let id = ToolIDs.adjustImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        try await PixelToolPipeline(request: request, context: context).run { decoded in
            try ImageAdjustments(options: request.options).render(decoded.image)
        }
    }
}
