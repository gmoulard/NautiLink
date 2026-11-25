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
  String get homeFreeVersion => 'Version gratuite - abonnement';

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
}
