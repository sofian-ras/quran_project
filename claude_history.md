en theme blanc et papier en mode il faut que mes logos de la barres en haut du telephone soient noir, parce que en blanc on les voit pas
Il faut appeler SystemChrome.setSystemUIOverlayStyle selon le thème. Je cherche où c'est actuellement géré :

Grep "setSystemUIOverlayStyle|SystemUiOverlayStyle|statusBarIcon" (in c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart)
1 line of output
Rien de défini. La solution propre est d'enroupper avec AnnotatedRegion<SystemUiOverlayStyle> — il règle automatiquement les icônes de la barre selon le thème.

Read c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart (lines 61-75)
Edit c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart
Added 2 lines
Read c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart (lines 169-183)
Edit c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart
Added 1 line
Maintenant pareil pour TranslatedSurahScreen :

Read c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart (lines 3036-3047)
Read c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart (lines 2-81)
Grep "class TranslatedSurahScreen" (in c:\Users\rasmi\Projects\quran_project\lib\ui\translated_quran_screen.dart)
5 lines of output
You've hit your limit · resets 12am (Europe/Paris)