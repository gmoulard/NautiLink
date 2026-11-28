Fais l'« Atelier du look » de l'Application web de NautiLink (dépôt gmoulard/NautiLink, branche main), sur le modèle de celui de l'application Android : https://claude.ai/artifact/Wt8vAqLAAG4j1kWaCNamd2 (lis-le avec l'outil Artifact, action read, et reprends sa page, son design et sa mécanique).

But : une page où je vois chaque écran actuel de l'Application web et où je note, avec mes mots, ce que je veux changer, puis « Copier ma demande » pour te coller le texte.

1. L'Application web est servie par le serveur Go (server/, pages dans server/web/, styles dans server/web/static/style.css). Lance-la en local avec des données d'essai : PostgreSQL 16 sur une base jetable (NAUTILINK_BASE_TEST, voir server/README.md), un compte, deux bateaux, des amis, une navigation en cours et des navigations terminées, une alerte SOS. Inspire-toi des essais Go qui remplissent la base (server/*_test.go). Supprime la base à la fin.
2. Capture chaque écran avec Playwright (Chromium préinstallé, require('playwright')), en deux largeurs : ordinateur (1280 px) et téléphone (390 px, deviceScaleFactor 2), thème clair, plus quelques écrans en thème sombre. Écrans visés, ceux qui existent :
   - connexion, création du compte, mot de passe oublié ;
   - Log de nav avec ses filtres « Toutes », « Comme navigateur », « Mes amis en mer » ;
   - page d'une navigation en cours : carte, « Météo marine », « Terminer la navigation » et sa fenêtre de confirmation ;
   - page d'une navigation terminée : carte, journal de bord, exports PDF, CSV et YAML ;
   - Bateaux, Contacts, fiche d'un ami, Paramètres, Quota et abonnement, Alertes SOS, Corbeille, Mon compte, Assistance ;
   - Administration (tableau de bord, réglages Météo-France, annonces) ;
   - avertissement bêta (lien « Version bêta » du pied de page).
   Vérifie chaque capture à l'œil et écarte les doublons et les écrans vides. Si les cartes restent vides faute de réseau, dis-le sur la page.
3. Page de l'atelier : intro (version du serveur, server/VERSION, date des captures), section « Le look visé » avec docs/etudes/Nautilinkimages261126.png et docs/etudes/IMG_20230508_112008.jpg. Réglages pour toute l'Application web, tous sur « Garder » par défaut : couleurs, taille du texte, formes, ambiance, espacement, menu (boutons bleu clair / bleu foncé), largeur de la page sur ordinateur, bouton SOS. Puis une carte par écran avec ses deux captures (ordinateur et téléphone, touchez pour agrandir) et une zone de texte. Brouillon dans localStorage avec une clé à elle, et texte copié qui commence par « Modifier le look de l'Application web NautiLink <version> : ».
   Vocabulaire du glossaire : *ami*, jamais suiveur ni contact SOS ; libellés entre guillemets français tels qu'affichés.
4. Vérifie la page dans Chromium à 1280 et 390 px : pas d'erreur JavaScript, pas de défilement horizontal, la demande se compose.
5. Publie-la comme artifact privé et donne-moi le lien. Ne committe rien dans le dépôt.

Fais les captures et la page dans un sous-agent, puis publie depuis la session principale.
