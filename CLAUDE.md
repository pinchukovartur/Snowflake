# Snowflake

## Rules

- Flakes the game sets out for the player (events, duels, bosses, presets) take their colour as a `PaperColor` (the palette enum in `lib/snowflake/geometry.dart`), never a raw `Color`: the player must be able to make them. The flake records' `color` field is typed `PaperColor`, so the compiler enforces it.
