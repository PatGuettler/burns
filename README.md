# Burns

An original family multiplayer solitaire game for Android, iOS, and web, built in Godot 4.7 with GDScript and the Compatibility renderer.

**Status: design and deal preview, not a playable or production-ready release.** Open the project to explore the original illustrated title screen, six-suit cards, and deterministic table deals for 2–8 players. Gameplay implementation awaits clarification of the house rules in [docs/RULES.md](docs/RULES.md).

## Run

Open `project.godot` in Godot 4.7.1 or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_deck.gd
godot --headless --path . --script tests/test_ui.gd
godot --headless --path . --quit-after 5
```

The deck tests cover 280 seeded deals across all supported player counts, exact card conservation, balanced hands, repeatability, rank/suit naming, and invalid counts. These do not verify gameplay that has not been implemented.

To export the web preview with the matching Godot export templates installed:

```sh
mkdir -p build/web
godot --headless --path . --export-release Web
python3 -m http.server 8000 --directory build/web
```

Open `http://localhost:8000`. Browser/device validation is still required.

In this workspace, the editor inherits a Snap data directory while templates live in the standard user directory. Use `XDG_DATA_HOME=/home/pat/.local/share godot --headless --path . --export-release Web` if the default export reports missing templates.

## Design

Midnight teal felt, warm ivory cards, copper engraving, and a restrained ember motif. Original raster illustration generated with the built-in image generator; suit symbols and card backs are drawn in GDScript to remain crisp at different resolutions. Art provenance and generation prompt are in [docs/ART.md](docs/ART.md).

## Release work remaining

- Confirm house rules and deck variants; implement a deterministic rules engine and burn challenge state machine with scenario tests.
- Implement selected play modes, turn privacy, tutorials, accessibility settings, audio, game persistence, and complete game UI.
- If online play is selected: authoritative server validation, private room codes, reconnects, hidden-information views, latency-aware burn ordering, and integration tests. Do not send opponents’ hidden cards to clients.
- Configure Android and iOS exports; test all exports on actual devices and browsers, portrait/landscape layouts, safe areas, background/resume behavior, and touch input.
- Create final app icons, store artwork, signed builds, and required release metadata. iOS signing/build validation requires macOS and Xcode.

No online services, store releases, telemetry, or paid infrastructure are configured.
