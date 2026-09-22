// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'Aura';

  @override
  String get common_continue => 'కొనసాగించండి';

  @override
  String get common_back => 'వెనక్కి';

  @override
  String get common_done => 'అయిపోయింది';

  @override
  String get common_notNow => 'ఇప్పుడు కాదు';

  @override
  String get common_cancel => 'రద్దు చేయండి';

  @override
  String get common_close => 'మూసివేయండి';

  @override
  String get common_comingSoon => 'త్వరలో వస్తుంది';

  @override
  String get help_button => 'నాకు ఇప్పుడే సహాయం కావాలి';

  @override
  String get help_title => 'సహాయం ఇక్కడే ఉంది';

  @override
  String get help_subtitle =>
      'దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. ఇప్పుడే ఎవరినైనా సంప్రదించండి, లేదా ఒక నిమిషం శ్వాస మీద ధ్యాస పెట్టండి.';

  @override
  String get help_crisisTitle => 'ఇప్పుడు చాలా భారంగా ఉన్నట్టుంది.';

  @override
  String get help_crisisSubtitle =>
      'దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీ చెక్-ఇన్ సేవ్ అయింది.';

  @override
  String get help_teleManas => 'Tele-MANAS · ఉచితం, 24×7';

  @override
  String get help_teleManasTollFree => 'Tele-MANAS టోల్-ఫ్రీ';

  @override
  String get help_emergency112 => 'అత్యవసరం';

  @override
  String get help_childline => 'Childline · 18 ఏళ్ల లోపు వారికి';

  @override
  String get help_us988 => 'Suicide & Crisis Lifeline · కాల్ లేదా మెసేజ్';

  @override
  String get help_otherEmergency =>
      'మీరు ఇప్పుడు ప్రమాదంలో ఉంటే, దయచేసి మీ ప్రాంతంలోని అత్యవసర నంబర్‌కు కాల్ చేయండి.';

  @override
  String help_callSemantic(String name, String number) {
    return '$nameకి కాల్ చేయండి, $number';
  }

  @override
  String get help_groundingTitle => 'అరవై సెకన్లు, మెల్లగా';

  @override
  String get help_groundingBody =>
      'ఈ వృత్తంతో పాటు శ్వాస తీసుకోండి. మిగతావన్నీ ఒక్క నిమిషం ఆగవచ్చు.';

  @override
  String get help_groundingStart => 'మొదలుపెట్టండి';

  @override
  String get help_groundingPause => 'ఆపండి';

  @override
  String get help_groundingResume => 'మళ్ళీ కొనసాగించండి';

  @override
  String get help_breatheIn => 'శ్వాస లోపలికి';

  @override
  String get help_breatheOut => 'శ్వాస బయటకు';

  @override
  String get help_ground1 => 'మీ పాదాలు నేలను తాకుతున్నట్టు గమనించండి.';

  @override
  String get help_ground2 => 'మీకు కనిపిస్తున్న ఐదు వస్తువులను గమనించండి.';

  @override
  String get help_ground3 => 'మీ చుట్టూ వినిపిస్తున్న మూడు శబ్దాలను గమనించండి.';

  @override
  String get help_ground4 => 'భుజాలను వదులుగా వదిలేయండి.';

  @override
  String get help_ground5 => 'మీరు ఇక్కడే ఉన్నారు. ఇప్పటికి అది చాలు.';

  @override
  String get help_groundingDone =>
      'బాగా చేశారు. మీకు కావలసినంత సేపు ఇక్కడే ఉండండి.';

  @override
  String help_secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds సెకన్లు మిగిలాయి',
      one: '1 సెకను మిగిలింది',
    );
    return '$_temp0';
  }

  @override
  String get help_disclaimer =>
      'Aura వైద్య పరికరం కాదు, అత్యవసర సేవ కూడా కాదు.';

  @override
  String get help_backToCheckin => 'నా చెక్-ఇన్‌కి తిరిగి వెళ్ళండి';

  @override
  String get welcome_title => 'Auraకి స్వాగతం';

  @override
  String get welcome_body =>
      'మీ మనసు ఎలా ఉందో ప్రశాంతంగా గమనించుకునే చోటు. మీ చెక్-ఇన్‌లు మీకు మాత్రమే, మీరు వచ్చిన ప్రతిసారీ మీ Aura కొంచెం పెరుగుతుంది.';

  @override
  String get welcome_begin => 'మొదలుపెడదాం';

  @override
  String get dob_title => 'మీ పుట్టినరోజు ఎప్పుడు?';

  @override
  String get dob_body =>
      'అందరినీ ఇదే అడుగుతాం. ఇది గోప్యంగా ఉంటుంది, ఎవరికీ కనిపించదు.';

  @override
  String get dob_day => 'రోజు';

  @override
  String get dob_month => 'నెల';

  @override
  String get dob_year => 'సంవత్సరం';

  @override
  String get dob_invalid => 'ఆ తేదీ ఉండదు. ఒకసారి చూసుకుంటారా?';

  @override
  String get dob_future => 'ఆ తేదీ ఇంకా రాలేదు. ఒకసారి చూసుకుంటారా?';

  @override
  String get blocked_title => 'Aura 13 ఏళ్లు, ఆ పైబడిన వారి కోసం.';

  @override
  String get blocked_body => 'అప్పుడు మిమ్మల్ని తప్పకుండా కలుస్తాం.';

  @override
  String get blocked_helpIndia =>
      'ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, Childline 1098కి ఉచితంగా కాల్ చేయండి. అత్యవసరమైతే 112కి కాల్ చేయండి.';

  @override
  String get blocked_helpOther =>
      'ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, మీరు నమ్మే పెద్దవాళ్ళతో మాట్లాడండి.';

  @override
  String get language_title => 'ఏ భాష మీకు సొంతంగా అనిపిస్తుంది?';

  @override
  String get language_body => 'దీన్ని సెట్టింగ్‌లలో ఎప్పుడైనా మార్చుకోవచ్చు.';

  @override
  String get language_teLatnHint => 'తెలుగు, ఇంగ్లీష్ అక్షరాల్లో';

  @override
  String get language_hiLatnHint => 'హిందీ, ఇంగ్లీష్ అక్షరాల్లో';

  @override
  String get language_beta => 'బీటా';

  @override
  String get signin_title => 'మీ Auraని భద్రంగా ఉంచండి';

  @override
  String get signin_body =>
      'మీ ఈమెయిల్‌తో సైన్ ఇన్ చేయండి, అప్పుడు కొత్త ఫోన్‌లో కూడా మీ Aura మీతోనే ఉంటుంది. పేరు, ఫోన్ నంబర్, పాస్‌వర్డ్ ఏవీ అక్కర్లేదు.';

  @override
  String get signin_emailLabel => 'ఈమెయిల్';

  @override
  String get signin_sendCode => 'నాకు కోడ్ పంపండి';

  @override
  String signin_codeSent(String email) {
    return '$emailకి 6 అంకెల కోడ్ పంపాం. ఆ ఈమెయిల్‌లోని లింక్‌ను కూడా నొక్కవచ్చు.';
  }

  @override
  String get signin_codeLabel => '6 అంకెల కోడ్';

  @override
  String get signin_verify => 'కొనసాగించండి';

  @override
  String get signin_resend => 'కొత్త కోడ్ పంపండి';

  @override
  String get signin_changeEmail => 'వేరే ఈమెయిల్ వాడండి';

  @override
  String get signin_error =>
      'అది జరగలేదు. మళ్ళీ ప్రయత్నించండి, లేదా వేరే విధంగా సైన్ ఇన్ చేయండి.';

  @override
  String get signin_codeExpired => 'ఈ కోడ్ గడువు ముగిసింది. కొత్తది పంపుతాం.';

  @override
  String get signin_invalidCode => 'ఆ కోడ్ సరిపోలలేదు. ఒకసారి చూసుకుంటారా?';

  @override
  String get signin_invalidEmail => 'ఆ ఈమెయిల్ సరిగ్గా ఉన్నట్టు లేదు.';

  @override
  String get signin_apple => 'Appleతో కొనసాగించండి';

  @override
  String get signin_google => 'Googleతో కొనసాగించండి';

  @override
  String get signin_offline =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. ముందు మీ మొదటి మూడ్ ఎంచుకోండి. కనెక్ట్ అయ్యాక మిగతా సెటప్ పూర్తి చేస్తాం.';

  @override
  String get signin_offlineContinue => 'ఇప్పుడే చెక్-ఇన్ చేయండి';

  @override
  String get signin_unavailable =>
      'ఈ బిల్డ్‌లో సైన్-ఇన్ ఇంకా సెట్ కాలేదు. ప్రస్తుతానికి మీ చెక్-ఇన్‌లు ఈ ఫోన్‌లోనే ఉంటాయి.';

  @override
  String get signin_continueLocal => 'ఈ ఫోన్‌లోనే కొనసాగించండి';

  @override
  String get checkin_title => 'మీకు ఇప్పుడు ఎలా అనిపిస్తోంది?';

  @override
  String get checkin_subtitle =>
      'దగ్గరగా ఉన్నదాన్ని ఎంచుకోండి. తప్పు సమాధానం అంటూ ఏదీ లేదు.';

  @override
  String get checkin_moreEnergy => 'ఎక్కువ శక్తి';

  @override
  String get checkin_lessEnergy => 'తక్కువ శక్తి';

  @override
  String get checkin_pleasant => 'హాయిగా';

  @override
  String get checkin_unpleasant => 'ఇబ్బందిగా';

  @override
  String get quadrant_storm => 'తుఫాను';

  @override
  String get quadrant_rain => 'వాన';

  @override
  String get quadrant_moonlight => 'వెన్నెల';

  @override
  String get quadrant_sunrise => 'సూర్యోదయం';

  @override
  String mood_semantic(
    String mood,
    String quadrant,
    String energy,
    String feel,
  ) {
    return '$mood, $quadrant గుంపు, $energy, $feel';
  }

  @override
  String get semantic_highEnergy => 'ఎక్కువ శక్తి';

  @override
  String get semantic_lowEnergy => 'తక్కువ శక్తి';

  @override
  String get semantic_pleasant => 'హాయిగా';

  @override
  String get semantic_unpleasant => 'ఇబ్బందిగా';

  @override
  String get checkin_addDetails => 'ఒక ట్యాగ్ లేదా కొన్ని మాటలు జోడించండి';

  @override
  String get checkin_tagsTitle => 'దేని గురించి?';

  @override
  String get tag_study => 'చదువు';

  @override
  String get tag_work => 'పని';

  @override
  String get tag_family => 'కుటుంబం';

  @override
  String get tag_friends => 'స్నేహితులు';

  @override
  String get tag_sleep => 'నిద్ర';

  @override
  String get tag_health => 'ఆరోగ్యం';

  @override
  String get tag_money => 'డబ్బు';

  @override
  String get tag_love => 'ప్రేమ';

  @override
  String get tag_alone => 'ఒంటరితనం';

  @override
  String get tag_commute => 'ప్రయాణం';

  @override
  String get checkin_customTag => 'మీ సొంత ట్యాగ్';

  @override
  String get checkin_customTagAdd => 'ట్యాగ్ జోడించండి';

  @override
  String get checkin_noteLabel => 'కావాలంటే, కొన్ని మాటలు';

  @override
  String get checkin_noteHint => 'ఇది మీరు మాత్రమే చదవగలరు.';

  @override
  String get checkin_save => 'సేవ్ చేయండి';

  @override
  String get checkin_saveFailed =>
      'దాన్ని సేవ్ చేయలేకపోయాం. మీ ఫోన్‌లో స్థలం తక్కువగా ఉండొచ్చు.';

  @override
  String checkin_savedStarlight(int amount) {
    return '+$amount Starlight';
  }

  @override
  String get checkin_saved => 'సేవ్ అయింది';

  @override
  String get checkin_savedOffline => 'ఈ ఫోన్‌లో సేవ్ అయింది';

  @override
  String get checkin_savedThanks => 'చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get checkin_savedFull =>
      'ఈరోజు Starlight అంతా సేకరించేశారు. మీ చెక్-ఇన్ ఇప్పటికీ లెక్కలోకి వస్తుంది.';

  @override
  String get checkin_roomButton => 'ఇలాగే అనిపిస్తున్నవాళ్ళ గదిలో చేరండి';

  @override
  String get home_checkIn => 'చెక్-ఇన్ చేయండి';

  @override
  String home_todayStarlight(int count) {
    return 'ఈరోజు $count Starlight';
  }

  @override
  String home_totalStarlight(int count) {
    return 'మొత్తం $count';
  }

  @override
  String get home_empty => 'ఇది మీ Aura. చెక్-ఇన్ చేసి దానికి వెలుగు ఇవ్వండి.';

  @override
  String get home_resting =>
      'మీ Aura కొంచెం విశ్రాంతి తీసుకుంటోంది. మీకు వీలైనప్పుడు ఒక్క హాయ్ చెప్పండి.';

  @override
  String home_glowStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వెలుగు వరుస · $count రోజులు',
      one: 'వెలుగు వరుస · 1 రోజు',
    );
    return '$_temp0';
  }

  @override
  String home_restDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count విశ్రాంతి రోజులు దాచి ఉన్నాయి',
      one: '1 విశ్రాంతి రోజు దాచి ఉంది',
      zero: 'ఇంకా విశ్రాంతి రోజులు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get home_restingSafe => 'విశ్రాంతి · మీ వెలుగు భద్రంగా ఉంది';

  @override
  String get home_glowCarriesOn => 'మీ వెలుగు కొనసాగుతుంది';

  @override
  String home_lifetimeGlow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'మొత్తం $count వెలుగు రోజులు',
      one: 'మొత్తం 1 వెలుగు రోజు',
    );
    return '$_temp0';
  }

  @override
  String get home_habitsTitle => 'ఈరోజు చిన్న చిన్న పనులు';

  @override
  String home_habitDone(String habit) {
    return '$habit, ఈరోజు అయింది';
  }

  @override
  String home_habitNotYet(String habit) {
    return '$habit, ఈరోజు ఇంకా లేదు';
  }

  @override
  String get home_offline =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. మీ విషయాలు ఇక్కడ సేవ్ అవుతూనే ఉంటాయి.';

  @override
  String get home_finishSetup =>
      'మీ Aura భద్రంగా ఉండటానికి సెటప్ పూర్తి చేయండి.';

  @override
  String get home_signIn => 'సైన్ ఇన్';

  @override
  String get home_syncIdle => 'అన్నీ సేవ్ అయ్యాయి';

  @override
  String home_syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సింక్ కోసం వేచి ఉన్నాయి',
      one: '1 సింక్ కోసం వేచి ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get home_syncLocal => 'ఈ ఫోన్‌లో సేవ్ అయింది';

  @override
  String get home_settings => 'సెట్టింగ్‌లు';

  @override
  String get home_welcomeBack => 'మళ్ళీ స్వాగతం. ఈరోజు ఒక్క చిన్న పని చాలు.';

  @override
  String home_evolved(String stage) {
    return 'మీ Aura $stageగా ఎదిగింది.';
  }

  @override
  String get stage_spark => 'రవ్వ';

  @override
  String get stage_ember => 'నిప్పు కణిక';

  @override
  String get stage_glow => 'వెలుగు';

  @override
  String get stage_radiance => 'తేజస్సు';

  @override
  String get stage_constellation => 'నక్షత్ర మండలం';

  @override
  String get habit_hydrate => 'నీళ్ళు';

  @override
  String get habit_sleep_on_time => 'సమయానికి నిద్ర';

  @override
  String get habit_move => 'కదలిక';

  @override
  String get habit_breathe => 'శ్వాస';

  @override
  String get habit_journal => 'డైరీ';

  @override
  String get habit_go_outside => 'బయటికి';

  @override
  String avatar_semantic(String stage, String hue) {
    return 'మీ Aura, $stage దశ, $hue వెలుగు';
  }

  @override
  String get avatar_semanticResting =>
      'మెత్తని నెబ్యులాలో విశ్రాంతి తీసుకుంటోంది';

  @override
  String avatar_semanticRings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'చుట్టూ తిరిగే $count వెలుగులు',
      one: 'చుట్టూ తిరిగే ఒక వెలుగు',
    );
    return '$_temp0';
  }

  @override
  String avatar_semanticStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'నక్షత్ర మండలంలో $count నక్షత్రాలు',
      one: 'నక్షత్ర మండలంలో ఒక నక్షత్రం',
    );
    return '$_temp0';
  }

  @override
  String get hue_gold => 'బంగారు';

  @override
  String get hue_green => 'ఆకుపచ్చ';

  @override
  String get hue_teal => 'నీలి-ఆకుపచ్చ';

  @override
  String get hue_silverBlue => 'వెండి-నీలి';

  @override
  String get hue_violet => 'ఊదా';

  @override
  String get hue_rose => 'గులాబీ';

  @override
  String get settings_title => 'సెట్టింగ్‌లు';

  @override
  String get settings_language => 'భాష';

  @override
  String get settings_account => 'ఖాతా';

  @override
  String settings_signedInAs(String email) {
    return '$emailతో సైన్ ఇన్ అయ్యారు';
  }

  @override
  String get settings_signOut => 'సైన్ అవుట్';

  @override
  String settings_signOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count విషయాలు ఇంకా సింక్ కాలేదు. అవి అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?',
      one: '1 విషయం ఇంకా సింక్ కాలేదు. అది అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?',
    );
    return '$_temp0';
  }

  @override
  String get settings_stay => 'సైన్ ఇన్‌లోనే ఉంటాను';

  @override
  String get settings_signOutAnyway => 'అయినా సైన్ అవుట్ చేయండి';

  @override
  String get settings_signIn => 'మీ Auraని భద్రంగా ఉంచడానికి సైన్ ఇన్ చేయండి';

  @override
  String get settings_avatarLab => 'Avatar lab';

  @override
  String get settings_about => 'గురించి';

  @override
  String settings_version(String version) {
    return 'వెర్షన్ $version';
  }

  @override
  String get push_title => 'ప్రతి సాయంత్రం ఒక మృదువైన గుర్తు కావాలా?';

  @override
  String get push_body =>
      'రోజుకు ఒక్కటి మాత్రమే, streaks గురించి ఎప్పుడూ కాదు. మీరు ఎలా ఫీల్ అవుతున్నారో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.';

  @override
  String get push_allow => 'అనుమతించండి';

  @override
  String get legal_privacy => 'గోప్యతా విధానం';

  @override
  String get legal_terms => 'వినియోగ నిబంధనలు';

  @override
  String get legal_opensInBrowser => 'మీ బ్రౌజర్‌లో తెరుచుకుంటుంది';
}

