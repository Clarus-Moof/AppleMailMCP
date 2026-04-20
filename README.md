# AppleMailMCP

Lokaler MCP-Server für Apple Mail mit Contacts-Integration.  
Vollständig in Swift, kein Node.js, kein Python. Läuft als reines macOS-Executable.

## Features

- **mail_search** — E-Mails suchen (Betreff, Absender, Inhalt)
- **mail_list_unread** — Ungelesene Mails auflisten
- **mail_get_body** — Vollständigen Mailinhalt abrufen
- **mail_send** — E-Mail senden (inkl. CC/BCC)
- **mail_mark_read** — Als gelesen markieren
- **mail_mark_unread** — Als ungelesen markieren
- **mail_move** — In anderen Ordner verschieben
- **mail_delete** — Löschen (in Papierkorb)
- **mail_list_accounts** — Alle Konten und Ordner auflisten
- **Contacts-Integration** — Absendernamen werden automatisch aus Kontakten aufgelöst

## Voraussetzungen

- macOS 14+
- Xcode 16+ (Swift 6)

## Build

```bash
cd AppleMailMCP
swift build -c release
```

Das Binary liegt dann unter:
```
.build/release/AppleMailMCP
```

Optional nach `/usr/local/bin` kopieren:
```bash
sudo cp .build/release/AppleMailMCP /usr/local/bin/AppleMailMCP
```

## LM Studio konfigurieren

In `~/.lmstudio/mcp.json` eintragen:

```json
{
  "mcpServers": {
    "web-search": {
      "command": "node",
      "args": ["/Users/michel/MCP-Servers/web-search-mcp/dist/index.js"],
      "env": {
        "MAX_CONTENT_LENGTH": "50000",
        "DEFAULT_SEARCH_LIMIT": "3"
      }
    },
    "apple-mail": {
      "command": "/usr/local/bin/AppleMailMCP",
      "args": []
    }
  }
}
```

## macOS-Berechtigungen

Beim ersten Start fragt macOS nach Zugriff auf:
- **Automation → Mail** (für alle Mail-Operationen)
- **Automation → Contacts** (für Namensauflösung)

Einfach bestätigen. Falls der Dialog nicht erscheint:  
Systemeinstellungen → Datenschutz & Sicherheit → Automation

## Hinweise

- Mail.app muss laufen (AppleScript-Voraussetzung)
- Das Contacts-Verzeichnis wird einmalig beim Start geladen
- Alle Operationen sind vollständig lokal — keine Daten verlassen den Mac
- Bei großen Mailboxen kann `mail_list_unread` ohne Mailbox-Filter langsam sein;
  besser einen Account/Mailbox-Filter angeben
