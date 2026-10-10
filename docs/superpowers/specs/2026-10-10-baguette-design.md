# Baguette — spécification de conception

Date : 10/10/2026 · Statut : en revue

## 1. Objectif

Une application macOS minimale qui reproduit la **baguette magique** de Photoshop pour **détourer** :
on ouvre une image, on clique sur des zones de couleur proche, on les **efface** (transparence),
puis on **exporte en PNG**. Rien d'autre (pas de calques, pas de pinceaux, pas de presse-papiers).

Critères de réussite :
- Sur une photo d'objet sur fond uni, détourer en quelques clics et obtenir un PNG transparent propre.
- Comportement de sélection identique à photocraft (donc proche de Photoshop) pour la tolérance,
  le mode contigu et l'anticrénelage.
- App native : raccourcis standard, glisser-déposer entrant et sortant, mode clair/sombre.

## 2. Contraintes

- Pas d'Xcode : seulement les Command Line Tools (Swift 6.4), macOS 27.
  → **Swift Package** compilé avec `swift build`, testé avec `swift test`,
  et un script `scripts/bundle.sh` qui assemble `Baguette.app` (Info.plist, icône, binaire).
- Cible minimale : macOS 14 (SwiftUI récent sans dépendre des toutes dernières API).
- Aucune dépendance externe.
- Algorithme **porté** de [storytold/photocraft](https://github.com/storytold/photocraft)
  (`crates/algo/src/selection.rs`, double licence MIT / Apache-2.0). Attribution dans `NOTICE`
  et en tête des fichiers portés ; Baguette est publiée sous MIT.

## 3. Architecture

```
Package.swift
Sources/
  WandCore/          # Swift pur, aucun import AppKit/SwiftUI — testable
    RGBAImage.swift      # pixels RGBA8 non prémultipliés + largeur/hauteur
    Mask.swift           # masque de couverture UInt8 (0–255), même taille que l'image
    MagicWand.swift      # sélection (port de wand_region) + anticrénelage
    MaskOps.swift        # combiner (remplacer/ajouter/soustraire), inverser, contour progressif
    Erase.swift          # alpha *= (1 − couverture)
  Baguette/          # app SwiftUI + AppKit
    BaguetteApp.swift    # @main, scène, commandes de menu
    Document.swift       # état observable : image, masque, réglages, pile d'annulation
    ImageIO+.swift       # chargement (ImageIO) ⇄ RGBAImage, export PNG
    CanvasView.swift     # NSView : affichage, damier, zoom, clics ⇧/⌥, pointillés animés
    Toolbar/…, EmptyState, ActionBar, OptionsPopover
Tests/WandCoreTests/
scripts/bundle.sh
```

Responsabilités :
- **WandCore** ne connaît que des tableaux d'octets. Entrées/sorties explicites, pas d'état global.
- **Document** orchestre : un clic → `MagicWand.select` → `MaskOps.combine` → nouveau masque.
  Effacer → `Erase.apply` → nouvelle image + masque vidé. Chaque modification (image ou masque)
  est enregistrée dans l'`UndoManager` de la fenêtre (on stocke l'état précédent ; les images
  visées font quelques Mo, c'est acceptable).
- **CanvasView** convertit les coordonnées écran → pixels et détecte les modificateurs.

## 4. Algorithme (port de photocraft)

`MagicWand.select(image, seed: (x, y), tolerance: Int (0–255), contiguous: Bool, antiAlias: Bool) -> Mask`

- **Similarité** : pixel `p` similaire à la cible `t` si `t.a == 0 && p.a == 0`
  (deux pixels totalement transparents, quelle que soit leur couleur cachée),
  ou si `|p[c] − t[c]| ≤ tolérance` pour **chacun** des canaux R, G, B, A.
- **Contigu** : remplissage par segments (scanline span fill) en 4-connexité, pile explicite
  (pas de récursion), suivi de la boîte englobante.
- **Global** : tout pixel similaire de l'image.
- **Anticrénelage** (si activé) : pour chaque pixel dont le voisinage 3×3 contient une valeur
  différente (voisins hors image = le pixel lui-même), `moy = somme / (9 × 255)` ;
  couverture = `0,5 + 0,5·moy` si le pixel était sélectionné, sinon `0,5·moy` ; arrondi à l'octet.
- Graine hors de l'image → masque vide.

`MaskOps` :
- `combine(old, new, mode)` : Remplacer = `new` ; Ajouter = `max` ; Soustraire = `max(0, old − new)`.
- `invert(m)` = `255 − m`.
- `feather(m, radius)` : flou gaussien séparable du masque (rayon 0 = aucun effet).
  Appliqué au masque du clic avant combinaison.

`Erase.apply(image, mask)` : `a' = round(a × (255 − m) / 255)` ; RVB inchangés.

## 5. Interface

- **Fenêtre unique, sans barre latérale.** Barre du haut intégrée aux boutons de fenêtre :
  nom du fichier à gauche ; à droite, curseur **Tolérance** (0–255, défaut 32, valeur affichée)
  et bouton **⚙︎** ouvrant un popover : *Contigu* (défaut : oui), *Lisser les bords*
  (anticrénelage, défaut : oui), *Contour progressif* (0–50 px, défaut : 0).
  Tout à droite, un bouton **Exporter** (icône de partage + libellé, style proéminent,
  désactivé tant que l'image n'a pas été ouverte) qui lance le même export que ⌘⇧E.
  Les réglages sont mémorisés (`@AppStorage`).
- **État vide** : icône baguette, « Glisse une image ici », bouton « Ouvrir… ⌘O ».
  Barre d'outils et barre d'actions masquées tant qu'aucune image n'est ouverte.
- **Canevas** : image sur damier, sélection en **pointillés animés** + légère teinte d'accent.
  Curseur baguette ; badge « + » avec ⇧, « − » avec ⌥. Zoom : pincement, ⌘+ / ⌘− / ⌘0 (ajuster).
- **Clic** : remplacer ; **⇧+clic** : ajouter ; **⌥+clic** : soustraire.
- **Barre d'actions flottante** (en bas au centre, apparaît avec animation s'il y a une sélection) :
  Effacer ⌫ · Inverser ⌘⇧I · Désélectionner ⌘D.
