# Étude : notes vocales — format audio, durée, transcription en français

Action : [TODO-2.5](../TODO.md) · Question : [D-53](../07-decisions.md#d-53) · Règles : RG-JRN-04, RG-SMS-06, [D-07](../07-decisions.md#d-07).

**Depuis le 2026-11-25 ([D-71](../07-decisions.md#d-71)), la note vocale est un enregistrement seul, sans transcription : les parties sur la transcription ne servent plus.**

**Statut : recherche documentaire faite (novembre 2026). Les essais de transcription (taux d'erreur constaté) et le choix du format et de la durée restent à faire.** Rien de ce document n'est une décision.

## 1. Contraintes déjà décidées

- La note vocale est un enregistrement audio conservé sur le serveur avec sa transcription ; le navigateur valide la transcription **avant l'envoi** (RG-JRN-04, D-07).
- Le SMS d'une note vocale contient la transcription, pas l'audio (RG-SMS-06). En mer, il arrive qu'il y ait du réseau mobile sans Internet utilisable : pour envoyer ce SMS et faire valider la transcription sans Internet, **la transcription doit pouvoir se faire sur le téléphone, hors connexion**. Une transcription seulement sur le serveur obligerait à attendre Internet avant la validation et le SMS.

## 2. Format audio

| Format | Android (encodeur intégré) | iPhone | Remarques |
|--------|----------------------------|--------|-----------|
| AAC-LC dans MPEG-4 (`.m4a`) | Oui, toutes versions ; 8 à 48 kHz, mono ou stéréo ([formats Android](https://developer.android.com/media/platform/supported-formats)) | Oui (`kAudioFormatMPEG4AAC`, [Apple](https://developer.apple.com/documentation/coreaudiotypes/kaudioformatmpeg4aac)) avec `AVAudioRecorder` ([Apple](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)) | Même format sur les deux téléphones ; lecture courante dans les navigateurs Web (à vérifier pour le site). |
| Opus dans Ogg (`.ogg`) | Encodeur à partir d'Android 10 ([formats Android](https://developer.android.com/media/platform/supported-formats)) | Codec présent (`kAudioFormatOpus`, [Apple](https://developer.apple.com/documentation/coreaudiotypes/kaudioformatopus)) ; conteneur Ogg à vérifier | Plus compact à qualité égale pour la voix ; impose Android 10 minimum ([Q-31](../06-questions-ouvertes.md#q-31)). |
| AMR-NB / AMR-WB (`.3gp`, `.amr`) | Oui, toutes versions ; 4,75 à 23,85 kbit/s ([formats Android](https://developer.android.com/media/platform/supported-formats)) | Non vérifié | Très petit, qualité téléphonique ; mal lu par les navigateurs Web. |

**Taille** (calcul, mono) : à 32 kbit/s, une minute fait environ 240 ko ; à 64 kbit/s, environ 480 ko. Une note de 2 minutes en AAC à 32 kbit/s fait donc environ 0,5 Mo, à transmettre par Internet seulement (pas de MMS pour l'audio, RG-SMS-06).

## 3. Transcription en français

### 3.1 Sur le téléphone (hors connexion possible)

- **Android** : `SpeechRecognizer.createOnDeviceSpeechRecognizer()` (Android 12, API 31) crée un moteur sur l'appareil ; il échoue si `isOnDeviceRecognitionAvailable()` est faux. `checkRecognitionSupport()` et `triggerModelDownload()` (Android 13+) vérifient la langue et téléchargent le modèle ; l'erreur `ERROR_LANGUAGE_UNAVAILABLE` signale une langue prise en charge mais pas encore téléchargée. La documentation précise que l'API, souvent appuyée sur des serveurs, n'est pas faite pour une reconnaissance continue. Source : [SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer).
  - Conséquences : disponibilité selon le téléphone (moteur fourni par Google ou par le constructeur) ; le modèle français doit être téléchargé **avant le départ** ; la reconnaissance se fait pendant la dictée (flux micro), donc l'audio conservé et le texte doivent être captés en même temps (à vérifier au prototype).
- **iPhone** : `SFSpeechRecognizer` ; la reconnaissance hors connexion n'est possible que si `supportsOnDeviceRecognition` est vrai, et `requiresOnDeviceRecognition` empêche l'envoi de l'audio sur le réseau, avec une précision moindre selon Apple. Apple prévoit aussi une **limite d'une minute** par tâche de reconnaissance et des quotas journaliers par appareil et par application. Sources : [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer), [supportsOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [requiresOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).
  - API plus récente : `SpeechAnalyzer` avec le module `SpeechTranscriber` (modèles à installer sur l'appareil, `isAvailable` et `supportedLocales` à vérifier ; repli `DictationTranscriber`). Sources : [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer), [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber). Version d'iOS requise à vérifier.
- **Modèle embarqué dans l'application** (même moteur sur Android et iPhone) : par exemple Whisper (code et modèles sous licence MIT ; tailles de 39 M à 1 550 M paramètres ; les performances varient beaucoup selon la langue). Source : [openai/whisper](https://github.com/openai/whisper). Un petit modèle (`tiny`, `base`) tiendrait sur un téléphone ; précision en français, taille de l'application et temps de calcul à mesurer. Vosk propose aussi des modèles français légers (site [alphacephei.com/vosk/models](https://alphacephei.com/vosk/models) non joignable lors de la rédaction : à vérifier).

### 3.2 Sur le serveur (Internet requis)

- Whisper ou un service de transcription en ligne, appliqué à l'audio reçu. Meilleure précision attendue avec les grands modèles, mais incompatible avec une validation hors connexion avant l'envoi (§ 1). Pourrait servir de seconde transcription, à proposer au navigateur au retour de la connexion (non décidé).

## 4. Durée maximale

Aucune source n'impose de durée pour l'enregistrement lui-même. Deux limites techniques pèsent :

- la limite d'une minute par tâche de `SFSpeechRecognizer` sur iPhone (§ 3.1) ;
- la longueur du SMS de transcription (RG-SMS-06) : environ 150 mots par minute de parole, à confronter à la longueur des SMS (traitée avec [Q-12](../06-questions-ouvertes.md#q-12)).

## 5. Essais à faire (critères d'acceptation de TODO-2.5)

1. Corpus : une dizaine de phrases de navigation en français (caps, noms de ports, chiffres, vent), dites par deux voix, à bord ou avec bruit de vent et de moteur.
2. Moteurs : Android sur l'appareil (Pixel, Samsung), iPhone sur l'appareil, petit modèle Whisper embarqué, grand modèle Whisper sur serveur.
3. Mesure : taux d'erreur sur les mots (WER) par moteur, hors connexion et en ligne ; temps de transcription.

## 6. Questions pour l'utilisateur (non tranchées)

- Format : AAC `.m4a` (même format partout, toutes versions d'Android) ou Opus (plus compact, Android 10 minimum).
- Durée maximale d'une note : 1 minute (cohérente avec la limite iPhone et un SMS court), 2 minutes, ou 5 minutes.
- Moteur de transcription : celui du téléphone (gratuit, qualité variable selon l'appareil), un modèle embarqué identique sur Android et iPhone, ou le serveur (exige Internet avant validation).
