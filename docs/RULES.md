# Burns rules

## Confirmed family rules

- Start with one standard 52-card deck and 2–8 players. The six-suit deck is deferred.
- Deal five cards face up into five shared rows, then deal the remaining cards face down to players as evenly as possible.
- Four shared foundations build from Ace to King in the same suit.
- Rows build downward by one rank in alternating colors. Move a card together with the valid sequence below it. Any card can fill an empty row. An exposed row card can move to its foundation.
- Opponents’ nonempty discards build upward **or** downward by one rank in alternating colors. Empty opponent discards are not legal targets and never count as missed plays.
- Players may use their revealed play-pile top or their own discard top. No player may inspect a face-down card before their turn.
- Destination priority is foundations, rows, then opponents’ discards.
- Discarding ends a turn. A correct Burns call must be made **after** the player finishes, before the next turn begins. The Burns button remains available to all players; an out-of-window call burns the caller.
- A missed required play burns the offender. An incorrect Burns call burns the caller instead.
- Every other player gives the burnt player one card from their hidden top or discard top. Gifts go on the bottom of the burnt player’s hidden pile.
- When the hidden pile empties, the discard stays in its existing order. The player can use its exposed top or reveal its bottom. Once a new discard is made, the remaining old pile becomes face down again.
- Win by getting rid of **all** personal cards, including the play pile and discard.

The example “red 3 with a black 3” is interpreted as “red 3 with a black 2,” consistent with descending alternating-color rows.

## Explicit implementation choices

These resolve cases not fully specified in the conversation and can be adjusted after family playtesting:

- The top of an array is its last element. An old discard becoming face down retains that order; its former top is the next hidden top. The bottom option reveals one card into the player’s hand before it can be played.
- Ace and King do not wrap. Shared rows cannot be transferred onto an opponent’s discard; that destination accepts personal cards only.
- Priority is global across all exposed playable sources. A placement that fits can still skip a higher-priority move and become burnable. Structurally invalid placements are rejected immediately, with no card moved.
- A whole row moving onto an occupied row frees a space and is a required move. Splitting a row or moving it to an empty row is optional; reversible rearrangements cannot create an endless requirement to move.
- Only exposed cards count as missed plays. The remaining hidden play pile and the unseen bottom of an open pile never provide secret evidence for a Burns verdict.
- The engine records missed opportunities immediately before discarding, plus any priority violation earlier in that turn. Review uses this recorded evidence, not the changed board after the discard.
- In shared-device and online games, every other player explicitly calls Burns or passes. Against computers, you start your own turn by drawing or playing; that first action closes your challenge window. Between computer turns there is a brief review pause (at least 2.5 seconds after a computer discards), then play continues automatically. Online, the first valid challenge processed by the server resolves the window; stale competing actions are rejected.
- After either a correct or false call, donors choose in clockwise order starting after the burnt player. Each gift is inserted at the bottom. A donor with no cards is skipped. An open-pile top or already revealed play card is also an available donation source.
- A burn does not undo already legal card placements. After a challenge in the review window, penalties advance play to the next player. Out-of-window false calls pause play for donations, then resume the interrupted turn or pending review/penalty.
- A final empty hand still goes through the Burns window before victory is confirmed. A player can also empty their hand by donating a final card.

## Engine states

`turn → review → next turn` after all passes, or `turn → review → penalty → next turn` after a call. A confirmed empty hand changes the phase to `finished` instead of starting another turn.

The client never decides the legality of an online action. The same `BurnsGame` engine powers offline play, computer opponents, and the room server. `view()` removes hidden pile arrays and private adjudication evidence from network snapshots.
