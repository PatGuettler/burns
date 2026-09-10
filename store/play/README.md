# Burns — ember raven marketing set

Original artwork generated with OpenAI's built-in imagegen tool on 2026-09-10.
The approved full-resolution masters are in `source/`.

- `icon-512.png`: opaque 512 × 512 listing icon.
- `feature-1024x500.png`: 1024 × 500 feature graphic.
- `phone-1080x1920.png`: 1080 × 1920 rivalry promotional panel.
- `phone-menu-1080x1920.png`: 1080 × 1920 play-modes promotional panel.

All four contain **no playing cards or suit imagery**. The phone panels are
marketing illustrations, not screenshots of the running app. Their filenames
are retained for compatibility with the previous asset set. Do not describe
them as gameplay captures. Real gameplay capture remains a separate task.

Run `godot --headless --path . --script tools/render_play_store.gd` to export
from the approved masters. This also updates the 1024px application icon and
the padded Android adaptive icon. Exporting only resizes and converts to RGB;
it does not regenerate the artwork or alter game visuals.

## Generation prompt set

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
   Left: large ivory serif “Burns”, then “A little solitaire. A little rivalry.”
   Bottom left: “2–8 PLAYERS · ONE SHARP EYE”. Generous margins, premium lighting,
   exact readable text and no extra text.
3. **Rivalry phone / ads-marketing:** Portrait 9:16. Small “Burns” at top,
   large “A little solitaire. A little rivalry.” above a large central copper
   raven flame. Bottom: “Bring everyone to the table.” then “2–8 PLAYERS”.
   Subtle feather framing at lower corners, generous safe margins, no people.
4. **Modes phone / ads-marketing:** Portrait 9:16. Top “Burns”; large headline
   “Your table. Your way.”; medium central copper raven flame. Lower editorial
   sections separated by thin copper rules: “Pass & play” / “Share one device.”;
   “Play computers” / “Practice your next move.”; “Private online tables” /
   “Invite your people.” Seven-percent safe margins; no boxes or buttons.
