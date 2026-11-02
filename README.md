# ZELVORA TV

Lecteur IPTV pour Windows 11 (puis Android et Android TV), construit avec Flutter.
ZELVORA TV ne fournit aucun contenu : chaque utilisateur ajoute ses propres sources légales
(playlist M3U/M3U8 ou compte Xtream Codes).

## Télécharger l'installeur Windows

1. Onglet **Actions** du dépôt sur GitHub, puis la dernière exécution verte « Windows build ».
2. En bas de la page, section **Artifacts** : télécharger `ZELVORA-TV-Windows-installeur`.
3. Décompresser le .zip et lancer `ZELVORA-TV-Setup-x.y.z.exe`.
   Windows peut afficher « Windows a protégé votre ordinateur » (l'installeur n'est pas encore signé) :
   cliquer sur **Informations complémentaires** puis **Exécuter quand même**.

## Avancement

| Étape | Contenu | État |
|---|---|---|
| 1 | Thème, menu latéral, écrans de base, installeur Windows | Fait |
| 2 | Playlists M3U/M3U8 + TV en direct + lecteur vidéo | À venir |
| 3 | Xtream Codes | À venir |
| 4 | Guide TV (EPG) | À venir |
| 5 | Films et séries | À venir |
| 6 | Favoris, historique, recherche | À venir |
| 7 | Finitions | À venir |
| 8 | Android / Android TV | À venir |
| 9 | Comptes, essai, abonnements | À venir |

## Développement

```
flutter pub get
flutter test
flutter run -d windows
```

Structure : `lib/core` (thème, navigation, composants communs), `lib/features/<rubrique>` (un dossier par écran).
