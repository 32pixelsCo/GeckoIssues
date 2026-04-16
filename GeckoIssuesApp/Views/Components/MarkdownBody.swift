import SwiftUI

/// Renders GitHub-flavored markdown as SwiftUI views.
///
/// Handles headings, paragraphs, fenced code blocks, bullet and numbered lists,
/// task list items, blockquotes, horizontal rules, and inline formatting.
struct MarkdownBody: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseBlocks(text)) { block in
                blockView(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .codeBlock(_, let code):
            codeBlockView(code: code)
        case .bulletItem(let text, let depth, let checked):
            bulletItemView(text: text, depth: depth, checked: checked)
        case .numberedItem(let text, let number, let depth):
            numberedItemView(text: text, number: number, depth: depth)
        case .blockquote(let text):
            blockquoteView(text: text)
        case .horizontalRule:
            Divider()
        case .paragraph(let text):
            inlineText(text)
        }
    }

    private func headingView(level: Int, text: String) -> some View {
        let font: Font = switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        default: .headline
        }
        return inlineText(text).font(font)
    }

    private func codeBlockView(code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func bulletItemView(text: String, depth: Int, checked: Bool?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let checked {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? .green : .secondary)
                    .font(.system(size: 14))
            } else {
                Text("•")
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .center)
            }
            inlineText(text)
        }
        .padding(.leading, CGFloat(depth) * 16)
    }

    private func numberedItemView(text: String, number: Int, depth: Int) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(number).")
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            inlineText(text)
        }
        .padding(.leading, CGFloat(depth) * 16)
    }

    private func blockquoteView(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            inlineText(text)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Text

    private func inlineText(_ markdown: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return Text(attributed)
        }
        return Text(markdown)
    }
}

// MARK: - Block Model

private struct Block: Identifiable {
    var id: Int
    var kind: BlockKind
}

private enum BlockKind {
    case heading(level: Int, text: String)
    case codeBlock(language: String?, code: String)
    case bulletItem(text: String, depth: Int, checked: Bool?)
    case numberedItem(text: String, number: Int, depth: Int)
    case blockquote(text: String)
    case horizontalRule
    case paragraph(text: String)
}

// MARK: - Parser

private func parseBlocks(_ text: String) -> [Block] {
    var blocks: [Block] = []
    var nextId = 0
    let lines = text.components(separatedBy: "\n")
    var i = 0

    func addBlock(_ kind: BlockKind) {
        nextId += 1
        blocks.append(Block(id: nextId, kind: kind))
    }

    while i < lines.count {
        let line = lines[i]
        let stripped = line.trimmingCharacters(in: .whitespaces)

        // Skip blank lines
        if stripped.isEmpty {
            i += 1
            continue
        }

        // Fenced code block
        if line.hasPrefix("```") || line.hasPrefix("~~~") {
            let fence = String(line.prefix(3))
            let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix(fence) {
                codeLines.append(lines[i])
                i += 1
            }
            if i < lines.count { i += 1 } // consume closing fence
            addBlock(.codeBlock(language: lang.isEmpty ? nil : lang, code: codeLines.joined(separator: "\n")))
            continue
        }

        // ATX heading
        if let heading = parseHeading(line) {
            addBlock(.heading(level: heading.level, text: heading.text))
            i += 1
            continue
        }

        // Horizontal rule (check before bullet to distinguish --- from a bullet)
        if isHorizontalRule(stripped) {
            addBlock(.horizontalRule)
            i += 1
            continue
        }

        // Bullet list item (including task list checkboxes)
        if let bullet = parseBullet(line) {
            addBlock(.bulletItem(text: bullet.text, depth: bullet.depth, checked: bullet.checked))
            i += 1
            continue
        }

        // Numbered list item
        if let numbered = parseNumbered(line) {
            addBlock(.numberedItem(text: numbered.text, number: numbered.number, depth: numbered.depth))
            i += 1
            continue
        }

        // Blockquote
        if line.hasPrefix("> ") || line == ">" {
            let quoteText = line.hasPrefix("> ") ? String(line.dropFirst(2)) : ""
            addBlock(.blockquote(text: quoteText))
            i += 1
            continue
        }

        // Paragraph — accumulate lines until a block break
        var paraLines: [String] = [line]
        i += 1
        while i < lines.count {
            let next = lines[i]
            let nextStripped = next.trimmingCharacters(in: .whitespaces)
            if nextStripped.isEmpty { break }
            if next.hasPrefix("```") || next.hasPrefix("~~~") { break }
            if parseHeading(next) != nil { break }
            if isHorizontalRule(nextStripped) { break }
            if parseBullet(next) != nil { break }
            if parseNumbered(next) != nil { break }
            if next.hasPrefix("> ") || next == ">" { break }
            paraLines.append(next)
            i += 1
        }
        // Join lines with space (standard soft-wrap handling)
        addBlock(.paragraph(text: paraLines.joined(separator: " ")))
    }

    return blocks
}

// MARK: - Line Parsers

private struct HeadingResult { let level: Int; let text: String }

private func parseHeading(_ line: String) -> HeadingResult? {
    var n = 0
    var s = line[line.startIndex...]
    while s.first == "#" { n += 1; s = s.dropFirst() }
    guard n >= 1, n <= 6, s.first == " " || s.isEmpty else { return nil }
    return HeadingResult(level: n, text: String(s).trimmingCharacters(in: .whitespaces))
}

private func isHorizontalRule(_ stripped: String) -> Bool {
    guard stripped.count >= 3 else { return false }
    let ch = stripped.first!
    guard ch == "-" || ch == "*" || ch == "_" else { return false }
    return stripped.allSatisfy { $0 == ch || $0 == " " }
        && stripped.filter({ $0 == ch }).count >= 3
}

private struct BulletResult { let text: String; let depth: Int; let checked: Bool? }

private func parseBullet(_ line: String) -> BulletResult? {
    var s = line[line.startIndex...]
    var spaces = 0
    while s.first == " " { spaces += 1; s = s.dropFirst() }
    guard let ch = s.first, ch == "-" || ch == "*" || ch == "+" else { return nil }
    s = s.dropFirst()
    guard s.first == " " else { return nil }
    s = s.dropFirst()
    var text = String(s)
    var checked: Bool? = nil
    if text.hasPrefix("[ ] ") {
        checked = false
        text = String(text.dropFirst(4))
    } else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
        checked = true
        text = String(text.dropFirst(4))
    }
    return BulletResult(text: text, depth: spaces / 2, checked: checked)
}

private struct NumberedResult { let text: String; let number: Int; let depth: Int }

private func parseNumbered(_ line: String) -> NumberedResult? {
    var s = line[line.startIndex...]
    var spaces = 0
    while s.first == " " { spaces += 1; s = s.dropFirst() }
    var digits = ""
    while let ch = s.first, ch.isNumber { digits.append(ch); s = s.dropFirst() }
    guard !digits.isEmpty, s.first == ".", let number = Int(digits) else { return nil }
    s = s.dropFirst()
    guard s.first == " " else { return nil }
    s = s.dropFirst()
    return NumberedResult(text: String(s), number: number, depth: spaces / 2)
}
