# Fridge app-icon concepts

All files are 1024×1024 RGB PNG, full-bleed, opaque, square corners (iOS applies
the mask). `concept-N@60.png` is a 60px downscale for home-screen legibility checks.
Regenerate with `python3 Distribution/Logo/render_icons.py` (Pillow only).

| # | File | Idea | Background |
|---|---|---|---|
| 1 | concept-1.png | Cream two-door fridge with a green sprout growing from the top | Fresh green `#26A66E` |
| 2 | concept-2.png | Top-down frying pan with a sunny-side egg and scallion bits | Tomato `#F26040` |
| 3 | concept-3.png | Rice bowl, chopsticks and steam inside a rounded fridge outline | Deep blue `#2254BA` |
| 4 | concept-4.png | Bold "F" monogram whose top bar splits into fork tines | Amber `#FFB81C` |

## Recommendation: concept 1 (fridge + sprout)

- **Says the product in one glance.** The app is literally "clear out your fridge";
  a fridge is the one object no generic recipe app uses, while pans (2) and
  bowls (3) are everywhere on the Food & Drink charts.
- **The sprout carries the message** — fresh ingredients, less waste (少買、少浪費),
  and "something new grows from what you have".
- **Best at 60px.** A single cream silhouette on a solid green field; the split
  line and handles still read at home-screen size, and there are no thin strokes.
- **Fits the app.** SF Symbol `refrigerator.fill` already opens onboarding, so the
  icon and first screen tell the same story.
- Green is calm and food-safe; it also stays distinct from LINE's brand green
  because the glyph is a large cream fridge, not a speech bubble (check side by side
  on a real home screen before finalising).

Runner-up: concept 3 (keeps the fridge idea and adds "a meal", but has more parts and
thinner strokes, so it is weaker at small sizes). Concept 4 works as a monogram but
says less about the app; concept 2 is the most appetising but generic.

## Next steps (not done here)

- Put the chosen PNG into `Fridge/Assets.xcassets/AppIcon.appiconset` (single-size
  1024 icon) — deliberately left untouched in this change.
- Optional: iOS 18 dark / tinted variants (e.g. transparent-background cream fridge
  for dark mode). Not produced.
- These are programmatic concepts; a designer polish pass (optical balance of the
  leaves, subtle gradient) is worth it before launch.
