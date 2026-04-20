import Foundation
import MCP

// MARK: - Value helpers

private func intArg(_ args: [String: Value], _ key: String, default def: Int = 0) -> Int {
    switch args[key] {
    case .int(let n):    return n
    case .double(let d): return Int(d)
    default:             return def
    }
}

private func stringArg(_ args: [String: Value], _ key: String) -> String? {
    if case .string(let s) = args[key] { return s }
    return nil
}

private func arrayArg(_ args: [String: Value], _ key: String) -> [String] {
    guard case .array(let vals) = args[key] else { return [] }
    return vals.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
}

// MARK: - Tool Definitions

let allTools: [Tool] = [
    Tool(
        name: "mail_search",
        description: "Search emails in Apple Mail by subject.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query":   .object(["type": .string("string"),  "description": .string("Search text (matches subject)")]),
                "mailbox": .object(["type": .string("string"),  "description": .string("Mailbox name, e.g. 'INBOX'. Omit to search all.")]),
                "account": .object(["type": .string("string"),  "description": .string("Account name. Omit to search all accounts.")]),
                "limit":   .object(["type": .string("integer"), "description": .string("Max results (default 20, max 50)")])
            ]),
            "required": .array([.string("query")])
        ])
    ),
    Tool(
        name: "mail_search_by_person",
        description: "Search emails by sender name. Looks up all email addresses for the person in Contacts and searches across all of them. Use this when the user says 'emails from [name]' or 'Mails von [name]'.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name":    .object(["type": .string("string"),  "description": .string("Person's name to search for, e.g. 'Esther Kaiser'")]),
                "mailbox": .object(["type": .string("string"),  "description": .string("Mailbox name. Omit to search all.")]),
                "account": .object(["type": .string("string"),  "description": .string("Account name. Omit to search all accounts.")]),
                "limit":   .object(["type": .string("integer"), "description": .string("Max results (default 20, max 50)")])
            ]),
            "required": .array([.string("name")])
        ])
    ),
    Tool(
        name: "mail_list_unread",
        description: "List unread emails from Apple Mail, newest first. Sender names are resolved from Contacts.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "mailbox": .object(["type": .string("string"),  "description": .string("Mailbox name, e.g. 'INBOX'. Omit for all.")]),
                "account": .object(["type": .string("string"),  "description": .string("Account name. Omit for all accounts.")]),
                "limit":   .object(["type": .string("integer"), "description": .string("Max results (default 20, max 50)")])
            ])
        ])
    ),
    Tool(
        name: "mail_get_body",
        description: "Get the full body of an email. Provide the numeric ID string from mail_search, mail_search_by_person, or mail_list_unread.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "message_id": .object(["type": .string("string"), "description": .string("Numeric ID string, e.g. '12345'")])
            ]),
            "required": .array([.string("message_id")])
        ])
    ),
    Tool(
        name: "mail_send",
        description: "Send an email via Apple Mail.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "to":      .object(["type": .string("string"), "description": .string("Recipient email address")]),
                "subject": .object(["type": .string("string"), "description": .string("Email subject")]),
                "body":    .object(["type": .string("string"), "description": .string("Email body (plain text)")]),
                "cc":      .object(["type": .string("string"), "description": .string("CC address (optional)")]),
                "bcc":     .object(["type": .string("string"), "description": .string("BCC address (optional)")])
            ]),
            "required": .array([.string("to"), .string("subject"), .string("body")])
        ])
    ),
    Tool(
        name: "mail_mark_read",
        description: "Mark emails as read.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "message_ids": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of numeric ID strings")
                ])
            ]),
            "required": .array([.string("message_ids")])
        ])
    ),
    Tool(
        name: "mail_mark_unread",
        description: "Mark emails as unread.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "message_ids": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of numeric ID strings")
                ])
            ]),
            "required": .array([.string("message_ids")])
        ])
    ),
    Tool(
        name: "mail_move",
        description: "Move emails to a different mailbox.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "message_ids": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of numeric ID strings to move")
                ]),
                "target_mailbox": .object(["type": .string("string"), "description": .string("Destination mailbox, e.g. 'Archive' or 'Trash'")]),
                "account":        .object(["type": .string("string"), "description": .string("Account containing the target mailbox")])
            ]),
            "required": .array([.string("message_ids"), .string("target_mailbox"), .string("account")])
        ])
    ),
    Tool(
        name: "mail_delete",
        description: "Delete emails (moves to Trash).",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "message_ids": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of numeric ID strings to delete")
                ])
            ]),
            "required": .array([.string("message_ids")])
        ])
    ),
    Tool(
        name: "mail_list_accounts",
        description: "List all configured email accounts and their mailboxes in Apple Mail.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )
]

