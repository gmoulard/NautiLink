# Étude : envoi de SMS et de MMS par l'application Android

Étude documentaire pour [TODO-2.1](../TODO.md) ([Q-12](../06-questions-ouvertes.md#q-12), RG-COM-01, RG-SMS-07) et TODO-2.4 ([Q-13](../06-questions-ouvertes.md#q-13), RG-SMS-05, § 5). Rédigée le 24 novembre 2026, sans essai sur téléphone. Elle ne décide rien : la voie à suivre reste à choisir par l'utilisateur.

## 1. Ce que dit Google Play

- Google Play réserve les permissions du groupe SMS (`SEND_SMS`, `READ_SMS`, `RECEIVE_SMS`, `RECEIVE_MMS`, `WRITE_SMS`, `RECEIVE_WAP_PUSH`) aux applications enregistrées comme **application SMS par défaut** (ou Assistant) sur le téléphone, sauf si l'application entre dans un des **cas d'exception** de la page d'aide de la Play Console. [S1] [S2]
- Les exceptions sont **temporaires**, accordées **au cas par cas** après examen d'une **déclaration des autorisations** (Permissions Declaration Form) remplie dans la Play Console. [S1] [S3]
- Le tableau des exceptions contient une ligne « sécurité physique / alertes d'urgence » qui autorise `SEND_SMS` pour les applications envoyant des SMS d'alerte en situation d'urgence. [S1] [S3]
- Une version révisée de la règle est annoncée pour le **27 janvier 2027** ; son contenu exact n'a pas pu être lu. [S4]

**Limite de cette étude** : les pages d'aide Google Play (support.google.com) n'étaient pas accessibles depuis l'environnement de rédaction. Les trois points ci-dessus viennent de la page développeur Android [S2] et d'extraits de recherche des pages [S1] et [S3]. Avant toute décision, relire [S1], [S3] et [S4] en entier, en particulier la ligne « urgence » et la nouvelle version de 2027.

## 2. Conséquences pour NautiLink

| Envoi | Couvert par l'exception « urgence » ? |
|-------|---------------------------------------|
| SMS SOS (RG-SOS-14) | Probablement : c'est exactement le cas visé. À faire accepter par Google. |
| SMS ordinaires (début, positions, notes, photos, fin : RG-SMS-02) | Peu probable : ce n'est pas une alerte d'urgence. Le refus de Google peut porter sur toute l'application. |
| Invitations par SMS | Peu probable, pour la même raison. |
| MMS avec photo (RG-SMS-05) | Peu probable pour une photo ordinaire ; voir § 5. |

## 3. Voies possibles

| Voie | Principe | Pour | Contre |
|------|----------|------|--------|
| A. Exception « urgence » + application SMS préremplie | `SEND_SMS` demandé seulement pour le SOS, déclaré à Google. Les SMS ordinaires ouvrent l'application SMS du téléphone avec le message prérempli (`Intent.ACTION_SENDTO`, adresse `smsto:`, texte dans `sms_body`) [S5] ; l'utilisateur appuie sur Envoyer. | Seule voie Play Store qui garde un SOS automatique. Aucune permission pour les SMS ordinaires. | Accord de Google incertain et révocable. Les SMS ordinaires ne partent plus seuls, ce qui contredit RG-SMS-03 (sans confirmation) et les positions automatiques. |
| B. Application SMS préremplie pour tout | Aucun `SEND_SMS` ; chaque SMS, SOS compris, ouvre l'application SMS préremplie. | Aucune déclaration à Google, aucun risque de refus. | Le SOS demande un geste de plus et ne part pas écran verrouillé ; contredit RG-SMS-03 et l'envoi automatique. |
| C. NautiLink application SMS par défaut | NautiLink remplace l'application de messagerie du téléphone. | Toutes les permissions, MMS compris. | Il faut gérer toute la messagerie (réception, conversations, MMS entrants) ; disproportionné. [S2] |
| D. Distribution hors Play Store | APK installé directement ou autre magasin, avec `SEND_SMS` sans déclaration. | Envoi automatique de tout, comme décrit aujourd'hui. | Installation plus difficile (sources inconnues), mises à jour à gérer, public restreint. |

Les voies peuvent se combiner (par exemple A sur Play Store et D pour un public averti).

## 4. Ce que permet l'API Android

- Envoi : `SmsManager`, obtenu par `Context.getSystemService(SmsManager.class)` puis `createForSubscriptionId(subId)` ; `getDefault()` est obsolète depuis Android 12 (API 31). Avec un identifiant de SIM explicite, aucune boîte de choix de SIM n'apparaît. [S6]
- Texte long : `divideMessage()` découpe le texte, `sendMultipartTextMessage()` l'envoie en plusieurs parties. [S6]
- Résultat : le `PendingIntent` d'envoi reçoit un code (`RESULT_ERROR_NONE`, `RESULT_ERROR_GENERIC_FAILURE`, `RESULT_ERROR_RADIO_OFF` mode avion, `RESULT_ERROR_NO_SERVICE` hors réseau, `RESULT_ERROR_LIMIT_EXCEEDED` file d'envoi pleine, `RESULT_SMS_SEND_FAILED_AFTER_MAX_RETRY` tentatives du système épuisées…). Utile pour [D-50](../07-decisions.md#d-50). [S6]
- Quand l'application n'est pas l'application SMS par défaut, le système recopie les SMS envoyés dans la messagerie du téléphone : l'utilisateur les retrouve dans ses conversations. [S6]
- Aucun envoi possible sans la fonction `FEATURE_TELEPHONY_MESSAGING` (tablettes sans SIM). [S6]
- Android limite le nombre de SMS envoyés par une application dans une période donnée et peut demander une confirmation au-delà : la valeur exacte dépend du téléphone, à mesurer lors de l'essai (positions automatiques fréquentes vers plusieurs suiveurs).

## 5. MMS (TODO-2.4)

- **Envoi direct** : `SmsManager.sendMultimediaMessage()` lit un message MMS déjà encodé (PDU) depuis un `contentUri` ; l'application doit construire ce PDU elle-même (Android ne fournit pas d'outil public pour cela). Le résultat arrive par `Activity.RESULT_OK` ou un code `MMS_ERROR_…` : `MMS_ERROR_NO_DATA_NETWORK`, `MMS_ERROR_DATA_DISABLED` (données mobiles coupées), `MMS_ERROR_MMS_DISABLED_BY_CARRIER`, `MMS_ERROR_INVALID_APN`, `MMS_ERROR_HTTP_FAILURE`, `MMS_ERROR_RETRY`… [S6] Le MMS passe par les **données mobiles**, pas seulement par le réseau GSM : en mer, il échoue plus souvent qu'un SMS.
- **Envoi prérempli** : `Intent.ACTION_SEND` avec la photo dans `EXTRA_STREAM` ouvre l'application de messagerie, qui fabrique et envoie le MMS ; aucune permission, mais un geste de l'utilisateur. [S5]
- **Taille maximale** : propre à l'opérateur, lue sur le téléphone par `SmsManager.getCarrierConfigValues()`, clé `MMS_CONFIG_MAX_MESSAGE_SIZE` (octets) ; d'autres clés donnent la largeur et la hauteur maximales d'image (`CarrierConfigManager.KEY_MMS_MAX_IMAGE_WIDTH_INT`, `KEY_MMS_MAX_IMAGE_HEIGHT_INT`). [S6] [S7] Repères non officiels trouvés : 300 Ko ou 600 Ko selon l'opérateur, pour le message entier (photo + texte) [S8] [S9]. Aucun chiffre officiel d'Orange, SFR, Bouygues Telecom ou Free n'a été trouvé : à mesurer lors de l'essai.
- **Conséquence** : une photo de téléphone (plusieurs Mo) doit être réduite et recompressée sous la limite lue sur le téléphone avant l'envoi.
- **Repli possible si le MMS échoue** (non décidé) : SMS contenant le lien vers la photo hébergée, déjà prévu par RG-SMS-05. Le comportement exact (repli automatique, nouvelle tentative, affichage) relève de [D-50](../07-decisions.md#d-50) et [Q-13](../06-questions-ouvertes.md#q-13).
- **Reste à faire pour TODO-2.4** : essai d'un MMS avec photo envoyé et reçu chez les quatre opérateurs français, avec la taille lue sur chaque téléphone ; choix de la taille maximale et du comportement en cas d'échec par l'utilisateur. Dépend du choix de la voie (§ 3) : sans `SEND_SMS`, seul l'envoi prérempli reste possible.

## 6. Ce qui reste à faire pour TODO-2.1

1. Relire en entier [S1], [S3], [S4] (accès réseau à support.google.com nécessaire).
2. Choix de la voie par l'utilisateur (§ 3), puis écriture dans les règles métier (RG-COM-01, RG-SMS-03, RG-SMS-07) et tracé en `D-nn`.
3. Si la voie A est choisie : préparer la déclaration des autorisations (vidéo du SOS, justification) et prévoir le cas d'un refus.

## Sources

- [S1] Google Play Console, « Use of SMS or Call Log permission groups » : https://support.google.com/googleplay/android-developer/answer/10208820
- [S2] Android Developers, « Default handlers » : https://developer.android.com/guide/topics/permissions/default-handlers
- [S3] Google Play Console, « Permissions declaration form » et tableau des exceptions : https://support.google.com/googleplay/android-developer/answer/9047303
- [S4] Google Play Console, aperçu de la règle révisée (effet au 27 janvier 2027) : https://support.google.com/googleplay/android-developer/answer/13986130
- [S5] Android Developers, « Common intents », section messagerie : https://developer.android.com/guide/components/intents-common
- [S6] Android Developers, référence `SmsManager` : https://developer.android.com/reference/android/telephony/SmsManager
- [S7] Android Developers, référence `CarrierConfigManager` : https://developer.android.com/reference/android/telephony/CarrierConfigManager
- [S8] Selectra, « Fin des MMS : ce qui les remplace » (taille 300 ou 600 Ko) : https://selectra.info/telecom/actualites/marche/fin-des-mms-ce-qui-les-remplace
- [S9] Communauté Orange, « Taille limitée MMS » (réponse d'utilisateur, non officielle) : https://communaute.orange.fr/t5/offres-mobile-Orange-et-options/Taille-limit%C3%A9-MMS/td-p/1278202
