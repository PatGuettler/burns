# Polish notes for the next pass

Playtest feedback from Pat, 2026-09-09, with the code locations each item touches.
Implementation status: items 3 and 7 now land as concrete destination descriptions, priority-sorted evidence, an inline verdict, and destination highlighting. The remaining notes below record the original playtest request.

## 1. Do not make the human tap "Pass" to start their turn

**What happens now.** After any turn ends, `_end()` sets `phase = "review"` and fills
`s.reviewers` with every other seat (`scripts/game.gd`). The footer then shows only
**Pass** / **BURNS!** (`scripts/table_view.gd:269`). Against computers that means the
human taps Pass after every single computer turn before their own turn begins. It reads
like a "start turn" button, which is why it feels wrong.

**This is not a bug** — the review window is the documented rule (`docs/RULES.md`,
"Every other player must explicitly call Burns or pass"). The problem is that the window
is presented as a blocking step instead of an opportunity.

**Recommended fix (in preference order).**

1. **Auto-pass computer seats, and fold the human's review into their own turn.** When
   `mode == "bots"` and every remaining reviewer is a bot, resolve them immediately.
   For the human's own review, do not stop the game: go straight into `phase = "turn"`
   for them and keep **BURNS!** live with a short window. `_burn()` already handles an
   out-of-window call correctly via `s.interrupts`, so a late call is not a correctness
   problem — it just burns the caller. The cleanest version is a real *challenge window*:
   the human's turn starts, and BURNS! stays armed until they make their first move.
2. If the explicit acknowledgement must stay, make it a transient toast on the table with
   a countdown ("Computer 2 finished — call Burns?" auto-passing after ~3s) rather than a
   footer button that gates the turn. Never a modal.

Either way, drop the `handoff` style gate for bot games entirely — `_handoff()`
(`scripts/main.gd:349`) is only meant for pass-and-play.

## 2. Computer turns are unreadable — animate card movement

Bots act on a fixed `bot_wait = 0.8` tick in `_process()` (`scripts/main.gd:94`), and
each action triggers a full `_show_table()` rebuild. Every control is destroyed and
recreated (`_clear()`, `scripts/main.gd:103`), so a card teleports from source to
destination with no visual continuity.

**Recommended fix.** Before rebuilding, capture the source and destination `Rect2` for the
moved card. `BurnsTableView` already tracks `card_rects` / `card_sources`, so the geometry
is available. After the rebuild, draw a single throwaway `BurnsCardView` at the old rect
and tween it to the new rect (~0.25s) over the top of the table, then free it. Hold the
next bot tick until the tween finishes so moves never overlap. Gate it on
`animations_enabled` and skip it in headless so `tools/check.sh` stays fast.

Also worth doing: leave a brief highlight on the destination pile after the tween lands,
and slow `bot_wait` slightly when a bot chains several moves in one turn.

## 3. "4♦ could have been played" — where?

Investigated against the screenshot. **Not a bug in the rules engine.** With foundations
at A♦ / A♣ / 3♥ / 4♠ and row tops K♠, 5♦, 9♠, J♥, 9♣, the 4♦ had no foundation and no row
destination. The only legal target was the **opponent's discard top**, which builds one
rank up *or* down in alternating colour (`moves()`, `scripts/game.gd`) — so a black 3 or
black 5 on Computer 2's discard makes the 4♦ a required play.

**The real defect is that the message never says this.** `describe()` renders the
opponent case as the bare string `"another player's discard"` — no player name, no card,
no indication that opponent discards build in both directions. The player cannot verify
the verdict, so a correct call looks like a bug.

**Fix `describe()` to name the destination concretely:**

- `"4♦ could have played onto Computer 2's discard (3♣)."`
- `"4♦ could have played to the Aces area."`
- `"4♦ could have played to row 3, onto the 5♠."`

**Second, smaller defect in the same area.** `_end()` reports `describe(available[0])`,
and `available` is in `sources()` order (held, discard, reserve, then rows) — *not*
priority order. So when several plays were missed, the one named can be an arbitrary
lower-priority move while a foundation play also existed. Sort `available` by `priority`
before describing, so the message always names the most damning miss.

## 4. Penalty gifts should land on the discard, not under the hidden pile

`_donate()` does `s.players[s.burnt].play.push_front(card)` — bottom of the hidden pile.
That matches what `docs/RULES.md` currently says ("Gifts go on the bottom of the burnt
player's hidden pile") and what the rules screen tells the player
(`scripts/main.gd:543`).

Pat wants gifts to go **face up on top of the burnt player's discard** instead. That is a
real rules change, not a bug fix, and it is a meaningful one: a gift on the discard is
immediately playable by everyone and changes what opponents can target next turn. Confirm
with the family before changing it, then update **all three** places together:
`_donate()`, `docs/RULES.md`, and the rules page copy. Tests in `tests/test_game.gd` that
assert donation placement will need updating too.

## 5. Playing onto another player's discard already works — it is just invisible

The engine supports it (`moves()` emits `target: "opponent"` at priority 2) and the UI
wires it up (`_pile_action()`, `scripts/main.gd:339`; the `"opponent"` drop target in
`accepts_drop()`). Nothing to fix in the logic.

What is missing is **legibility** — see the next item.

## 6. Rebuild the table so every player's draw and discard are readable

This is the big one, and it is the root cause of items 3 and 5 feeling like bugs.

**Now.** Opponents are a cramped strip of tiny cards across the top (`_opponents()`,
`scripts/table_view.gd`), sized down to as little as 44px tall, with the rank often
unreadable — in the screenshot the opponent's discard is a blurred club with no visible
rank. The human's own draw/discard get a proper labelled shelf at the bottom
(`_hand()`), and opponents get nothing comparable.

**Wanted.** Give every seat the same treatment the local player gets: a named panel with a
face-down **Draw** pile showing its count and a face-up **Discard** showing a legible
card, arranged around the shared rows in the centre. Concretely:

- Seat panels around the perimeter of the shared board, local player at the bottom.
- Same card size, same `Draw · N` / `Discard` captions as `_hand()` uses.
- Legibility floor: never shrink an opponent's discard below the size where the rank
  reads. If the space is not there, drop decorative padding or the row spread before the
  cards.
- Mark a seat's discard as a live drop target whenever the selected card can legally land
  there — a highlight ring the moment a card is picked up would teach rule 5 by itself.
- 2-player and 8-player layouts are very different problems; solve 2-player first, since
  that is what is being playtested.

`tests/test_ui.gd` checks layout bounds at seven sizes from 320×568 to 1920×1080 — that
suite is the guard rail for this rework, so extend it rather than working around it.

## 7. Keep the burn on the table — no full-screen verdict

`_prepare_burn_result()` / `_show_burn_result()` (`scripts/main.gd:586`) replace the whole
board with a title and two lines of log text. The player loses sight of the position at
exactly the moment they want to check it.

**Recommended fix.** Stay on the table:

- A 🔥 badge on the burnt player's panel.
- An inline banner in the existing status line: `🔥 Burns — 4♦ could have played onto
  Computer 2's discard (3♣).` This depends on the `describe()` fix in item 3.
- Highlight the source card and pulse the destination pile it should have gone to, so the
  player *sees* the missed play on the real board.
- Penalty donation continues in place, on the table.

Retire the `burn_result` screen once this lands, including its entry in `_relayout()`
(`scripts/main.gd:314`).

## Suggested order

3 → 7 (the verdict is wrong-feeling and cheap to fix), then 1 and 2 (turn pacing), then 6
(the layout rework), and 4 only after the rules question is settled with the family.
