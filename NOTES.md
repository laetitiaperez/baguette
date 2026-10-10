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
- **Géométrie du canevas** : `CanvasGeometry` (vue à origine en haut-gauche, en points) ; `fit` n'agrandit jamais au-delà de 100 % et renvoie zoom 1 / origine nulle si image ou vue de taille nulle.
- **Lecture d'images** : `ImageFile.load` applique l'orientation EXIF (sans réduire), convertit en sRGB 8 bits, dé-prémultiplie ; seule la première image d'un fichier multi-images est chargée. `cgImage` produit un CGImage sRGB à alpha droit.
- **Usage** : la zone sélectionnée est **effacée** (fond transparent), puis l'image est **exportée en PNG**.
  Pas de presse-papiers ni de remplissage pour l'instant.
- **Annulation** : `Editor` enregistre un instantané (image, sélection, isDirty) par action utilisateur ; annuler/rétablir restaurent aussi `isDirty`. Un clic hors image ou « Désélectionner » sans sélection n'enregistre rien. `Editor` ouvre/ferme lui-même le groupe d'annulation.
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
- **Fenêtre unique** : scène `Window` (et non `WindowGroup`, qui ouvrait une nouvelle fenêtre par fichier ouvert depuis le Finder) ; pas d'onglets ; l'app se ferme avec sa fenêtre. Les fichiers ouverts depuis le Finder passent par `application(_:open:)`.
- **Barre du haut** = barre d'outils unifiée de la fenêtre : le nom du fichier est le titre de la fenêtre (à gauche), Tolérance et ⚙︎ à droite (`.primaryAction`). `.hiddenTitleBar` abandonné : sans espace flexible (`ToolbarSpacer` exige macOS 26), les éléments restaient collés à gauche. Sans image, la barre d'outils est masquée (barre de titre « Baguette »).
- **`@State` sans Xcode** : dans le SDK, `@State` est une macro dont le plugin manque aux Command Line Tools ; l'app utilise l'alias `ViewState` (= `SwiftUI.State`).
- **Info.plist** : région de développement et localisation `fr` (menus système en français), rang `Alternate` pour les images, signature ad hoc par `bundle.sh`.
- **Ouverture** : chargement hors du fil principal ; seules les URL de fichier sont acceptées ; la confirmation « Ignorer les modifications ? » est posée après le choix du fichier (panneau, dépôt ou Finder).
- **Canevas** : calques Core Animation (image, teinte d'accent 25 % masquée par la sélection, contour noir + pointillés blancs animés) ; rendus recalculés seulement quand le tampon de pixels change ; damier limité à la partie visible de l'image ; pointillés non animés au-delà de 100 000 segments de contour ; zoom de 1 % à 3200 %, l'image suit la fenêtre tant qu'on n'a pas zoomé. Curseur : SF Symbol `wand.and.rays`, point chaud au centre des rayons.
- **Touche ⌫** : jamais enregistrée comme raccourci de menu ou de bouton (elle volerait la touche aux champs de texte, y compris ceux des panneaux d'ouverture/enregistrement) ; ⌫ et ⌦ sont traitées par `CanvasNSView.keyDown`, qui devient premier répondeur dès qu'une image s'affiche. Le menu affiche « Effacer (⌫) » en indication.
- **Menus** : Édition remplace Couper/Copier/Coller par Effacer, Inverser ⌘⇧I, Désélectionner ⌘D ; Inverser est actif dès qu'une image est ouverte (sans sélection, il sélectionne tout).
- **Glisser l'image hors du canevas** : il faut maintenir **⌘** pendant le glisser (le clic simple reste la baguette, sélection au moment de l'appui) ; avec ⌘ le curseur devient une main ouverte et ⌘-clic sans glisser ne fait rien. Le glisser fournit une promesse de fichier (`NSFilePromiseProvider`, type PNG) nommée `<nom>-baguette.png` : le PNG est écrit directement à l'endroit du dépôt (Finder, autre app) plutôt que dans un fichier temporaire ; une écriture réussie compte comme un export (toast « Exporté », image marquée exportée si elle n'a pas changé entre-temps). Dépôt refusé à l'intérieur de l'app. Vignette du glisser : l'image réduite à 256 pt au plus.
- **Export** : panneau d'enregistrement en feuille, dossier proposé = celui de l'image ouverte, nom `<nom>-baguette.png` (`image-baguette.png` à défaut). Échec d'écriture → alerte « Impossible d'exporter l'image » avec le message système. Le toast « Exporté » (bas centre, 2 s, fondu + glissement) se place au-dessus de la barre d'actions et est annoncé à VoiceOver.