- **Export** : ⌘⇧E → panneau d'enregistrement (`<nom>-baguette.png`) ; glisser l'image hors
  du canevas exporte aussi un PNG ; toast « Exporté » 2 s.
- **Menus** : Fichier (Ouvrir ⌘O, Exporter ⌘⇧E), Édition (Annuler ⌘Z, Rétablir ⌘⇧Z,
  Effacer ⌫, Désélectionner ⌘D, Inverser ⌘⇧I), Présentation (Zoom +/−, Ajuster ⌘0).
- Couleurs système → mode clair et sombre automatiques.

## 6. Erreurs

- Fichier illisible ou format non pris en charge par ImageIO → alerte « Impossible d'ouvrir cette image ».
- Clic hors image → aucun effet.
- Ouvrir une autre image ou quitter avec des modifications non exportées → confirmation.
- Échec d'écriture du PNG → alerte avec le message système.

## 7. Tests

`swift test` sur WandCore :
- Ports des tests photocraft : contigu vs global, tolérance, pixels transparents à RVB caché.
- Anticrénelage : valeurs exactes sur un petit motif.
- `combine` (3 modes), `invert`, `feather` (rayon 0 = identité, masque reste dans [0, 255]).
- `Erase.apply` : alpha mis à 0 sous couverture 255, conservé sous 0, proportionnel entre les deux.
- Aller-retour PNG : chargement → effacement → export → rechargement, alpha conservé.

Interface : vérification manuelle par lancement de l'app et captures d'écran.

## 8. Hors périmètre

Copier/coller, remplissage, recadrage, calques, pinceau de retouche, sélection rapide par IA,
traitement par lot, distribution signée/notarisée.

## 9. Dépôt

Git local + dépôt GitHub **privé** `baguette`, commits fréquents. Notes de travail dans `NOTES.md`.
