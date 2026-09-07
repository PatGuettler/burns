# Art provenance

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
