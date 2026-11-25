// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NautiLink';

  @override
  String get demoBanner => 'Beta version · Demo: nothing is actually sent';

  @override
  String get sponsorText => 'Sponsored by the SRT';

  @override
  String get sponsorLogoLabel => 'SRT burgee';

  @override
  String buildCommit(String commit) {
    return 'Commit $commit';
  }

  @override
  String get buildLocal => 'Local build, no commit';

  @override
  String get footerSiteLink => 'NautiLink website';

  @override
  String get sosButton => 'Send an SOS';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get continueLabel => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get noVoyageInProgress => 'No voyage in progress.';

  @override
  String get logbook => 'Logbook';

  @override
  String distanceNm(String distance) {
    return '$distance nautical miles';
  }

  @override
  String get chooseTitle => 'NautiLink · demo';

  @override
  String get chooseQuestion => 'What would you like to try?';

  @override
  String get chooseNavigatorTitle => 'The skipper on board';

  @override
  String get chooseNavigatorText =>
      'The mobile app: start a voyage, send your position, take notes, trigger an SOS.';

  @override
  String get chooseFollowerTitle => 'The follower, on the web platform';

  @override
  String get chooseFollowerText =>
      'The dashboard: current and past voyages, track map, logbook.';

  @override
  String get warningTitle => 'Warning';

  @override
  String get warningHeading => 'Beta version and liability';

  @override
  String get warningSection1Title => '1. Beta version';

  @override
  String get warningSection1Body =>
      'NautiLink is currently offered as a beta version, that is, in a testing phase. Its features (position tracking, sending text messages and e-mails, SOS alerts, logbook) may suffer errors, delays or interruptions, due in particular to mobile network coverage, Internet access, GPS reception, or the state or settings of the phone. Continuity and accuracy of the service are not guaranteed during this phase.';

  @override
  String get warningSection2Title => '2. NautiLink is not safety equipment';

  @override
  String get warningSection2Body =>
      'NautiLink is not safety equipment within the meaning of maritime regulations. It replaces neither the mandatory safety equipment (VHF radio, signalling devices, distress beacon, etc.) nor the official alert procedures. In distress, first alert the rescue services on VHF channel 16, 196 or 112. An alert sent by NautiLink, or its failure to be sent, cannot be considered an alert to the rescue services.';

  @override
  String get warningSection3Title => '3. Skipper\'s responsibility';

  @override
  String get warningSection3Body =>
      'The skipper remains solely responsible for handling the vessel, the safety of the people on board, preparing the trip and complying with the regulations in force.';

  @override
  String get warningSection4Title => '4. Limitation of liability';

  @override
  String get warningSection4Body =>
      'To the fullest extent permitted by law, the publisher of NautiLink cannot be held liable for indirect damage resulting from a malfunction, interruption or unavailability of the service, or from use of the app that does not comply with its purpose or with this warning.\n\nThis limitation does not apply to personal injury, nor in the event of gross negligence or wilful misconduct by the publisher. It does not deprive users who are consumers of the rights granted to them by law, in particular the French Consumer Code, which cannot be waived.';

  @override
  String get warningAccept => 'I have read and accept this warning';

  @override
  String get menuContacts => 'Contacts';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuQuota => 'Quota and subscription';

  @override
  String get menuDashboard => 'Dashboard (Web)';

  @override
  String get homeFreeVersion => 'Free version - subscription';

  @override
  String homeFreeLeft(String duration) {
    return '$duration of free sailing left over the last 7 days';
  }

  @override
  String get startVoyage => 'Start voyage';

  @override
  String get resumeVoyage => 'Resume last voyage';

  @override
  String get savedVoyages => 'Saved voyages';

  @override
  String get homeDistressHint =>
      'In distress, first call on VHF channel 16 or 196.';

  @override
  String get homeSecurityMemo => 'Safety at sea memo';

  @override
  String get firstVoyageTitle => 'Before your first voyage';

  @override
  String get firstVoyageText =>
      'NautiLink is a beta version and is not safety equipment. In distress, first alert the rescue services on VHF channel 16 or 196.';

  @override
  String get understood => 'I understand';

  @override
  String get contactsDefault =>
      'By default, each contact is both a follower and an SOS contact.';

  @override
  String get roleFollower => 'Follower';

  @override
  String get roleSos => 'SOS contact';

  @override
  String get phoneRequired => 'Number required';

  @override
  String get defaultFrequency => 'Default frequency';

  @override
  String get sosAlwaysSent =>
      'SOS text messages are always sent, whatever these settings.';

  @override
  String get smsEnabled => 'Text messages on';

  @override
  String get quotaHeading => 'Free sailing: 24 h over the last 7 rolling days';

  @override
  String quotaUsed(String duration) {
    return 'Used: $duration';
  }

  @override
  String quotaLeft(String duration) {
    return 'Available: $duration';
  }

  @override
  String get quotaNextRecovery =>
      'Next recoverable minutes: 3 h 40 min in 4 days (voyage from early this week).';

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get subscriptionText =>
      'Unlimited sailing: €15 for 10 years, no automatic renewal. Following and viewing history remain free.';

  @override
  String get subscriptionMore => 'Learn more about the subscription';

  @override
  String get boat => 'Boat';

  @override
  String get destinationOptional => 'Destination (optional)';

  @override
  String get destinationHint => 'Address or place';

  @override
  String get personsOnBoard => 'People on board';

  @override
  String get onePersonLess => 'One person fewer';

  @override
  String get onePersonMore => 'One more person';

  @override
  String get autoFrequency => 'Automatic sending frequency';

  @override
  String get alertedPersons => 'People alerted';

  @override
  String get alertedRoleFollower => 'follower';

  @override
  String get alertedRoleSos => 'SOS contact';

  @override
  String get addPerson => 'Add a person';

  @override
  String get voyageSettings => 'Settings for this voyage';

  @override
  String get noSosChecked =>
      'No SOS contact checked: nobody will receive your SOS text messages.';

  @override
  String get sendStart => 'Send message – Start of voyage';

  @override
  String get addPersonText =>
      'The person joins your contacts, as follower and SOS contact by default, and will be alerted during this voyage.';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get email => 'E-mail';

  @override
  String get phoneNeededForSos =>
      'A phone number is needed to be an SOS contact.';

  @override
  String get add => 'Add';

  @override
  String get smsPrefilled => 'Text message prefilled for your followers';

  @override
  String get smsDisabled => 'Text messages off';

  @override
  String get serverSent => 'Server: sent';

  @override
  String get nothingReallySent => '(demo: nothing is actually sent)';

  @override
  String get voyageEnded => 'Voyage over?';

  @override
  String get stationaryText =>
      'You have not moved more than 20 metres in 2 hours.';

  @override
  String get endVoyage => 'End voyage';

  @override
  String get endVoyageQuestion => 'End the voyage?';

  @override
  String get end => 'End';

  @override
  String get validateSend => 'Send';

  @override
  String get demoMenu => 'Demo';

  @override
  String get demoStationary => 'Demo: simulate 2 h without moving';

  @override
  String get sinceStart => 'Since start';

  @override
  String get sinceLastSend => 'Since last send';

  @override
  String get sendPosition => 'Send position';

  @override
  String get positionSent => 'Position sent';

  @override
  String get noteButton => 'NOTE';

  @override
  String get noteTitle => 'Note';

  @override
  String get noteHint => 'Your note';

  @override
  String get noteSent => 'Note sent';

  @override
  String get photoButton => 'Photo';

  @override
  String get photoSent => 'Photo sent';

  @override
  String get voiceButton => 'Voice';

  @override
  String get voiceSent => 'Voice note sent';

  @override
  String get recording => 'Recording';

  @override
  String get recordingHint =>
      '1 minute at most. Your voice is sent as is, without transcription.';

  @override
  String get stopAndSend => 'Stop and send';

  @override
  String get photo => 'Photo';

  @override
  String samplePhoto(String time) {
    return '$time · sample photo';
  }

  @override
  String get listenVoice => 'Voice note playback';

  @override
  String get recordingDefault => 'Recording';

  @override
  String noSoundRecorded(String recording) {
    return '$recording\nDemo: no sound is recorded.';
  }

  @override
  String get sosQuestion => 'Send an SOS?';

  @override
  String get sosConfirmText =>
      'Your SOS contacts will receive your position and the boat\'s details. Also alert the rescue services: VHF channel 16 or 196.';

  @override
  String get sosProblem => 'Problem encountered (optional)';

  @override
  String get sosProblemHint => 'Leak, engine failure, injury…';

  @override
  String get sosConfirm => 'Confirm SOS';

  @override
  String get sosAlert => 'SOS alert';

  @override
  String get sosNoSmsSent => 'Demo: no text message was actually sent.';

  @override
  String sosSmsAccepted(String phone) {
    return 'SOS text message accepted for sending · $phone';
  }

  @override
  String get sosCopyNavigator => 'Copy to the skipper';

  @override
  String get sosCopyNavigatorDetail =>
      'Text message and e-mail in copy (RG-SMS-08, RG-NOT-03)';

  @override
  String get sosServer => 'Server';

  @override
  String get sosServerDetail => 'Alert received · e-mail to followers';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get filterAll => 'All';

  @override
  String get filterNavigator => 'As skipper';

  @override
  String get filterFollower => 'As follower';

  @override
  String get inProgress => 'In progress';

  @override
  String get history => 'History';

  @override
  String get live => 'Live';

  @override
  String voyageCardFollowed(String navigator) {
    return ' · followed ($navigator)';
  }

  @override
  String get infoDeparture => 'Departure';

  @override
  String get infoDeparturePlace => 'Departure place';

  @override
  String get infoWeatherStart => 'Weather at departure';

  @override
  String get infoArrival => 'Arrival';

  @override
  String get infoArrivalPlace => 'Arrival place';

  @override
  String get infoWeatherEnd => 'Weather at arrival';

  @override
  String get infoDestination => 'Destination';

  @override
  String get infoDuration => 'Duration';

  @override
  String get infoDistance => 'Distance';

  @override
  String get infoNavigator => 'Skipper';

  @override
  String get rename => 'Rename';

  @override
  String get renameVoyage => 'Rename voyage';

  @override
  String get exportPdf => 'Export to PDF';

  @override
  String get exportPdfSoon => 'PDF export: available in the real version.';

  @override
  String get me => 'Me';

  @override
  String get eventStart => 'Voyage start';

  @override
  String get eventAutoPosition => 'Automatic position';

  @override
  String get eventManualPosition => 'Position sent';

  @override
  String get eventNote => 'Note';

  @override
  String get eventPhoto => 'Photo';

  @override
  String get eventVoice => 'Voice note';

  @override
  String get eventSos => 'SOS alert';

  @override
  String get eventEnd => 'Voyage end';

  @override
  String eventFrequency(String frequency) {
    return 'Frequency: $frequency';
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
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String frequencyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
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
    return '$distance nm from $place';
  }

  @override
  String get smsTypeStart => 'Voyage start';

  @override
  String get smsTypeAutoPosition => 'Automatic positions';

  @override
  String get smsTypeManualPosition => 'Manual positions';

  @override
  String get smsTypeNote => 'Written notes';

  @override
  String get smsTypePhoto => 'Photos';

  @override
  String get smsTypeVoice => 'Voice notes';

  @override
  String get smsTypeEnd => 'Voyage end';

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
      other: '$count people on board.',
      one: '1 person on board.',
    );
    return '$_temp0';
  }

  @override
  String sosSmsProblem(String problem) {
    return 'Problem: $problem.';
  }

  @override
  String sosSmsPosition(String position, String time) {
    return 'Position $position at $time.';
  }
}
