import Foundation
import MCP

// MARK: - Contacts Cache
// Loaded lazily on first use via contactsData() — avoids slow startup.
nonisolated(unsafe) var _contacts: ContactsData? = nil

func contactsData() -> ContactsData {
    if let c = _contacts { return c }
    let c = loadContacts()
    _contacts = c
    return c
}

// MARK: - Server Setup

let server = Server(
    name: "AppleMailMCP",
    version: "1.0.0",
    capabilities: .init(tools: .init(listChanged: false))
)

// Register handlers BEFORE start()
await server.withMethodHandler(ListTools.self) { _ in
    return .init(tools: allTools)
}

await server.withMethodHandler(CallTool.self) { params in
    let name = params.name
    let args = params.arguments ?? [:]

    do {
        let result: String
        switch name {
        case "mail_search":
            result = try handleMailSearch(args: args, contacts: contactsData())
        case "mail_search_by_person":
            result = try handleMailSearchByPerson(args: args, contacts: contactsData())
        case "mail_list_unread":
            result = try handleMailListUnread(args: args, contacts: contactsData())
        case "mail_get_body":
            result = try handleMailGetBody(args: args)
        case "mail_send":
            result = try handleMailSend(args: args)
        case "mail_mark_read":
            result = try handleMailMarkRead(args: args, read: true)
        case "mail_mark_unread":
            result = try handleMailMarkRead(args: args, read: false)
        case "mail_move":
            result = try handleMailMove(args: args)
        case "mail_delete":
            result = try handleMailDelete(args: args)
        case "mail_list_accounts":
            result = try handleMailListAccounts()
        default:
            return .init(content: [.text(text: "Unknown tool: \(name)", annotations: nil, _meta: nil)], isError: true)
        }
        return .init(content: [.text(text: result, annotations: nil, _meta: nil)], isError: false)
    } catch {
        return .init(content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
    }
}

// MARK: - Run

let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
