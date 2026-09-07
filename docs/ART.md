# Art provenance

## Standard-deck revision (current)

`assets/art/card_room_standard.png` is the current background, edited with the built-in image generator from the original illustration. Hearts, diamonds, clubs, and spades replace the six-suit props. The original remains archived below. `assets/art/icon.svg` is an original code-native app mark extending the ivory-card and copper-ember visual system.

Exact edit prompt:

Use case: precise-object-edit
Asset type: original Burns card game title background, updated to standard 52-card deck.
Primary request: Preserve this illustration's midnight teal felt, walnut edges, warm copper engravings, ivory cards, painterly texture, lighting, composition, and the mostly empty left two thirds. Replace the cherry motifs on the decorative cards with classic red heart and red diamond motifs, and replace the loose cherries and dice props with a few small decorative ivory playing cards showing black clubs and spades. Keep the elegant restrained ember flecks and the same original art style. No cherries, no dice, no text, no letters, no numbers, no watermark. All changes should be confined to the card motifs and props on the right third; preserve the empty felt area for menu text.

## Card room

- Asset: `assets/art/card_room.png`
- Tool: built-in `image_gen` (no CLI/API fallback).
- Created for this project on 2026-09-07.
- Original generated illustration; no reference images supplied.
- Used as the title and table-preview backdrop. It contains decorative card motifs, not authoritative gameplay cards.

### Exact generation prompt

Use case: stylized-concept
Asset type: original background illustration for the title screen of Burns, a family multiplayer solitaire card game.
Primary request: An exquisite hand-painted overhead view of a midnight teal felt card table, with a quiet copper ember glow, inviting and sophisticated like an illustrated board game. Wide landscape composition, 1536x1024 or similar. Keep the LEFT TWO THIRDS mostly empty dark teal felt with very subtle grain for a readable game menu overlay. In the RIGHT THIRD, a small artful arrangement of cream playing cards with original copper engraved ornaments, cherry and dice motifs, and a few softly glowing abstract ember flecks. Corners of the table subtly framed in dark walnut. Flat overhead view, tactile gouache and fine etched linework, restrained palette of deep petrol teal, warm ivory, antique copper, muted vermilion. No people, no lettering, no words, no numbers, no logos, no watermark. This must be an original game illustration, not a mockup or screenshot.

## Playable card design

`scripts/card_view.gd` draws ivory card faces, six distinct suit shapes, rank labels, and a copper radial back design. Cherries and dice are custom geometry, not font substitutions. Colors follow the supplied rules. These are original code-native assets; no external card pack or third-party art is used.
