# Build and validation status

Version: 0.2.0. Engine: Godot 4.7.1. This is a playable development build.

## Mobile polish, September 2026

The current UI has bundled serif/sans fonts, an artwork-led home screen, larger personal cards, smooth suit outlines, hold-to-inspect artwork, a swipeable gallery with suit navigation and card-back viewing, redesigned setup/verdict/victory screens, and native safe-area insets. Supplied Jack and King portraits are preserved unchanged. All twelve court cards now carry their own portrait, and every face is baked from art kept under `assets/art/deck/source/`.

Android release exports now run the full automated suite before building an upload artifact. Private-room resynchronization no longer rewrites persistence on stale requests; expired rooms are also removed from persistent storage.

## Playtest follow-up

Burns now names the exact missed destination and stays inline on the board, with the relevant card and destination highlighted. Two-player tables show named opponent draw/discard panels. Computer reveals, plays, and discards animate; the human begins the next turn by drawing or playing instead of a separate Pass tap. Compact pile ranks render without stretching. `test_bot_pacing.gd` verifies reveal motion, the open challenge window, direct turn start, and conservation.

Penalty placement remains under the hidden pile until the conflicting playtest note is confirmed. Larger multiplayer tables still use compact opponent panels.

## Completed checks

- 280 seeded deals across all player counts: uniqueness, conservation, balance, repeatability.
- Rules scenarios: foundation order, sequence movement, empty rows, bidirectional alternate-color discard play, no rank wrapping, turn ownership, challenge timing, correct/false Burns, ordered penalties, stock exhaustion, deferred victory, and save validation.
- 35 complete computer games across 2–8 players, checking exact card conservation after each action.
- UI at 320×568, 390×844, 430×932, 667×375, 844×390, 1120×800, and 1920×1080. Tests assert no visible controls exceed the viewport, no scrolling controls exist, and row cards do not overlap personal cards. A thirteen-card sequence remains selectable through an inspection grid.
- High-density notch/home-indicator inset calculations, hold-to-inspect and swipe gestures, and unchanged game state after closing the artwork viewer.
- Native rendered screenshots and real Chromium interaction at phone/desktop sizes, including draw, discard, review, live resizing, and touch input at 3× device pixel density.
- Real WebSocket room tests including competing claims, reconnection, hidden-card redaction, and restoration after a server restart.
- Successful single-threaded Web release export and Android debug APK export.

## Before a production launch

- Family playtesting of the documented edge-case choices, including open-pile order, empty opponent discards, optional rearrangements, and priority handling.
- Physical Android and iPhone/iPad testing: touch targets, density, notches/safe areas, orientation changes, background/resume, audio interruption, and low-memory behavior.
- Safari/iOS browser validation, additional browsers, slow networks, and real cross-device games. Chromium and native resized windows do not substitute for physical-device testing.
- Configure the iOS developer team, signing/provisioning, and Xcode export/build. No iOS build was validated in this Linux workspace.
- Finish the Play Console listing for `com.grapegames.burns` (paid, Contains ads = No): price, screenshots, Data safety, content rating, and internal testers. CI already signs a Gradle AAB and uploads it to the internal track once GitHub secrets and the Play app exist; see [docs/PLAY_ANDROID.md](PLAY_ANDROID.md).
- Deploy and test a TLS room endpoint and HTTPS web host. Validate load, persistent storage permissions/backups, monitoring, and recovery for lost host credentials or abandoned seats.
- Additional accessibility work: screen-reader integration for the custom-drawn board and user-adjustable text size. Keyboard focus, distinct suit shapes, labeled controls, and sound toggling are present, but this is not a full accessibility certification.

No public server, store listing, analytics, or ads have been deployed. Play uploads are paid and ad-free; in-app purchases are not used.
