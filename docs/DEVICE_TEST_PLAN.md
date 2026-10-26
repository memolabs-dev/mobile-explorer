# Recette Mobile Explorer — appareils autorisés

## Préparation

- Mac avec Xcode (vérifier `xcodebuild -version`) et projet compilable : `swift build && swift test`.
- Appareil iOS appartenant au testeur, déverrouillé, jumelé et approuvant « Faire confiance ».
- Application de démonstration avec permission explicite. Ne pas utiliser les comptes, messages ou données privées comme jeu de test.
- `ideviceinstaller` est facultatif : le premier essai utilise CoreDevice de Xcode.

## Parcours minimal

1. Lancer Mobile Explorer sans iPhone : la liste vide doit être explicite, sans données fictives.
2. Connecter l'appareil autorisé : vérifier l'affichage du modèle, de l'état et **l'absence d'UDID complet** dans l'interface.
3. Cliquer sur « Lire les applications ». CoreDevice doit tenter l'inventaire. Si la lecture échoue, afficher la cause d'indisponibilité et la possibilité d'utiliser le repli facultatif.
4. Choisir uniquement une application de démonstration autorisée. Saisir le nom de l'écran, une action et son résultat observé.
5. Exporter un Markdown local. Vérifier qu'il indique bien « observation manuelle », sans mention de compatibilité complète et sans données personnelles.
6. Débrancher l'appareil et vérifier la gestion d'un nouveau scan et des états d'erreur.

## Cas négatifs obligatoires

- iPhone verrouillé, absent, non jumelé ou sans services CoreDevice utilisables.
- `ideviceinstaller` absent et CoreDevice refusant l'accès : message explicite, aucun catalogue inventé.
- Réponse CoreDevice au schéma inconnu : erreur visible, pas de crash ni de faux résultat.
- Aucun export automatique ni requête réseau lors de la saisie.

## Données de test et publication

N'enregistrer dans l'issue que : version macOS/Xcode, version iOS **sans identifiant d'appareil**, étapes, résultat obtenu, types d'erreurs avec identifiants masqués, statut réussi/échoué. Les notes contenant des secrets doivent être nettoyées avant tout partage.

Cette recette est à exécuter manuellement. Les tests d'intégration USB et d'applications tierces autorisées ne sont **pas** couverts par la CI Swift.
