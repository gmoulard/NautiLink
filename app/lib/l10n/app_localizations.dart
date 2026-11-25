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
  /// **'Version gratuite - abonnement'**
  String get homeFreeVersion;

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

  /// No description provided for @quotaNextRecovery.
  ///
  /// In fr, this message translates to:
  /// **'Prochaines minutes récupérables : 3 h 40 min dans 4 jours (navigation du début de semaine).'**
  String get quotaNextRecovery;

  /// No description provided for @subscriptionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionText.
  ///
  /// In fr, this message translates to:
  /// **'Navigation sans limite, au mois ou à l\'année. Prix à venir. Suivre et consulter l\'historique restent gratuits.'**
  String get subscriptionText;

  /// No description provided for @subscriptionMore.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus sur l\'abonnement'**
  String get subscriptionMore;

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
  /// **'Envoi message – Début de navigation'**
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
  /// **'Depuis le dernier envoi'**
  String get sinceLastSend;

  /// No description provided for @sendPosition.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer information position'**
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
