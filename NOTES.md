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
- **Usage** : la zone sélectionnée est **effacée** (fond transparent), puis l'image est **exportée en PNG**.
  Pas de presse-papiers ni de remplissage pour l'instant.
- **Sélection (option C)** : clic = nouvelle sélection ; ⇧+clic = ajouter ; ⌥+clic = soustraire ;
  Inverser la sélection ; tolérance (0–255) ; case « contigu » ; anticrénelage on/off ;
  contour progressif (rayon en px). Supprimer efface la sélection.
- **Environnement** : pas d'Xcode installé, seulement les Command Line Tools (Swift 6.4, macOS 27).
- **Tests** : avec les seules Command Line Tools, le plugin de macros Swift Testing n'est pas trouvé ; `Package.swift` passe `-plugin-path` (unsafeFlags) à la cible de test pour que `swift test` fonctionne.
- **Approche 1 retenue** : Swift Package (`swift build` / `swift test`) + script qui assemble `Baguette.app`.
  Module `WandCore` (Swift pur, testé) + app `Baguette` (SwiftUI, canevas AppKit).
- **Langage** : algorithme porté de Rust vers Swift (pas de FFI), avec attribution MIT/Apache.
- **Interface et erreurs/tests validés** ; dépôt GitHub **privé**. Spec : `docs/superpowers/specs/2026-10-10-baguette-design.md`.
- **Bouton Exporter** en haut à droite de la barre (demande du 10/10/2026), même action que ⌘⇧E.
- **Contour progressif** : flou gaussien séparable (σ = rayon / 2, noyau de demi-largeur ⌈rayon⌉, bords répétés), intermédiaire en `Float`, arrondi final. **Effacer** : alpha × (255 − masque) / 255, arrondi ; RVB inchangé.