// MARK: - Shared message output block
// Uses (id of msg) as string — NOT "message id of msg" which causes parse error.
// Uses return (AppleScript constant) for line separators.
// Uses text 1 thru N of ((content of msg) as string) for preview.

private func msgOutputScript() -> String {
    """
                        set rawContent to (content of msg) as string
                        set previewLen to length of rawContent
                        if previewLen > 200 then set previewLen to 200
                        set output to output & "ID::" & ((id of msg) as string) & return
                        set output to output & "SUBJECT::" & (subject of msg) & return
                        set output to output & "SENDER::" & (sender of msg) & return
                        set output to output & "DATE::" & ((date sent of msg) as string) & return
                        set output to output & "READ::" & ((read status of msg) as string) & return
                        set output to output & "MAILBOX::" & (name of m) & return
                        set output to output & "ACCOUNT::" & (name of a) & return
                        set output to output & "PREVIEW::" & (text 1 thru previewLen of rawContent) & return
                        set output to output & "---MSG---" & return
                        set msgCount to msgCount + 1
    """
}

// MARK: - Tool Implementations

func handleMailSearch(args: [String: Value], contacts: ContactsData) throws -> String {
    guard let query = stringArg(args, "query") else {
        throw AppleScriptError.executionFailed("Missing required argument: query")
    }
    let limit = min(intArg(args, "limit", default: 20), 50)
    let mailboxFilter = stringArg(args, "mailbox").map { "if name of m is \"\($0)\" then" } ?? "if true then"
    let accountFilter = stringArg(args, "account").map { "if name of a is \"\($0)\" then" } ?? "if true then"

    let script = """
set output to ""
set msgCount to 0
tell application "Mail"
    repeat with a in every account
        \(accountFilter)
            repeat with m in every mailbox of a
                \(mailboxFilter)
                    set msgs to (messages of m whose subject contains "\(query)")
                    repeat with msg in msgs
                        if msgCount >= \(limit) then exit repeat
\(msgOutputScript())
                    end repeat
                end if
            end repeat
        end if
    end repeat
end tell
return output
"""
    let raw = try runAppleScript(script)
    let messages = parseMessages(raw, contacts: contacts)
    if messages.isEmpty { return "No messages found with '\(query)' in subject." }
    return messages.map { formatMessage($0) }.joined(separator: "\n\n---\n\n")
}

