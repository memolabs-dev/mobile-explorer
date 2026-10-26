# TRD — Mobile Explorer

## Environnement

macOS 14+, Xcode et ses command-line tools, Swift 5.9+, un iPhone approuvé et appairé, facultativement `ideviceinstaller` (libimobiledevice). `ideviceinstaller` peut ne pas être compatible avec tous les iPhone/iOS : c'est une dépendance facultative, pas une garantie.

## Stack et modules

```
SwiftUI (ContentView)
    └── @MainActor ExplorerModel
          ├── DeviceScanner → ProcessExecutor → /usr/bin/xcrun devicectl list devices --json-output <temp>
          ├── ApplicationScanner → ProcessExecutor → ideviceinstaller -u <udid> list --xml
          └── AppSpecExporter → NSSavePanel → Markdown local
```

- Les processus externes sont invoqués avec `Process` et un tableau d'arguments ; aucun shell et aucune commande provenant des notes utilisateur.
- Les interrogations d'appareils et d'applications sont effectuées via une tâche détachée pour éviter de bloquer le thread d'interface.
- Erreurs explicites, jamais de fallback à un faux catalogue.
- Les noms, versions et identifiants viennent de l'appareil ; aucune assertion de compatibilité ou de sécurité n'en est déduite.
- Le modèle d'observations contient `screenName`, `expectedAction`, `observedResult`, `notes`.
- Le rapport exporté affirme uniquement une **observation manuelle**. Aucun contenu de l'iPhone n'est envoyé vers un serveur.

## Limitations de la plateforme

- `devicectl` dépend de Xcode et de l'appairage ; ses structures JSON peuvent évoluer selon les versions.
- `ideviceinstaller` dépend des capacités exposées par les versions iOS, peut retourner des métadonnées partielles ou ne pas fonctionner.
- Liste des applications ≠ accès à leur code, données internes, vues d'accessibilité ou backend.
- Les tests d'interface automatisés nécessiteront un runner de QA/Appium et des autorisations adaptées, pas simplement la présence d'un câble USB.

## Tests et livraison

`swift test` et `swift build` **à exécuter sur macOS** ; impossible de confirmer une compilation SwiftUI ou une connexion USB depuis Linux. Les tests fournis couvrent les entrées JSON d'appareil, le plist des applications et l'export Markdown. L'intégration QA/Appium, la notarisation et la distribution DMG sont hors périmètre P0.

## Sécurité

- Aucun bypass FairPlay, DRM, sandbox ou contrôle d'accès.
- Aucun accès au trousseau iOS, aux tokens ou aux bases de données privées.
- Pas de transfert automatique, collecte des notes saisies localement.
- L'utilisateur sélectionne explicitement un chemin lors de l'export Markdown.
- L'identifiant de l'appareil est masqué dans le modèle affichable ; le bundle ID reste visible.
