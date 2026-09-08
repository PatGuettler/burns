# Running private rooms

The room server is part of the Godot project. It uses JSON over WebSocket, allowing native and browser clients to share a table.

```sh
godot --headless --path . -- --server --port=9080 --bind=127.0.0.1
```

Options:

- `--port=9080`: listening port.
- `--bind=127.0.0.1`: listening address. For a LAN server use `0.0.0.0` and connect clients to the computer’s LAN IP.
- `--server-store=/absolute/path/rooms.cfg`: durable storage file; defaults to `user://server-rooms.cfg`.

For public hosting, keep the listener behind a TLS reverse proxy. A minimal Caddy configuration, after assigning a real domain and configuring DNS:

```caddyfile
rooms.example.com {
    reverse_proxy 127.0.0.1:9080
}
```

Serve `build/web/` over HTTPS separately and enter `wss://rooms.example.com` in the game. HTTPS pages cannot connect to insecure `ws://` endpoints. No domain, certificate, service account, or paid host is configured by this repository.

## Room lifecycle

A player creates a room by joining with a blank code. Subsequent players use that code. The original host starts a game once at least two players are connected. A room holds at most eight seats.

A disconnected seat is reserved. All gameplay pauses until it reconnects, avoiding skipped turns and lost challenge opportunities. Each client keeps its random reconnect credential in local settings; a reload or restart can use **Reconnect to previous seat**. Clearing browser/device data also clears that credential. There is currently no account-based recovery or host seat-removal flow.

Each accepted update persists room state via a temporary file and rename. After a server restart, all seats begin disconnected and their credentials can restore them. Entirely disconnected rooms expire after 24 hours. The storage file contains hidden decks and reconnect credentials: keep it private to the server account and out of web document roots and source control.

## Authority and transport

- The server shuffles and owns the complete state. Only revealed cards, shared rows/foundations, discard/open-pile tops, and pile counts leave it.
- An authenticated socket determines the acting seat. An action cannot claim another seat.
- Revisions prevent duplicate or stale actions. The server validates phase, actor, source, and destination.
- A Burns verdict is based on recorded pre-discard evidence. Clients cannot submit their own evidence or penalty amount.
- Reconnect credentials are 32 random bytes. Room codes are eight hexadecimal characters.
- The server caps room/socket counts, message size, packet processing, and per-socket request rate. Unauthenticated connections time out.

The integration test creates three real clients, exercises ownership and stale requests, submits competing Burns calls, rejects an invalid reconnect key, restores a seat, restarts the server, and restores the persisted room. Public load testing, infrastructure monitoring/backups, and operational recovery still need validation before a production service is launched.
