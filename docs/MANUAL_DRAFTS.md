# Brouillons manuels — données locales

Une fiche manuelle peut être enregistrée et réouverte explicitement depuis Mobile Explorer.

- **Sauvegarder :** choisir une fiche manuelle, saisir des parcours, puis utiliser **Brouillon** et sélectionner un emplacement sur le Mac.
- **Reprendre :** cliquer sur **Reprendre un brouillon** dans la barre latérale et choisir un fichier JSON créé par Mobile Explorer. Cette opération **remplace les observations affichées**.
- **Confidentialité :** aucun envoi réseau et aucune sauvegarde automatique. Le JSON est **en clair**, avec les notes saisies par l'utilisateur : choisir un dossier privé, sans informations personnelles ni secrets. Le fichier enregistré reçoit des permissions POSIX `0600` lorsque le système le permet.
- **Limites :** brouillon v1, 1 Mio maximum, jusqu'à 100 parcours, 4 000 caractères par champ de parcours. Seules les fiches manuelles sont prises en charge ; aucun UDID ni bundle ID n'est enregistré.
- L'export **JSONL v0.1** reste distinct : il représente des observations non vérifiées, pas un brouillon éditable. Les brouillons JSON ne sont pas publiés dans Rebuild Radar.

À valider ensuite : recette utilisateur de sauvegarde, fermeture/réouverture de l'application, et restauration des champs via l'interface macOS.
