# Diagnostic CoreDevice — 26 octobre 2026

**Résultat observé sur macOS / Xcode 27.1 (sans identifiants d'appareil)** :

- Un iPhone physique est visible et **jumelé** à l'ordinateur ; le **mode développeur est activé**.
- Sa connexion rapportait `transportType: localNetwork`, `tunnelState: disconnected` et `ddiServicesAvailable: false`.
- `xcrun devicectl device info apps --device ... --json-output -` a échoué avec **CoreDeviceError 4016**, le dispositif ne satisfaisant pas les conditions d'accès demandées.
- Aucun inventaire applicatif réel n'a pu être validé ; les tests unitaires de parsing JSON n'établissent pas la lecture d'un iPhone connecté.

## Parcours de reprise (avec accès physique légitime)

1. Déverrouiller l'iPhone, connecter un câble USB fonctionnel, autoriser « Faire confiance à cet ordinateur ».
2. Vérifier dans Xcode → Window → Devices and Simulators que l'appareil est utilisable, et confirmer le mode développeur.
3. Relancer l'inventaire depuis Mobile Explorer ; relever **uniquement** la catégorie d'erreur, sans UDID, noms d'applications privées ou données personnelles.
4. Vérifier un parcours dans une **application de démonstration autorisée**, puis exporter un Markdown sans donnée confidentielle.
5. Ne marquer « validé sur iPhone » qu'après un inventaire réel et une observation reproduite.

Ce diagnostic ne prouve pas que `ideviceinstaller` fonctionnera : c'est uniquement une alternative facultative, soumise aux droits et versions iOS. Aucune modification de configuration système ou de l'iPhone n'a été effectuée pendant le diagnostic.

## Correction de l'interprétation

\`tunnelState: disconnected\` peut décrire un tunnel inactif ouvert à la demande, **même lorsque le téléphone est utilisable**. Des implémentations publiques et les échanges Apple montrent qu'il ne faut pas assimiler ce champ seul à une panne. L'erreur 4016 est le constat pertinent de l'échec de la commande ; sa cause précise n'est pas établie sans diagnostic supplémentaire dans Xcode Device Hub, avec l'appareil physiquement accessible. Ne pas redémarrer les services système et ne pas réinitialiser le jumelage sans examen.
