# Raven deck art

The original user-supplied King of Spades is preserved byte-for-byte at `assets/art/deck/faces/king_spades.jpg` (SHA-256 `67550f1b2b9ffd4cd31ec0cbc0aa86157c09b2980cfc38f5222e0dfc67a6b229`). The person was not generated, retouched, cropped, or stretched. The renderer fits the complete card and draws readable gameplay corner indices above it.

Three new raster assets were made with the built-in image_gen tool (no CLI fallback): `raven_face.png`, `raven_back.png`, `raven_room.png`, all under `assets/art/deck/`. Number cards compose the engraved face with exact suit pip counts and corner ranks. Black suits are represented in silver on charcoal; red suits use warm coral, preserving the alternating-color distinction. All suit symbols are vector geometry to avoid missing font glyphs.

The eleven other court cards deliberately display crown-and-suit placeholders marked PORTRAIT TO COME. To supply another complete face-card image, add it under `assets/art/deck/faces/` and add a preload entry to `BurnsDeckArt.PORTRAITS` in `scripts/deck_art.gd`. Card IDs: diamonds J/Q/K 10/11/12, clubs 23/24/25, hearts 36/37/38, spades 49/50/51. No invented portraits are used. In-game View the deck allows inspection of all 52 cards without scrolling.

## Exact generation prompts

### face

Use case: stylized-concept. Asset type: production playing-card face background texture for Burns game, portrait 2:3 aspect ratio, flat orthographic full-bleed printable card, not a mockup. Reference: the user supplied Noodle King card shows charcoal engraved gothic raven and crown border; use that ornamental language only, no person or photograph. Blend with existing Burns midnight petrol teal and antique copper theme. Create an exquisite dark charcoal card face with restrained silver engraved intertwining feather filigree along the extreme left/right edges, tiny ravens and a crown ornament centered at top and inverted at bottom, subtle tarnished copper hairline inner frame and very dark teal-black fine paper grain. Center 65 percent must remain almost uniform dark charcoal, blank for high-contrast pips. Leave upper-left and lower-right index areas dark and clear. Borders narrow, finely etched, readable silhouette at small sizes. Rounded outer corners within image. No letters, numbers, suit symbols, faces, humans, words, pseudo-writing, or watermark. Single card face template only.

### back

Use case: stylized-concept. Asset type: actual production playing-card BACK texture, one portrait card 2:3 ratio, full-bleed flat orthographic artwork, not a photographed card or mockup. Reference image is style only: the Noodle King card's gothic silver raven-and-crown engraving. Do NOT reproduce the man or lettering. Blend this with Burns antique copper and midnight petrol teal theme. Perfect 180-degree rotational symmetry: two intricately engraved ravens with spread feathered wings facing opposite directions around a central fine antique-copper crown medallion, flowing feather filigree, narrow double silver-and-copper border, rich charcoal-black paper and subtle teal undertones. Sophisticated antique etching, crisp silver highlights, muted copper hairlines, sumptuous but restrained. Match the narrow raven ornamental frame of reference. Fill entire image with single card artwork. No people, no letters, no numbers, no rank/suit symbols, no watermark. Back design cannot identify card rank or suit.

### room

Use case: stylized-concept. Asset type: production Burns game menu and table backdrop, landscape 1536x1024. Original fine painterly illustration with etched silver and antique copper detail. Overhead midnight petrol teal felt table fades into charcoal black, barely lit by soft warm embers. LEFT TWO THIRDS almost empty dark felt for UI. Along extreme RIGHT edge only, three overlapping charcoal playing-card backs with delicate silver raven feathers, fine crown medallions and narrow copper border engraving. One loose dark silver feather beside them. Gothic raven-and-crown ornament to coordinate with a monochrome Noodle King portrait card, blended with cozy old Burns teal-felt-and-copper atmosphere. No people, no faces, no numbers, no text or pseudo-writing, no exposed ranks, no bright ivory cards, no logos or watermark. Quiet restrained high-end board game art, avoid distracting highlights behind controls.


