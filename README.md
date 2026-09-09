# Burns

A family multiplayer solitaire game built in Godot 4.7.1 with GDScript. Version 0.2 is playable with a standard 52-card deck, 2–8 players, pass-and-play, computer opponents, and private online rooms.

The board adapts to portrait phones, landscape phones, and desktop windows, with safe-area spacing on native phones. Hold any face-up card to inspect its original artwork, or open **Explore the deck** from Home and swipe through the cards, switch suits, or view the raven back. All five rows, opponents’ discard targets, the current hand, and turn controls stay on screen. Long rows open a card-selection grid; rules use pages. There are no scrollbars. Suit icons, card faces, card backs, and app branding are custom artwork, with no dependency on suit glyphs in the browser’s fonts.

**This is a playable development build.** Web and Android test exports have succeeded. Google Play CI uploads a paid, ad-free AAB as `com.grapegames.burns` to the internal track; store listing, pricing, and physical-device testing still need to be finished. See [docs/PLAY_ANDROID.md](docs/PLAY_ANDROID.md).

## Play locally

Open `project.godot` in Godot, or run:

```sh
godot --path .
```

Choose **Pass & play** or **Play computers**, select 2–8 players, and deal. Tap the hidden pile to reveal a card. Drag an exposed card onto its destination with a mouse or finger, or tap to select and place it. Drag onto your own discard to end the turn. Tap a row card to select its sequence, or its card-count badge to inspect a long row. **Discard & end** ends the turn and opens the Burns window. **BURNS!** stays available to all players, including out of turn; an early or incorrect call penalizes the caller. Empty opponent discards cannot be played on.

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

Android requires configured SDK/JDK paths and matching templates. The **Android** preset writes a debug APK as `com.grapegames.burns.debug` (`build/android/Burns-debug.apk`). The Play Store identity is `com.grapegames.burns`; CI signs an AAB with the Grapegames release keystore and uploads it to the internal track. Local Play exports:

```sh
SKIP_DEBUG_APK=1 ./scripts/ci/godot-export-android.sh
```

Android orientation follows the device. The iOS preset uses `com.grapegames.burns`, but the developer team, provisioning, signing, and Xcode validation must be completed on macOS. Play Console steps, GitHub secrets, and the paid/no-ads listing checklist are in [docs/PLAY_ANDROID.md](docs/PLAY_ANDROID.md).

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

The **Explore the deck** menu opens all 52 cards in the raven-and-crown theme. The supplied Noodle King and Jack artwork are the King and Jack of Spades; the ten other court portraits are marked placeholders. Art sources and replacement instructions: [Raven deck art](docs/RAVEN_ART.md).