/// The translations for Telugu, using the Latin script (`te_Latn`).
class AppLocalizationsTeLatn extends AppLocalizationsTe {
  AppLocalizationsTeLatn() : super('te_Latn');

  @override
  String get appTitle => 'Aura';

  @override
  String get common_continue => 'Continue cheyandi';

  @override
  String get common_back => 'Venakki';

  @override
  String get common_done => 'Aipoyindi';

  @override
  String get common_notNow => 'Ippudu kaadu';

  @override
  String get common_cancel => 'Cancel cheyandi';

  @override
  String get common_close => 'Close cheyandi';

  @override
  String get common_comingSoon => 'Tvaralo vastundi';

  @override
  String get help_button => 'Naaku ippude help kaavali';

  @override
  String get help_title => 'Help ikkade undi';

  @override
  String get help_subtitle =>
      'Idi meeru okkare moyyalsina avasaram ledu. Ippude evarinaina contact cheyandi, leda oka nimisham breath meeda dhyaasa pettandi.';

  @override
  String get help_crisisTitle => 'Ippudu chaala bhaaranga unnattundi.';

  @override
  String get help_crisisSubtitle =>
      'Idi meeru okkare moyyalsina avasaram ledu. Mee check-in save ayyindi.';

  @override
  String get help_teleManas => 'Tele-MANAS · free, 24×7';

