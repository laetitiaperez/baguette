# Baguette — notes de projet

## Objectif
Une petite app macOS en Swift qui ne fait qu'une chose : la « baguette magique » de Photoshop
(sélectionner une zone de couleur proche en cliquant, puis l'effacer / la copier / l'exporter).

## Source réutilisable : storytold/photocraft (10/10/2026)
- Dépôt : https://github.com/storytold/photocraft — « clean-room reimplementation of Adobe Photoshop in pure Rust »
- Licence : double **MIT / Apache-2.0** → réutilisation et portage autorisés, à condition de garder
  la mention de copyright + licence (fichier NOTICE / ATTRIBUTION à reprendre).
- C'est du **Rust**, pas du Swift : on ne peut pas copier les fichiers tels quels.
  Options : (a) porter l'algorithme en Swift (~150 lignes), (b) compiler la crate Rust et l'appeler
  depuis Swift (FFI). Le portage est beaucoup plus simple pour une app de cette taille.

### Code pertinent
- `crates/algo/src/selection.rs`
  - `magic_wand(px, area, seed, tolerance, contiguous, anti_alias)` : version simple (pile, 4-voisins).
  - `wand_region(...)` : version optimisée 8 bits — **remplissage par segments (scanline span fill)**,
    calcule la boîte englobante, anticrénelage seulement sur les bords. C'est celle à porter.
  - Similarité : pour chaque canal R,G,B,A, |p − cible| ≤ tolérance (0–255, comme Photoshop).
    Cas spécial : deux pixels totalement transparents sont toujours « similaires ».
  - `contiguous` : vrai = seulement la zone connectée au clic ; faux = tous les pixels similaires de l'image.
  - Anticrénelage : un pixel de bord prend la moyenne 3×3 (sélectionné → 0,5 + 0,5·moy ; sinon 0,5·moy).
  - `combine_region(old, new, mode)` : modes Remplacer / Ajouter (Maj) / Soustraire (⌥) / Intersection.
- Tests utiles à reprendre : `wand_contiguous_vs_global`, `wand_tolerance`,
  `wand_ignores_hidden_rgb_only_when_both_pixels_are_fully_transparent`.
- Icône : `assets/icons/wand.svg`, `wand-sparkles.svg` (même licence).

## Décisions
- (à compléter au fil des échanges)
