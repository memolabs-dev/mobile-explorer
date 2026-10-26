# Specs de fonctionnalités

## ME-001 — Liste d'appareils
L'application détecte les iPhone disponibles via un appel en lecture seule à `xcrun devicectl` et affiche nom/modèle/état. Si Xcode ou l'appareil manque, un message explicite est affiché. Pas d'affichage d'UDID complet.

## ME-002 — Inventaire d'applications
Après sélection d'un appareil, bouton d'inventaire déclenchant `ideviceinstaller list --xml` (si installé) sur le device. Afficher nom, bundle ID, version. Aucun binaire, fichier interne ou permission élevée lu.

## ME-003 — Observations
Après sélection d'une app, proposer notes générales et n parcours, chacun contenant écran, action, résultat et remarque. Il s'agit de données déclarées par l'utilisateur.

## ME-004 — Export
Export Markdown local via panneau de sélection. Mentionner date, provenance, limites, et degré de preuve « observation manuelle ».

## ME-005 — Transparence
Aucune exploration automatisée annoncée avant existence de la fonctionnalité. Aucun accès appareil en réseau. Ne pas créer de fausse preuve de reverse engineering.
