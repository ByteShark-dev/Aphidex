# Aphidex 1.3 — Implementation report

## Generated data

- Editorial creatures: 38/38.
- Normalized creatures: 132.
- Equipment items: 209; verified icons: 207.
- Defense entries: 2; variants: 4.
- Unresolved acquisitions: 11.

## Mandatory invariants

- `duplicateSemanticFields = 0`
- `coverAsCard = 0`
- `unauthorizedCrossGameAssets = 0`
- `approvedCrossGameExceptions = 1` (Orchid Mantis only)
- Picnic and Resting remain exclusively in `known_pending_assets`.
- iOS validation remains pending on macOS/Codemagic; no deploy was performed.

## Provenance

Gameplay fields retain extractor or historical provenance. Presentation overrides are versioned in `g2_presentation_overrides.json`; unresolved values remain explicit.

## Community-calibrated danger pass

- 46 danger assignments are versioned under `dangerOverrides` with review date, methodology and source URLs.
- Tadpole, Water Boatman and Woolly Aphid use the lowest supported danger, `baja`.
- All newly imported G2 catalog entries now have a concrete danger; `unknown` count is 0 in ES/EN/RU.
- Boss progression: Masked Fighter `alta`, Masked Stranger and O.R.C. Broodmother `muy_alta`, Axl and King Dozer `imposible_superior`.
- The current community outlier, O.G.R.R. Toe Biter Leviathan, is `extrema`.
- Orchid Mantis remains `proximamente` because its G2 presence is Playground-only rather than a campaign encounter.

## Supplied logo integration

- Masked Stranger O.R.C. Waves, MIX.R catalog/map presentation and Raw Science rewards/loot use the user-supplied assets.
- Picnic and Resting remain exclusively in `known_pending_assets`.

## Latest validation

- Reproducible importer: completed successfully; 38/38 editorial rows, 49 presentation targets and 46 danger overrides applied.
- `flutter analyze lib test`: no issues.
- Focused danger tests: 19/19 passed.
- Full `flutter test`: 281/281 passed.
- `flutter build appbundle --release`: completed successfully in 174.4 s.
- Android artifact: `build/app/outputs/bundle/release/app-release.aab` (137,161,264 bytes; Flutter reports 130.8 MB).
- `git diff --check`: passed; only informational LF-to-CRLF warnings were reported.
- iOS validation remains pending on macOS/Codemagic; no deploy was performed.
