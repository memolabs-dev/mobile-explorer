# Brouillons manuels — données locales

Une fiche manuelle peut être enregistrée et réouverte explicitement depuis Mobile Explorer.

- **Sauvegarder :** choisir une fiche manuelle, saisir des parcours, puis utiliser **Brouillon** et sélectionner un emplacement sur le Mac.
- **Reprendre :** cliquer sur **Reprendre un brouillon** dans la barre latérale et choisir un fichier JSON créé par Mobile Explorer. Cette opération **remplace les observations affichées**.
- **Confidentialité :** aucun envoi réseau et aucune sauvegarde automatique. Le JSON est **en clair**, avec les notes saisies par l'utilisateur : choisir un dossier privé, sans informations personnelles ni secrets. Le fichier temporaire est créé avec des permissions POSIX `0600` **avant** l'écriture des notes, puis remplacé atomiquement ; le brouillon final reste non chiffré. Un ancien fichier existant n'est pas écrasé si la finalisation échoue.
- **Limites :** brouillon v1, 1 Mio maximum, jusqu'à 100 parcours, 4 000 caractères par champ de parcours. Seules les fiches manuelles sont prises en charge ; aucun UDID ni bundle ID n'est enregistré.
- L'export **JSONL v0.1** reste distinct : il représente des observations non vérifiées, pas un brouillon éditable. Les brouillons JSON ne sont pas publiés dans Rebuild Radar.

À valider ensuite : recette utilisateur de sauvegarde, fermeture/réouverture de l'application, et restauration des champs via l'interface macOS.

## Tests de confidentialité et de récupération

Les tests couvrent les permissions dès l'écriture, le remplacement d'un ancien fichier trop permissif, une lecture bornée à 1 Mio et le nettoyage des fichiers temporaires si la finalisation échoue. Les permissions POSIX protègent contre les autres comptes locaux ; elles ne constituent pas un chiffrement et ne couvrent pas automatiquement les sauvegardes cloud d'un dossier synchronisé.

## Confidentialité des exports Markdown / JSONL

Les exports réutilisent le même mécanisme que les brouillons : création d'un fichier privé POSIX 0600 **avant** écriture, remplacement atomique et nettoyage des temporaires en cas d'échec, dans la limite de 8 Mio par export. Les fichiers restent **non chiffrés** et ne sont jamais envoyés automatiquement. Les anciennes copies déjà exportées ne sont pas modifiées.
