import AppKit

/// Draws segment and hub content into bitmaps once per state, so hovering only
/// swaps layer opacities (no text layout or drawing while the pointer moves).
@MainActor
enum ContentRenderer {
    enum State { case normal, highlighted, disabled }

    struct Metrics {
        var glyph: CGFloat
        var label: CGFloat
        var caption: CGFloat
        var badge: CGFloat
        var labelWeight: NSFont.Weight
        var tracking: CGFloat
        var maxLines: Int
        var gap: CGFloat
    }

    static func metrics(for item: RadialItem, ring: Int, config: RadialMenuConfiguration) -> Metrics {
        let outer = ring == 1
        switch item.prominence {
        case .title:
            return Metrics(glyph: config.titleGlyphSize - (outer ? 1 : 0), label: config.labelSize - (outer ? 0.5 : 0),
                           caption: config.captionSize, badge: config.badgeSize,
                           labelWeight: .semibold, tracking: 0.5, maxLines: 1, gap: 3)
        case .glyph:
            return Metrics(glyph: config.glyphSize - (outer ? 2 : 0), label: config.compactLabelSize,
                           caption: config.captionSize, badge: config.badgeSize,
                           labelWeight: .medium, tracking: 0.05, maxLines: 2, gap: 4)
        }
    }

    /// Bitmap of glyph + label (+ subtitle + badge) centred in `size`.
    static func segmentImage(item: RadialItem, ring: Int, size: CGSize, scale: CGFloat, state: State,
                             palette: RadialPalette, style: RadialMenuStyle,
                             config: RadialMenuConfiguration) -> CGImage? {
        let m = metrics(for: item, ring: ring, config: config)
        let color: NSColor
        let secondary: NSColor
        switch state {
        case .normal:
            color = palette.content
            secondary = palette.secondaryContent
        case .highlighted:
            color = palette.highlightContent
            secondary = palette.highlightContent.withAlphaComponent(0.78)
        case .disabled:
            color = palette.disabledContent
            secondary = palette.disabledContent
        }
        let glyphTint: NSColor = (item.prominence == .title && state == .normal) ? palette.secondaryContent : color

        let title = item.prominence == .title && style.uppercaseTitleProminence ? item.title.localizedUppercase : item.title
        let maxWidth = size.width
        let label = fittedLabel(title, maxWidth: maxWidth, size: m.label, weight: m.labelWeight,
                                tracking: m.tracking, maxLines: m.maxLines, color: color)
        var subtitle: NSAttributedString?
        if let text = item.subtitle, !text.isEmpty {
            subtitle = attributed(text, size: m.caption, weight: .regular, tracking: 0, color: secondary, alignment: .center)
        }
        let badge = item.badge.map { badgeImageSpec(text: $0, accessory: item.accessory, size: m.badge, palette: palette) }

        let glyph = item.image.map { glyphImage($0, pointSize: m.glyph) }
        let glyphSize = glyph.map { fit($0.size, into: m.glyph * 1.35) } ?? .zero

        // Measure the stack and drop optional rows until it fits.
        var rows: [CGFloat] = []
        if glyph != nil { rows.append(glyphSize.height) }
        rows.append(label.height)
        var showSubtitle = subtitle != nil
        var showBadge = badge != nil
        func total() -> CGFloat {
            var h = rows.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * m.gap
            if showSubtitle, let subtitle { h += 1.5 + ceil(subtitle.size().height) }
            if showBadge, let badge { h += m.gap + badge.size.height }
            return h
        }
        if total() > size.height { showSubtitle = false }
        if total() > size.height { showBadge = false }
        // No room for a badge row: a compact chip sits on the glyph's top-right
        // corner instead, so Pro segments always say so.
        let cornerBadge = !showBadge && glyph != nil
            ? item.badge.map { badgeImageSpec(text: $0, accessory: item.accessory, size: m.badge - 0.5, palette: palette) }
            : nil
        let accessoryBesideGlyph = !showBadge && cornerBadge == nil && item.accessory != nil

        return draw(size: size, scale: scale) { _ in
            var y = (size.height + total()) / 2 // top of the stack (non-flipped)
            if let glyph {
                y -= glyphSize.height
                let rect = CGRect(x: (size.width - glyphSize.width) / 2, y: y, width: glyphSize.width, height: glyphSize.height)
                drawImage(glyph, in: rect, tint: glyphTint)
                if let cornerBadge {
                    // Overlap the glyph's top-right quarter and stay inside the stack's
                    // box: on outer-ring wedges the box corners sit at the curved edge.
                    let x = min(size.width - cornerBadge.size.width, rect.maxX - cornerBadge.size.width * 0.55)
                    let top = min(size.height, rect.maxY + 1)
                    cornerBadge.draw(CGPoint(x: max(0, x), y: top - cornerBadge.size.height))
                }
                if accessoryBesideGlyph, let accessory = item.accessory {
                    let a = glyphImage(accessory, pointSize: m.badge + 1)
                    let s = fit(a.size, into: m.badge + 3)
                    drawImage(a, in: CGRect(x: rect.maxX - 1, y: rect.maxY - s.height + 1, width: s.width, height: s.height),
                              tint: state == .normal ? palette.badgeFill : color)
                }
                y -= m.gap
            }
            y -= label.height
            label.text.draw(with: CGRect(x: 0, y: y, width: size.width, height: label.height),
                            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            if showSubtitle, let subtitle {
                let h = ceil(subtitle.size().height)
                y -= 1.5 + h
                subtitle.draw(with: CGRect(x: 0, y: y, width: size.width, height: h),
                              options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            }
            if showBadge, let badge {
                y -= m.gap + badge.size.height
                badge.draw(CGPoint(x: (size.width - badge.size.width) / 2, y: y))
            }
        }
    }

    // MARK: Hub pill

    static func pillImage(text: String, highlighted: Bool, palette: RadialPalette, config: RadialMenuConfiguration,
                          maxWidth: CGFloat, scale: CGFloat) -> (CGImage?, CGSize) {
        let padding: CGFloat = 8
        var fontSize = config.hubLabelSize
        var label = attributed(text, size: fontSize, weight: .semibold, tracking: 0.3,
                               color: palette.pillText, alignment: .center, truncate: true)
        let oneLineHeight = ceil(config.hubLabelSize + 8)
        // Shrink a little, then wrap onto two lines, rather than truncating long names.
        if ceil(label.size().width) + padding * 2 > maxWidth {
            fontSize = max(9, config.hubLabelSize - 1)
            label = attributed(text, size: fontSize, weight: .semibold, tracking: 0.2,
                               color: palette.pillText, alignment: .center, truncate: true)
        }
        var size: CGSize
        var lines = 1
        var textBox: CGSize
        if ceil(label.size().width) + padding * 2 <= maxWidth {
            textBox = CGSize(width: ceil(label.size().width), height: ceil(label.size().height))
            size = CGSize(width: max(oneLineHeight + 12, textBox.width + padding * 2), height: oneLineHeight)
        } else {
            label = attributed(text, size: fontSize, weight: .semibold, tracking: 0.2,
                               color: palette.pillText, alignment: .center, truncate: false)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            let lineHeight = ceil(font.ascender - font.descender + font.leading)
            let bounds = label.boundingRect(with: CGSize(width: maxWidth - padding * 2, height: lineHeight * 2),
                                            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            lines = 2
            textBox = CGSize(width: ceil(bounds.width), height: lineHeight * 2)
            size = CGSize(width: min(maxWidth, textBox.width + padding * 2), height: textBox.height + 7)
        }
        let corner: CGFloat = lines == 1 ? size.height / 2 : 9
        let image = draw(size: size, scale: scale) { ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
            ctx.setFillColor(highlighted ? palette.pillHighlightFill : palette.pillFill)
            ctx.fillPath()
            let box = CGRect(x: padding, y: (size.height - textBox.height) / 2 + 0.5,
                             width: size.width - padding * 2, height: textBox.height)
            label.draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
        return (image, size)
    }

    /// Small count chip for multi-file drags.
    static func countBadge(_ count: Int, palette: RadialPalette, scale: CGFloat) -> (CGImage?, CGSize) {
        let text = attributed(count > 99 ? "99+" : "\(count)", size: 10, weight: .bold, tracking: 0,
                              color: palette.highlightContent, alignment: .center)
        let h: CGFloat = 17
        let w = max(h, ceil(text.size().width) + 9)
        let size = CGSize(width: w, height: h)
        let image = draw(size: size, scale: scale) { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil))
            ctx.setFillColor(palette.accent.cgColor)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.5)
            ctx.drawPath(using: .fillStroke)
            let th = ceil(text.size().height)
            text.draw(with: CGRect(x: 0, y: (h - th) / 2 + 0.5, width: w, height: th), options: [.usesLineFragmentOrigin])
        }
        return (image, size)
    }

    /// The hub thumbnail with rounded corners, a hairline and stacked "cards" for multi-file drags.
    static func thumbnailImage(_ image: NSImage?, stackCount: Int, side: CGFloat, palette: RadialPalette,
                               scale: CGFloat) -> CGImage? {
        let canvas = CGSize(width: side + 16, height: side + 16)
        return draw(size: canvas, scale: scale) { ctx in
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            if stackCount > 1 {
                // Two tilted cards behind: reads as "several files" at a glance.
                for (i, angle) in [CGFloat(-0.16), 0.11].enumerated() where i < stackCount - 1 {
                    ctx.saveGState()
                    ctx.translateBy(x: center.x, y: center.y)
                    ctx.rotate(by: angle)
                    let card = CGRect(x: -side * 0.4, y: -side * 0.42, width: side * 0.8, height: side * 0.84)
                    let path = CGPath(roundedRect: card, cornerWidth: 6, cornerHeight: 6, transform: nil)
                    ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3,
                                  color: NSColor.black.withAlphaComponent(0.25).cgColor)
                    ctx.addPath(path)
                    ctx.setFillColor(palette.appearance.isDark ? NSColor(white: 0.32, alpha: 1).cgColor : NSColor(white: 0.97, alpha: 1).cgColor)
                    ctx.fillPath()
                    ctx.setShadow(offset: .zero, blur: 0, color: nil)
                    ctx.addPath(path)
                    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
                    ctx.setLineWidth(0.5)
                    ctx.strokePath()
                    ctx.restoreGState()
                }
            }
            guard let image else { return }
            let fitted = aspectFit(image.size, into: side)
            let rect = CGRect(x: center.x - fitted.width / 2, y: center.y - fitted.height / 2,
                              width: fitted.width, height: fitted.height)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 4, color: NSColor.black.withAlphaComponent(0.28).cgColor)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            ctx.restoreGState()
        }
    }

    // MARK: Drawing primitives

    struct FittedLabel {
        let text: NSAttributedString
        let height: CGFloat
    }

    /// Fits a label into `maxWidth`: wraps up to `maxLines`, shrinking the font
    /// (down to 75 %) when a single word is too wide.
    static func fittedLabel(_ text: String, maxWidth: CGFloat, size: CGFloat, weight: NSFont.Weight,
                            tracking: CGFloat, maxLines: Int, color: NSColor) -> FittedLabel {
        var fontSize = size
        let minimum = size * 0.75
        var attributedText = attributed(text, size: fontSize, weight: weight, tracking: tracking, color: color,
                                        alignment: .center, truncate: maxLines == 1)
        func longestWordWidth(_ s: NSAttributedString) -> CGFloat {
            let words = s.string.split(whereSeparator: { $0 == " " || $0 == "\n" })
            let attrs = s.attributes(at: 0, effectiveRange: nil)
            return words.map { NSAttributedString(string: String($0), attributes: attrs).size().width }.max() ?? 0
        }
        func lineCount(_ s: NSAttributedString, size: CGFloat) -> Int {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let lh = font.ascender - font.descender + font.leading
            let h = s.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height
            return Int((h / lh).rounded())
        }
        while fontSize > minimum {
            let tooWide = maxLines == 1
                ? attributedText.size().width > maxWidth
                : longestWordWidth(attributedText) > maxWidth || lineCount(attributedText, size: fontSize) > maxLines
            if !tooWide { break }
            fontSize -= 0.5
            attributedText = attributed(text, size: fontSize, weight: weight, tracking: tracking, color: color,
                                        alignment: .center, truncate: maxLines == 1)
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let bounds = attributedText.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                 options: [.usesLineFragmentOrigin])
        let lines = min(maxLines, max(1, Int((bounds.height / lineHeight).rounded())))
        return FittedLabel(text: attributedText, height: CGFloat(lines) * lineHeight)
    }

    static func attributed(_ text: String, size: CGFloat, weight: NSFont.Weight, tracking: CGFloat, color: NSColor,
                           alignment: NSTextAlignment, truncate: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = truncate ? .byTruncatingTail : .byWordWrapping
        paragraph.lineSpacing = 0
        paragraph.maximumLineHeight = 0
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: tracking,
            .paragraphStyle: paragraph,
        ])
    }

    struct BadgeSpec {
        let size: CGSize
        let render: (CGPoint) -> Void
        func draw(_ origin: CGPoint) { render(origin) }
    }

    static func badgeImageSpec(text: String, accessory: NSImage?, size: CGFloat, palette: RadialPalette) -> BadgeSpec {
        let label = attributed(text.localizedUppercase, size: size, weight: .heavy, tracking: 0.5,
                               color: palette.badgeText, alignment: .left)
        let textSize = label.size()
        let icon = accessory.map { glyphImage($0, pointSize: size) }
        let iconSize = icon.map { fit($0.size, into: size + 2) } ?? .zero
        let height = ceil(size + 5)
        let width = ceil(textSize.width + 10 + (icon != nil ? iconSize.width + 2.5 : 0))
        return BadgeSpec(size: CGSize(width: width, height: height)) { origin in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            let rect = CGRect(origin: origin, size: CGSize(width: width, height: height))
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
            ctx.setFillColor(palette.badgeFill.cgColor)
            ctx.fillPath()
            var x = rect.minX + 5
            if let icon {
                drawImage(icon, in: CGRect(x: x, y: rect.midY - iconSize.height / 2, width: iconSize.width, height: iconSize.height),
                          tint: palette.badgeText)
                x += iconSize.width + 2.5
            }
            label.draw(at: CGPoint(x: x, y: rect.midY - textSize.height / 2 + 0.25))
        }
    }

    /// Symbol images get the requested point size; others are used as-is.
    static func glyphImage(_ image: NSImage, pointSize: CGFloat) -> NSImage {
        let configured = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium))
        if let configured {
            configured.isTemplate = image.isTemplate
            return configured
        }
        return image
    }

    /// Shrinks (never enlarges) `size` to fit a `side` square, keeping the aspect ratio.
    static func fit(_ size: CGSize, into side: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
        let s = min(1, side / size.width, side / size.height)
        return CGSize(width: size.width * s, height: size.height * s)
    }

    /// Scales `size` up or down to fit a `side` square, keeping the aspect ratio.
    static func aspectFit(_ size: CGSize, into side: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
        let s = min(side / size.width, side / size.height)
        return CGSize(width: size.width * s, height: size.height * s)
    }

    static func drawImage(_ image: NSImage, in rect: CGRect, tint: NSColor?) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if image.isTemplate, let tint {
            ctx.saveGState()
            ctx.beginTransparencyLayer(in: rect.insetBy(dx: -2, dy: -2), auxiliaryInfo: nil)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            ctx.setBlendMode(.sourceIn)
            ctx.setFillColor(tint.cgColor)
            ctx.fill(rect.insetBy(dx: -2, dy: -2))
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        } else {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    /// Runs AppKit drawing into a premultiplied sRGB bitmap at `scale`.
    static func draw(size: CGSize, scale: CGFloat, _ body: (CGContext) -> Void) -> CGImage? {
        let w = max(1, Int(ceil(size.width * scale))), h = max(1, Int(ceil(size.height * scale)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setShouldSmoothFonts(false)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        body(ctx)
        NSGraphicsContext.current = previous
        return ctx.makeImage()
    }
}