  @override
  String get help_teleManasTollFree => 'Tele-MANAS toll-free';

  @override
  String get help_emergency112 => 'Emergency';

  @override
  String get help_childline => 'Childline · 18 ella lopu vaallaki';

  @override
  String get help_us988 => 'Suicide & Crisis Lifeline · call leda text';

  @override
  String get help_otherEmergency =>
      'Meeru ippudu danger lo unte, dayachesi mee local emergency number ki call cheyandi.';

  @override
  String help_callSemantic(String name, String number) {
    return '$name ki call cheyandi, $number';
  }

  @override
  String get help_groundingTitle => 'Sixty seconds, mellaga';

  @override
  String get help_groundingBody =>
      'Ee circle tho paatu breathe cheyandi. Migathavanni oka nimisham aagochu.';

  @override
  String get help_groundingStart => 'Start cheyandi';

  @override
  String get help_groundingPause => 'Aapandi';

  @override
  String get help_groundingResume => 'Malli continue cheyandi';

  @override
  String get help_breatheIn => 'Lopaliki breathe cheyandi';

  @override
  String get help_breatheOut => 'Bayataki vadalandi';

  @override
  String get help_ground1 => 'Mee paadaalu nelani taakutunnattu gamaninchandi.';

  @override
  String get help_ground2 =>
      'Meeku kanipistunna aidu vastuvulni gamaninchandi.';

