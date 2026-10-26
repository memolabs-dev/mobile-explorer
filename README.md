# Mobile Explorer

[![Verify SwiftUI](https://github.com/memolabs-dev/mobile-explorer/actions/workflows/ci.yml/badge.svg)](https://github.com/memolabs-dev/mobile-explorer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Un prototype macOS SwiftUI** pour documenter les parcours d'applications iOS que vous êtes autorisé à examiner. Ce projet ne permet ni d'extraire le code d'une application App Store ni de contourner le sandbox, FairPlay ou les protections iOS.

> **Statut : expérimental.** Compilation et tests Swift automatisés disponibles dans GitHub Actions ; le parcours complet sur un iPhone physique reste à confirmer. Aucun paquet macOS signé ou notarisé n'est publié.

## Fonctionnalités

- Découverte des iPhone visibles via `xcrun devicectl list devices`.
- Inventaire des **métadonnées accessibles** des applications via `xcrun devicectl device info apps` en priorité (Xcode), avec repli facultatif sur `ideviceinstaller`.
- Choix d'une application, saisie manuelle d'observations d'écran et de parcours, export local en Markdown.
- Aucune transmission des notes ou des identifiants d'appareil vers un serveur.

L'accès aux métadonnées dépend de l'état de l'appareil, du jumelage, des permissions et de la version iOS. Un échec est signalé, jamais remplacé par de fausses données. CoreDevice peut refuser une requête si l'iPhone n'est pas dans un état autorisant l'opération.

## Démarrer

Prérequis : macOS 14+, Xcode actif et Swift 5.9+. Pour le repli facultatif : `brew install ideviceinstaller` (inutile pour essayer CoreDevice).

```bash
git clone https://github.com/memolabs-dev/mobile-explorer.git
cd mobile-explorer
swift build
swift test
swift run MobileExplorer
```

Vous pouvez aussi ouvrir `Package.swift` dans Xcode et lancer la cible `MobileExplorer`. Pour l'essai physique, connecter et déverrouiller un iPhone autorisé, valider la confiance dans cet ordinateur, puis vérifier le mode développeur lorsque requis.

Le binaire est une interface **macOS**, pas une app distribuée sur iPhone. La détection d'un téléphone ne signifie pas qu'une app tierce peut être inspectée automatiquement.

## Tester avec un iPhone

Suivre le [plan de recette d'appareil](docs/DEVICE_TEST_PLAN.md) et ne publier aucun identifiant complet, capture de données personnelles ni fichier propriétaire. Un scénario valide commence par une application de démonstration autorisée.

## Architecture, limites et contributions

[PRD](docs/PRD.md) · [TRD](docs/TRD.md) · [Fonctionnalités](specs/FEATURES.md) · [Roadmap V1](https://github.com/memolabs-dev/mobile-explorer/issues/4).

Le contrat `contracts/observation-v0.1.schema.json` est **préparatoire** : l'export actuel reste du Markdown, et l'intégration à Rebuild Radar n'est pas encore opérationnelle.

Pour proposer une PR : expliquer le scénario iOS, les permissions, l'outillage, la méthode de reproduction et les tests. Ne jamais publier de journaux contenant des UDID, données utilisateur, cookies, tokens ou captures privées.

Licence : [MIT](LICENSE) © 2026 Memo Labs.