func handleMailSearchByPerson(args: [String: Value], contacts: ContactsData) throws -> String {
    guard let name = stringArg(args, "name") else {
        throw AppleScriptError.executionFailed("Missing required argument: name")
    }
    let limit = min(intArg(args, "limit", default: 20), 50)
    let mailboxFilter = stringArg(args, "mailbox").map { "if name of m is \"\($0)\" then" } ?? "if true then"
    let accountFilter = stringArg(args, "account").map { "if name of a is \"\($0)\" then" } ?? "if true then"

    // Look up all email addresses for this person in Contacts
    let addrs = addresses(for: name, contacts: contacts)
    if addrs.isEmpty {
        return "No contact found for '\(name)'. Try mail_search instead."
    }

    // Build one AppleScript block per address, deduplicating by id
    let addrSearchBlocks = addrs.map { addr in
        """
                    set msgs to (messages of m whose sender contains "\(addr)")
                    repeat with msg in msgs
                        if msgCount >= \(limit) then exit repeat
                        set msgId to (id of msg) as string
                        if msgId is not in seenIds then
                            set end of seenIds to msgId
                            set rawContent to (content of msg) as string
                            set previewLen to length of rawContent
                            if previewLen > 200 then set previewLen to 200
                            set output to output & "ID::" & msgId & return
                            set output to output & "SUBJECT::" & (subject of msg) & return
                            set output to output & "SENDER::" & (sender of msg) & return
                            set output to output & "DATE::" & ((date sent of msg) as string) & return
                            set output to output & "READ::" & ((read status of msg) as string) & return
                            set output to output & "MAILBOX::" & (name of m) & return
                            set output to output & "ACCOUNT::" & (name of a) & return
                            set output to output & "PREVIEW::" & (text 1 thru previewLen of rawContent) & return
                            set output to output & "---MSG---" & return
                            set msgCount to msgCount + 1
                        end if
                    end repeat
"""
    }.joined(separator: "\n")

    let script = """
set output to ""
set msgCount to 0
set seenIds to {}
tell application "Mail"
    repeat with a in every account
        \(accountFilter)
            repeat with m in every mailbox of a
                \(mailboxFilter)
\(addrSearchBlocks)
                end if
            end repeat
        end if
    end repeat
end tell
return output
"""
    try? script.write(to: URL(fileURLWithPath: "/tmp/apmcp_debug.applescript"), atomically: true, encoding: .utf8)
    let raw = try runAppleScript(script)
    let messages = parseMessages(raw, contacts: contacts)
    if messages.isEmpty { return "No messages found from '\(name)' (searched addresses: \(addrs.joined(separator: ", ")))." }
    return "Found \(messages.count) message(s) from \(name) (\(addrs.joined(separator: ", "))):\n\n" +
           messages.map { formatMessage($0) }.joined(separator: "\n\n---\n\n")
}

func handleMailListUnread(args: [String: Value], contacts: ContactsData) throws -> String {
    let limit = min(intArg(args, "limit", default: 20), 50)
    let mailboxFilter = stringArg(args, "mailbox").map { "if name of m is \"\($0)\" then" } ?? "if true then"
    let accountFilter = stringArg(args, "account").map { "if name of a is \"\($0)\" then" } ?? "if true then"

    let script = """
set output to ""
set msgCount to 0
tell application "Mail"
    repeat with a in every account
        \(accountFilter)
            repeat with m in every mailbox of a
                \(mailboxFilter)
                    set msgs to (messages of m whose read status is false)
                    repeat with msg in msgs
                        if msgCount >= \(limit) then exit repeat
\(msgOutputScript())
                    end repeat
                end if
            end repeat
        end if
    end repeat
end tell
return output
"""
    let raw = try runAppleScript(script)
    let messages = parseMessages(raw, contacts: contacts)
    if messages.isEmpty { return "No unread messages found." }
    return messages.map { formatMessage($0) }.joined(separator: "\n\n---\n\n")
}

func handleMailGetBody(args: [String: Value]) throws -> String {
    guard let msgIdStr = stringArg(args, "message_id"),
          let msgId = Int(msgIdStr) else {
        throw AppleScriptError.executionFailed("Invalid message_id: must be a numeric string")
    }
    let script = """
tell application "Mail"
    repeat with a in every account
        repeat with m in every mailbox of a
            set msgs to (messages of m whose id is \(msgId))
            if (count of msgs) > 0 then
                return (content of (first item of msgs)) as string
            end if
        end repeat
    end repeat
    return ""
end tell
"""
    let body = try runAppleScript(script)
    return body.isEmpty ? "(empty body)" : body
}

