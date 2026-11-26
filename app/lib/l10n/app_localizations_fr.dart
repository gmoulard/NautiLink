// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'NautiLink';

  @override
  String get demoBanner =>
      'Version bêta · Démonstration : rien n\'est réellement envoyé';

  @override
  String get sponsorText => 'Sponsorisée par la SRT';

  @override
  String get sponsorLogoLabel => 'Guidon de la SRT';

  @override
  String get rightsReserved => 'Tous droits réservés';

  @override
  String buildInfo(String version, String build, String commit) {
    return 'V$version · build $build · commit $commit';
  }

  @override
  String get buildLocal => 'version locale';

  @override
  String buildCommit(String commit) {
    return 'Commit $commit';
  }

  @override
  String get footerSiteLink => 'Site de NautiLink';

  @override
  String get sosButton => 'Envoyer un SOS';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get ok => 'OK';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get save => 'Enregistrer';

  @override
  String get back => 'Retour';

  @override
  String get noVoyageInProgress => 'Aucune navigation en cours.';

  @override
  String get logbook => 'Journal de bord';

  @override
  String distanceNm(String distance) {
    return '$distance milles';
  }

  @override
  String get chooseTitle => 'NautiLink · démonstration';

  @override
  String get chooseQuestion => 'Que voulez-vous essayer ?';

  @override
  String get chooseNavigatorTitle => 'Le navigateur à bord';

  @override
  String get chooseNavigatorText =>
      'L\'application mobile : démarrer une navigation, envoyer sa position, noter, déclencher un SOS.';

  @override
  String get chooseFollowerTitle => 'Le suiveur, sur la plateforme Web';

  @override
  String get chooseFollowerText =>
      'Le tableau de bord : navigations en cours et passées, carte du tracé, journal de bord.';

  @override
  String get warningTitle => 'Avertissement';

  @override
  String get warningHeading => 'Version bêta et responsabilité';

  @override
  String get warningSection1Title => '1. Version bêta';

  @override
  String get warningSection1Body =>
      'NautiLink est actuellement proposé en version bêta, c\'est-à-dire en phase de test. Ses fonctions (suivi de position, envoi de SMS et d\'e-mails, alertes SOS, journal de bord) peuvent présenter des erreurs, des retards ou des interruptions, liés notamment à la couverture du réseau mobile, à l\'accès à Internet, à la réception GPS, à l\'état ou aux réglages du téléphone. La continuité et l\'exactitude du service ne sont pas garanties pendant cette phase.';

  @override
  String get warningSection2Title =>
      '2. NautiLink n\'est pas un équipement de sécurité';

  @override
  String get warningSection2Body =>
      'NautiLink n\'est pas un équipement de sécurité au sens de la réglementation maritime. Il ne remplace ni le matériel d\'armement et de sécurité obligatoire (radio VHF, moyens de signalisation, balise de détresse, etc.), ni les procédures officielles d\'alerte. En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF, le 196 ou le 112. Une alerte transmise par NautiLink, ou son absence de transmission, ne peut pas être considérée comme une alerte des secours.';

  @override
  String get warningSection3Title => '3. Responsabilité du chef de bord';

  @override
  String get warningSection3Body =>
      'Le chef de bord reste seul responsable de la conduite du navire, de la sécurité des personnes embarquées, de la préparation de la sortie et du respect de la réglementation en vigueur.';

  @override
  String get warningSection4Title => '4. Limitation de responsabilité';

  @override
  String get warningSection4Body =>
      'Dans toute la mesure permise par la loi, l\'éditeur de NautiLink ne saurait être tenu responsable des dommages indirects résultant d\'un dysfonctionnement, d\'une interruption ou d\'une indisponibilité du service, ni d\'une utilisation de l\'application non conforme à sa destination ou au présent avertissement.\n\nCette limitation ne s\'applique pas aux dommages corporels, ni en cas de faute lourde ou intentionnelle de l\'éditeur. Elle ne prive pas l\'utilisateur ayant la qualité de consommateur des droits que lui reconnaît la loi, notamment le Code de la consommation, auquel il ne peut être dérogé.';

  @override
  String get warningAccept => 'J\'ai lu et j\'accepte cet avertissement';

  @override
  String get menuContacts => 'Contacts';

  @override
  String get menuSettings => 'Paramètres';

  @override
  String get menuQuota => 'Quota et abonnement';

  @override
  String get menuDashboard => 'Tableau de bord (Web)';

  @override
  String get homeFreeVersion => 'Version gratuite';

  @override
  String get homeSubscriberVersion => 'Version abonné';

  @override
  String homeFreeLeft(String duration) {
    return '$duration de navigation gratuite disponibles sur les 7 derniers jours';
  }

  @override
  String get startVoyage => 'Démarrer navigation';

  @override
  String get resumeVoyage => 'Reprendre la dernière navigation';

  @override
  String get savedVoyages => 'Navigations enregistrées';

  @override
  String get homeDistressHint =>
      'En cas de détresse, alertez d\'abord par le canal 16 de la VHF ou le 196.';

  @override
  String get homeSecurityMemo => 'Mémo sécurité en mer';

  @override
  String get firstVoyageTitle => 'Avant votre première navigation';

  @override
  String get firstVoyageText =>
      'NautiLink est en version bêta et n\'est pas un équipement de sécurité. En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF ou le 196.';

  @override
  String get understood => 'J\'ai compris';

  @override
  String get contactsDefault =>
      'Par défaut, chaque contact est à la fois suiveur et contact SOS.';

  @override
  String get roleFollower => 'Suiveur';

  @override
  String get roleSos => 'Contact SOS';

  @override
  String get phoneRequired => 'Numéro requis';

  @override
  String get defaultFrequency => 'Fréquence par défaut';

  @override
  String get sosAlwaysSent =>
      'Les SMS SOS partent toujours, quels que soient ces réglages.';

  @override
  String get smsEnabled => 'SMS activés';

  @override
  String get quotaHeading =>
      'Navigation gratuite : 24 h sur les 7 derniers jours glissants';

  @override
  String quotaUsed(String duration) {
    return 'Consommé : $duration';
  }

  @override
  String quotaLeft(String duration) {
    return 'Disponible : $duration';
  }

  @override
  String get quotaNextRecovery =>
      'Prochaines minutes récupérables : 3 h 40 min dans 4 jours (navigation du début de semaine).';

  @override
  String get subscriptionTitle => 'Abonnement';

  @override
  String get subscriptionText =>
      'Navigation sans limite : 15 € pour 10 ans, sans renouvellement automatique. Suivre et consulter l\'historique restent gratuits.';

  @override
  String get subscriptionMore => 'En savoir plus sur l\'abonnement';

  @override
  String get menuSosHistory => 'Alertes SOS';

  @override
  String get menuAssistance => 'Assistance';

  @override
  String get contactAdd => 'Ajouter un contact';

  @override
  String get contactName => 'Nom';

  @override
  String get contactPhone => 'Téléphone';

  @override
  String get contactEmail => 'E-mail';

  @override
  String get contactPhoneOrEmail =>
      'Indiquez un numéro de téléphone ou une adresse e-mail.';

  @override
  String get contactSave => 'Enregistrer';

  @override
  String get contactDelete => 'Supprimer le contact';

  @override
  String contactDeleteConfirm(String name) {
    return 'Supprimer $name de vos contacts ? Ses accès à vos navigations sont retirés.';
  }

  @override
  String get contactPending =>
      'Modification gardée sur le téléphone, envoyée au retour de la connexion';

  @override
  String get contactsOffline =>
      'Hors connexion : liste gardée sur le téléphone, utilisable pour le SOS ; vos modifications partiront au retour de la connexion.';

  @override
  String contactRefused(String message) {
    return 'Modification refusée par le serveur : $message';
  }

  @override
  String get followerNeedsVerifiedEmail =>
      'Confirmez votre adresse e-mail pour inviter des suiveurs ; un contact SOS reste possible.';

  @override
  String get scopeTitle => 'Ce que le suiveur voit';

  @override
  String get scopeNavigator =>
      'Toutes mes navigations (présentes et futures, historique compris)';

  @override
  String get scopeVoyage => 'Une seule navigation';

  @override
  String get scopeChooseVoyage => 'Navigation';

  @override
  String get scopeNoVoyage => 'Aucune navigation à partager pour l\'instant.';

  @override
  String get scopeChange => 'Changer le périmètre';

  @override
  String get invitationNone => 'Pas encore invité';

  @override
  String get invitationSent => 'Invitation envoyée, pas encore acceptée';

  @override
  String get invitationAccepted => 'Suiveur : invitation acceptée';

  @override
  String get invitationCancelled => 'Invitation annulée';

  @override
  String get inviteByEmail => 'Inviter par e-mail';

  @override
  String get inviteByPhone => 'Inviter par téléphone';

  @override
  String invitationEmailSent(String email) {
    return 'Invitation envoyée par e-mail à $email, avec copie à votre adresse.';
  }

  @override
  String get invitationLink => 'Lien d\'invitation à transmettre';

  @override
  String get invitationLinkHint =>
      'Ce lien mène à la connexion ou à la création d\'un compte NautiLink ; ce n\'est jamais un accès public.';

  @override
  String get invitationSendSms => 'Envoyer par SMS';

  @override
  String get invitationCopyLink => 'Copier le lien';

  @override
  String get linkCopied => 'Lien copié.';

  @override
  String get invitationCancel => 'Annuler l\'invitation';

  @override
  String get followerRemove => 'Retirer le suiveur de toutes mes navigations';

  @override
  String followerRemoveConfirm(String name) {
    return 'Retirer $name de toutes vos navigations, présentes et futures ? L\'effet est immédiat.';
  }

  @override
  String get onlineOnly =>
      'Demande Internet : réessayez au retour de la connexion.';

  @override
  String get smsInviteOffline =>
      'Invitation par SMS impossible hors connexion : le lien vient du serveur.';

  @override
  String get iphoneNoSmsInvite =>
      'Sur iPhone, aucun SMS n\'est envoyé : transmettez vous-même le lien.';

  @override
  String get photoAsMms => 'Joindre la photo en MMS';

  @override
  String get settingsSynced =>
      'Réglages synchronisés avec le Web ; hors connexion, la modification part au retour.';

  @override
  String get settingsIphone =>
      'Sur iPhone, aucun SMS n\'est envoyé : ces réglages servent aux navigations menées depuis un téléphone Android.';

  @override
  String get sosHistoryEmpty => 'Aucune alerte SOS.';

  @override
  String sosHistoryOffline(String date) {
    return 'Hors connexion : alertes de ce téléphone et dernier historique reçu le $date.';
  }

  @override
  String sosAlertTitle(String date) {
    return 'SOS · $date';
  }

  @override
  String get sosAlertPending =>
      'Alerte encore sur le téléphone, envoyée au retour de la connexion';

  @override
  String get sosPositionCurrent => 'Position actuelle';

  @override
  String get sosPositionLast => 'Dernière position connue';

  @override
  String get sosPositionNone => 'Aucune position';

  @override
  String get sosSmsPending => 'en attente';

  @override
  String get sosHistorySmsAccepted => 'accepté pour envoi';

  @override
  String get sosSmsDelivered => 'livraison confirmée';

  @override
  String get sosSmsFailed => 'échec';

  @override
  String sosEmailsSent(String count) {
    return 'E-mail envoyé à $count adresse(s)';
  }

  @override
  String sosHistoryProblem(String text) {
    return 'Problème : $text';
  }

  @override
  String get assistanceWrite => 'Écrire à l\'équipe NautiLink';

  @override
  String get assistanceWriteHint =>
      'Page de suivi du projet NautiLink sur GitHub';

  @override
  String get assistanceOffline =>
      'Contact de l\'équipe impossible sans Internet.';

  @override
  String get assistanceWarning => 'Avertissement bêta';

  @override
  String get assistanceMemoHint => 'Canal 16 de la VHF, 196';

  @override
  String get subscribe => 'Souscrire l\'abonnement';

  @override
  String get subscribeNotYet =>
      'L\'achat de l\'abonnement par Google Play ou par l\'App Store n\'est pas encore ouvert dans l\'application.';

  @override
  String get subscribeOffline => 'Souscription impossible sans Internet.';

  @override
  String get boat => 'Bateau';

  @override
  String get destinationOptional => 'Destination (facultative)';

  @override
  String get destinationHint => 'Adresse ou lieu';

  @override
  String get personsOnBoard => 'Personnes à bord';

  @override
  String get onePersonLess => 'Une personne de moins';

  @override
  String get onePersonMore => 'Une personne de plus';

  @override
  String get autoFrequency => 'Fréquence d\'envoi automatique';

  @override
  String get alertedPersons => 'Personnes alertées';

  @override
  String get alertedRoleFollower => 'suiveur';

  @override
  String get alertedRoleSos => 'contact SOS';

  @override
  String get addPerson => 'Ajouter une personne';

  @override
  String get voyageSettings => 'Paramètres de cette navigation';

  @override
  String get noSosChecked =>
      'Aucun contact SOS coché : personne ne recevra vos SMS SOS.';

  @override
  String get sendStart => 'Envoi message – Début de navigation';

  @override
  String get addPersonText =>
      'La personne rejoint vos contacts, suiveur et contact SOS par défaut, et sera alertée pendant cette navigation.';

  @override
  String get name => 'Nom';

  @override
  String get phone => 'Téléphone';

  @override
  String get email => 'E-mail';

  @override
  String get phoneNeededForSos =>
      'Un numéro de téléphone est nécessaire pour être contact SOS.';

  @override
  String get add => 'Ajouter';

  @override
  String get smsPrefilled => 'SMS prérempli pour vos suiveurs';

  @override
  String get smsDisabled => 'SMS désactivés';

  @override
  String get serverSent => 'Serveur : envoyé';

  @override
  String get nothingReallySent =>
      '(démonstration : rien n\'est réellement envoyé)';

  @override
  String get voyageEnded => 'Navigation terminée ?';

  @override
  String get stationaryText =>
      'Vous ne vous êtes pas éloigné de plus de 20 mètres depuis 2 heures.';

  @override
  String get endVoyage => 'Terminer la navigation';

  @override
  String get endVoyageQuestion => 'Terminer la navigation ?';

  @override
  String get end => 'Terminer';

  @override
  String get validateSend => 'Valider l\'envoi';

  @override
  String get demoMenu => 'Démonstration';

  @override
  String get demoStationary => 'Démo : simuler 2 h sans bouger';

  @override
  String get sinceStart => 'Depuis le début';

  @override
  String get sinceLastSend => 'Depuis le dernier envoi';

  @override
  String get sendPosition => 'Envoyer information position';

  @override
  String get positionSent => 'Position envoyée';

  @override
  String get noteButton => 'NOTE';

  @override
  String get noteTitle => 'Note';

  @override
  String get noteHint => 'Votre note';

  @override
  String get noteSent => 'Note envoyée';

  @override
  String get photoButton => 'Photo';

  @override
  String get photoSent => 'Photo envoyée';

  @override
  String get voiceButton => 'Vocal';

  @override
  String get voiceSent => 'Note vocale envoyée';

  @override
  String get recording => 'Enregistrement en cours';

  @override
  String get recordingHint =>
      '1 minute au plus. Votre voix est envoyée telle quelle, sans transcription.';

  @override
  String get stopAndSend => 'Arrêter et envoyer';

  @override
  String get photo => 'Photo';

  @override
  String samplePhoto(String time) {
    return '$time · photo d\'exemple';
  }

  @override
  String get listenVoice => 'Écoute de la note vocale';

  @override
  String get recordingDefault => 'Enregistrement';

  @override
  String noSoundRecorded(String recording) {
    return '$recording\nDémonstration : aucun son n\'est enregistré.';
  }

  @override
  String get sosQuestion => 'Envoyer un SOS ?';

  @override
  String get sosConfirmText =>
      'Vos contacts SOS recevront votre position et la fiche du bateau. Alertez aussi les secours : canal 16 de la VHF ou 196.';

  @override
  String get sosProblem => 'Problème rencontré (facultatif)';

  @override
  String get sosProblemHint => 'Voie d\'eau, avarie moteur, blessé…';

  @override
  String get sosConfirm => 'Confirmer le SOS';

  @override
  String get sosAlert => 'Alerte SOS';

  @override
  String get sosNoSmsSent =>
      'Démonstration : aucun SMS n\'est réellement parti.';

  @override
  String sosSmsAccepted(String phone) {
    return 'SMS SOS accepté pour envoi · $phone';
  }

  @override
  String get sosCopyNavigator => 'Copie au navigateur';

  @override
  String get sosCopyNavigatorDetail =>
      'SMS et e-mail en copie (RG-SMS-08, RG-NOT-03)';

  @override
  String get sosServer => 'Serveur';

  @override
  String get sosServerDetail => 'Alerte reçue · e-mail aux suiveurs';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get filterAll => 'Toutes';

  @override
  String get filterNavigator => 'Comme navigateur';

  @override
  String get filterFollower => 'Comme suiveur';

  @override
  String get inProgress => 'En cours';

  @override
  String get history => 'Historique';

  @override
  String get live => 'En direct';

  @override
  String voyageCardFollowed(String navigator) {
    return ' · suivie ($navigator)';
  }

  @override
  String get infoDeparture => 'Départ';

  @override
  String get infoDeparturePlace => 'Lieu de départ';

  @override
  String get infoWeatherStart => 'Météo au départ';

  @override
  String get infoArrival => 'Arrivée';

  @override
  String get infoArrivalPlace => 'Lieu d\'arrivée';

  @override
  String get infoWeatherEnd => 'Météo à l\'arrivée';

  @override
  String get infoDestination => 'Destination';

  @override
  String get infoDuration => 'Durée';

  @override
  String get infoDistance => 'Distance';

  @override
  String get infoNavigator => 'Navigateur';

  @override
  String get rename => 'Renommer';

  @override
  String get renameVoyage => 'Renommer la navigation';

  @override
  String get exportPdf => 'Exporter en PDF';

  @override
  String get exportPdfSoon => 'Export PDF : disponible dans la version réelle.';

  @override
  String get me => 'Moi';

  @override
  String get eventStart => 'Début de navigation';

  @override
  String get eventAutoPosition => 'Position automatique';

  @override
  String get eventManualPosition => 'Position envoyée';

  @override
  String get eventNote => 'Note';

  @override
  String get eventPhoto => 'Photo';

  @override
  String get eventVoice => 'Note vocale';

  @override
  String get eventSos => 'Alerte SOS';

  @override
  String get eventEnd => 'Fin de navigation';

  @override
  String eventFrequency(String frequency) {
    return 'Fréquence : $frequency';
  }

  @override
  String frequencyMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String frequencyHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String frequencyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(int hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String dateTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String nearPlace(String distance, String place) {
    return 'à $distance milles de $place';
  }

  @override
  String get smsTypeStart => 'Début de navigation';

  @override
  String get smsTypeAutoPosition => 'Positions automatiques';

  @override
  String get smsTypeManualPosition => 'Positions manuelles';

  @override
  String get smsTypeNote => 'Notes écrites';

  @override
  String get smsTypePhoto => 'Photos';

  @override
  String get smsTypeVoice => 'Notes vocales';

  @override
  String get smsTypeEnd => 'Fin de navigation';

  @override
  String sosSmsBoat(
    String name,
    String type,
    String length,
    String registration,
  ) {
    return 'SOS $name, $type, $length, $registration.';
  }

  @override
  String sosSmsPersons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes à bord.',
      one: '1 personne à bord.',
    );
    return '$_temp0';
  }

  @override
  String sosSmsProblem(String problem) {
    return 'Problème : $problem.';
  }

  @override
  String sosSmsPosition(String position, String time) {
    return 'Position $position à $time.';
  }

  @override
  String get betaBanner => 'Version bêta';

  @override
  String offlineSince(String date) {
    return 'Hors connexion · données du $date';
  }

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordMin => '8 caractères au moins';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get createAccountTitle => 'Création du compte';

  @override
  String get createAccountButton => 'Créer mon compte';

  @override
  String get continueGoogle => 'Continuer avec Google';

  @override
  String get continueApple => 'Continuer avec Apple';

  @override
  String get providerUnavailable =>
      'Connexion par Google ou Apple : pas encore disponible.';

  @override
  String get loginOffline => 'Connexion impossible sans Internet.';

  @override
  String get sessionExpired => 'Votre session a expiré : reconnectez-vous.';

  @override
  String get errorGeneric => 'Le serveur n\'a pas pu traiter la demande.';

  @override
  String get fieldRequired => 'Champ obligatoire';

  @override
  String get forgotTitle => 'Mot de passe oublié';

  @override
  String get forgotText =>
      'Indiquez l\'adresse e-mail de votre compte : vous recevrez un lien, valable 1 heure, pour choisir un nouveau mot de passe.';

  @override
  String get forgotSend => 'Recevoir le lien';

  @override
  String get forgotSent =>
      'Si un compte existe pour cette adresse, un e-mail vient de partir. Le lien est valable 1 heure.';

  @override
  String get warningNewVersion =>
      'L\'avertissement a changé : lisez-le et acceptez-le pour continuer.';

  @override
  String emailNotVerified(String email) {
    return 'Confirmez votre adresse e-mail ($email) avec le lien reçu : sans confirmation, vous ne pouvez ni démarrer une navigation ni inviter.';
  }

  @override
  String get resendLink => 'Recevoir un nouveau lien';

  @override
  String get linkSent => 'Lien envoyé.';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get quotaUnknown => 'Quota pas encore reçu du serveur';

  @override
  String quotaAsOf(String date) {
    return 'État du $date';
  }

  @override
  String quotaNextAt(String duration, String date) {
    return 'Prochaines minutes récupérables : $duration le $date.';
  }

  @override
  String voyageInProgress(String name) {
    return 'Navigation en cours : $name';
  }

  @override
  String get notYetAvailable =>
      'Pas encore disponible dans cette version de l\'application.';

  @override
  String savedOffline(String date) {
    return 'Hors connexion : dernière liste reçue le $date';
  }

  @override
  String get noSavedVoyages => 'Aucune navigation enregistrée.';

  @override
  String get pageOffline =>
      'La page de la navigation sera disponible au retour de la connexion.';

  @override
  String get serverQueued =>
      'Serveur : en attente, envoi au retour de la connexion';

  @override
  String get smsNotYet =>
      'SMS : pas encore envoyés par cette version de l\'application';

  @override
  String get voyageStarted => 'Navigation démarrée';

  @override
  String get startRefused => 'Démarrage refusé';

  @override
  String startQuotaExhausted(String date) {
    return 'Quota de navigation gratuite épuisé : la navigation ne peut pas démarrer. Des minutes redeviendront disponibles le $date. Vous pouvez aussi vous abonner.';
  }

  @override
  String get startQuotaExhaustedNoDate =>
      'Quota de navigation gratuite épuisé : la navigation ne peut pas démarrer. Attendez que des minutes redeviennent disponibles, ou abonnez-vous.';

  @override
  String get noBoatYet =>
      'Aucun bateau dans votre compte : créez d\'abord la fiche de votre bateau sur la plateforme Web (« Bateaux »).';

  @override
  String get locationTitle => 'Votre position';

  @override
  String get locationExplain =>
      'NautiLink va demander l\'accès à la position précise du téléphone. Elle sert aux positions automatiques et manuelles de la navigation et au SOS, même sans Internet. Sans elle, la navigation se déroule sans positions.';

  @override
  String get gpsUnavailable => 'GPS non disponible';

  @override
  String get noSosContact =>
      'Vous n\'avez aucun contact SOS : personne ne recevra vos SMS SOS. Ajoutez-en un dans vos contacts sur la plateforme Web.';

  @override
  String get noAlertablePerson => 'Aucun contact suiveur ou contact SOS.';

  @override
  String voyageRefused(String message) {
    return 'Refusé par le serveur : $message';
  }

  @override
  String nextAutoPosition(String time) {
    return 'Prochaine position automatique : $time';
  }

  @override
  String get sendRefused => 'Envoi refusé';

  @override
  String get micRefused =>
      'Accès au micro refusé : la note vocale ne peut pas être enregistrée.';

  @override
  String get recordingHintReal =>
      '1 minute au plus, arrêt automatique. Votre voix est envoyée telle quelle, sans transcription.';

  @override
  String get sosReelNoBoat =>
      'Aucun bateau dans votre compte : NautiLink ne peut pas envoyer l\'alerte. Alertez les secours : canal 16 de la VHF ou 196.';

  @override
  String get sosReelChooseBoat => 'Bateau en détresse';

  @override
  String get sosReelSearching => 'Recherche de la position…';

  @override
  String get sosReelSending => 'Envoi de l\'alerte au serveur…';

  @override
  String get sosReelServerReceived =>
      'Serveur : alerte reçue, e-mails envoyés aux suiveurs et aux contacts SOS';

  @override
  String get sosReelServerQueued =>
      'Serveur : alerte gardée sur le téléphone, envoyée en priorité au retour de la connexion';

  @override
  String get sosReelSmsOpened =>
      'SMS SOS prérempli ouvert dans l\'application SMS : appuyez sur « Envoyer ».';

  @override
  String get sosReelSmsFailed =>
      'L\'application SMS n\'a pas pu s\'ouvrir : aucun SMS SOS n\'est parti.';

  @override
  String get sosReelSmsNoContact =>
      'Aucun contact SOS avec un numéro : pas de SMS SOS.';

  @override
  String sosReelSmsLastKnown(String position, String date) {
    return 'Dernière position connue, pas nécessairement la position actuelle : $position le $date.';
  }

  @override
  String get sosReelSmsNoPosition =>
      'GPS indisponible : aucune position connue.';

  @override
  String get sosReelSailboat => 'voilier';

  @override
  String get sosReelMotorboat => 'bateau à moteur';

  @override
  String get voyageFinished => 'Navigation terminée';

  @override
  String smsHeader(String boat, String kind, String time) {
    return 'NautiLink $boat — $kind à $time.';
  }

  @override
  String get smsKindStart => 'début de navigation';

  @override
  String get smsKindPosition => 'position';

  @override
  String get smsKindNote => 'note';

  @override
  String get smsKindPhoto => 'photo';

  @override
  String get smsKindVoice => 'note vocale';

  @override
  String get smsKindEnd => 'fin de navigation';

  @override
  String smsDestination(String destination) {
    return 'Destination : $destination.';
  }

  @override
  String smsPositionLine(String position, String link) {
    return 'Position $position : $link';
  }

  @override
  String get smsGpsUnavailable => 'GPS NON DISPONIBLE';

  @override
  String smsNoteLine(String text) {
    return 'Note : $text';
  }

  @override
  String smsPhotoLine(String link) {
    return 'Photo : $link';
  }

  @override
  String smsVoiceLine(String link) {
    return 'Note vocale : $link';
  }

  @override
  String smsFollowLine(String link) {
    return 'Suivre la navigation : $link';
  }

  @override
  String sosSmsSecond(
    String name,
    String port,
    String engine,
    String range,
    String fuel,
    String speed,
    String draft,
  ) {
    return 'SOS $name (suite). Port d\'attache : $port. Moteur : $engine. Autonomie : $range. Carburant : $fuel. Vitesse : $speed. Tirant d\'eau : $draft.';
  }

  @override
  String smsResultAuto(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinataires',
      one: '1 destinataire',
    );
    return 'SMS : envoyé automatiquement à $_temp0';
  }

  @override
  String get smsResultPrefilled =>
      'SMS : prérempli dans l\'application SMS, appuyez sur « Envoyer »';

  @override
  String get smsResultMms =>
      'MMS : prérempli avec la photo dans l\'application SMS';

  @override
  String get smsResultMmsFailed =>
      'MMS impossible : SMS avec le lien vers la photo prérempli à la place';

  @override
  String get smsResultOff => 'SMS : désactivés pour ce type d\'envoi';

  @override
  String get smsResultNoRecipient =>
      'SMS : aucun suiveur avec un numéro de téléphone';

  @override
  String get smsResultNoPermission =>
      'SMS : pas d\'autorisation d\'envoi, position envoyée au serveur seulement';

  @override
  String get smsResultFailed =>
      'SMS : l\'application SMS n\'a pas pu s\'ouvrir';

  @override
  String get smsPermissionTitle => 'Envoi de SMS';

  @override
  String get smsPermissionExplain =>
      'NautiLink envoie lui-même les SMS SOS à vos contacts SOS, et les SMS de positions automatiques à vos suiveurs, même écran éteint. Autorisez l\'envoi de SMS à l\'écran suivant. Sans cette autorisation, le SMS SOS s\'ouvrira prérempli et les positions automatiques partiront au serveur seulement.';

  @override
  String get smsAutoOffNotice =>
      'Sans autorisation d\'envoi de SMS, les positions automatiques partiront au serveur seulement, sans SMS.';

  @override
  String smsAutoFailed(String phone) {
    return 'SMS de position automatique non envoyé à $phone';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String sosSmsAutoSent(int count) {
    return 'SMS SOS envoyés automatiquement : $count';
  }

  @override
  String get sosSmsRetrying => 'SMS SOS en échec : nouvel essai chaque minute';

  @override
  String get sosSmsStopRetry => 'Arrêter les nouveaux essais des SMS';

  @override
  String get batteryTitle => 'Positions écran éteint';

  @override
  String get batteryExplain =>
      'Pour que les positions automatiques continuent écran éteint, autorisez NautiLink à ignorer l\'optimisation de la batterie à l\'écran suivant, et laissez les notifications de NautiLink activées.';

  @override
  String get batterySamsung =>
      'Sur Samsung : Paramètres > Batterie > Limites d\'utilisation en arrière-plan, mettez NautiLink dans les applications « jamais en veille ».';

  @override
  String get batteryXiaomi =>
      'Sur Xiaomi : activez le « Démarrage automatique » de NautiLink, réglez son économiseur de batterie sur « Aucune restriction » et verrouillez-la dans les applications récentes.';

  @override
  String get batteryOther =>
      'Si votre téléphone a ses propres réglages d\'économie de batterie, autorisez NautiLink à fonctionner en arrière-plan.';

  @override
  String get batteryOpen => 'Ouvrir le réglage';

  @override
  String get later => 'Plus tard';

  @override
  String get iosStartWarning =>
      'Sur iPhone, le SOS passe uniquement par Internet, sans SMS : alerte au serveur, e-mails et notifications. Aucun SMS ne part de l\'iPhone ; les réglages SMS sont sans effet pour cette navigation.';

  @override
  String iosStartNoEmail(String names) {
    return 'Contacts SOS sans e-mail, qui ne seront pas prévenus : $names';
  }

  @override
  String get iosSosOffline =>
      'Sans Internet, l\'alerte SOS ne peut pas partir de l\'iPhone. Elle partira automatiquement dès le retour de la connexion. Alertez les secours maintenant : canal 16 de la VHF ou 196.';

  @override
  String get menuFollowed => 'Navigations suivies';

  @override
  String get followNoVoyage => 'Aucune navigation à suivre pour le moment.';

  @override
  String get followFollowers => 'Suiveurs';

  @override
  String get followSosContacts => 'Contacts SOS';

  @override
  String get followBoatSheet => 'Fiche du bateau';

  @override
  String get followSosAlerts => 'Alertes SOS de la navigation';

  @override
  String get followNoPosition => 'Aucune position reçue.';

  @override
  String get followLoadError =>
      'Navigation inaccessible : vérifiez la connexion, ou l\'accès a été retiré.';

  @override
  String get followListen => 'Écouter';

  @override
  String get followStop => 'Arrêter';

  @override
  String get followFileMissing => 'Fichier pas encore reçu par le serveur.';

  @override
  String get followWebPage => 'Ouvrir la page Web de la navigation';

  @override
  String followUpdated(String time) {
    return 'Mise à jour à $time';
  }

  @override
  String get boatHomePort => 'Port d\'attache';

  @override
  String get boatLength => 'Longueur';

  @override
  String get boatRegistration => 'Immatriculation';

  @override
  String get boatEngine => 'Moteur';

  @override
  String get boatDraft => 'Tirant d\'eau';

  @override
  String get scopeThisVoyage => 'Cette navigation seulement';

  @override
  String get addPersonPending => 'Nouveau contact, enregistré au démarrage';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languagePhone => 'Langue du téléphone';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English (anglais)';

  @override
  String get destinationOnMap => 'Choisir sur la carte';

  @override
  String get destinationMapHint =>
      'Touchez la carte pour placer la destination.';

  @override
  String destinationPoint(String position) {
    return 'Point choisi : $position';
  }

  @override
  String get destinationRemovePoint => 'Retirer le point';

  @override
  String get validate => 'Valider';

  @override
  String get eventEdit => 'Modifier';

  @override
  String get eventDelete => 'Supprimer';

  @override
  String get eventDeleteConfirm => 'Supprimer cet élément du journal ?';

  @override
  String get eventChangeOffline =>
      'Modification impossible sans Internet : réessayez au retour de la connexion.';

  @override
  String get eventFullLog => 'Voir dans le journal complet';
}
