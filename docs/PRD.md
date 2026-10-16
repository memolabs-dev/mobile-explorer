# PRD — Mobile Explorer

**Version :** 0.1 · **Date :** 2026-10-16 · **Statut :** prototype macOS non validé sur Mac/iPhone · **Owner :** Memo Labs

## 1. Vision

Créer un explorateur local pour les applications iOS **sur appareils possédés ou explicitement autorisés** : inventaire, documentation des écrans et parcours, export d'une spécification traçable. Ce n'est pas un outil d'extraction automatique du code App Store.

## 2. Utilisateurs

- Développeur qui audite sa propre application iOS.
- Équipe QA qui documente les workflows d'une application qu'elle est autorisée à tester.
- Équipe migration qui compare une application témoin avec une nouvelle implémentation.

## 3. User stories

- ME-001 : je branche un iPhone, je vois le nom du modèle et le statut de connexion sans exposer mon UDID complet.
- ME-002 : je vois, quand le service iOS l'autorise, une liste des applications installées et leurs identifiants de bundle.
- ME-003 : je sélectionne une application que je suis autorisé à analyser et je saisis mes observations d'écran.
- ME-004 : j'exporte en Markdown une fiche structurée contenant l'identité de l'app, les parcours observés et les limites.

## 4. P0 livré dans les sources

- Application SwiftUI pour macOS 14+.
- Recherche de périphériques via `xcrun devicectl` en lecture seule.
- Énumération via `ideviceinstaller list --xml` lorsque disponible.
- Formulaire manuel de documentation et export Markdown local.
- Indicateur d'état explicite et pas de transfert réseau.
- Tests unitaires sur les parseurs et l'export.

## 5. Ce que P0 ne fait pas

- Pas d'extraction de binaires App Store, pas de déchiffrement, pas de jailbreak.
- Pas d'exploration automatique des écrans : intégration Appium/XCUITest future, seulement avec permission, simulateur/app de test, compte et signature compatibles.
- Pas de lecture de secrets, cookies, comptes ou données privées.
- Pas de génération d'un clone fonctionnel à partir d'observations partielles.
- Pas de prise en charge Windows/Linux pour la GUI SwiftUI.

## 6. Roadmap

- **P1 :** détection fiable et automatisation de QA pour applications de test signées, collecte de vues d'accessibilité avec consentement, caviardage des données sensibles, capture locale contrôlée.
- **P2 :** graphe d'états UI, scénarios de régression, export JSON avec schéma et preuve du contexte, analyse statique facultative sur binaires non chiffrés autorisés.
- **P3 :** connecteur de contributions vérifiées vers Rebuild Radar ; version web consultative uniquement, sans accès appareil depuis le navigateur.

## 7. Critères de succès

- Sur un Mac équipé des outils Xcode, afficher les iPhone appairés.
- Si `ideviceinstaller` ne peut pas lister les apps, afficher une erreur claire, jamais des données factices.
- Exporter un Markdown local sans transmettre d'identifiant ni de capture.
- Tests de parsing et de format d'export verts sur macOS ; essais réels avec une application de test autorisée.

## 8. Limites et garde-fous

L'utilisateur doit disposer de droits sur l'appareil et sur l'application évaluée. Les métadonnées d'inventaire restent sur le Mac. Les captures futures devront protéger les informations personnelles, documents et jetons. Le projet n'essaie pas de contourner les protections de l'App Store et ne demande pas de jailbreak.
