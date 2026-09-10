# Burns — Play Console assets

## What goes in the screenshot slots

`screenshots/` only. Every file there is a real frame captured from the running
game — no mockups, no overlaid marketing copy, no artwork panels. Google Play
rejects listings whose screenshots are marketing illustrations rather than the
in-app experience, so nothing from this directory's top level belongs in a
screenshot slot.

Regenerate them with a display attached (the capture needs a real GL context):

```sh
godot --path . --audio-driver Dummy --script tools/render_store_shots.gd
```

Each frame is 1080 × 1920 (9:16, within Play's 320–3840 px limits), laid out at
360 × 640 logical points and drawn at 3×, which is how the app renders on a
high-density phone.

| File | Screen |
| --- | --- |
| `01-home.png` | Home: the three ways to sit down |
| `02-turn.png` | Pass & play turn with a revealed card |
| `03-burns.png` | The review window: call BURNS! or pass |
| `04-computers.png` | A table against computer opponents |
| `05-players.png` | Choosing a table size, 2–8 |
| `06-long-row.png` | Long-row selection grid |
| `07-deck.png` | Explore the deck |
| `08-victory.png` | Winning the table |

## Promotional artwork

Original artwork generated with OpenAI's built-in imagegen tool on 2026-09-10.
The approved full-resolution masters are in `source/`.

- `icon-512.png`: opaque 512 × 512 listing icon.
- `feature-1024x500.png`: 1024 × 500 feature graphic.
- `promo-rivalry-1080x1920.png`, `promo-modes-1080x1920.png`: portrait
  promotional panels. **Not screenshots.** They contain no app UI and must not
  be uploaded to a screenshot slot.

Run `godot --headless --path . --script tools/render_play_store.gd` to export
from the approved masters. This also updates the 1024px application icon and
the padded Android adaptive icon. Exporting only resizes and converts to RGB;
it does not regenerate the artwork or alter game visuals.

### Generation prompt set

Shared direction: production-quality Burns marketing identity; dark teal velvet,
sculptural copper raven/flame, restrained embers, ivory editorial serif type.
No cards, card shapes, suit symbols, phone mockups, fake UI, or store badges.
Each asset was generated separately with the built-in tool; the icon master
was the reference for the other three assets.

1. **Icon / logo-brand:** Square full-bleed opaque dark teal with subtle tactile
   grain. One striking sculptural copper flame whose negative space forms a
   raven head and beak. Brushed copper and illuminated ember edges. Simple,
   high-contrast silhouette, centered, readable at 32px. No text, letters,
   borders, rounded-square frame, crowns, or extra objects.
2. **Feature / ads-marketing:** Panoramic 1024:500. Reference copper raven flame
   on the right third; dark teal velvet, sparse embers, feather texture.
   Left: large ivory serif "Burns", then "A little solitaire. A little rivalry."
   Bottom left: "2–8 PLAYERS · ONE SHARP EYE". Generous margins, premium lighting,
   exact readable text and no extra text.
3. **Rivalry phone / ads-marketing:** Portrait 9:16. Small "Burns" at top,
   large "A little solitaire. A little rivalry." above a large central copper
   raven flame. Bottom: "Bring everyone to the table." then "2–8 PLAYERS".
   Subtle feather framing at lower corners, generous safe margins, no people.
4. **Modes phone / ads-marketing:** Portrait 9:16. Top "Burns"; large headline
   "Your table. Your way."; medium central copper raven flame. Lower editorial
   sections separated by thin copper rules: "Pass & play" / "Share one device.";
   "Play computers" / "Practice your next move."; "Private online tables" /
   "Invite your people." Seven-percent safe margins; no boxes or buttons.