  @override
  String get help_ground3 =>
      'Mee chuttu vinipistunna moodu sounds gamaninchandi.';

  @override
  String get help_ground4 => 'Bhujaalu loose ga vadileyandi.';

  @override
  String get help_ground5 => 'Meeru ikkade unnaru. Ippatiki adi chaalu.';

  @override
  String get help_groundingDone =>
      'Baaga chesaru. Meeku kaavalsinanta sepu ikkade undandi.';

  @override
  String help_secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds migilaayi',
      one: '1 second migilindi',
    );
    return '$_temp0';
  }

  @override
  String get help_disclaimer =>
      'Aura medical device kaadu, emergency service kooda kaadu.';

  @override
  String get help_backToCheckin => 'Naa check-in ki tirigi vellandi';

  @override
  String get welcome_title => 'Aura ki swaagatam';

  @override
  String get welcome_body =>
      'Mee manasu ela undo prashaanthanga gamaninchukune chotu. Mee check-ins private ga untaayi, meeru vachina prati saari mee Aura konchem perugutundi.';

  @override
  String get welcome_begin => 'Modalupedadam';

  @override
  String get dob_title => 'Mee birthday eppudu?';

  @override
  String get dob_body =>
      'Andarini ide adugutaam. Idi private ga untundi, evariki kanipinchadu.';

  @override
  String get dob_day => 'Roju';

  @override
  String get dob_month => 'Nela';

  @override
  String get dob_year => 'Samvatsaram';

  @override
  String get dob_invalid => 'Aa date undadu. Okasari choosukuntaara?';

  @override
  String get dob_future => 'Aa date inka raaledu. Okasari choosukuntaara?';

  @override
  String get blocked_title => 'Aura 13 ella paiga unna vaalla kosam.';

  @override
  String get blocked_body => 'Appudu mimmalni tappakunda kalustaam.';

  @override
  String get blocked_helpIndia =>
      'Ippude evaritho ainaa maatlaadaalanipiste, Childline 1098 ki free ga call cheyandi. Emergency aite 112 ki call cheyandi.';

  @override
  String get blocked_helpOther =>
      'Ippude evaritho ainaa maatlaadaalanipiste, meeru namme peddavaalla tho maatlaadandi.';

  @override
  String get language_title => 'Ye bhaasha meeku sontham anipistundi?';

  @override
  String get language_body => 'Deenni Settings lo eppudaina maarchukovachu.';

  @override
  String get language_teLatnHint => 'Telugu, English aksharaallo';

  @override
  String get language_hiLatnHint => 'Hindi, English aksharaallo';

  @override
  String get language_beta => 'Beta';

  @override
  String get signin_title => 'Mee Aura ni safe ga unchandi';

  @override
  String get signin_body =>
      'Mee email tho sign in cheyandi, appudu kotta phone lo kooda mee Aura meetho untundi. Peru, phone number, password edee akkarledu.';

  @override
  String get signin_emailLabel => 'Email';

  @override
  String get signin_sendCode => 'Naaku code pampandi';

  @override
  String signin_codeSent(String email) {
    return '$email ki 6-digit code pampaam. Aa email lo unna link ni kooda tap cheyochu.';
  }

  @override
  String get signin_codeLabel => '6-digit code';

  @override
  String get signin_verify => 'Continue cheyandi';

  @override
  String get signin_resend => 'Kotta code pampandi';

  @override
  String get signin_changeEmail => 'Vere email vaadandi';

  @override
  String get signin_error =>
      'Adi jaragaledu. Malli try cheyandi, leda vere vidhamga sign in cheyandi.';

  @override
  String get signin_codeExpired => 'Ee code time aipoyindi. Kottadi pamputaam.';

  @override
  String get signin_invalidCode =>
      'Aa code match avvaledu. Okasari choosukuntaara?';

  @override
  String get signin_invalidEmail => 'Aa email correct ga unnattu ledu.';

  @override
  String get signin_apple => 'Apple tho continue cheyandi';

  @override
  String get signin_google => 'Google tho continue cheyandi';

  @override
  String get signin_offline =>
      'Meeru offline lo unnaru. Mundu mee first mood select cheyandi. Connect ayyaaka migataa setup complete chestaam.';

  @override
  String get signin_offlineContinue => 'Ippude check-in cheyandi';

  @override
  String get signin_unavailable =>
      'Ee build lo sign-in inka set avvaledu. Prastutaaniki mee check-ins ee phone lone untaayi.';

  @override
  String get signin_continueLocal => 'Ee phone lone continue cheyandi';

  @override
  String get checkin_title => 'Meeku ippudu ela anipistondi?';

  @override
  String get checkin_subtitle =>
      'Daggaraga unnadi select cheyandi. Tappu answer antu edi ledu.';

  @override
  String get checkin_moreEnergy => 'Ekkuva energy';

  @override
  String get checkin_lessEnergy => 'Takkuva energy';

  @override
  String get checkin_pleasant => 'Haayiga';

  @override
  String get checkin_unpleasant => 'Ibbandiga';

  @override
  String get quadrant_storm => 'Storm';

  @override
  String get quadrant_rain => 'Rain';

  @override
  String get quadrant_moonlight => 'Moonlight';

  @override
  String get quadrant_sunrise => 'Sunrise';

  @override
  String mood_semantic(
    String mood,
    String quadrant,
    String energy,
    String feel,
  ) {
    return '$mood, $quadrant group, $energy, $feel';
  }

  @override
  String get semantic_highEnergy => 'ekkuva energy';

  @override
  String get semantic_lowEnergy => 'takkuva energy';

  @override
  String get semantic_pleasant => 'haayiga';

  @override
  String get semantic_unpleasant => 'ibbandiga';

  @override
  String get checkin_addDetails => 'Oka tag leda konni maatalu add cheyandi';

  @override
  String get checkin_tagsTitle => 'Deeni gurinchi?';

  @override
  String get tag_study => 'Chaduvu';

  @override
  String get tag_work => 'Pani';

  @override
  String get tag_family => 'Family';

  @override
  String get tag_friends => 'Friends';

  @override
  String get tag_sleep => 'Nidra';

  @override
  String get tag_health => 'Health';

  @override
  String get tag_money => 'Dabbu';

  @override
  String get tag_love => 'Prema';

  @override
  String get tag_alone => 'Ontaritanam';

  @override
  String get tag_commute => 'Prayaanam';

  @override
  String get checkin_customTag => 'Mee sontha tag';

  @override
  String get checkin_customTagAdd => 'Tag add cheyandi';

  @override
  String get checkin_noteLabel => 'Kaavaalante, konni maatalu';

  @override
  String get checkin_noteHint => 'Idi meeru maatrame chadavagalaru.';

  @override
  String get checkin_save => 'Save cheyandi';

  @override
  String get checkin_saveFailed =>
      'Daanni save cheyalekapoyaam. Mee phone lo space takkuva undochu.';

  @override
  String checkin_savedStarlight(int amount) {
    return '+$amount Starlight';
  }

  @override
  String get checkin_saved => 'Save ayyindi';

  @override
  String get checkin_savedOffline => 'Ee phone lo save ayyindi';

  @override
  String get checkin_savedThanks => 'Check-in chesinanduku thanks.';

  @override
  String get checkin_savedFull =>
      'Ee roju Starlight antaa sekarinchesaaru. Mee check-in ippatiki count avutundi.';

  @override
  String get checkin_roomButton => 'Ilaane anipistunna vaalla room lo cherandi';

  @override
  String get home_checkIn => 'Check in cheyandi';

  @override
  String home_todayStarlight(int count) {
    return 'Ee roju $count Starlight';
  }

  @override
  String home_totalStarlight(int count) {
    return 'Mottham $count';
  }

  @override
  String get home_empty =>
      'Idi mee Aura. Check in chesi daaniki velugu ivvandi.';

  @override
  String get home_resting =>
      'Mee Aura konchem rest teesukuntondi. Meeku veelainappudu oka hi cheppandi.';

  @override
  String home_glowStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Glow streak · $count rojulu',
      one: 'Glow streak · 1 roju',
    );
    return '$_temp0';
  }

  @override
  String home_restDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rest days daachi unnaayi',
      one: '1 rest day daachi undi',
      zero: 'Inka rest days levu',
    );
    return '$_temp0';
  }

  @override
  String get home_restingSafe => 'Rest · mee glow safe ga undi';

  @override
  String get home_glowCarriesOn => 'Mee glow continue avutundi';

  @override
  String home_lifetimeGlow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mottham $count glow days',
      one: 'Mottham 1 glow day',
    );
    return '$_temp0';
  }

  @override
  String get home_habitsTitle => 'Ee roju chinna chinna panulu';

  @override
  String home_habitDone(String habit) {
    return '$habit, ee roju ayyindi';
  }

  @override
  String home_habitNotYet(String habit) {
    return '$habit, ee roju inka ledu';
  }

  @override
  String get home_offline =>
      'Meeru offline lo unnaru. Mee vishayaalu ikkada save avtune untaayi.';

  @override
  String get home_finishSetup =>
      'Mee Aura safe ga undadaaniki setup complete cheyandi.';

  @override
  String get home_signIn => 'Sign in';

  @override
  String get home_syncIdle => 'Anni save ayyaayi';

  @override
  String home_syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sync kosam wait chestunnaayi',
      one: '1 sync kosam wait chestondi',
    );
    return '$_temp0';
  }

  @override
  String get home_syncLocal => 'Ee phone lo save ayyindi';

  @override
  String get home_settings => 'Settings';

  @override
  String get home_welcomeBack =>
      'Malli swaagatam. Ee roju oka chinna pani chaalu.';

  @override
  String home_evolved(String stage) {
    return 'Mee Aura $stage ga edigindi.';
  }

  @override
  String get stage_spark => 'Spark';

  @override
  String get stage_ember => 'Ember';

  @override
  String get stage_glow => 'Glow';

  @override
  String get stage_radiance => 'Radiance';

  @override
  String get stage_constellation => 'Constellation';

  @override
  String get habit_hydrate => 'Neellu';

  @override
  String get habit_sleep_on_time => 'Time ki nidra';

  @override
  String get habit_move => 'Kadalika';

  @override
  String get habit_breathe => 'Breathe';

  @override
  String get habit_journal => 'Journal';

  @override
  String get habit_go_outside => 'Bayataki';

  @override
  String avatar_semantic(String stage, String hue) {
    return 'Mee Aura, $stage stage, $hue glow';
  }

  @override
  String get avatar_semanticResting => 'mettani nebula lo rest teesukuntondi';

  @override
  String avatar_semanticRings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'chuttu tirige $count velugulu',
      one: 'chuttu tirige oka velugu',
    );
    return '$_temp0';
  }

  @override
  String avatar_semanticStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'constellation lo $count stars',
      one: 'constellation lo oka star',
    );
    return '$_temp0';
  }

  @override
  String get hue_gold => 'bangaaru';

  @override
  String get hue_green => 'aakupacha';

  @override
  String get hue_teal => 'teal';

  @override
  String get hue_silverBlue => 'silver-blue';

  @override
  String get hue_violet => 'violet';

  @override
  String get hue_rose => 'gulaabi';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_language => 'Bhaasha';

  @override
  String get settings_account => 'Account';

  @override
  String settings_signedInAs(String email) {
    return '$email tho sign in ayyaru';
  }

  @override
  String get settings_signOut => 'Sign out';

  @override
  String settings_signOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vishayaalu inka sync avvaledu. Avi ayye varaku sign in lone untaara?',
      one: '1 vishayam inka sync avvaledu. Adi ayye varaku sign in lone untaara?',
    );
    return '$_temp0';
  }

  @override
  String get settings_stay => 'Sign in lone untaanu';

  @override
  String get settings_signOutAnyway => 'Ayinaa sign out cheyandi';

  @override
  String get settings_signIn =>
      'Mee Aura ni safe ga unchadaaniki sign in cheyandi';

  @override
  String get settings_avatarLab => 'Avatar lab';

  @override
  String get settings_about => 'Gurinchi';

  @override
  String settings_version(String version) {
    return 'Version $version';
  }

  @override
  String get push_title => 'Prati saayantram oka gentle nudge kaavaalaa?';

  @override
  String get push_body =>
      'Rojuki okkate, streaks gurinchi eppudu kaadu. Meeru ela feel avutunnaro mee lock screen eppudu cheppadu.';

  @override
  String get push_allow => 'Allow cheyandi';

  @override
  String get legal_privacy => 'Privacy policy';

  @override
  String get legal_terms => 'Terms of use';

  @override
  String get legal_opensInBrowser => 'Mee browser lo open avutundi';
}
