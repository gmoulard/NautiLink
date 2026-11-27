import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink'**
  String get appTitle;

  /// No description provided for @demoBanner.
  ///
  /// In fr, this message translates to:
  /// **'Version bêta · Démonstration : rien n\'est réellement envoyé'**
  String get demoBanner;

  /// No description provided for @sponsorText.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisée par la SRT'**
  String get sponsorText;

  /// No description provided for @sponsorLogoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Guidon de la SRT'**
  String get sponsorLogoLabel;

  /// No description provided for @rightsReserved.
  ///
  /// In fr, this message translates to:
  /// **'Tous droits réservés'**
  String get rightsReserved;

  /// No description provided for @buildInfo.
  ///
  /// In fr, this message translates to:
  /// **'V{version} · build {build} · commit {commit}'**
  String buildInfo(String version, String build, String commit);

  /// No description provided for @buildLocal.
  ///
  /// In fr, this message translates to:
  /// **'version locale'**
  String get buildLocal;

  /// No description provided for @buildCommit.
  ///
  /// In fr, this message translates to:
  /// **'Commit {commit}'**
  String buildCommit(String commit);

  /// No description provided for @footerSiteLink.
  ///
  /// In fr, this message translates to:
  /// **'Site de NautiLink'**
  String get footerSiteLink;

  /// No description provided for @sosButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un SOS'**
  String get sosButton;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @noVoyageInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Aucune navigation en cours.'**
  String get noVoyageInProgress;

  /// No description provided for @logbook.
  ///
  /// In fr, this message translates to:
  /// **'Journal de bord'**
  String get logbook;

  /// No description provided for @distanceNm.
  ///
  /// In fr, this message translates to:
  /// **'{distance} milles'**
  String distanceNm(String distance);

  /// No description provided for @chooseTitle.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink · démonstration'**
  String get chooseTitle;

  /// No description provided for @chooseQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Que voulez-vous essayer ?'**
  String get chooseQuestion;

  /// No description provided for @chooseNavigatorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le navigateur à bord'**
  String get chooseNavigatorTitle;

  /// No description provided for @chooseNavigatorText.
  ///
  /// In fr, this message translates to:
  /// **'L\'application mobile : démarrer une navigation, envoyer sa position, noter, déclencher un SOS.'**
  String get chooseNavigatorText;

  /// No description provided for @chooseFollowerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le suiveur, sur la plateforme Web'**
  String get chooseFollowerTitle;

  /// No description provided for @chooseFollowerText.
  ///
  /// In fr, this message translates to:
  /// **'Le tableau de bord : navigations en cours et passées, carte du tracé, journal de bord.'**
  String get chooseFollowerText;

  /// No description provided for @warningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avertissement'**
  String get warningTitle;

  /// No description provided for @warningHeading.
  ///
  /// In fr, this message translates to:
  /// **'Version bêta et responsabilité'**
  String get warningHeading;

  /// No description provided for @warningSection1Title.
  ///
  /// In fr, this message translates to:
  /// **'1. Version bêta'**
  String get warningSection1Title;

  /// No description provided for @warningSection1Body.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink est actuellement proposé en version bêta, c\'est-à-dire en phase de test. Ses fonctions (suivi de position, envoi de SMS et d\'e-mails, alertes SOS, journal de bord) peuvent présenter des erreurs, des retards ou des interruptions, liés notamment à la couverture du réseau mobile, à l\'accès à Internet, à la réception GPS, à l\'état ou aux réglages du téléphone. La continuité et l\'exactitude du service ne sont pas garanties pendant cette phase.'**
  String get warningSection1Body;

  /// No description provided for @warningSection2Title.
  ///
  /// In fr, this message translates to:
  /// **'2. NautiLink n\'est pas un équipement de sécurité'**
  String get warningSection2Title;

  /// No description provided for @warningSection2Body.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink n\'est pas un équipement de sécurité au sens de la réglementation maritime. Il ne remplace ni le matériel d\'armement et de sécurité obligatoire (radio VHF, moyens de signalisation, balise de détresse, etc.), ni les procédures officielles d\'alerte. En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF, le 196 ou le 112. Une alerte transmise par NautiLink, ou son absence de transmission, ne peut pas être considérée comme une alerte des secours.'**
  String get warningSection2Body;

  /// No description provided for @warningSection3Title.
  ///
  /// In fr, this message translates to:
  /// **'3. Responsabilité du chef de bord'**
  String get warningSection3Title;

  /// No description provided for @warningSection3Body.
  ///
  /// In fr, this message translates to:
  /// **'Le chef de bord reste seul responsable de la conduite du navire, de la sécurité des personnes embarquées, de la préparation de la sortie et du respect de la réglementation en vigueur.'**
  String get warningSection3Body;

  /// No description provided for @warningSection4Title.
  ///
  /// In fr, this message translates to:
  /// **'4. Limitation de responsabilité'**
  String get warningSection4Title;

  /// No description provided for @warningSection4Body.
  ///
  /// In fr, this message translates to:
  /// **'Dans toute la mesure permise par la loi, l\'éditeur de NautiLink ne saurait être tenu responsable des dommages indirects résultant d\'un dysfonctionnement, d\'une interruption ou d\'une indisponibilité du service, ni d\'une utilisation de l\'application non conforme à sa destination ou au présent avertissement.\n\nCette limitation ne s\'applique pas aux dommages corporels, ni en cas de faute lourde ou intentionnelle de l\'éditeur. Elle ne prive pas l\'utilisateur ayant la qualité de consommateur des droits que lui reconnaît la loi, notamment le Code de la consommation, auquel il ne peut être dérogé.'**
  String get warningSection4Body;

  /// No description provided for @warningAccept.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai lu et j\'accepte cet avertissement'**
  String get warningAccept;

  /// No description provided for @menuContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get menuContacts;

  /// No description provided for @menuSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get menuSettings;

  /// No description provided for @menuQuota.
  ///
  /// In fr, this message translates to:
  /// **'Quota et abonnement'**
  String get menuQuota;

  /// No description provided for @menuDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord (Web)'**
  String get menuDashboard;

  /// No description provided for @homeFreeVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version gratuite'**
  String get homeFreeVersion;

  /// No description provided for @homeSubscriberVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version abonné'**
  String get homeSubscriberVersion;

  /// No description provided for @homeFreeLeft.
  ///
  /// In fr, this message translates to:
  /// **'{duration} de navigation gratuite disponibles sur les 7 derniers jours'**
  String homeFreeLeft(String duration);

  /// No description provided for @startVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer navigation'**
  String get startVoyage;

  /// No description provided for @resumeVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la dernière navigation'**
  String get resumeVoyage;

  /// No description provided for @savedVoyages.
  ///
  /// In fr, this message translates to:
  /// **'Navigations enregistrées'**
  String get savedVoyages;

  /// No description provided for @homeDistressHint.
  ///
  /// In fr, this message translates to:
  /// **'En cas de détresse, alertez d\'abord par le canal 16 de la VHF ou le 196.'**
  String get homeDistressHint;

  /// No description provided for @homeSecurityMemo.
  ///
  /// In fr, this message translates to:
  /// **'Mémo sécurité en mer'**
  String get homeSecurityMemo;

  /// No description provided for @firstVoyageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avant votre première navigation'**
  String get firstVoyageTitle;

  /// No description provided for @firstVoyageText.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink est en version bêta et n\'est pas un équipement de sécurité. En cas de détresse, alertez d\'abord les secours par le canal 16 de la VHF ou le 196.'**
  String get firstVoyageText;

  /// No description provided for @understood.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris'**
  String get understood;

  /// No description provided for @contactsDefault.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut, chaque contact est à la fois suiveur et contact SOS.'**
  String get contactsDefault;

  /// No description provided for @roleFollower.
  ///
  /// In fr, this message translates to:
  /// **'Suiveur'**
  String get roleFollower;

  /// No description provided for @roleSos.
  ///
  /// In fr, this message translates to:
  /// **'Contact SOS'**
  String get roleSos;

  /// No description provided for @phoneRequired.
  ///
  /// In fr, this message translates to:
  /// **'Numéro requis'**
  String get phoneRequired;

  /// No description provided for @defaultFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence par défaut'**
  String get defaultFrequency;

  /// No description provided for @sosAlwaysSent.
  ///
  /// In fr, this message translates to:
  /// **'Les SMS SOS partent toujours, quels que soient ces réglages.'**
  String get sosAlwaysSent;

  /// No description provided for @smsEnabled.
  ///
  /// In fr, this message translates to:
  /// **'SMS activés'**
  String get smsEnabled;

  /// No description provided for @quotaHeading.
  ///
  /// In fr, this message translates to:
  /// **'Navigation gratuite : 24 h sur les 7 derniers jours glissants'**
  String get quotaHeading;

  /// No description provided for @quotaUsed.
  ///
  /// In fr, this message translates to:
  /// **'Consommé : {duration}'**
  String quotaUsed(String duration);

  /// No description provided for @quotaLeft.
  ///
  /// In fr, this message translates to:
  /// **'Disponible : {duration}'**
  String quotaLeft(String duration);

  /// No description provided for @subscriptionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionText.
  ///
  /// In fr, this message translates to:
  /// **'Navigation sans limite : 15 € pour 10 ans, sans renouvellement automatique. Suivre et consulter l\'historique restent gratuits.'**
  String get subscriptionText;

  /// No description provided for @subscriptionMore.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus sur l\'abonnement'**
  String get subscriptionMore;

  /// No description provided for @menuSosHistory.
  ///
  /// In fr, this message translates to:
  /// **'Alertes SOS'**
  String get menuSosHistory;

  /// No description provided for @menuAssistance.
  ///
  /// In fr, this message translates to:
  /// **'Assistance'**
  String get menuAssistance;

  /// No description provided for @contactAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get contactAdd;

  /// No description provided for @contactName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get contactName;

  /// No description provided for @contactPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get contactPhone;

  /// No description provided for @contactEmail.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get contactEmail;

  /// No description provided for @contactPhoneOrEmail.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un numéro de téléphone ou une adresse e-mail.'**
  String get contactPhoneOrEmail;

  /// No description provided for @contactSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get contactSave;

  /// No description provided for @contactDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contact'**
  String get contactDelete;

  /// No description provided for @contactDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} de vos contacts ? Ses accès à vos navigations sont retirés.'**
  String contactDeleteConfirm(String name);

  /// No description provided for @contactPending.
  ///
  /// In fr, this message translates to:
  /// **'Modification gardée sur le téléphone, envoyée au retour de la connexion'**
  String get contactPending;

  /// No description provided for @contactsOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion : liste gardée sur le téléphone, utilisable pour le SOS ; vos modifications partiront au retour de la connexion.'**
  String get contactsOffline;

  /// No description provided for @contactRefused.
  ///
  /// In fr, this message translates to:
  /// **'Modification refusée par le serveur : {message}'**
  String contactRefused(String message);

  /// No description provided for @followerNeedsVerifiedEmail.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre adresse e-mail pour inviter des suiveurs ; un contact SOS reste possible.'**
  String get followerNeedsVerifiedEmail;

  /// No description provided for @scopeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que le suiveur voit'**
  String get scopeTitle;

  /// No description provided for @scopeNavigator.
  ///
  /// In fr, this message translates to:
  /// **'Toutes mes navigations (présentes et futures, historique compris)'**
  String get scopeNavigator;

  /// No description provided for @scopeVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Une seule navigation'**
  String get scopeVoyage;

  /// No description provided for @scopeChooseVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Navigation'**
  String get scopeChooseVoyage;

  /// No description provided for @scopeNoVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune navigation à partager pour l\'instant.'**
  String get scopeNoVoyage;

  /// No description provided for @scopeChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer le périmètre'**
  String get scopeChange;

  /// No description provided for @invitationNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore invité'**
  String get invitationNone;

  /// No description provided for @invitationSent.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée, pas encore acceptée'**
  String get invitationSent;

  /// No description provided for @invitationAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Suiveur : invitation acceptée'**
  String get invitationAccepted;

  /// No description provided for @invitationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Invitation annulée'**
  String get invitationCancelled;

  /// No description provided for @inviteByEmail.
  ///
  /// In fr, this message translates to:
  /// **'Inviter par e-mail'**
  String get inviteByEmail;

  /// No description provided for @inviteByPhone.
  ///
  /// In fr, this message translates to:
  /// **'Inviter par téléphone'**
  String get inviteByPhone;

  /// No description provided for @invitationEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée par e-mail à {email}, avec copie à votre adresse.'**
  String invitationEmailSent(String email);

  /// No description provided for @invitationLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien d\'invitation à transmettre'**
  String get invitationLink;

  /// No description provided for @invitationLinkHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien mène à la connexion ou à la création d\'un compte NautiLink ; ce n\'est jamais un accès public.'**
  String get invitationLinkHint;

  /// No description provided for @invitationSendSms.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer par SMS'**
  String get invitationSendSms;

  /// No description provided for @invitationCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get invitationCopyLink;

  /// No description provided for @linkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get linkCopied;

  /// No description provided for @invitationCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'invitation'**
  String get invitationCancel;

  /// No description provided for @followerRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le suiveur de toutes mes navigations'**
  String get followerRemove;

  /// No description provided for @followerRemoveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} de toutes vos navigations, présentes et futures ? L\'effet est immédiat.'**
  String followerRemoveConfirm(String name);

  /// No description provided for @onlineOnly.
  ///
  /// In fr, this message translates to:
  /// **'Demande Internet : réessayez au retour de la connexion.'**
  String get onlineOnly;

  /// No description provided for @smsInviteOffline.
  ///
  /// In fr, this message translates to:
  /// **'Invitation par SMS impossible hors connexion : le lien vient du serveur.'**
  String get smsInviteOffline;

  /// No description provided for @iphoneNoSmsInvite.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone, aucun SMS n\'est envoyé : transmettez vous-même le lien.'**
  String get iphoneNoSmsInvite;

  /// No description provided for @photoAsMms.
  ///
  /// In fr, this message translates to:
  /// **'Joindre la photo en MMS'**
  String get photoAsMms;

  /// No description provided for @settingsSynced.
  ///
  /// In fr, this message translates to:
  /// **'Réglages synchronisés avec le Web ; hors connexion, la modification part au retour.'**
  String get settingsSynced;

  /// No description provided for @settingsIphone.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone, aucun SMS n\'est envoyé : ces réglages servent aux navigations menées depuis un téléphone Android.'**
  String get settingsIphone;

  /// No description provided for @sosHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte SOS.'**
  String get sosHistoryEmpty;

  /// No description provided for @sosHistoryOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion : alertes de ce téléphone et dernier historique reçu le {date}.'**
  String sosHistoryOffline(String date);

  /// No description provided for @sosAlertTitle.
  ///
  /// In fr, this message translates to:
  /// **'SOS · {date}'**
  String sosAlertTitle(String date);

  /// No description provided for @sosAlertPending.
  ///
  /// In fr, this message translates to:
  /// **'Alerte encore sur le téléphone, envoyée au retour de la connexion'**
  String get sosAlertPending;

  /// No description provided for @sosPositionCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Position actuelle'**
  String get sosPositionCurrent;

  /// No description provided for @sosPositionLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position connue'**
  String get sosPositionLast;

  /// No description provided for @sosPositionNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune position'**
  String get sosPositionNone;

  /// No description provided for @sosSmsPending.
  ///
  /// In fr, this message translates to:
  /// **'en attente'**
  String get sosSmsPending;

  /// No description provided for @sosHistorySmsAccepted.
  ///
  /// In fr, this message translates to:
  /// **'accepté pour envoi'**
  String get sosHistorySmsAccepted;

  /// No description provided for @sosSmsDelivered.
  ///
  /// In fr, this message translates to:
  /// **'livraison confirmée'**
  String get sosSmsDelivered;

  /// No description provided for @sosSmsFailed.
  ///
  /// In fr, this message translates to:
  /// **'échec'**
  String get sosSmsFailed;

  /// No description provided for @sosEmailsSent.
  ///
  /// In fr, this message translates to:
  /// **'E-mail envoyé à {count} adresse(s)'**
  String sosEmailsSent(String count);

  /// No description provided for @sosHistoryProblem.
  ///
  /// In fr, this message translates to:
  /// **'Problème : {text}'**
  String sosHistoryProblem(String text);

  /// No description provided for @assistanceWrite.
  ///
  /// In fr, this message translates to:
  /// **'Écrire à l\'équipe NautiLink'**
  String get assistanceWrite;

  /// No description provided for @assistanceWriteHint.
  ///
  /// In fr, this message translates to:
  /// **'Page de suivi du projet NautiLink sur GitHub'**
  String get assistanceWriteHint;

  /// No description provided for @assistanceOffline.
  ///
  /// In fr, this message translates to:
  /// **'Contact de l\'équipe impossible sans Internet.'**
  String get assistanceOffline;

  /// No description provided for @assistanceWarning.
  ///
  /// In fr, this message translates to:
  /// **'Avertissement bêta'**
  String get assistanceWarning;

  /// No description provided for @assistanceMemoHint.
  ///
  /// In fr, this message translates to:
  /// **'Canal 16 de la VHF, 196'**
  String get assistanceMemoHint;

  /// No description provided for @subscribe.
  ///
  /// In fr, this message translates to:
  /// **'Souscrire l\'abonnement'**
  String get subscribe;

  /// No description provided for @subscribeNotYet.
  ///
  /// In fr, this message translates to:
  /// **'L\'achat de l\'abonnement par Google Play ou par l\'App Store n\'est pas encore ouvert dans l\'application.'**
  String get subscribeNotYet;

  /// No description provided for @subscribeOffline.
  ///
  /// In fr, this message translates to:
  /// **'Souscription impossible sans Internet.'**
  String get subscribeOffline;

  /// No description provided for @boat.
  ///
  /// In fr, this message translates to:
  /// **'Bateau'**
  String get boat;

  /// No description provided for @destinationOptional.
  ///
  /// In fr, this message translates to:
  /// **'Destination (facultative)'**
  String get destinationOptional;

  /// No description provided for @destinationHint.
  ///
  /// In fr, this message translates to:
  /// **'Adresse ou lieu'**
  String get destinationHint;

  /// No description provided for @personsOnBoard.
  ///
  /// In fr, this message translates to:
  /// **'Personnes à bord'**
  String get personsOnBoard;

  /// No description provided for @onePersonLess.
  ///
  /// In fr, this message translates to:
  /// **'Une personne de moins'**
  String get onePersonLess;

  /// No description provided for @onePersonMore.
  ///
  /// In fr, this message translates to:
  /// **'Une personne de plus'**
  String get onePersonMore;

  /// No description provided for @autoFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence d\'envoi automatique'**
  String get autoFrequency;

  /// No description provided for @alertedPersons.
  ///
  /// In fr, this message translates to:
  /// **'Personnes alertées'**
  String get alertedPersons;

  /// No description provided for @alertedRoleFollower.
  ///
  /// In fr, this message translates to:
  /// **'suiveur'**
  String get alertedRoleFollower;

  /// No description provided for @alertedRoleSos.
  ///
  /// In fr, this message translates to:
  /// **'contact SOS'**
  String get alertedRoleSos;

  /// No description provided for @addPerson.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une personne'**
  String get addPerson;

  /// No description provided for @voyageSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de cette navigation'**
  String get voyageSettings;

  /// No description provided for @noSosChecked.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact SOS coché : personne ne recevra vos SMS SOS.'**
  String get noSosChecked;

  /// No description provided for @sendStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de navigation'**
  String get sendStart;

  /// No description provided for @addPersonText.
  ///
  /// In fr, this message translates to:
  /// **'La personne rejoint vos contacts, suiveur et contact SOS par défaut, et sera alertée pendant cette navigation.'**
  String get addPersonText;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @phoneNeededForSos.
  ///
  /// In fr, this message translates to:
  /// **'Un numéro de téléphone est nécessaire pour être contact SOS.'**
  String get phoneNeededForSos;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @smsPrefilled.
  ///
  /// In fr, this message translates to:
  /// **'SMS prérempli pour vos suiveurs'**
  String get smsPrefilled;

  /// No description provided for @smsDisabled.
  ///
  /// In fr, this message translates to:
  /// **'SMS désactivés'**
  String get smsDisabled;

  /// No description provided for @serverSent.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : envoyé'**
  String get serverSent;

  /// No description provided for @nothingReallySent.
  ///
  /// In fr, this message translates to:
  /// **'(démonstration : rien n\'est réellement envoyé)'**
  String get nothingReallySent;

  /// No description provided for @voyageEnded.
  ///
  /// In fr, this message translates to:
  /// **'Navigation terminée ?'**
  String get voyageEnded;

  /// No description provided for @stationaryText.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne vous êtes pas éloigné de plus de 20 mètres depuis 2 heures.'**
  String get stationaryText;

  /// No description provided for @endVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la navigation'**
  String get endVoyage;

  /// No description provided for @endVoyageQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la navigation ?'**
  String get endVoyageQuestion;

  /// No description provided for @end.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get end;

  /// No description provided for @validateSend.
  ///
  /// In fr, this message translates to:
  /// **'Valider l\'envoi'**
  String get validateSend;

  /// No description provided for @demoMenu.
  ///
  /// In fr, this message translates to:
  /// **'Démonstration'**
  String get demoMenu;

  /// No description provided for @demoStationary.
  ///
  /// In fr, this message translates to:
  /// **'Démo : simuler 2 h sans bouger'**
  String get demoStationary;

  /// No description provided for @sinceStart.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le début'**
  String get sinceStart;

  /// No description provided for @sinceLastSend.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le dernier envoi position'**
  String get sinceLastSend;

  /// No description provided for @sendPosition.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer position'**
  String get sendPosition;

  /// No description provided for @positionSent.
  ///
  /// In fr, this message translates to:
  /// **'Position envoyée'**
  String get positionSent;

  /// No description provided for @noteButton.
  ///
  /// In fr, this message translates to:
  /// **'NOTE'**
  String get noteButton;

  /// No description provided for @noteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get noteTitle;

  /// No description provided for @noteHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre note'**
  String get noteHint;

  /// No description provided for @noteSent.
  ///
  /// In fr, this message translates to:
  /// **'Note envoyée'**
  String get noteSent;

  /// No description provided for @noteKindNote.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get noteKindNote;

  /// No description provided for @noteKindIncident.
  ///
  /// In fr, this message translates to:
  /// **'Incident - avarie'**
  String get noteKindIncident;

  /// No description provided for @incidentHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez l\'incident ou l\'avarie'**
  String get incidentHint;

  /// No description provided for @incidentAttachment.
  ///
  /// In fr, this message translates to:
  /// **'Pièce jointe (facultative)'**
  String get incidentAttachment;

  /// No description provided for @attachmentNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get attachmentNone;

  /// No description provided for @attachmentPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get attachmentPhoto;

  /// No description provided for @attachmentVoice.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale'**
  String get attachmentVoice;

  /// No description provided for @incidentSent.
  ///
  /// In fr, this message translates to:
  /// **'Incident - avarie envoyé'**
  String get incidentSent;

  /// No description provided for @photoButton.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get photoButton;

  /// No description provided for @photoSent.
  ///
  /// In fr, this message translates to:
  /// **'Photo envoyée'**
  String get photoSent;

  /// No description provided for @voiceButton.
  ///
  /// In fr, this message translates to:
  /// **'Vocal'**
  String get voiceButton;

  /// No description provided for @voiceSent.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale envoyée'**
  String get voiceSent;

  /// No description provided for @recording.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement en cours'**
  String get recording;

  /// No description provided for @recordingHint.
  ///
  /// In fr, this message translates to:
  /// **'1 minute au plus. Votre voix est envoyée telle quelle, sans transcription.'**
  String get recordingHint;

  /// No description provided for @stopAndSend.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter et envoyer'**
  String get stopAndSend;

  /// No description provided for @photo.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @samplePhoto.
  ///
  /// In fr, this message translates to:
  /// **'{time} · photo d\'exemple'**
  String samplePhoto(String time);

  /// No description provided for @listenVoice.
  ///
  /// In fr, this message translates to:
  /// **'Écoute de la note vocale'**
  String get listenVoice;

  /// No description provided for @recordingDefault.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement'**
  String get recordingDefault;

  /// No description provided for @noSoundRecorded.
  ///
  /// In fr, this message translates to:
  /// **'{recording}\nDémonstration : aucun son n\'est enregistré.'**
  String noSoundRecorded(String recording);

  /// No description provided for @sosQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un SOS ?'**
  String get sosQuestion;

  /// No description provided for @sosConfirmText.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts SOS recevront votre position et la fiche du bateau. Alertez aussi les secours : canal 16 de la VHF ou 196.'**
  String get sosConfirmText;

  /// No description provided for @sosProblem.
  ///
  /// In fr, this message translates to:
  /// **'Problème rencontré (facultatif)'**
  String get sosProblem;

  /// No description provided for @sosProblemHint.
  ///
  /// In fr, this message translates to:
  /// **'Voie d\'eau, avarie moteur, blessé…'**
  String get sosProblemHint;

  /// No description provided for @sosConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le SOS'**
  String get sosConfirm;

  /// No description provided for @sosAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte SOS'**
  String get sosAlert;

  /// No description provided for @sosNoSmsSent.
  ///
  /// In fr, this message translates to:
  /// **'Démonstration : aucun SMS n\'est réellement parti.'**
  String get sosNoSmsSent;

  /// No description provided for @sosSmsAccepted.
  ///
  /// In fr, this message translates to:
  /// **'SMS SOS accepté pour envoi · {phone}'**
  String sosSmsAccepted(String phone);

  /// No description provided for @sosCopyNavigator.
  ///
  /// In fr, this message translates to:
  /// **'Copie au navigateur'**
  String get sosCopyNavigator;

  /// No description provided for @sosCopyNavigatorDetail.
  ///
  /// In fr, this message translates to:
  /// **'SMS et e-mail en copie (RG-SMS-08, RG-NOT-03)'**
  String get sosCopyNavigatorDetail;

  /// No description provided for @sosServer.
  ///
  /// In fr, this message translates to:
  /// **'Serveur'**
  String get sosServer;

  /// No description provided for @sosServerDetail.
  ///
  /// In fr, this message translates to:
  /// **'Alerte reçue · e-mail aux suiveurs'**
  String get sosServerDetail;

  /// No description provided for @dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboard;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get filterAll;

  /// No description provided for @filterNavigator.
  ///
  /// In fr, this message translates to:
  /// **'Comme navigateur'**
  String get filterNavigator;

  /// No description provided for @filterFollower.
  ///
  /// In fr, this message translates to:
  /// **'Comme suiveur'**
  String get filterFollower;

  /// No description provided for @inProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get inProgress;

  /// No description provided for @history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get history;

  /// No description provided for @live.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get live;

  /// No description provided for @voyageCardFollowed.
  ///
  /// In fr, this message translates to:
  /// **' · suivie ({navigator})'**
  String voyageCardFollowed(String navigator);

  /// No description provided for @infoDeparture.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get infoDeparture;

  /// No description provided for @infoDeparturePlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu de départ'**
  String get infoDeparturePlace;

  /// No description provided for @infoWeatherStart.
  ///
  /// In fr, this message translates to:
  /// **'Météo au départ'**
  String get infoWeatherStart;

  /// No description provided for @infoArrival.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get infoArrival;

  /// No description provided for @infoArrivalPlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu d\'arrivée'**
  String get infoArrivalPlace;

  /// No description provided for @infoWeatherEnd.
  ///
  /// In fr, this message translates to:
  /// **'Météo à l\'arrivée'**
  String get infoWeatherEnd;

  /// No description provided for @infoDestination.
  ///
  /// In fr, this message translates to:
  /// **'Destination'**
  String get infoDestination;

  /// No description provided for @infoDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get infoDuration;

  /// No description provided for @infoDistance.
  ///
  /// In fr, this message translates to:
  /// **'Distance'**
  String get infoDistance;

  /// No description provided for @infoNavigator.
  ///
  /// In fr, this message translates to:
  /// **'Navigateur'**
  String get infoNavigator;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @renameVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Renommer la navigation'**
  String get renameVoyage;

  /// No description provided for @exportPdf.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF'**
  String get exportPdf;

  /// No description provided for @exportPdfSoon.
  ///
  /// In fr, this message translates to:
  /// **'Export PDF : disponible dans la version réelle.'**
  String get exportPdfSoon;

  /// No description provided for @me.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get me;

  /// No description provided for @eventStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de navigation'**
  String get eventStart;

  /// No description provided for @eventAutoPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position automatique'**
  String get eventAutoPosition;

  /// No description provided for @eventManualPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position envoyée'**
  String get eventManualPosition;

  /// No description provided for @eventNote.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get eventNote;

  /// No description provided for @eventPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get eventPhoto;

  /// No description provided for @eventVoice.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale'**
  String get eventVoice;

  /// No description provided for @eventIncident.
  ///
  /// In fr, this message translates to:
  /// **'Incident - avarie'**
  String get eventIncident;

  /// No description provided for @eventSos.
  ///
  /// In fr, this message translates to:
  /// **'Alerte SOS'**
  String get eventSos;

  /// No description provided for @eventEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de navigation'**
  String get eventEnd;

  /// No description provided for @eventFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence : {frequency}'**
  String eventFrequency(String frequency);

  /// No description provided for @frequencyMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String frequencyMinutes(int count);

  /// No description provided for @frequencyHours.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 heure} other{{count} heures}}'**
  String frequencyHours(int count);

  /// No description provided for @frequencyDays.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 jour} other{{count} jours}}'**
  String frequencyDays(int count);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, String minutes);

  /// No description provided for @dateTime.
  ///
  /// In fr, this message translates to:
  /// **'{date}, {time}'**
  String dateTime(String date, String time);

  /// No description provided for @nearPlace.
  ///
  /// In fr, this message translates to:
  /// **'à {distance} milles de {place}'**
  String nearPlace(String distance, String place);

  /// No description provided for @smsTypeStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de navigation'**
  String get smsTypeStart;

  /// No description provided for @smsTypeAutoPosition.
  ///
  /// In fr, this message translates to:
  /// **'Positions automatiques'**
  String get smsTypeAutoPosition;

  /// No description provided for @smsTypeManualPosition.
  ///
  /// In fr, this message translates to:
  /// **'Positions manuelles'**
  String get smsTypeManualPosition;

  /// No description provided for @smsTypeNote.
  ///
  /// In fr, this message translates to:
  /// **'Notes écrites'**
  String get smsTypeNote;

  /// No description provided for @smsTypePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get smsTypePhoto;

  /// No description provided for @smsTypeVoice.
  ///
  /// In fr, this message translates to:
  /// **'Notes vocales'**
  String get smsTypeVoice;

  /// No description provided for @smsTypeIncident.
  ///
  /// In fr, this message translates to:
  /// **'Incidents - avaries'**
  String get smsTypeIncident;

  /// No description provided for @smsTypeEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de navigation'**
  String get smsTypeEnd;

  /// No description provided for @sosSmsBoat.
  ///
  /// In fr, this message translates to:
  /// **'SOS {name}, {type}, {length}, {registration}.'**
  String sosSmsBoat(
    String name,
    String type,
    String length,
    String registration,
  );

  /// No description provided for @sosSmsPersons.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 personne à bord.} other{{count} personnes à bord.}}'**
  String sosSmsPersons(int count);

  /// No description provided for @sosSmsProblem.
  ///
  /// In fr, this message translates to:
  /// **'Problème : {problem}.'**
  String sosSmsProblem(String problem);

  /// No description provided for @sosSmsPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position {position} à {time}.'**
  String sosSmsPosition(String position, String time);

  /// No description provided for @betaBanner.
  ///
  /// In fr, this message translates to:
  /// **'Version bêta'**
  String get betaBanner;

  /// No description provided for @offlineSince.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion · données du {date}'**
  String offlineSince(String date);

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// No description provided for @loginButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginButton;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @passwordMin.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères au moins'**
  String get passwordMin;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @createAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Création du compte'**
  String get createAccountTitle;

  /// No description provided for @createAccountButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get createAccountButton;

  /// No description provided for @continueGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueGoogle;

  /// No description provided for @continueApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get continueApple;

  /// No description provided for @providerUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par Google ou Apple : pas encore disponible.'**
  String get providerUnavailable;

  /// No description provided for @loginOffline.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible sans Internet.'**
  String get loginOffline;

  /// No description provided for @sessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré : reconnectez-vous.'**
  String get sessionExpired;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas pu traiter la demande.'**
  String get errorGeneric;

  /// No description provided for @fieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ obligatoire'**
  String get fieldRequired;

  /// No description provided for @forgotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotTitle;

  /// No description provided for @forgotText.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez l\'adresse e-mail de votre compte : vous recevrez un lien, valable 1 heure, pour choisir un nouveau mot de passe.'**
  String get forgotText;

  /// No description provided for @forgotSend.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le lien'**
  String get forgotSend;

  /// No description provided for @forgotSent.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte existe pour cette adresse, un e-mail vient de partir. Le lien est valable 1 heure.'**
  String get forgotSent;

  /// No description provided for @warningNewVersion.
  ///
  /// In fr, this message translates to:
  /// **'L\'avertissement a changé : lisez-le et acceptez-le pour continuer.'**
  String get warningNewVersion;

  /// No description provided for @emailNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre adresse e-mail ({email}) avec le lien reçu : sans confirmation, vous ne pouvez ni démarrer une navigation ni inviter.'**
  String emailNotVerified(String email);

  /// No description provided for @resendLink.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un nouveau lien'**
  String get resendLink;

  /// No description provided for @linkSent.
  ///
  /// In fr, this message translates to:
  /// **'Lien envoyé.'**
  String get linkSent;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @quotaUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Quota pas encore reçu du serveur'**
  String get quotaUnknown;

  /// No description provided for @quotaAsOf.
  ///
  /// In fr, this message translates to:
  /// **'État du {date}'**
  String quotaAsOf(String date);

  /// No description provided for @voyageInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Navigation en cours : {name}'**
  String voyageInProgress(String name);

  /// No description provided for @notYetAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore disponible dans cette version de l\'application.'**
  String get notYetAvailable;

  /// No description provided for @savedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion : dernière liste reçue le {date}'**
  String savedOffline(String date);

  /// No description provided for @noSavedVoyages.
  ///
  /// In fr, this message translates to:
  /// **'Aucune navigation enregistrée.'**
  String get noSavedVoyages;

  /// No description provided for @pageOffline.
  ///
  /// In fr, this message translates to:
  /// **'La page de la navigation sera disponible au retour de la connexion.'**
  String get pageOffline;

  /// No description provided for @serverQueued.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : en attente, envoi au retour de la connexion'**
  String get serverQueued;

  /// No description provided for @smsNotYet.
  ///
  /// In fr, this message translates to:
  /// **'SMS : pas encore envoyés par cette version de l\'application'**
  String get smsNotYet;

  /// No description provided for @voyageStarted.
  ///
  /// In fr, this message translates to:
  /// **'Navigation démarrée'**
  String get voyageStarted;

  /// No description provided for @startRefused.
  ///
  /// In fr, this message translates to:
  /// **'Démarrage refusé'**
  String get startRefused;

  /// No description provided for @startQuotaExhausted.
  ///
  /// In fr, this message translates to:
  /// **'Quota de navigation gratuite épuisé : la navigation ne peut pas démarrer. Des minutes redeviendront disponibles le {date}. Vous pouvez aussi vous abonner.'**
  String startQuotaExhausted(String date);

  /// No description provided for @startQuotaExhaustedNoDate.
  ///
  /// In fr, this message translates to:
  /// **'Quota de navigation gratuite épuisé : la navigation ne peut pas démarrer. Attendez que des minutes redeviennent disponibles, ou abonnez-vous.'**
  String get startQuotaExhaustedNoDate;

  /// No description provided for @noBoatYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bateau dans votre compte : créez d\'abord la fiche de votre bateau sur la plateforme Web (« Bateaux »).'**
  String get noBoatYet;

  /// No description provided for @locationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre position'**
  String get locationTitle;

  /// No description provided for @locationExplain.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink va demander l\'accès à la position précise du téléphone. Elle sert aux positions automatiques et manuelles de la navigation et au SOS, même sans Internet. Sans elle, la navigation se déroule sans positions.'**
  String get locationExplain;

  /// No description provided for @gpsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'GPS non disponible'**
  String get gpsUnavailable;

  /// No description provided for @noSosContact.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez aucun contact SOS : personne ne recevra vos SMS SOS. Ajoutez-en un dans vos contacts sur la plateforme Web.'**
  String get noSosContact;

  /// No description provided for @noAlertablePerson.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact suiveur ou contact SOS.'**
  String get noAlertablePerson;

  /// No description provided for @voyageRefused.
  ///
  /// In fr, this message translates to:
  /// **'Refusé par le serveur : {message}'**
  String voyageRefused(String message);

  /// No description provided for @nextAutoPosition.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine position automatique : {time}'**
  String nextAutoPosition(String time);

  /// No description provided for @sendRefused.
  ///
  /// In fr, this message translates to:
  /// **'Envoi refusé'**
  String get sendRefused;

  /// No description provided for @micRefused.
  ///
  /// In fr, this message translates to:
  /// **'Accès au micro refusé : la note vocale ne peut pas être enregistrée.'**
  String get micRefused;

  /// No description provided for @recordingHintReal.
  ///
  /// In fr, this message translates to:
  /// **'Votre voix est envoyée telle quelle, sans transcription.'**
  String get recordingHintReal;

  /// No description provided for @sosReelNoBoat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bateau dans votre compte : NautiLink ne peut pas envoyer l\'alerte. Alertez les secours : canal 16 de la VHF ou 196.'**
  String get sosReelNoBoat;

  /// No description provided for @sosReelChooseBoat.
  ///
  /// In fr, this message translates to:
  /// **'Bateau en détresse'**
  String get sosReelChooseBoat;

  /// No description provided for @sosReelSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de la position…'**
  String get sosReelSearching;

  /// No description provided for @sosReelSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de l\'alerte au serveur…'**
  String get sosReelSending;

  /// No description provided for @sosReelServerReceived.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : alerte reçue, e-mails envoyés aux suiveurs et aux contacts SOS'**
  String get sosReelServerReceived;

  /// No description provided for @sosReelServerQueued.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : alerte gardée sur le téléphone, envoyée en priorité au retour de la connexion'**
  String get sosReelServerQueued;

  /// No description provided for @sosReelSmsOpened.
  ///
  /// In fr, this message translates to:
  /// **'SMS SOS prérempli ouvert dans l\'application SMS : appuyez sur « Envoyer ».'**
  String get sosReelSmsOpened;

  /// No description provided for @sosReelSmsFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'application SMS n\'a pas pu s\'ouvrir : aucun SMS SOS n\'est parti.'**
  String get sosReelSmsFailed;

  /// No description provided for @sosReelSmsNoContact.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact SOS avec un numéro : pas de SMS SOS.'**
  String get sosReelSmsNoContact;

  /// No description provided for @sosReelSmsLastKnown.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position connue, pas nécessairement la position actuelle : {position} le {date}.'**
  String sosReelSmsLastKnown(String position, String date);

  /// No description provided for @sosReelSmsNoPosition.
  ///
  /// In fr, this message translates to:
  /// **'GPS indisponible : aucune position connue.'**
  String get sosReelSmsNoPosition;

  /// No description provided for @sosReelSailboat.
  ///
  /// In fr, this message translates to:
  /// **'voilier'**
  String get sosReelSailboat;

  /// No description provided for @sosReelMotorboat.
  ///
  /// In fr, this message translates to:
  /// **'bateau à moteur'**
  String get sosReelMotorboat;

  /// No description provided for @voyageFinished.
  ///
  /// In fr, this message translates to:
  /// **'Navigation terminée'**
  String get voyageFinished;

  /// No description provided for @smsHeader.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink {boat} — {kind} à {time}.'**
  String smsHeader(String boat, String kind, String time);

  /// No description provided for @smsKindStart.
  ///
  /// In fr, this message translates to:
  /// **'début de navigation'**
  String get smsKindStart;

  /// No description provided for @smsKindPosition.
  ///
  /// In fr, this message translates to:
  /// **'position'**
  String get smsKindPosition;

  /// No description provided for @smsKindNote.
  ///
  /// In fr, this message translates to:
  /// **'note'**
  String get smsKindNote;

  /// No description provided for @smsKindPhoto.
  ///
  /// In fr, this message translates to:
  /// **'photo'**
  String get smsKindPhoto;

  /// No description provided for @smsKindVoice.
  ///
  /// In fr, this message translates to:
  /// **'note vocale'**
  String get smsKindVoice;

  /// No description provided for @smsKindIncident.
  ///
  /// In fr, this message translates to:
  /// **'incident - avarie'**
  String get smsKindIncident;

  /// No description provided for @smsKindEnd.
  ///
  /// In fr, this message translates to:
  /// **'fin de navigation'**
  String get smsKindEnd;

  /// No description provided for @smsDestination.
  ///
  /// In fr, this message translates to:
  /// **'Destination : {destination}.'**
  String smsDestination(String destination);

  /// No description provided for @smsPositionLine.
  ///
  /// In fr, this message translates to:
  /// **'Position {position} : {link}'**
  String smsPositionLine(String position, String link);

  /// No description provided for @smsGpsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'GPS NON DISPONIBLE'**
  String get smsGpsUnavailable;

  /// No description provided for @smsNoteLine.
  ///
  /// In fr, this message translates to:
  /// **'Note : {text}'**
  String smsNoteLine(String text);

  /// No description provided for @smsPhotoLine.
  ///
  /// In fr, this message translates to:
  /// **'Photo : {link}'**
  String smsPhotoLine(String link);

  /// No description provided for @smsVoiceLine.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale : {link}'**
  String smsVoiceLine(String link);

  /// No description provided for @smsIncidentLine.
  ///
  /// In fr, this message translates to:
  /// **'Détails : {link}'**
  String smsIncidentLine(String link);

  /// No description provided for @smsFollowLine.
  ///
  /// In fr, this message translates to:
  /// **'Suivre la navigation : {link}'**
  String smsFollowLine(String link);

  /// No description provided for @sosSmsSecond.
  ///
  /// In fr, this message translates to:
  /// **'SOS {name} (suite). Port d\'attache : {port}. Moteur : {engine}. Autonomie : {range}. Carburant : {fuel}. Vitesse : {speed}. Tirant d\'eau : {draft}.'**
  String sosSmsSecond(
    String name,
    String port,
    String engine,
    String range,
    String fuel,
    String speed,
    String draft,
  );

  /// No description provided for @smsResultAuto.
  ///
  /// In fr, this message translates to:
  /// **'SMS : envoyé automatiquement à {count, plural, =1{1 destinataire} other{{count} destinataires}}'**
  String smsResultAuto(int count);

  /// No description provided for @smsResultPrefilled.
  ///
  /// In fr, this message translates to:
  /// **'SMS : prérempli dans l\'application SMS, appuyez sur « Envoyer »'**
  String get smsResultPrefilled;

  /// No description provided for @smsResultMms.
  ///
  /// In fr, this message translates to:
  /// **'MMS : prérempli avec la photo dans l\'application SMS'**
  String get smsResultMms;

  /// No description provided for @smsResultMmsFailed.
  ///
  /// In fr, this message translates to:
  /// **'MMS impossible : SMS avec le lien vers la photo prérempli à la place'**
  String get smsResultMmsFailed;

  /// No description provided for @smsResultOff.
  ///
  /// In fr, this message translates to:
  /// **'SMS : désactivés pour ce type d\'envoi'**
  String get smsResultOff;

  /// No description provided for @smsResultNoRecipient.
  ///
  /// In fr, this message translates to:
  /// **'SMS : aucun suiveur avec un numéro de téléphone'**
  String get smsResultNoRecipient;

  /// No description provided for @smsResultNoPermission.
  ///
  /// In fr, this message translates to:
  /// **'SMS : pas d\'autorisation d\'envoi, position envoyée au serveur seulement'**
  String get smsResultNoPermission;

  /// No description provided for @smsResultFailed.
  ///
  /// In fr, this message translates to:
  /// **'SMS : l\'application SMS n\'a pas pu s\'ouvrir'**
  String get smsResultFailed;

  /// No description provided for @smsPermissionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de SMS'**
  String get smsPermissionTitle;

  /// No description provided for @smsPermissionExplain.
  ///
  /// In fr, this message translates to:
  /// **'NautiLink envoie lui-même les SMS SOS à vos contacts SOS, et les SMS de positions automatiques à vos suiveurs, même écran éteint. Autorisez l\'envoi de SMS à l\'écran suivant. Sans cette autorisation, le SMS SOS s\'ouvrira prérempli et les positions automatiques partiront au serveur seulement.'**
  String get smsPermissionExplain;

  /// No description provided for @smsAutoOffNotice.
  ///
  /// In fr, this message translates to:
  /// **'Sans autorisation d\'envoi de SMS, les positions automatiques partiront au serveur seulement, sans SMS.'**
  String get smsAutoOffNotice;

  /// No description provided for @smsAutoFailed.
  ///
  /// In fr, this message translates to:
  /// **'SMS non envoyé à {phone}'**
  String smsAutoFailed(String phone);

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @sosSmsAutoSent.
  ///
  /// In fr, this message translates to:
  /// **'SMS SOS envoyés automatiquement : {count}'**
  String sosSmsAutoSent(int count);

  /// No description provided for @sosSmsRetrying.
  ///
  /// In fr, this message translates to:
  /// **'SMS SOS en échec : nouvel essai chaque minute'**
  String get sosSmsRetrying;

  /// No description provided for @sosSmsStopRetry.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter les nouveaux essais des SMS'**
  String get sosSmsStopRetry;

  /// No description provided for @batteryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Positions écran éteint'**
  String get batteryTitle;

  /// No description provided for @batteryExplain.
  ///
  /// In fr, this message translates to:
  /// **'Pour que les positions automatiques continuent écran éteint, autorisez NautiLink à ignorer l\'optimisation de la batterie à l\'écran suivant, et laissez les notifications de NautiLink activées.'**
  String get batteryExplain;

  /// No description provided for @batterySamsung.
  ///
  /// In fr, this message translates to:
  /// **'Sur Samsung : Paramètres > Batterie > Limites d\'utilisation en arrière-plan, mettez NautiLink dans les applications « jamais en veille ».'**
  String get batterySamsung;

  /// No description provided for @batteryXiaomi.
  ///
  /// In fr, this message translates to:
  /// **'Sur Xiaomi : activez le « Démarrage automatique » de NautiLink, réglez son économiseur de batterie sur « Aucune restriction » et verrouillez-la dans les applications récentes.'**
  String get batteryXiaomi;

  /// No description provided for @batteryOther.
  ///
  /// In fr, this message translates to:
  /// **'Si votre téléphone a ses propres réglages d\'économie de batterie, autorisez NautiLink à fonctionner en arrière-plan.'**
  String get batteryOther;

  /// No description provided for @batteryOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le réglage'**
  String get batteryOpen;

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// No description provided for @iosStartWarning.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone, le SOS passe uniquement par Internet, sans SMS : alerte au serveur, e-mails et notifications. Aucun SMS ne part de l\'iPhone ; les réglages SMS sont sans effet pour cette navigation.'**
  String get iosStartWarning;

  /// No description provided for @iosStartNoEmail.
  ///
  /// In fr, this message translates to:
  /// **'Contacts SOS sans e-mail, qui ne seront pas prévenus : {names}'**
  String iosStartNoEmail(String names);

  /// No description provided for @iosSosOffline.
  ///
  /// In fr, this message translates to:
  /// **'Sans Internet, l\'alerte SOS ne peut pas partir de l\'iPhone. Elle partira automatiquement dès le retour de la connexion. Alertez les secours maintenant : canal 16 de la VHF ou 196.'**
  String get iosSosOffline;

  /// No description provided for @menuFollowed.
  ///
  /// In fr, this message translates to:
  /// **'Navigations suivies'**
  String get menuFollowed;

  /// No description provided for @followNoVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune navigation à suivre pour le moment.'**
  String get followNoVoyage;

  /// No description provided for @followFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Suiveurs'**
  String get followFollowers;

  /// No description provided for @followSosContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts SOS'**
  String get followSosContacts;

  /// No description provided for @followBoatSheet.
  ///
  /// In fr, this message translates to:
  /// **'Fiche du bateau'**
  String get followBoatSheet;

  /// No description provided for @followSosAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes SOS de la navigation'**
  String get followSosAlerts;

  /// No description provided for @followNoPosition.
  ///
  /// In fr, this message translates to:
  /// **'Aucune position reçue.'**
  String get followNoPosition;

  /// No description provided for @followLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Navigation inaccessible : vérifiez la connexion, ou l\'accès a été retiré.'**
  String get followLoadError;

  /// No description provided for @followListen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get followListen;

  /// No description provided for @followStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get followStop;

  /// No description provided for @followFileMissing.
  ///
  /// In fr, this message translates to:
  /// **'Fichier pas encore reçu par le serveur.'**
  String get followFileMissing;

  /// No description provided for @followWebPage.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la page Web de la navigation'**
  String get followWebPage;

  /// No description provided for @followUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour à {time}'**
  String followUpdated(String time);

  /// No description provided for @boatHomePort.
  ///
  /// In fr, this message translates to:
  /// **'Port d\'attache'**
  String get boatHomePort;

  /// No description provided for @boatLength.
  ///
  /// In fr, this message translates to:
  /// **'Longueur'**
  String get boatLength;

  /// No description provided for @boatRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Immatriculation'**
  String get boatRegistration;

  /// No description provided for @boatEngine.
  ///
  /// In fr, this message translates to:
  /// **'Moteur'**
  String get boatEngine;

  /// No description provided for @boatDraft.
  ///
  /// In fr, this message translates to:
  /// **'Tirant d\'eau'**
  String get boatDraft;

  /// No description provided for @scopeThisVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Cette navigation seulement'**
  String get scopeThisVoyage;

  /// No description provided for @addPersonPending.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact, enregistré au démarrage'**
  String get addPersonPending;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @languagePhone.
  ///
  /// In fr, this message translates to:
  /// **'Langue du téléphone'**
  String get languagePhone;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English (anglais)'**
  String get languageEnglish;

  /// No description provided for @destinationOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Choisir sur la carte'**
  String get destinationOnMap;

  /// No description provided for @destinationMapHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez la carte pour placer la destination.'**
  String get destinationMapHint;

  /// No description provided for @destinationPoint.
  ///
  /// In fr, this message translates to:
  /// **'Point choisi : {position}'**
  String destinationPoint(String position);

  /// No description provided for @destinationRemovePoint.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le point'**
  String get destinationRemovePoint;

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @eventEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get eventEdit;

  /// No description provided for @eventDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get eventDelete;

  /// No description provided for @eventDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cet élément du journal ?'**
  String get eventDeleteConfirm;

  /// No description provided for @eventChangeOffline.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible sans Internet : réessayez au retour de la connexion.'**
  String get eventChangeOffline;

  /// No description provided for @eventFullLog.
  ///
  /// In fr, this message translates to:
  /// **'Voir dans le journal complet'**
  String get eventFullLog;

  /// No description provided for @subscribeDone.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement ouvert pour 10 ans : merci !'**
  String get subscribeDone;

  /// No description provided for @subscribeRefused.
  ///
  /// In fr, this message translates to:
  /// **'Paiement non confirmé : l\'abonnement n\'est pas ouvert.'**
  String get subscribeRefused;

  /// No description provided for @subscribeCanceled.
  ///
  /// In fr, this message translates to:
  /// **'Achat abandonné.'**
  String get subscribeCanceled;

  /// No description provided for @subscribePending.
  ///
  /// In fr, this message translates to:
  /// **'Paiement reçu par le magasin : l\'abonnement sera ouvert au retour de la connexion.'**
  String get subscribePending;

  /// No description provided for @subscribePrice.
  ///
  /// In fr, this message translates to:
  /// **'Souscrire l\'abonnement — {price}'**
  String subscribePrice(String price);

  /// No description provided for @pushTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications des navigations suivies'**
  String get pushTitle;

  /// No description provided for @pushStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de navigation'**
  String get pushStart;

  /// No description provided for @pushEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de navigation'**
  String get pushEnd;

  /// No description provided for @pushPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle photo'**
  String get pushPhoto;

  /// No description provided for @pushLate.
  ///
  /// In fr, this message translates to:
  /// **'Position en retard'**
  String get pushLate;

  /// No description provided for @pushSosAlways.
  ///
  /// In fr, this message translates to:
  /// **'Les alertes SOS sont toujours notifiées.'**
  String get pushSosAlways;

  /// No description provided for @inviteSmsSent.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée par SMS, avec la copie à votre numéro.'**
  String get inviteSmsSent;

  /// Heure envoyée aux suiveurs et contacts SOS (RG-PRM-07) : heure locale du téléphone, puis UTC.
  ///
  /// In fr, this message translates to:
  /// **'{local} ({utc} UTC)'**
  String timeWithUtc(String local, String utc);

  /// No description provided for @alertByEmail.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get alertByEmail;

  /// No description provided for @alertBySms.
  ///
  /// In fr, this message translates to:
  /// **'SMS'**
  String get alertBySms;

  /// No description provided for @weatherLink.
  ///
  /// In fr, this message translates to:
  /// **'Météo marine'**
  String get weatherLink;

  /// No description provided for @voyageEndingSending.
  ///
  /// In fr, this message translates to:
  /// **'Navigation terminée, en cours d\'envoi'**
  String get voyageEndingSending;

  /// No description provided for @homeSecurityRules.
  ///
  /// In fr, this message translates to:
  /// **'Règles de sécurité en mer'**
  String get homeSecurityRules;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à votre compte NautiLink'**
  String get loginSubtitle;

  /// No description provided for @showPassword.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get hidePassword;

  /// No description provided for @mapAttribution.
  ///
  /// In fr, this message translates to:
  /// **'Fond de carte © les contributeurs d\'OpenStreetMap · balisage © OpenSeaMap'**
  String get mapAttribution;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
