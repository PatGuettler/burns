# Burns

A family multiplayer solitaire game built in Godot 4.7.1 with GDScript. Version 0.2 is playable with a standard 52-card deck, 2–8 players, pass-and-play, computer opponents, and private online rooms.

The board adapts to portrait phones, landscape phones, and desktop windows. All five rows, opponents’ discard targets, the current hand, and turn controls stay on screen. Long rows open a card-selection grid; rules use pages. There are no scrollbars. Suit icons, card faces, card backs, and app branding are custom artwork, with no dependency on suit glyphs in the browser’s fonts.

**This is a playable development build, not a store-ready release.** Web and Android test exports have succeeded. Physical Android/iOS device testing, iOS signing/build validation, production hosting, and store submissions remain.

## Play locally

Open `project.godot` in Godot, or run:

```sh
godot --path .
```

Choose **Pass & play** or **Play computers**, select 2–8 players, and deal. Tap the hidden pile to reveal a card. The revealed card is selected automatically; tap its destination to play it. Tap a row card to select its sequence, or its card-count badge to inspect a long row. **Discard & end** ends the turn and opens the Burns window.

Everyone else calls **BURNS!** or **Pass**. The game explains the verdict, then each donor chooses a penalty card. Offline games save after every successful action. Return through **Resume**; dealing a new game replaces the offline save.

The confirmed rules and explicit edge-case choices are in [docs/RULES.md](docs/RULES.md).

## Web

Install matching Godot export templates, then:

```sh
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Open `http://localhost:8000`. Do not open the HTML directly from disk. The web export is single-threaded and uses the Compatibility renderer.

In this workspace, the editor inherits a Snap data directory while templates and Android settings live in the standard directories. Prefix exports with `XDG_DATA_HOME=/home/pat/.local/share XDG_CONFIG_HOME=/home/pat/.config` if templates or SDK settings are reported missing.

## Online rooms

Run a room server:

```sh
godot --headless --path . -- --server --port=9080
```

In the game, choose **Online table**, enter `ws://127.0.0.1:9080`, choose a name, and leave the code blank to create a room. Friends on the same server enter the room code. The first player starts when everyone has joined.

For another device on your LAN, run the server with `--bind=0.0.0.0` and use the server computer’s LAN address. Internet/browser hosting requires a reachable HTTPS web host and a `wss://` room endpoint. No hosted service is provisioned; see [docs/ONLINE.md](docs/ONLINE.md).

The server owns all hidden cards and adjudicates actions. Clients receive only exposed cards and pile counts. Rooms pause on disconnect; a reconnect key restores the same seat. Room state survives a server restart.

## Native builds

```sh
mkdir -p build/android build/linux
godot --headless --path . --export-debug Android
godot --headless --path . --export-release Linux
```

Android requires configured SDK/JDK paths and matching templates. The APK at `build/android/burns.apk` is a debug-signed test build, not a Play Store submission. Android orientation follows the device. The iOS preset is included, but the developer team, provisioning, signing, and Xcode validation must be completed on macOS. Release packages use `com.patguettler.burns` as the provisional bundle identifier.

## Checks

```sh
bash tools/check.sh
```

This imports scripts, checks for engine errors, and runs deck, rules, and responsive UI tests. Tests include 280 deals, 35 complete computer games, card conservation after every action, Burns/false-call cases, pile recycling, saves, and layout bounds at seven sizes from 320×568 to 1920×1080.

Optional real WebSocket and Chromium integration tests:

```sh
python3 -m venv build/testenv
build/testenv/bin/pip install -r tests/requirements.txt
build/testenv/bin/playwright install chromium
build/testenv/bin/python tests/test_network.py
# The browser test starts its own local HTTP server:
build/testenv/bin/python tests/test_browser.py
```

To render native screenshots:

```sh
godot --path . --audio-driver Dummy --script tests/test_ui.gd -- --screenshots
```

Screenshots and build outputs stay under ignored `build/`. Testing details and remaining release work are in [docs/RELEASE.md](docs/RELEASE.md). Original art provenance and exact image-generation prompts are in [docs/ART.md](docs/ART.md).
