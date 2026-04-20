import Foundation

// MARK: - AppleScript Runner

enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "AppleScript error: \(msg)"
        case .noResult: return "AppleScript returned no result"
        }
    }
}

func runAppleScript(_ script: String) throws -> String {
    // Write to temp file — avoids -e argument issues with multiline scripts
    // and AppleScript keywords like "return" being misinterpreted.
    let tmpPath = NSTemporaryDirectory() + "apmcp_\(Int.random(in: 100000...999999)).applescript"
    let tmpURL = URL(fileURLWithPath: tmpPath)
    try script.write(to: tmpURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [tmpPath]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError  = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        throw AppleScriptError.executionFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Contacts Data

struct ContactsData {
    /// address (lowercase) → display name
    let addressToName: [String: String]
    /// name (lowercase) → [email addresses] (original case)
    let nameToAddresses: [String: [String]]
}

func loadContacts() -> ContactsData {
    let script = """
set output to ""
tell application "Contacts"
    repeat with p in every person
        set pName to name of p
        repeat with e in every email of p
            set addr to value of e
            set output to output & pName & "||" & addr & return
        end repeat
    end repeat
end tell
return output
"""
    guard let raw = try? runAppleScript(script), !raw.isEmpty else {
        return ContactsData(addressToName: [:], nameToAddresses: [:])
    }

    var addressToName: [String: String] = [:]
    var nameToAddresses: [String: [String]] = [:]

    for line in raw.components(separatedBy: "\r") {
        let parts = line.components(separatedBy: "||")
        guard parts.count == 2 else { continue }
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let addr = parts[1].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !addr.isEmpty else { continue }

        addressToName[addr.lowercased()] = name
        let nameKey = name.lowercased()
        nameToAddresses[nameKey, default: []].append(addr)
    }

    return ContactsData(addressToName: addressToName, nameToAddresses: nameToAddresses)
}

/// Returns display name for an email address, falling back to the address itself
func displayName(for address: String, contacts: ContactsData) -> String {
    contacts.addressToName[address.lowercased()] ?? address
}

/// Returns all email addresses for a person name (case-insensitive, partial match)
func addresses(for name: String, contacts: ContactsData) -> [String] {
    let nameLower = name.lowercased()
    var result: [String] = []
    for (key, addrs) in contacts.nameToAddresses {
        if key.contains(nameLower) {
            result.append(contentsOf: addrs)
        }
    }
    return result
}

// MARK: - Message Model

struct MailMessage: Sendable {
    let id: String
    let subject: String
    let sender: String
    let senderName: String
    let date: String
    let isRead: Bool
    let mailbox: String
    let account: String
    let preview: String
}

func parseMessages(_ raw: String, contacts: ContactsData) -> [MailMessage] {
    // osascript returns CR (\r) as line separator; split on both variants
    let normalised = raw.replacingOccurrences(of: "\r", with: "\n")
    let blocks = normalised.components(separatedBy: "---MSG---")
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return blocks.compactMap { block in
        var fields: [String: String] = [:]
        for line in block.components(separatedBy: "\n") {
            let kv = line.components(separatedBy: "::")
            guard kv.count >= 2 else { continue }
            fields[kv[0].trimmingCharacters(in: .whitespaces)] = kv.dropFirst().joined(separator: "::")
        }
        guard let id = fields["ID"], let subject = fields["SUBJECT"] else { return nil }
        let sender = fields["SENDER"] ?? ""
        // Extract bare address from "Name <addr>" format if present
        let bareAddr: String
        if let lt = sender.firstIndex(of: "<"), let gt = sender.firstIndex(of: ">"), lt < gt {
            bareAddr = String(sender[sender.index(after: lt)..<gt])
        } else {
            bareAddr = sender
        }
        let senderName = displayName(for: bareAddr, contacts: contacts)
        return MailMessage(
            id: id,
            subject: subject,
            sender: sender,
            senderName: senderName,
            date: fields["DATE"] ?? "",
            isRead: fields["READ"] == "true",
            mailbox: fields["MAILBOX"] ?? "",
            account: fields["ACCOUNT"] ?? "",
            preview: (fields["PREVIEW"] ?? "").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        )
    }
}

func formatMessage(_ msg: MailMessage) -> String {
    """
    ID: \(msg.id)
    Subject: \(msg.subject)
    From: \(msg.senderName) <\(msg.sender)>
    Date: \(msg.date)
    Mailbox: \(msg.account)/\(msg.mailbox)
    Read: \(msg.isRead ? "yes" : "no")
    Preview: \(msg.preview)
    """
}
