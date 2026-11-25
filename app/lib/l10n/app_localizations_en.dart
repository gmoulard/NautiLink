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
  String get rightsReserved => 'All rights reserved';

  @override
  String buildInfo(String version, String build, String commit) {
    return 'V$version · build $build · commit $commit';
  }

  @override
  String get buildLocal => 'local build';

  @override
  String buildCommit(String commit) {
    return 'Commit $commit';
  }

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

  @override
  String get betaBanner => 'Beta version';

  @override
  String offlineSince(String date) {
    return 'Offline · data from $date';
  }

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginButton => 'Sign in';

  @override
  String get password => 'Password';

  @override
  String get passwordMin => 'At least 8 characters';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get createAccount => 'Create an account';

  @override
  String get createAccountTitle => 'New account';

  @override
  String get createAccountButton => 'Create my account';

  @override
  String get continueGoogle => 'Continue with Google';

  @override
  String get continueApple => 'Continue with Apple';

  @override
  String get providerUnavailable =>
      'Google or Apple sign-in: not available yet.';

  @override
  String get loginOffline => 'Cannot sign in without Internet.';

  @override
  String get sessionExpired =>
      'Your session has expired: please sign in again.';

  @override
  String get errorGeneric => 'The server could not process the request.';

  @override
  String get fieldRequired => 'Required field';

  @override
  String get forgotTitle => 'Forgotten password';

  @override
  String get forgotText =>
      'Enter your account\'s e-mail address: you will receive a link, valid for 1 hour, to choose a new password.';

  @override
  String get forgotSend => 'Send me the link';

  @override
  String get forgotSent =>
      'If an account exists for this address, an e-mail has just been sent. The link is valid for 1 hour.';

  @override
  String get warningNewVersion =>
      'The warning has changed: read and accept it to continue.';

  @override
  String emailNotVerified(String email) {
    return 'Confirm your e-mail address ($email) with the link you received: until then, you can neither start a voyage nor invite anyone.';
  }

  @override
  String get resendLink => 'Send a new link';

  @override
  String get linkSent => 'Link sent.';

  @override
  String get logout => 'Sign out';

  @override
  String get quotaUnknown => 'Quota not yet received from the server';

  @override
  String quotaAsOf(String date) {
    return 'As of $date';
  }

  @override
  String quotaNextAt(String duration, String date) {
    return 'Next minutes recovered: $duration on $date.';
  }

  @override
  String voyageInProgress(String name) {
    return 'Voyage in progress: $name';
  }

  @override
  String get notYetAvailable => 'Not yet available in this version of the app.';

  @override
  String savedOffline(String date) {
    return 'Offline: last list received on $date';
  }

  @override
  String get noSavedVoyages => 'No saved voyages.';

  @override
  String get pageOffline =>
      'The voyage page will be available when the connection is back.';

  @override
  String get serverQueued =>
      'Server: waiting, sent when the connection is back';

  @override
  String get smsNotYet => 'SMS: not yet sent by this version of the app';

  @override
  String get voyageStarted => 'Voyage started';

  @override
  String get startRefused => 'Start refused';

  @override
  String startQuotaExhausted(String date) {
    return 'Free voyage quota used up: the voyage cannot start. Minutes will be available again on $date. You can also subscribe.';
  }

  @override
  String get startQuotaExhaustedNoDate =>
      'Free voyage quota used up: the voyage cannot start. Wait for minutes to become available again, or subscribe.';

  @override
  String get noBoatYet =>
      'No boat in your account: first create your boat on the web platform (\"Boats\").';

  @override
  String get locationTitle => 'Your position';

  @override
  String get locationExplain =>
      'NautiLink will ask for the phone\'s precise location. It is used for the voyage\'s automatic and manual positions and for the SOS, even without Internet. Without it, the voyage has no positions.';

  @override
  String get gpsUnavailable => 'GPS unavailable';

  @override
  String get noSosContact =>
      'You have no SOS contact: nobody will receive your SOS text messages. Add one to your contacts on the web platform.';

  @override
  String get noAlertablePerson => 'No follower or SOS contact.';

  @override
  String voyageRefused(String message) {
    return 'Refused by the server: $message';
  }

  @override
  String nextAutoPosition(String time) {
    return 'Next automatic position: $time';
  }

  @override
  String get sendRefused => 'Sending refused';

  @override
  String get micRefused =>
      'Microphone access refused: the voice note cannot be recorded.';

  @override
  String get recordingHintReal =>
      '1 minute at most, stops automatically. Your voice is sent as is, without transcription.';

  @override
  String get sosReelNoBoat =>
      'No boat in your account: NautiLink cannot send the alert. Alert the rescue services: VHF channel 16 or 196.';

  @override
  String get sosReelChooseBoat => 'Boat in distress';

  @override
  String get sosReelSearching => 'Looking for the position…';

  @override
  String get sosReelSending => 'Sending the alert to the server…';

  @override
  String get sosReelServerReceived =>
      'Server: alert received, e-mails sent to followers and SOS contacts';

  @override
  String get sosReelServerQueued =>
      'Server: alert kept on the phone, sent first when the connection is back';

  @override
  String get sosReelSmsOpened =>
      'Pre-filled SOS text message opened in the messaging app: tap \"Send\".';

  @override
  String get sosReelSmsFailed =>
      'The messaging app could not open: no SOS text message was sent.';

  @override
  String get sosReelSmsNoContact =>
      'No SOS contact with a number: no SOS text message.';

  @override
  String sosReelSmsLastKnown(String position, String date) {
    return 'Last known position, not necessarily the current one: $position on $date.';
  }

  @override
  String get sosReelSmsNoPosition => 'GPS unavailable: no known position.';

  @override
  String get sosReelSailboat => 'sailboat';

  @override
  String get sosReelMotorboat => 'motorboat';
}