func handleMailSend(args: [String: Value]) throws -> String {
    guard let to      = stringArg(args, "to"),
          let subject = stringArg(args, "subject"),
          let body    = stringArg(args, "body") else {
        throw AppleScriptError.executionFailed("Missing required arguments: to, subject, body")
    }
    let ccLine  = stringArg(args, "cc").map  { "make new to recipient at end of cc recipients with properties {address:\"\($0)\"}" } ?? ""
    let bccLine = stringArg(args, "bcc").map { "make new to recipient at end of bcc recipients with properties {address:\"\($0)\"}" } ?? ""

    let script = """
tell application "Mail"
    set newMsg to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
    tell newMsg
        make new to recipient at end of to recipients with properties {address:"\(to)"}
        \(ccLine)
        \(bccLine)
    end tell
    send newMsg
end tell
return "sent"
"""
    _ = try runAppleScript(script)
    return "Email sent to \(to) with subject '\(subject)'."
}

func handleMailMarkRead(args: [String: Value], read: Bool) throws -> String {
    let idStrings = arrayArg(args, "message_ids")
    let ids = idStrings.compactMap { Int($0) }
    guard !ids.isEmpty else { return "No valid message IDs provided." }
    let readVal = read ? "true" : "false"

    let statements = ids.map { id in
        """
        set msgs to (messages of m whose id is \(id))
        if (count of msgs) > 0 then set read status of (first item of msgs) to \(readVal)
"""
    }.joined(separator: "\n")

    let script = """
tell application "Mail"
    repeat with a in every account
        repeat with m in every mailbox of a
\(statements)
        end repeat
    end repeat
end tell
return "done"
"""
    _ = try runAppleScript(script)
    return "Marked \(ids.count) message(s) as \(read ? "read" : "unread")."
}

func handleMailMove(args: [String: Value]) throws -> String {
    let idStrings = arrayArg(args, "message_ids")
    let ids = idStrings.compactMap { Int($0) }
    guard let targetMailbox = stringArg(args, "target_mailbox"),
          let account       = stringArg(args, "account"),
          !ids.isEmpty else {
        throw AppleScriptError.executionFailed("Missing required arguments: message_ids, target_mailbox, account")
    }

    let statements = ids.map { id in
        """
        set msgs to (messages of m whose id is \(id))
        if (count of msgs) > 0 then set mailbox of (first item of msgs) to destMailbox
"""
    }.joined(separator: "\n")

    let script = """
tell application "Mail"
    set destAccount to first account whose name is "\(account)"
    set destMailbox to first mailbox of destAccount whose name is "\(targetMailbox)"
    repeat with a in every account
        repeat with m in every mailbox of a
\(statements)
        end repeat
    end repeat
end tell
return "done"
"""
    _ = try runAppleScript(script)
    return "Moved \(ids.count) message(s) to \(account)/\(targetMailbox)."
}

func handleMailDelete(args: [String: Value]) throws -> String {
    let idStrings = arrayArg(args, "message_ids")
    let ids = idStrings.compactMap { Int($0) }
    guard !ids.isEmpty else { return "No valid message IDs provided." }

    let statements = ids.map { id in
        """
        set msgs to (messages of m whose id is \(id))
        if (count of msgs) > 0 then delete (first item of msgs)
"""
    }.joined(separator: "\n")

    let script = """
tell application "Mail"
    repeat with a in every account
        repeat with m in every mailbox of a
\(statements)
        end repeat
    end repeat
end tell
return "done"
"""
    _ = try runAppleScript(script)
    return "Deleted \(ids.count) message(s) (moved to Trash)."
}

func handleMailListAccounts() throws -> String {
    let script = """
set output to ""
tell application "Mail"
    repeat with a in every account
        set output to output & "Account: " & (name of a) & return
        repeat with m in every mailbox of a
            set output to output & "  - " & (name of m) & return
        end repeat
    end repeat
end tell
return output
"""
    let result = try runAppleScript(script)
    return result.isEmpty ? "No accounts found." : result
}
