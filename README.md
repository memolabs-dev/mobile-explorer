# Mobile Explorer

Application macOS expérimentale pour documenter **des applications iOS dont vous avez l'autorisation d'exploration**.

## Capacités de ce prototype

- Détecter des iPhone appairés via `xcrun devicectl` (nécessite Xcode).
- Lister les applications visibles par le service d'installation via `ideviceinstaller list --xml` (nécessite l'outil installé et un iOS compatible ; non garanti).
- Sélectionner une app, ajouter des parcours manuels et exporter la fiche au format Markdown.
- Aucune collecte réseau, aucun contournement de protection, aucune extraction du code des applications App Store.

## Prérequis

- Mac sous macOS 14+, Xcode, outils CLI de Xcode activés.
- iPhone déverrouillé et ayant approuvé « Faire confiance à cet ordinateur ».
- Pour inventorier les apps : `ideviceinstaller` de `libimobiledevice` installé, généralement via Homebrew sur Apple Silicon.
- Pour lancer l'app : ouvrir `Package.swift` dans Xcode, sélectionner la cible `MobileExplorer`, puis Run. Alternativement :

```bash
swift build
swift run MobileExplorer
swift test
```

Le binaire GUI SwiftUI et l'accès à un iPhone **ne sont pas vérifiables sous Linux**. Aucune fonctionnalité d'exploration automatique n'est revendiquée à ce stade.

## Architecture et documents

- [PRD](docs/PRD.md)
- [TRD](docs/TRD.md)
- [Specs](specs/FEATURES.md)
- [Backlog](specs/TASKS.md)

## Design

SwiftUI natif, modèle local, palettes douces et lisibilité élevée. Lié conceptuellement à Rebuild Radar par une future spécification commune de preuves.

## Déclarations de sécurité

Ce logiciel n'est ni un déchiffreur d'IPA ni un outil de jailbreak. Il ne peut pas afficher le code source d'une app App Store simplement parce que l'iPhone est connecté.
