# Baguette

Une petite app macOS qui ne fait qu'une chose : la **baguette magique**. On clique sur une zone de
couleur, elle est sélectionnée ; on l'efface, et l'image est exportée en PNG à fond transparent.
Pratique pour détourer un logo ou retirer un fond uni.

Dépôt : <https://github.com/laetitiaperez/baguette>

## Ce que fait l'app

- **Ouvrir** une image : glisser-déposer dans la fenêtre, ⌘O, ou « Ouvrir avec › Baguette » depuis le Finder
  (tous les formats lus par macOS : PNG, JPEG, HEIC, TIFF…).
- **Sélectionner** d'un clic les pixels de couleur proche, réglés par la **Tolérance** (0–255, 32 par défaut).
  Le bouton ⚙︎ ouvre les options : *Contigu* (seulement la zone reliée au clic), *Lisser les bords*
  (anticrénelage) et *Contour progressif* (0–50 px). Les réglages sont mémorisés.
- **Combiner** les sélections : ⇧ + clic ajoute, ⌥ + clic retire ; Inverser et Désélectionner.
- **Effacer** la sélection : les pixels deviennent transparents (damier à l'écran).
- **Exporter** en PNG (bouton en haut à droite ou ⌘⇧E) sous le nom `<nom>-baguette.png`, ou glisser
  l'image hors de la fenêtre avec ⌘ maintenue (vers le Finder ou une autre app).
- Annuler / Rétablir pour chaque action ; confirmation avant de quitter ou d'ouvrir une autre image
  si le travail n'a pas été exporté.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir | ⌘O |
| Exporter en PNG | ⌘⇧E |
| Sélectionner (remplacer) | clic |
| Ajouter à la sélection | ⇧ + clic |
| Retirer de la sélection | ⌥ + clic |
| Effacer la sélection | ⌫ ou ⌦ |
| Inverser la sélection | ⌘⇧I |
| Désélectionner | ⌘D |
| Annuler / Rétablir | ⌘Z / ⌘⇧Z |
| Zoom avant / arrière | ⌘+ / ⌘− (ou pincement sur le trackpad) |
| Ajuster à la fenêtre | ⌘0 |
| Glisser l'image hors de la fenêtre | ⌘ + glisser |

## Compiler

Il faut macOS 14 ou plus récent et Swift 6 ; les Command Line Tools suffisent (Xcode n'est pas nécessaire).

```sh
./scripts/bundle.sh          # compile en release et assemble build/Baguette.app
open build/Baguette.app
swift test                   # tests de WandCore (sélection, masques, effacement, lecture/écriture PNG)
```

Pour l'installer, copier `build/Baguette.app` dans le dossier Applications. L'icône
(`Sources/Baguette/Resources/AppIcon.icns`) se régénère avec `swift scripts/make-icon.swift`.

## Organisation

- `Sources/WandCore` : la logique, en Swift pur et testée (baguette, opérations sur les masques,
  effacement, lecture/écriture d'images, géométrie du canevas, éditeur avec annulation).
- `Sources/Baguette` : l'interface SwiftUI, avec un canevas AppKit.
- `scripts/` : assemblage de l'app et génération de l'icône.

## Crédits

L'algorithme de la baguette magique (remplissage par segments, similarité par canal, anticrénelage des bords,
combinaison des sélections) est porté en Swift depuis
[photocraft](https://github.com/storytold/photocraft) (`crates/algo/src/selection.rs`), réimplémentation
de Photoshop en Rust par les contributeurs de photocraft, sous double licence MIT / Apache-2.0.
Voir `NOTICE`.

## Licence

MIT, voir `LICENSE`.
