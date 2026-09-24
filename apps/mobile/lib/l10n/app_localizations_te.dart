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
  String get signin_busy => 'ఒక్క క్షణం';

  @override
  String signin_resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds సెకన్లలో కొత్త కోడ్ అడగవచ్చు',
      one: '1 సెకనులో కొత్త కోడ్ అడగవచ్చు',
    );
    return '$_temp0';
  }

  @override
  String get signin_freshSent => 'కొత్త కోడ్ వస్తోంది.';

  @override
  String get acct_pendingTitle => 'మీ ఖాతాను ఉంచుకుంటారా?';

  @override
  String acct_pendingBody(String date) {
    return 'మీ ఖాతా $dateన తొలగించబడేలా సెట్ అయి ఉంది. దాన్ని ఉంచుకుంటారా?';
  }

  @override
  String get acct_pendingBodySoon =>
      'మీ ఖాతా త్వరలో తొలగించబడేలా సెట్ అయి ఉంది. దాన్ని ఉంచుకుంటారా?';

  @override
  String get acct_keep => 'నా ఖాతాను ఉంచండి';

  @override
  String get acct_letGo => 'వదిలేయండి';

  @override
  String get acct_keepFailed =>
      'అది జరగలేదు, కాబట్టి ఇంకా ఏమీ మారలేదు. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.';

  @override
  String get acct_deleteTitle => 'నా ఖాతాను తొలగించండి';

  @override
  String get acct_deleteIntro => 'మీ ఖాతాను తొలగిస్తే ఇవి పోతాయి:';

  @override
  String get acct_itemCheckIns => 'మీ చెక్-ఇన్‌లు, నోట్స్';

  @override
  String get acct_itemHabits => 'మీ అలవాట్లు';

  @override
  String get acct_itemProgress => 'మీ Starlight, మీ Aura ఎదుగుదల';

  @override
  String get acct_itemAccount => 'మీ ఖాతా, మీరు సైన్ ఇన్ చేసే ఈమెయిల్';

  @override
  String get acct_grace =>
      'మనసు మార్చుకోవడానికి మీకు 7 రోజులు ఉన్నాయి. ఆలోపు మళ్ళీ సైన్ ఇన్ చేస్తే అన్నీ అలాగే ఉంటాయి. ఆ తర్వాత అది శాశ్వతంగా తొలగిపోతుంది, తిరిగి తీసుకురాలేం.';

  @override
  String get acct_store =>
      'మీరు App Store లేదా Google Play ద్వారా సబ్‌స్క్రిప్షన్ చెల్లిస్తుంటే, ఖాతాను తొలగించినా అది రద్దు కాదు. దాన్ని మీ స్టోర్ సబ్‌స్క్రిప్షన్ సెట్టింగ్‌లలో నిర్వహించండి లేదా రద్దు చేయండి.';

  @override
  String get acct_phone =>
      'ఈ ఫోన్‌లోని మీ డేటా వెంటనే క్లియర్ అవుతుంది, సైన్ అవుట్ అవుతుంది.';

  @override
  String get acct_needsConnection =>
      'ఖాతాను తొలగించడానికి ఇంటర్నెట్ కనెక్షన్ కావాలి. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.';

  @override
  String get acct_confirmTitle => 'మీ ఖాతాను తొలగించాలా?';

  @override
  String get acct_confirmBody =>
      'మీ ఖాతా, అందులోని ప్రతిదీ 7 రోజుల్లో తొలగించబడతాయి. దాన్ని ఉంచుకోవాలంటే ఆలోపు మళ్ళీ సైన్ ఇన్ చేయండి. ఈ ఫోన్ ఇప్పుడే క్లియర్ అవుతుంది.';

  @override
  String get acct_failed =>
      'అది జరగలేదు, ఏదీ తొలగించబడలేదు. కొద్దిసేపట్లో మళ్ళీ ప్రయత్నించండి.';

  @override
  String get acct_failedOffline =>
      'Auraని చేరుకోలేకపోయాం, ఏదీ తొలగించబడలేదు. మీ కనెక్షన్ చూసుకుని మళ్ళీ ప్రయత్నించండి.';

  @override
  String get acct_retry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get acct_scheduledTitle => 'మీ ఖాతా తొలగింపుకు సెట్ అయింది';

  @override
  String acct_scheduledBody(String date) {
    return 'అది $dateన తొలగించబడుతుంది. దాన్ని ఉంచుకోవాలంటే ఆలోపు మళ్ళీ సైన్ ఇన్ చేయండి.';
  }

  @override
  String get acct_phoneCleared => 'ఈ ఫోన్ క్లియర్ అయింది, సైన్ అవుట్ అయింది.';

  @override
  String get acct_signedOut =>
      'మీరు సైన్ ఇన్ చేయలేదు, కాబట్టి తొలగించడానికి ఖాతా లేదు. మీరు సేవ్ చేసినవి ఈ ఫోన్‌లో మాత్రమే ఉన్నాయి.';

  @override
  String get acct_unavailable => 'ఈ బిల్డ్‌లో ఖాతా తొలగింపు ఇంకా సెట్ కాలేదు.';

  @override
  String get set_comfort => 'సౌకర్యం';

  @override
  String get set_reduceMotion => 'కదలికలు తగ్గించండి';

  @override
  String get set_reduceMotionNote => 'మీ ఫోన్ సెట్టింగ్‌ను కూడా అనుసరిస్తుంది';

  @override
  String get set_haptics => 'వైబ్రేషన్ స్పందన';

  @override
  String get set_hapticsNote => 'మీరు ఏదైనా ఎంచుకున్నప్పుడు మెల్లని వైబ్రేషన్';

  @override
  String get set_hideStreak => 'వరుస సంఖ్యను దాచండి';

  @override
  String get set_hideStreakNote =>
      'మీ వెలుగు పెరుగుతూనే ఉంటుంది. హోమ్‌లో రోజుల లెక్క మాత్రం కనిపించదు.';

  @override
  String get set_signOutTitle => 'Aura నుండి సైన్ అవుట్ చేయాలా?';

  @override
  String get set_helpSafety => 'సహాయం & భద్రత';

  @override
  String get set_grievanceOfficer => 'ఫిర్యాదుల అధికారి';

  @override
  String get set_grievanceSubject => 'Aura గురించి ఫిర్యాదు';

  @override
  String get set_contactSupport => 'సపోర్ట్‌ను సంప్రదించండి';

  @override
  String get set_supportSubject => 'Aura సపోర్ట్';

  @override
  String get set_opensEmail => 'మీ ఈమెయిల్ యాప్ తెరుచుకుంటుంది';

  @override
  String set_emailFailed(String email) {
    return 'ఈమెయిల్ యాప్‌ను తెరవలేకపోయాం. మీరు $emailకి రాయవచ్చు.';
  }

  @override
  String get acct_inProgress =>
      'ఈ ఖాతా తొలగింపు ఇప్పటికే మొదలైంది, కాబట్టి దాన్ని ఇక ఉంచలేం. ఈ ఫోన్ క్లియర్ అయి సైన్ అవుట్ అవుతుంది.';

  @override
  String get signin_or => 'లేదా';

  @override
  String get signin_socialNotReady =>
      'ఆ సైన్-ఇన్ ఆప్షన్ ఇంకా సిద్ధంగా లేదు. ప్రస్తుతానికి మీ ఈమెయిల్ వాడండి.';

  @override
  String get signin_socialOffline =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నట్టున్నారు. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.';

  @override
  String get capsules_title => 'భవిష్యత్తులో మీరు';

  @override
  String get capsules_emptyBody =>
      'భవిష్యత్తులోని మీకు రాయండి. ఒక తేదీ కోసం, లేదా ఒక భావన కోసం దాచిపెట్టండి.';

  @override
  String get capsules_emptyCta => 'మీ మొదటి క్యాప్సూల్ దాచిపెట్టండి';

  @override
  String get capsules_new => 'ఒక క్యాప్సూల్ రాయండి';

  @override
  String capsules_entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count క్యాప్సూల్స్ దాచారు',
      one: '1 క్యాప్సూల్ దాచారు',
      zero: 'ఇంకా ఏదీ దాచలేదు',
    );
    return '$_temp0';
  }

  @override
  String capsules_entryReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count తెరవడానికి సిద్ధంగా ఉన్నాయి',
      one: '1 తెరవడానికి సిద్ధంగా ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get capsules_sectionReady => 'తెరవడానికి సిద్ధం';

  @override
  String get capsules_sectionSealed => 'దాచినవి';

  @override
  String get capsules_sectionOpened => 'తెరిచినవి';

  @override
  String capsules_sealedUntil(String date) {
    return '$date వరకు దాచి ఉంది. భద్రంగా ఉంటుంది.';
  }

  @override
  String get capsules_waitingFeeling => 'ఒక భావన కోసం ఎదురుచూస్తోంది';

  @override
  String get capsules_readyRow => 'మీరు సిద్ధమైనప్పుడు తెరవండి';

  @override
  String capsules_untitled(String date) {
    return '$date నాటి క్యాప్సూల్';
  }

  @override
  String get capsules_lockedTitle => 'దాచిన ఒక క్యాప్సూల్';

  @override
  String capsules_sealedOn(String date) {
    return '$dateన దాచారు';
  }

  @override
  String capsules_openedOn(String date) {
    return '$dateన తెరిచారు';
  }

  @override
  String get capsules_draftTitle => 'మీ డ్రాఫ్ట్ ఇక్కడే ఉంది';

  @override
  String get capsules_draftBody => 'ఆపిన చోటు నుండి కొనసాగించండి.';

  @override
  String get capsules_composeTitle => 'భవిష్యత్తులోని మీకు రాయండి';

  @override
  String get capsules_titleLabel => 'శీర్షిక';

  @override
  String get capsules_titleHelper =>
      'దాచి ఉన్నప్పుడు క్యాప్సూల్ మీద ఇది కనిపిస్తుంది.';

  @override
  String get capsules_textLabel => 'మీ నోట్';

  @override
  String get capsules_textHelper =>
      'ఇది తెరుచుకున్నప్పుడు మీరు మాత్రమే చదువుతారు.';

  @override
  String get capsules_photosTitle => 'ఫోటోలు';

  @override
  String get capsules_addPhoto => 'ఒక ఫోటో జోడించండి';

  @override
  String get capsules_photoHint => '3 వరకు. లొకేషన్, కెమెరా వివరాలు తీసేస్తాం.';

  @override
  String get capsules_photoAdding => 'మీ ఫోటో జోడిస్తున్నాం…';

  @override
  String get capsules_photoFailed =>
      'ఆ ఫోటోను జోడించలేకపోయాం. ఇంకొకటి ప్రయత్నించండి.';

  @override
  String capsules_photoRemove(int index) {
    return 'ఫోటో $index తీసేయండి';
  }

  @override
  String capsules_photoSemantic(int index, int count) {
    return '$countలో ఫోటో $index';
  }

  @override
  String get capsules_voiceHint =>
      '2 నిమిషాల వరకు. ఇది మీకు మాత్రమే వినిపిస్తుంది.';

  @override
  String get capsules_voiceLimit =>
      'రెండు నిమిషాలు పూర్తయ్యాయి, అందుకే రికార్డింగ్ ఆగింది. మీ వాయిస్ నోట్ సిద్ధంగా ఉంది.';

  @override
  String get capsules_unlockTitle => 'ఇది ఎప్పుడు తెరుచుకోవాలి?';

  @override
  String get capsules_unlockDate => 'ఒక తేదీన';

  @override
  String get capsules_unlockFeeling => 'ఒక భావన కోసం';

  @override
  String get capsules_pickDate => 'తేదీ ఎంచుకోండి';

  @override
  String get capsules_changeDate => 'తేదీ మార్చండి';

  @override
  String capsules_dateChosen(String date, String time) {
    return '$date $timeకి తెరుచుకుంటుంది';
  }

  @override
  String get capsules_dateHelp => 'ఒక వారం నుండి ఐదేళ్ల లోపు ఏ రోజైనా.';

  @override
  String get capsules_datePickerHelp => 'ఆ రోజు 10:00కి తెరుచుకుంటుంది';

  @override
  String get capsules_feelingHelp =>
      'దాచిన 24 గంటల తర్వాత నుండి, మీరు తదుపరి సారి ఇలా ఫీల్ అవుతూ చెక్-ఇన్ చేసినప్పుడు తెరుచుకోవచ్చు.';

  @override
  String capsules_anyQuadrant(String quadrant) {
    return 'ఏదైనా $quadrant భావన';
  }

  @override
  String capsules_feelingChosen(String feeling) {
    return 'దీని కోసం ఎదురుచూస్తుంది: $feeling';
  }

  @override
  String get capsules_seal => 'దాచిపెట్టండి';

  @override
  String get capsules_needContent =>
      'ముందు కొన్ని మాటలు, ఒక వాయిస్ నోట్ లేదా ఒక ఫోటో జోడించండి.';

  @override
  String get capsules_needUnlock => 'ఇది ఎప్పుడు తెరుచుకోవాలో ఎంచుకోండి.';

  @override
  String get capsules_sealFailed =>
      'ఇప్పుడు దాచలేకపోయాం. మీ క్యాప్సూల్ ఇక్కడే ఉంది. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get capsules_sealedTitle => 'దాచిపెట్టాం';

  @override
  String get capsules_sealedFeeling =>
      'దాచిపెట్టాం. ఆ భావన కోసం ఎదురుచూస్తుంది.';

  @override
  String get capsules_mediaLater =>
      'ఈ ఫోన్‌లో భద్రంగా దాచాం. మీరు ఆన్‌లైన్‌కి వచ్చాక ఫోటోలు, వాయిస్ బ్యాకప్ అవుతాయి.';

  @override
  String get capsules_limitBody =>
      'ఉచిత ఖాతాలో 3 మూడ్ క్యాప్సూల్స్ వరకు ఎదురుచూడగలవు. తేదీ క్యాప్సూల్స్‌కు పరిమితి లేదు.';

  @override
  String get capsules_limitPickDate => 'బదులుగా ఒక తేదీ ఎంచుకోండి';

  @override
  String get capsules_makeDate => 'దీన్ని తేదీ క్యాప్సూల్‌గా మార్చండి';

  @override
  String get capsules_leaveTitle => 'ఈ డ్రాఫ్ట్ ఉంచాలా?';

  @override
  String get capsules_leaveBody =>
      'మీరు దాన్ని దాచే వరకు లేదా వదిలేసే వరకు ఇది ఈ ఫోన్‌లోనే ఉంటుంది.';

  @override
  String get capsules_leaveEditing => 'రాయడం కొనసాగించండి';

  @override
  String get capsules_leaveKeep => 'డ్రాఫ్ట్ ఉంచండి';

  @override
  String get capsules_leaveDiscard => 'వదిలేయండి';

  @override
  String capsules_detailFeeling(String feeling) {
    return 'ఒక భావన కోసం ఎదురుచూస్తోంది: $feeling.';
  }

  @override
  String capsules_detailArming(String date) {
    return '$date నుండి తెరుచుకోవచ్చు.';
  }

  @override
  String get capsules_detailNoEarly =>
      'దాచిందంటే దాచిందే: దీన్ని ముందుగా తెరవలేరు, మార్చలేరు.';

  @override
  String get capsules_delete => 'క్యాప్సూల్ తొలగించండి';

  @override
  String get capsules_deleteTitle => 'ఈ క్యాప్సూల్ తొలగించాలా?';

  @override
  String get capsules_deleteBody => 'ఇది తెరవకుండానే శాశ్వతంగా పోతుంది.';

  @override
  String get capsules_deleteBodyOpened => 'ఇది శాశ్వతంగా పోతుంది.';

  @override
  String get capsules_deleteConfirm => 'తొలగించండి';

  @override
  String get capsules_deleteKeep => 'ఉంచండి';

  @override
  String get capsules_deleted => 'క్యాప్సూల్ తొలగించాం.';

  @override
  String get capsules_triggerTitle =>
      'ఇలాంటి క్షణం కోసం మీరు ఒక నోట్ రాసుకున్నారు. ఇప్పుడే తెరవాలా, తర్వాతా?';

  @override
  String get capsules_holdTitle =>
      'గతంలోని మీ నుండి ఒక నోట్ ఎదురుచూస్తోంది. ఇప్పుడే తెరవాలా, తర్వాతా?';

  @override
  String get capsules_now => 'ఇప్పుడే';

  @override
  String get capsules_later => 'తర్వాత';

  @override
  String get capsules_readyTitle => 'మీరు దాచుకున్నది ఇప్పుడు తెరవొచ్చు.';

  @override
  String capsules_readyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count క్యాప్సూల్స్ సిద్ధంగా ఉన్నాయి.',
      one: '1 క్యాప్సూల్ సిద్ధంగా ఉంది.',
    );
    return '$_temp0';
  }

  @override
  String get capsules_readyOpen => 'తెరవండి';

  @override
  String get capsules_channelName => 'క్యాప్సూల్స్';

  @override
  String get capsules_notifyAskTitle =>
      'ఇది ఎప్పుడు తెరుచుకుంటుందో తెలుసుకోవాలనుకుంటున్నారా?';

  @override
  String get capsules_notifyAskBody =>
      'అది తెరుచుకునే రోజు ఒక్క నిశ్శబ్ద సందేశం. లోపల ఏముందో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.';

  @override
  String get capsules_channelDescription =>
      'మీరు దాచుకున్నది తెరవడానికి సిద్ధమైనప్పుడు.';

  @override
  String get capsules_hardMoment =>
      'మీరు ఇది ఒక కష్టమైన సమయంలో రాశారు. మీరు సిద్ధమైనప్పుడు తెరవండి.';

  @override
  String get capsules_skip => 'దాటవేయండి';

  @override
  String get capsules_opening => 'మీ క్యాప్సూల్ తెరుచుకుంటోంది';

  @override
  String get capsules_openedTitle => 'గతంలోని మీ నుండి';

  @override
  String get capsules_keepNextTime => 'తర్వాతి సారి కోసం ఉంచండి';

  @override
  String get capsules_keptNextTime => 'ఇది మళ్ళీ ఆ భావన కోసం ఎదురుచూస్తుంది.';

  @override
  String get capsules_voiceOffline =>
      'మీ క్యాప్సూల్ తెరుచుకుంది. మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక వాయిస్ నోట్ వస్తుంది.';

  @override
  String get capsules_photosOffline =>
      'మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక ఫోటోలు వస్తాయి.';

  @override
  String get capsules_mediaFailed =>
      'ఇది ఇప్పుడు లోడ్ కాలేదు. కాసేపాగి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get capsules_retry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get capsules_cantRead =>
      'ఈ క్యాప్సూల్‌ను ఈ ఫోన్‌లో ఇంకా చదవలేం. మీరు ఆన్‌లైన్‌కి వచ్చాక తెరుచుకుంటుంది.';

  @override
  String capsules_accountDeletionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'దాచిన $count క్యాప్సూల్స్ పోతాయి.',
      one: 'దాచిన 1 క్యాప్సూల్ పోతుంది.',
    );
    return '$_temp0';
  }

  @override
  String get checkin_discardTitle => 'సేవ్ చేయకుండా వెళ్ళిపోతారా?';

  @override
  String get checkin_discardKeep => 'ఇక్కడే కొనసాగిస్తాను';

  @override
  String get checkin_discardConfirm => 'వదిలేయండి';

  @override
  String checkin_tagLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ట్యాగ్‌ల వరకు',
      one: '1 ట్యాగ్ వరకు',
    );
    return '$_temp0';
  }

  @override
  String checkin_quadrantAxes(String energy, String feel) {
    return '$energy · $feel';
  }

  @override
  String get history_title => 'మీ చెక్-ఇన్‌లు';

  @override
  String get history_private => 'ఇవి మీకు మాత్రమే కనిపిస్తాయి.';

  @override
  String get history_empty =>
      'ఇక్కడ ఇంకా ఏమీ లేదు. మీ చెక్-ఇన్‌లు ఇక్కడ చేరుతాయి, అవి మీకు మాత్రమే కనిపిస్తాయి.';

  @override
  String get history_today => 'ఈరోజు';

  @override
  String get history_yesterday => 'నిన్న';

  @override
  String history_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ట్యాగ్‌లు',
      one: '1 ట్యాగ్',
    );
    return '$_temp0';
  }

  @override
  String get history_hasNote => 'ఒక నోట్ ఉంది';

  @override
  String get history_entryTitle => 'మీ చెక్-ఇన్';

  @override
  String history_when(String day, String time) {
    return '$day, $time';
  }

  @override
  String get history_tags => 'ట్యాగ్‌లు';

  @override
  String get history_note => 'మీ మాటలు';

  @override
  String get history_synced => 'సింక్ అయింది';

  @override
  String get history_edit => 'మార్చండి';

  @override
  String get history_editWindowOver =>
      'చెక్-ఇన్ చేసిన ఒక రోజు వరకు దాన్ని మార్చుకోవచ్చు.';

  @override
  String get history_delete => 'తొలగించండి';

  @override
  String get history_deleteTitle => 'ఈ చెక్-ఇన్‌ను తొలగించాలా?';

  @override
  String get history_deleteBody =>
      'దీనివల్ల మీ Starlight గానీ వెలుగు రోజులు గానీ మారవు.';

  @override
  String get history_missing => 'ఈ చెక్-ఇన్ ఇప్పుడు ఇక్కడ లేదు.';

  @override
  String get history_editNoteLocked =>
      'ఈ చెక్-ఇన్ నోట్ ఇంకా ఈ ఫోన్‌కు రాలేదు. అది వచ్చాక మీరు దీన్ని మార్చవచ్చు.';

  @override
  String get legal_privacy => 'గోప్యతా విధానం';

  @override
  String get legal_terms => 'వినియోగ నిబంధనలు';

  @override
  String get legal_opensInBrowser => 'మీ బ్రౌజర్‌లో తెరుచుకుంటుంది';

  @override
  String get help_crisisSubtitleCapsule =>
      'దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీ క్యాప్సూల్ సీల్ అయింది.';

  @override
  String get help_backToCapsule => 'నా క్యాప్సూల్‌కి తిరిగి';

  @override
  String get flows_startOverTitle => 'మళ్ళీ మొదటి నుంచి మొదలుపెడదామా?';

  @override
  String get flows_startOverBody =>
      'ఇప్పటివరకు మీరు ఎంచుకున్నవి, రాసినవి క్లియర్ అవుతాయి.';

  @override
  String get flows_startOver => 'మళ్ళీ మొదలుపెడదాం';

  @override
  String get closed_title => 'ఈ ఖాతా మూసివేయబడింది';

  @override
  String get closed_body => 'Aura నియమాలను పాటించనందుకు ఈ ఖాతా మూసివేయబడింది.';

  @override
  String get closed_review =>
      'ఇది పొరపాటు అని మీకు అనిపిస్తే, మళ్ళీ పరిశీలించమని అడగవచ్చు. 7 రోజుల్లో సమాధానం ఇస్తాం.';

  @override
  String get closed_askReview => 'మళ్ళీ పరిశీలించమని అడగండి';

  @override
  String get closed_reviewSubject => 'మూసివేసిన ఖాతా పునఃపరిశీలన';

  @override
  String get closed_deleteNote =>
      'మీ ఖాతాను, అందులోని ప్రతిదాన్నీ మీరు ఇప్పటికీ తొలగించవచ్చు.';

  @override
  String get closed_signOutNote =>
      'సైన్ అవుట్ చేస్తే ఈ ఫోన్ నుండి ఈ ఖాతా క్లియర్ అవుతుంది.';

  @override
  String get notif_roomsPoolBanner =>
      'హిందీ, హింగ్లిష్ రూమ్‌లు ఇప్పుడు మొదలయ్యాయి.';

  @override
  String get notif_roomsPoolAction => 'రూమ్‌లు చూడండి';

  @override
  String get notif_channelRooms => 'రూమ్‌లు & Lantern Hour';

  @override
  String get notif_channelRoomsDescription =>
      'మీరు అడిగిన రూమ్‌లు మొదలైనప్పుడు.';

  @override
  String home_stageProgress(String stage, String next, int count, int target) {
    return '$stage, $next వైపు $targetలో $count Starlight';
  }

  @override
  String home_constellationProgress(String stage, int count, int max) {
    return '$stage, మీ నక్షత్ర మండలంలో $maxలో $count నక్షత్రాలు';
  }

  @override
  String get home_glowTitle => 'మీ వెలుగు';

  @override
  String get home_restDaysHint =>
      'విశ్రాంతి రోజులు ఎలా పనిచేస్తాయో తెలుసుకోండి';

  @override
  String get home_restInfoTitle => 'విశ్రాంతి రోజులు';

  @override
  String home_restInfoEarn(int days, int max) {
    return 'ప్రతి $days వెలుగు రోజులకు ఒక విశ్రాంతి రోజు వస్తుంది. $max వరకు దాచుకోవచ్చు.';
  }

  @override
  String get home_restInfoUse =>
      'మీరు కొంచెం విరామం తీసుకున్నప్పుడు, అవి ఆ రోజులను తమంతట తామే నింపుతాయి. మీరు ఏమీ చేయాల్సిన అవసరం లేదు.';

  @override
  String get home_restInfoKeep =>
      'మీకు వచ్చిన ప్రతి వెలుగు రోజూ మీతోనే ఉంటుంది.';

  @override
  String home_checkInsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈరోజు $count చెక్-ఇన్‌లు',
      one: 'ఈరోజు 1 చెక్-ఇన్',
    );
    return '$_temp0';
  }

  @override
  String get home_seeAll => 'అన్నీ చూడండి';

  @override
  String get home_yourCheckIns => 'మీ చెక్-ఇన్‌లు';

  @override
  String get home_syncExplainIdle => 'అన్నీ ఈ ఫోన్‌లో, మీ ఖాతాలో సేవ్ అయ్యాయి.';

  @override
  String get home_syncExplainPending =>
      'అవి ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి, తమంతట తామే సింక్ అవుతాయి.';

  @override
  String get home_syncExplainOffline =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. అన్నీ ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి, మళ్ళీ ఆన్‌లైన్ అయ్యాక సింక్ అవుతాయి.';

  @override
  String get home_syncExplainSignedOut =>
      'మీరు సైన్ ఇన్ కాలేదు, కాబట్టి ప్రస్తుతానికి అన్నీ ఈ ఫోన్‌లోనే ఉంటాయి.';

  @override
  String get home_syncExplainUnavailable =>
      'ఈ వెర్షన్ అన్నింటినీ ఈ ఫోన్‌లోనే ఉంచుతుంది.';

  @override
  String get home_syncNow => 'ఇప్పుడే సింక్ చేయండి';

  @override
  String get home_syncing => 'సింక్ అవుతోంది…';

  @override
  String get home_syncHint => 'సింక్ వివరాలు చూపించండి';

  @override
  String get habits_edit => 'మార్చండి';

  @override
  String get habits_editSemantic => 'చిన్న పనులను మార్చండి';

  @override
  String get habits_sheetTitle => 'మీ చిన్న పనులు';

  @override
  String get habits_sheetBody =>
      'Homeలో ఏవి కనిపించాలో ఎంచుకోండి. ఎలాగైనా చెక్-ఇన్‌లతో మీ Aura పెరుగుతుంది.';

  @override
  String get habits_presetsTitle => 'సూచనలు';

  @override
  String get habits_customTitle => 'మీ సొంతవి';

  @override
  String get habits_addLabel => 'మీ సొంతది జోడించండి';

  @override
  String get habits_addHint => 'ఉదాహరణకు, మొక్కలకు నీళ్ళు';

  @override
  String get habits_add => 'జోడించండి';

  @override
  String habits_limit(int count) {
    return 'మీకు $count సొంత అలవాట్లు ఉన్నాయి. ఇంకొకటి జోడించడానికి ఒకదాన్ని మార్చండి.';
  }

  @override
  String get habits_saveFailed => 'అది సేవ్ కాలేదు. మళ్ళీ ప్రయత్నిస్తారా?';

  @override
  String habits_remove(String name) {
    return '$name తీసేయండి';
  }

  @override
  String habits_removeTitle(String name) {
    return '$name తీసేయాలా?';
  }

  @override
  String get habits_removeBody =>
      'ఇది మీ జాబితా నుండి వెళ్ళిపోతుంది. దీనితో వచ్చిన Starlight, వెలుగు రోజులు అలాగే ఉంటాయి.';

  @override
  String get habits_removeConfirm => 'తీసేయండి';

  @override
  String get habits_empty => 'మొదలుపెట్టడానికి ఒక చిన్న పని ఎంచుకోండి.';

  @override
  String get help_groundingProgress => 'ఈ నిమిషంలో ఎంతవరకు వచ్చారు';

  @override
  String get help_progressBegun => 'ఇప్పుడే మొదలైంది';

  @override
  String get help_progressHalf => 'దాదాపు సగం';

  @override
  String get help_progressNearly => 'దాదాపు పూర్తయింది';

  @override
  String get help_progressDone => 'పూర్తయింది';

  @override
  String help_breatheLogged(String habit) {
    return 'ఈరోజు $habit అయినట్టు గుర్తించాం.';
  }

  @override
  String get insights_title => 'Aura Sky';

  @override
  String get insights_private =>
      'మీ ఆకాశం మీకు మాత్రమే కనిపిస్తుంది. ఇదంతా ఈ ఫోన్‌లోనే లెక్కిస్తాం.';

  @override
  String get insights_empty =>
      'మీరు చెక్-ఇన్ చేస్తున్న కొద్దీ మీ ఆకాశం నిండుతుంది.';

  @override
  String get insights_allCheckIns => 'అన్ని చెక్-ఇన్‌లు';

  @override
  String get insights_viewMonth => 'నెల';

  @override
  String get insights_viewYear => 'సంవత్సరం';

  @override
  String get insights_prevMonth => 'ముందు నెల';

  @override
  String get insights_nextMonth => 'తర్వాతి నెల';

  @override
  String get insights_prevYear => 'ముందు సంవత్సరం';

  @override
  String get insights_nextYear => 'తర్వాతి సంవత్సరం';

  @override
  String insights_dayEmpty(String date) {
    return '$date, ప్రశాంత ఆకాశం';
  }

  @override
  String insights_dayRest(String date) {
    return '$date, విశ్రాంతి రోజు';
  }

  @override
  String insights_daySingle(String date, String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెక్-ఇన్‌లు',
      one: '1 చెక్-ఇన్',
    );
    return '$date, $quadrant, $_temp0';
  }

  @override
  String insights_dayPair(String date, String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెక్-ఇన్‌లు',
      one: '1 చెక్-ఇన్',
    );
    return '$date, $first, $second సమానంగా, $_temp0';
  }

  @override
  String insights_dayMixed(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెక్-ఇన్‌లు',
      one: '1 చెక్-ఇన్',
    );
    return '$date, సమానమైన మిశ్రమం, $_temp0';
  }

  @override
  String get insights_dayHint => 'ఈ రోజు చెక్-ఇన్‌లు చూపిస్తుంది';

  @override
  String get insights_dayNone =>
      'ఈ రోజు ఏమీ నమోదు కాలేదు. ఆకాశం ప్రశాంతంగా ఉంది.';

  @override
  String insights_monthSemantic(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రోజులు చెక్-ఇన్',
      one: '1 రోజు చెక్-ఇన్',
      zero: 'ప్రశాంత ఆకాశం',
    );
    return '$month, $_temp0';
  }

  @override
  String get insights_legendRest => 'విశ్రాంతి రోజు';

  @override
  String get insights_legendMixed => 'మిశ్రమ రోజు';

  @override
  String get insights_patternsTitle => 'ధోరణులు';

  @override
  String get insights_patternsLast30 => 'మీ గత 30 రోజుల నుండి';

  @override
  String insights_patternsNeedCheckIns(int count) {
    return '7 చెక్-ఇన్‌ల తర్వాత ధోరణులు కనిపిస్తాయి ($count/7)';
  }

  @override
  String insights_patternsNeedDays(int count) {
    return '5 వేర్వేరు రోజుల్లో చెక్-ఇన్ చేశాక ధోరణులు కనిపిస్తాయి ($count/5)';
  }

  @override
  String get insights_patternsNone =>
      'ఇప్పుడు స్పష్టమైన ధోరణులు ఏవీ లేవు. మీ ఆకాశం ఇక్కడే ఉంది.';

  @override
  String insights_patternTag(String tag, String quadrant) {
    return '$tag ఉన్న చెక్-ఇన్‌లలో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternHabit(String habit, String quadrant) {
    return 'మీరు $habit చేసిన రోజుల్లో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternMorning(String quadrant) {
    return 'ఉదయాల్లో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternAfternoon(String quadrant) {
    return 'మధ్యాహ్నాల్లో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternEvening(String quadrant) {
    return 'సాయంత్రాల్లో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternNight(String quadrant) {
    return 'రాత్రుల్లో $quadrant ఎక్కువగా కనిపించింది.';
  }

  @override
  String insights_patternMix(String quadrant) {
    return 'మీ ఆకాశంలో $quadrant అన్నిటికంటే ఎక్కువగా కనిపించింది.';
  }

  @override
  String get insights_plusBadge => 'Aura Plus';

  @override
  String get insights_rangeLocked =>
      'ఏ కాల పరిధి అయినా, మూడ్‌లతో పాటు అలవాట్లు Aura Plus‌తో వస్తాయి. మీ ఆకాశం, 30 రోజుల ధోరణులు ఎప్పుడూ ఉచితమే.';

  @override
  String get insights_rangeLabel => 'ఈ కాలం నుండి ధోరణులు';

  @override
  String get insights_range7 => '7 రోజులు';

  @override
  String get insights_range30 => '30 రోజులు';

  @override
  String get insights_range90 => '90 రోజులు';

  @override
  String get insights_range365 => '1 సంవత్సరం';

  @override
  String get insights_rangeAll => 'మొత్తం';

  @override
  String get insights_weeklyTitle => 'మీ గత వారం నుండి';

  @override
  String get insights_weeklyHide => 'ఈ వారానికి దాచండి';

  @override
  String get insights_careTitle => 'గత రెండు వారాలు భారంగా గడిచాయి';

  @override
  String get insights_careBody =>
      'దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీకు ఎప్పుడు కావాలంటే అప్పుడు సహాయం, ఒక రూమ్ ఇక్కడే ఉన్నాయి.';

  @override
  String get insights_careSupport => 'సహాయం చూడండి';

  @override
  String get insights_careRoom => 'ఒక రూమ్ వెతకండి';

  @override
  String get insights_monthTitle => 'నక్షత్రాల్లో మీ నెల';

  @override
  String insights_monthCardBody(String month) {
    return 'మీ ఆకాశంలో $month';
  }

  @override
  String get insights_monthOpen => 'తెరవండి';

  @override
  String get insights_monthHide => 'దాచండి';

  @override
  String insights_monthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రోజులు చెక్-ఇన్ చేశారు',
      one: '1 రోజు చెక్-ఇన్ చేశారు',
    );
    return '$_temp0';
  }

  @override
  String get insights_monthMixTitle => 'ఈ నెల మీ ఆకాశాలు';

  @override
  String insights_monthMixItem(String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెక్-ఇన్‌లు',
      one: '1 చెక్-ఇన్',
    );
    return '$quadrant: $_temp0';
  }

  @override
  String insights_monthSkySemantic(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count నక్షత్రాలు',
      one: '1 నక్షత్రం',
    );
    return '$monthలో ఒక్కో చెక్-ఇన్‌కి ఒక్కో నక్షత్రం, మొత్తం $_temp0';
  }

  @override
  String get insights_deeperTitle => 'లోతైన నెలవారీ సమీక్ష';

  @override
  String get insights_deeperLocked =>
      'నెల మొత్తంలోని ధోరణులు, మూడ్‌లతో పాటు అలవాట్లు Aura Plus‌తో వస్తాయి.';

  @override
  String get insights_deeperNone => 'ఈ నెల స్పష్టమైన ధోరణులు ఏవీ లేవు.';

  @override
  String get insights_statsTitle => 'ఇప్పటివరకు';

  @override
  String insights_statsCheckIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెక్-ఇన్‌లు',
      one: '1 చెక్-ఇన్',
    );
    return '$_temp0';
  }

  @override
  String insights_statsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'మీ ఆకాశంలో $count రోజులు',
      one: 'మీ ఆకాశంలో 1 రోజు',
    );
    return '$_temp0';
  }

  @override
  String get notif_reminderBanner =>
      'మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది?';

  @override
  String get notif_reminderAction => 'చెక్-ఇన్ చేయండి';

  @override
  String get notif_capsuleBanner => 'మీరు దాచుకున్నది ఇప్పుడు తెరవొచ్చు.';

  @override
  String get notif_capsuleAction => 'తెరవండి';

  @override
  String get notif_channelReminders => 'రిమైండర్లు';

  @override
  String get notif_channelRemindersDescription =>
      'మీ రోజువారీ చెక్-ఇన్ రిమైండర్.';

  @override
  String get set_notifications => 'నోటిఫికేషన్లు';

  @override
  String get set_notifMaster => 'Aura నుండి నోటిఫికేషన్లు';

  @override
  String get set_notifMasterNote =>
      'రోజుకు రెండు మించి రావు. మీరు ఎలా ఫీల్ అవుతున్నారో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.';

  @override
  String get set_notifReminder => 'రోజువారీ చెక్-ఇన్ రిమైండర్';

  @override
  String set_notifReminderNote(String time) {
    return 'రోజుకు ఒక్క మృదువైన గుర్తు, $timeకి. మీరు చెక్-ఇన్ చేశాక రాదు.';
  }

  @override
  String get set_notifReminderOffNote =>
      'ఆఫ్‌లో ఉంది. రోజుకు ఒక్క మృదువైన గుర్తు కావాలంటే ఆన్ చేయండి.';

  @override
  String get set_notifReminderTime => 'రిమైండర్ సమయం';

  @override
  String get set_notifCapsule => 'క్యాప్సూల్ తెరవడానికి సిద్ధంగా ఉన్నప్పుడు';

  @override
  String get set_notifCapsuleNote =>
      'మీరు దాచుకున్నదానికి మీరు ఎంచుకున్న రోజున.';

  @override
  String set_notifQuietNote(String start, String end) {
    return 'నిశ్శబ్ద సమయం: $start–$end మధ్య ఏదీ పంపం.';
  }

  @override
  String get set_notifQuietFrom => 'నిశ్శబ్దం మొదలు';

  @override
  String get set_notifQuietUntil => 'నిశ్శబ్దం ముగింపు';

  @override
  String get set_notifDiscreet => 'గోప్య మోడ్';

  @override
  String get set_notifDiscreetNote =>
      'ప్రతి నోటిఫికేషన్ “Aura · మీకు ఒక మృదువైన అప్‌డేట్ ఉంది” అని మాత్రమే చెబుతుంది.';

  @override
  String get set_notifOffNote =>
      'ఈ ఫోన్‌లో Aura నోటిఫికేషన్లు ఆఫ్‌లో ఉన్నాయి. అవి ఆన్ అయ్యాక ఇక్కడి మీ ఎంపికలే వర్తిస్తాయి.';

  @override
  String get set_notifTurnOn => 'ఆన్ చేయండి';

  @override
  String get set_notifOpenSettings => 'ఫోన్ సెట్టింగ్‌లు తెరవండి';

  @override
  String get set_notifQuietConfirmTitle => 'ఈ సమయం మీ నిశ్శబ్ద సమయంలో ఉంది';

  @override
  String set_notifQuietConfirmBody(String start, String end, String time) {
    return 'Aura $start–$end మధ్య నిశ్శబ్దంగా ఉంటుంది. అయినా మీ రిమైండర్‌ను $timeకి పంపాలా?';
  }

  @override
  String get set_notifQuietConfirmYes => 'అయినా పంపండి';

  @override
  String get set_notifQuietConfirmNo => 'నిశ్శబ్దంగానే ఉంచండి';

  @override
  String push_timeRow(String time) {
    return 'ప్రతి సాయంత్రం $timeకి';
  }

  @override
  String get push_changeTime => 'సమయం మార్చండి';

  @override
  String get push_discreet => 'గోప్యంగా ఉంచండి';

  @override
  String get onb_trustTitle => 'మొదలుపెట్టే ముందు';

  @override
  String get onb_trustBody => 'Aura మిమ్మల్ని ఎలా చూసుకుంటుందో కొన్ని విషయాలు.';

  @override
  String get onb_trustPrivateTitle => 'మొదటి నుంచీ గోప్యంగా';

  @override
  String get onb_trustPrivateBody =>
      'మీ చెక్-ఇన్‌లు, నోట్స్ మీవే. నోట్స్ ఎన్‌క్రిప్ట్ అవుతాయి. మీరు పంచుకోవాలని ఎంచుకుంటే తప్ప, మీకు ఎలా అనిపిస్తోందో వేరే ఎవరికీ కనిపించదు.';

  @override
  String get onb_trustCareTitle => 'ఇది వెల్‌నెస్ తోడు, థెరపీ కాదు';

  @override
  String get onb_trustCareBody =>
      'మీకు ఎలా అనిపిస్తోందో గమనించుకోవడానికి Aura సహాయపడుతుంది. ఇది ఏ రోగనిర్ధారణ గానీ, చికిత్స గానీ చేయదు.';

  @override
  String get onb_trustHelpTitle => 'సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలోనే';

  @override
  String onb_trustHelpBody(String button) {
    return 'హెల్ప్‌లైన్‌కు కాల్ చేయడానికి లేదా ఒక నిమిషం శ్వాస మీద ధ్యాస పెట్టడానికి, ఎప్పుడైనా “$button” నొక్కండి.';
  }

  @override
  String get onb_dobYearType => 'సంవత్సరం టైప్ చేయండి';

  @override
  String get onb_dobYearNoMatch =>
      'దానికి సరిపోయే సంవత్సరం లిస్ట్‌లో లేదు. ఒకసారి చూసుకుంటారా?';

  @override
  String get onb_blockedWrongDate => 'తప్పు తేదీ ఇచ్చారా?';

  @override
  String get onb_blockedWrongDateHint => 'మీ ఈమెయిల్ యాప్ తెరుచుకుంటుంది';

  @override
  String get onb_blockedMailSubject => 'Aura: నేను తప్పు తేదీ ఇచ్చాను';

  @override
  String onb_blockedMailFailed(String email) {
    return 'ఈమెయిల్ యాప్ తెరవలేకపోయాం. $emailకి మాకు రాయవచ్చు.';
  }

  @override
  String polish_legalOpenFailed(String url) {
    return 'మీ బ్రౌజర్ తెరుచుకోలేదు. ఆ పేజీ $url లో ఉంది.';
  }

  @override
  String get polish_legalCopyLink => 'లింక్ కాపీ చేయండి';

  @override
  String get polish_legalLinkCopied => 'లింక్ కాపీ అయింది';

  @override
  String polish_helpCallFailed(String number) {
    return 'ఈ ఫోన్ నుంచి కాల్ చేయడం కుదరడం లేదు. నంబర్ $number.';
  }

  @override
  String get polish_helpCopyNumber => 'నంబర్ కాపీ చేయండి';

  @override
  String get polish_helpNumberCopied => 'నంబర్ కాపీ అయింది';

  @override
  String get reflections_title => 'మనసులో మాటలు';

  @override
  String get reflections_intro =>
      'ఇక్కడ ఉన్నవాళ్ళ కొన్ని మాటలు. వీటికి సంజ్ఞలతో మాత్రమే స్పందించవచ్చు.';

  @override
  String get reflections_share => 'మీ మాట పంచుకోండి';

  @override
  String get reflections_empty =>
      'ఇక్కడ ఇంకా ఏ మాటలూ లేవు. మీరు ఒకటి పంచుకోవచ్చు, లేదా చదివి సంజ్ఞలు పంపవచ్చు.';

  @override
  String get reflections_emptyMemory => 'ఈ రూమ్‌లో ఏ మాటలూ పంచుకోలేదు.';

  @override
  String get reflections_loadFailed => 'ఇప్పుడు మాటలు లోడ్ కాలేదు.';

  @override
  String get reflections_offline =>
      'మాటలకు కనెక్షన్ కావాలి. మీరు రాసింది ఈ ఫోన్‌లోనే ఉంటుంది.';

  @override
  String get reflections_memory =>
      'ఈ రూమ్ ఒక జ్ఞాపకం: ఇందులోని మాటలు చదవవచ్చు, కొత్తవి జోడించలేరు.';

  @override
  String get reflections_paused =>
      'మాటలు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. సంజ్ఞలు పనిచేస్తూనే ఉంటాయి.';

  @override
  String reflections_limit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈ రోజుకు $count మాటలు అయిపోయాయి. సంజ్ఞలు ఎప్పుడూ తెరిచే ఉంటాయి.',
      one: 'ఈ రోజుకు 1 మాట అయిపోయింది. సంజ్ఞలు ఎప్పుడూ తెరిచే ఉంటాయి.',
    );
    return '$_temp0';
  }

  @override
  String get reflections_slow =>
      'ప్రస్తుతం మాటలు కొంచెం నెమ్మదిగా వెళ్తున్నాయి';

  @override
  String reflections_left(int remaining, int total) {
    return 'ఈ రోజు $totalలో $remaining మిగిలాయి';
  }

  @override
  String reflections_cardLabel(String pseudonym) {
    return '$pseudonym రాసిన మాట';
  }

  @override
  String get reflections_mine => 'మీ మాట';

  @override
  String get reflections_onlyYou => 'ఇది మీకు మాత్రమే కనిపిస్తుంది';

  @override
  String get reflections_pending => 'ఇంకా చూస్తున్నాం. మీరు చదువుతూ ఉండొచ్చు.';

  @override
  String get reflections_heldSoon => 'ఒక చిన్న తనిఖీ కోసం ఎదురుచూస్తోంది';

  @override
  String get reflections_heldOvernight =>
      'ఒక చిన్న తనిఖీ కోసం ఎదురుచూస్తోంది. ఉదయం వరకు పట్టొచ్చు.';

  @override
  String get reflections_rejectedCard => 'ఇది ఇక్కడ పెట్టలేకపోయాం.';

  @override
  String get reflections_removedCard => 'ఒక సమీక్ష తర్వాత దీన్ని తీసేశాం.';

  @override
  String reflections_gestureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సంజ్ఞలు',
      one: '1 సంజ్ఞ',
      zero: 'ఇంకా సంజ్ఞలు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get reflections_countPrivate => 'ఈ సంఖ్య మీకు మాత్రమే కనిపిస్తుంది';

  @override
  String get reflections_options => 'మాట ఆప్షన్లు';

  @override
  String reflections_gestureHint(String pseudonym) {
    return 'ఈ మాట కోసం $pseudonymకి పంపుతుంది';
  }

  @override
  String reflections_gestureSent(String gesture, String pseudonym) {
    return '$pseudonymకి $gesture పంపారు';
  }

  @override
  String get reflections_delete => 'తొలగించు';

  @override
  String get reflections_withdraw => 'వెనక్కి తీసుకో';

  @override
  String get reflections_deleteTitle => 'ఈ మాటను తొలగించాలా?';

  @override
  String get reflections_deleteBody =>
      'ఇది ఇక్కడ అందరికీ కనిపించదు. మాటలను మార్చలేరు, కానీ కొత్తది పంచుకోవచ్చు.';

  @override
  String get reflections_withdrawTitle => 'ఈ మాటను వెనక్కి తీసుకోవాలా?';

  @override
  String get reflections_withdrawBody =>
      'ఇది పెట్టబడదు. మీరు ఎప్పుడైనా కొత్తది పంచుకోవచ్చు.';

  @override
  String get reflections_deleted => 'మీ మాట తీసేశాం.';

  @override
  String get reflections_reportTitle => 'ఈ మాటను రిపోర్ట్ చేయండి';

  @override
  String get reflections_reportHidden =>
      'చెప్పినందుకు ధన్యవాదాలు. ఆ మాట ఇప్పుడు మీకు కనిపించదు.';

  @override
  String get reflections_composeTitle => 'మీ మాట పంచుకోండి';

  @override
  String get reflections_composeLabel => 'మీ మనసులో ఏముంది?';

  @override
  String get reflections_composeNote =>
      'ఈ రూమ్ కోసం కొన్ని మాటలు. ఇతరులు సంజ్ఞలతో మాత్రమే స్పందిస్తారు, జవాబులు ఉండవు.';

  @override
  String reflections_counter(int count, int max) {
    return '$count/$max';
  }

  @override
  String reflections_counterSemantic(int count, int max) {
    return '$maxలో $count అక్షరాలు';
  }

  @override
  String reflections_tooLong(int max) {
    return 'కొంచెం చిన్నగా రాయండి: $max అక్షరాల వరకు.';
  }

  @override
  String get reflections_send => 'పంపండి';

  @override
  String get reflections_sending => 'నెమ్మదిగా పంపుతున్నాం…';

  @override
  String get reflections_contactBlocked =>
      'ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ ఇక్కడ పంచుకోలేరు. ఇది అందరినీ సురక్షితంగా ఉంచుతుంది.';

  @override
  String get reflections_draftKept =>
      'డ్రాఫ్ట్ భద్రంగా ఉంది. మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక పంపవచ్చు.';

  @override
  String get reflections_sendFailed =>
      'ఇప్పుడు పంపలేకపోయాం. మీ మాటలు ఇక్కడే ఉన్నాయి: కాసేపట్లో మళ్ళీ ప్రయత్నించండి.';

  @override
  String get reflections_rejectedContact =>
      'మాటల్లో కాంటాక్ట్ వివరాలు ఉండకూడదు. అవి లేకుండా మళ్ళీ ప్రయత్నిస్తారా?';

  @override
  String get reflections_rejectedLink =>
      'మాటల్లో లింక్‌లు ఉండకూడదు. అది లేకుండా మళ్ళీ ప్రయత్నిస్తారా?';

  @override
  String get reflections_rejectedPersonal =>
      'ఎవరివైనా వ్యక్తిగత వివరాల గురించి ప్రశ్నలు ఇక్కడ పెట్టలేరు. అవి లేకుండా ప్రయత్నిస్తారా?';

  @override
  String get reflections_rejectedGeneral =>
      'ఇది ఇక్కడ పెట్టలేం. ఇది ఎవరినైనా బాధపెట్టొచ్చు లేదా వ్యక్తిగత వివరాలు పంచుకోవచ్చు. మీ మాటలు మార్చుకోవడానికి ఇక్కడే ఉన్నాయి.';

  @override
  String get reflections_supportSubtitle =>
      'మీరు దీన్ని ఒంటరిగా మోయాల్సిన అవసరం లేదు.';

  @override
  String get reflections_backToRoom => 'రూమ్‌కి తిరిగి వెళ్ళండి';

  @override
  String get device_bannedTitle => 'ఈ పరికరంలో Aura ఉపయోగించలేరు';

  @override
  String get device_bannedBody => 'ఈ ఫోన్‌లో Aura అందుబాటులో లేదు.';

  @override
  String get device_bannedReviewSubject => 'పరికరం పునఃపరిశీలన';

  @override
  String get rooms_paused =>
      'రూమ్‌లు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. తర్వాత మళ్ళీ ప్రయత్నించండి.';

  @override
  String get rooms_pausedJoin =>
      'రూమ్‌లు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. మీ చెక్-ఇన్ సేవ్ అయింది.';

  @override
  String get rooms_title => 'రూమ్‌లు';

  @override
  String get rooms_yourRooms => 'మీ రూమ్‌లు';

  @override
  String get rooms_memories => 'జ్ఞాపకాలు';

  @override
  String get rooms_whatTitle => 'రూమ్‌లు అంటే ఏమిటి';

  @override
  String get rooms_whatBody =>
      'ఇప్పుడు మీలాగే అనిపిస్తున్న కొంతమంది ఉండే ఒక చిన్న రూమ్, ఒక్క రోజు కోసం.';

  @override
  String get rooms_pointName =>
      'ప్రతి రూమ్‌లో ఒక కొత్త పేరు. మీ అకౌంట్ ఎవరికీ కనిపించదు.';

  @override
  String get rooms_pointGestures =>
      'మెసేజ్‌లు, DMలు ఉండవు: ఎనిమిది ఆత్మీయ సంజ్ఞలు మాత్రమే.';

  @override
  String get rooms_pointTime =>
      'రూమ్ ఒక రోజు ఉంటుంది, తర్వాత 7 రోజులు జ్ఞాపకంగా ఉంటుంది.';

  @override
  String get rooms_lanternNote =>
      'Lantern Hour: మీ ప్రాంతం సమయం ప్రకారం ప్రతి రాత్రి 9 నుంచి 11 వరకు, రూమ్‌లు కలిసి ఒక లాంతరు వెలిగిస్తాయి, ఎక్కువ మంది వస్తారు.';

  @override
  String get rooms_lanternNow => 'ఇప్పుడు Lantern Hour నడుస్తోంది';

  @override
  String get rooms_checkInCta => 'రూమ్ కోసం చెక్-ఇన్ చేయండి';

  @override
  String get rooms_empty =>
      'మీరు ఇప్పుడు ఏ రూమ్‌లోనూ లేరు. చెక్-ఇన్ తర్వాత, మీలాగే అనిపిస్తున్న వాళ్ళతో కలవొచ్చు.';

  @override
  String get rooms_offline =>
      'రూమ్‌లకు కనెక్షన్ కావాలి. మీ చెక్-ఇన్‌లు ఈ ఫోన్‌లో సేవ్ అవుతూనే ఉంటాయి.';

  @override
  String get rooms_loadFailed => 'ఇప్పుడు రూమ్‌లను చేరుకోలేకపోయాం.';

  @override
  String get rooms_tryAgain => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get rooms_signedOut => 'సైన్ ఇన్ చేశాక రూమ్‌లు తెరుచుకుంటాయి.';

  @override
  String get rooms_signIn => 'సైన్ ఇన్ చేయండి';

  @override
  String get rooms_suspended =>
      'ప్రస్తుతం మీ అకౌంట్‌కు రూమ్‌లు ఆపి ఉంచాం. సహాయం ఎప్పుడూ ఇక్కడే ఉంటుంది.';

  @override
  String rooms_suspendedUntil(String date) {
    return 'మీ అకౌంట్‌కు $date వరకు రూమ్‌లు ఆపి ఉంచాం. సహాయం ఎప్పుడూ ఇక్కడే ఉంటుంది.';
  }

  @override
  String get rooms_accountClosed =>
      'Aura నియమాలను ఉల్లంఘించినందుకు ఈ అకౌంట్ మూసివేయబడింది.';

  @override
  String get rooms_profilePending =>
      'మీ అకౌంట్ సెటప్ పూర్తయ్యాక రూమ్‌లు తెరుచుకుంటాయి. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.';

  @override
  String get rooms_openHint => 'రూమ్ తెరుచుకుంటుంది';

  @override
  String rooms_memoryUntil(String date) {
    return '$date వరకు జ్ఞాపకం';
  }

  @override
  String get rooms_theme_lighthouse => 'దీపస్తంభం';

  @override
  String get rooms_theme_rain_sanctuary => 'వాన నిలయం';

  @override
  String get rooms_theme_midnight_observatory => 'అర్ధరాత్రి నక్షత్రశాల';

  @override
  String get rooms_theme_sunrise_deck => 'సూర్యోదయ వేదిక';

  @override
  String get rooms_gesture_warm_tea => 'వెచ్చని టీ';

  @override
  String get rooms_gesture_light_a_candle => 'ఒక దీపం';

  @override
  String get rooms_gesture_hug => 'కౌగిలింత';

  @override
  String get rooms_gesture_me_too => 'నాకూ అంతే';

  @override
  String get rooms_gesture_soft_rain => 'చిరుజల్లు';

  @override
  String get rooms_gesture_stargaze => 'నక్షత్రాలు చూద్దాం';

  @override
  String get rooms_gesture_deep_breath => 'దీర్ఘ శ్వాస';

  @override
  String get rooms_gesture_youre_not_alone => 'మీరు ఒంటరి కాదు';

  @override
  String rooms_hereNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఇప్పుడు $count మంది ఉన్నారు',
      one: 'ఇప్పుడు 1 ఉన్నారు',
      zero: 'ఇప్పుడు ఎవరూ లేరు',
    );
    return '$_temp0';
  }

  @override
  String rooms_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈ రోజు $count మంది ఇక్కడికి వచ్చారు',
      one: 'ఈ రోజు 1 వ్యక్తి ఇక్కడికి వచ్చారు',
    );
    return '$_temp0';
  }

  @override
  String rooms_countsSemantic(int now, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      now,
      locale: localeName,
      other: 'ఇప్పుడు $now మంది',
      one: 'ఇప్పుడు 1 వ్యక్తి',
    );
    String _temp1 = intl.Intl.pluralLogic(
      today,
      locale: localeName,
      other: 'ఈ రోజు $today',
      one: 'ఈ రోజు 1',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String rooms_stripSemantic(String theme, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఇప్పుడు $count మంది',
      one: 'ఇప్పుడు 1 వ్యక్తి',
    );
    return '$theme, $_temp0';
  }

  @override
  String get rooms_opening => 'రూమ్ తెరుస్తున్నాం…';

  @override
  String rooms_youAre(String pseudonym) {
    return 'ఇక్కడ మీరు $pseudonym';
  }

  @override
  String rooms_coldStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ఈ రోజు $count మంది ఇక్కడికి వచ్చారు. తర్వాత వచ్చేవారి కోసం ఒక దీపం వదిలి వెళ్ళండి.',
      one: 'ఈ రోజు ఇక్కడికి వచ్చిన మొదటివారు మీరే. తర్వాత వచ్చేవారి కోసం ఒక దీపం వదిలి వెళ్ళండి.',
    );
    return '$_temp0';
  }

  @override
  String rooms_lanternOn(String time) {
    return 'Lantern Hour · $time వరకు';
  }

  @override
  String rooms_closing(String time) {
    return 'ఈ రూమ్ $timeకి జ్ఞాపకంగా మారుతుంది.';
  }

  @override
  String get rooms_memory =>
      'ఈ రూమ్ ఇప్పుడు ఒక జ్ఞాపకం. 7 రోజుల పాటు వెనక్కి చూసుకోవచ్చు.';

  @override
  String get rooms_findNew => 'కొత్త రూమ్ వెతకండి';

  @override
  String get rooms_reconnecting => 'మళ్ళీ కనెక్ట్ అవుతోంది…';

  @override
  String get rooms_membersTitle => 'మీతో ఇక్కడ';

  @override
  String get rooms_you => 'మీరు';

  @override
  String get rooms_memberHereNow => 'ఇప్పుడు ఇక్కడ ఉన్నారు';

  @override
  String get rooms_memberAway => 'ప్రస్తుతం దూరంగా ఉన్నారు';

  @override
  String get rooms_memberMuted => 'మీ కోసం మ్యూట్ చేశారు';

  @override
  String rooms_memberLabel(String pseudonym, String mood, String status) {
    return '$pseudonym, $mood, $status';
  }

  @override
  String rooms_youLabel(String pseudonym, String mood) {
    return 'మీరు, $pseudonym, $mood';
  }

  @override
  String get rooms_memberHint => 'ఆప్షన్లు తెరుచుకుంటాయి';

  @override
  String get rooms_recentTitle => 'ఈ రూమ్‌లో ఆత్మీయత';

  @override
  String rooms_receivedLine(String pseudonym, String gesture) {
    return '$pseudonym మీకు $gesture పంపారు';
  }

  @override
  String rooms_sentToMember(String gesture, String pseudonym) {
    return '$pseudonymకి $gesture పంపారు';
  }

  @override
  String rooms_sentToRoom(String gesture) {
    return 'ఇక్కడ అందరికీ $gesture పంపారు';
  }

  @override
  String rooms_someoneSent(String gesture) {
    return 'ఎవరో $gesture పంపారు';
  }

  @override
  String rooms_someoneSentRoom(String gesture) {
    return 'ఎవరో ఇక్కడ అందరికీ $gesture పంపారు';
  }

  @override
  String rooms_youSentMember(String gesture, String pseudonym) {
    return 'మీరు $pseudonymకి $gesture పంపారు';
  }

  @override
  String rooms_youSentRoom(String gesture) {
    return 'మీరు ఇక్కడ అందరికీ $gesture పంపారు';
  }

  @override
  String get rooms_trayTitle => 'ఇక్కడ అందరికీ ఆత్మీయత పంపండి';

  @override
  String get rooms_trayHint => 'ఇక్కడ అందరికీ పంపుతుంది';

  @override
  String get rooms_trayResting =>
      'జ్ఞాపకంలో సంజ్ఞలు విశ్రాంతిలో ఉంటాయి. రిపోర్ట్, బ్లాక్, మ్యూట్ ఇంకా పనిచేస్తాయి.';

  @override
  String get rooms_roomOptions => 'రూమ్ ఆప్షన్లు';

  @override
  String get rooms_reportRoom => 'ఇక్కడ ఒక సమస్యను రిపోర్ట్ చేయండి';

  @override
  String get rooms_leave => 'ఈ రూమ్ నుంచి వెళ్ళిపోండి';

  @override
  String get rooms_removeMemory => 'నా రూమ్‌ల నుంచి తీసేయండి';

  @override
  String get rooms_leaveTitle => 'ఈ రూమ్ నుంచి వెళ్ళిపోతారా?';

  @override
  String get rooms_leaveBody =>
      'మళ్ళీ ఈ రూమ్‌కి రాలేరు, మీ సీటు ఇంకొకరికి దొరుకుతుంది. మీ తర్వాతి చెక్-ఇన్ మీకు కొత్త రూమ్ వెతికిపెడుతుంది.';

  @override
  String get rooms_leaveConfirm => 'వెళ్ళిపోతాను';

  @override
  String get rooms_stay => 'ఇక్కడే ఉంటాను';

  @override
  String get rooms_removeTitle => 'ఈ జ్ఞాపకాన్ని తీసేయాలా?';

  @override
  String get rooms_removeBody =>
      'ఇది ఇప్పుడే మీ రూమ్‌ల నుంచి వెళ్ళిపోతుంది. ఎలాగూ 7 రోజుల తర్వాత జ్ఞాపకాలు పూర్తిగా మూసుకుపోతాయి.';

  @override
  String get rooms_removeConfirm => 'తీసేయండి';

  @override
  String get rooms_keep => 'ఉంచండి';

  @override
  String get rooms_leaveFailed => 'అది జరగలేదు. మీరు ఇంకా రూమ్‌లోనే ఉన్నారు.';

  @override
  String get rooms_gone =>
      'ఈ రూమ్ మూసుకుపోయింది. రూమ్‌లు 7 రోజులు జ్ఞాపకాలుగా ఉండి, తర్వాత పోతాయి.';

  @override
  String get rooms_backToRooms => 'మీ రూమ్‌లకు వెళ్ళండి';

  @override
  String get rooms_offlineRoom =>
      'రూమ్‌లకు కనెక్షన్ కావాలి. మీరు మళ్ళీ ఆన్‌లైన్‌కి రాగానే ఈ రూమ్ తెరుచుకుంటుంది.';

  @override
  String get rooms_joinTitle => 'మీ రూమ్ వెతుకుతున్నాం';

  @override
  String get rooms_finding =>
      'ఇప్పుడు ఇలాగే అనిపిస్తున్న వాళ్ళను వెతుకుతున్నాం…';

  @override
  String get rooms_offlineJoin =>
      'రూమ్‌లకు కనెక్షన్ కావాలి. మీ చెక్-ఇన్ సేవ్ అయింది.';

  @override
  String get rooms_joinFailed =>
      'ఇప్పుడు రూమ్‌లను చేరుకోలేకపోయాం. మీ చెక్-ఇన్ సేవ్ అయింది.';

  @override
  String get rooms_joinLimit =>
      'ఈ రోజు ఈ భావనకు ఇప్పటికే 3 కొత్త రూమ్‌లు అయ్యాయి. మీరు ఉన్న రూమ్‌లు ఇంకా మీ కోసం తెరిచే ఉన్నాయి.';

  @override
  String get rooms_seeYourRooms => 'మీ రూమ్‌లు చూడండి';

  @override
  String get rooms_poolUnavailable =>
      'హిందీ, హింగ్లిష్ రూమ్‌లు త్వరలో మొదలవుతాయి. ప్రస్తుతానికి ఇంగ్లీష్ రూమ్‌లో చేరతారా?';

  @override
  String get rooms_poolJoinEnglish => 'ఇంగ్లీష్ రూమ్‌లో చేరండి';

  @override
  String get rooms_poolNotify => 'అవి మొదలైనప్పుడు చెప్పండి';

  @override
  String get rooms_poolNotifyDone =>
      'హిందీ, హింగ్లిష్ రూమ్‌లు మొదలైనప్పుడు ఇక్కడే చెబుతాం.';

  @override
  String get rooms_noRequest => 'రూమ్‌లు చెక్-ఇన్ నుంచి తెరుచుకుంటాయి.';

  @override
  String get rooms_offer => 'ఇలాగే అనిపిస్తున్న వాళ్ళ రూమ్‌లో చేరండి';

  @override
  String get rooms_offerHint =>
      'దాని కోసమే కొత్త పేరుతో ఒక రూమ్ తెరుచుకుంటుంది';

  @override
  String get rooms_offerOffline =>
      'మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక రూమ్‌లు తెరుచుకుంటాయి';

  @override
  String get rooms_offerLater =>
      'తోడు కావాలనిపించినప్పుడు, రూమ్‌లు Rooms ట్యాబ్‌లో ఉంటాయి.';

  @override
  String get rooms_guidelinesTitle => 'మీ మొదటి రూమ్‌కి ముందు';

  @override
  String get rooms_guidelinesIntro =>
      'అందరూ ఈ కొన్ని చిన్న విషయాలు పాటిస్తారు కాబట్టే రూమ్‌లు ప్రశాంతంగా ఉంటాయి:';

  @override
  String get rooms_rule1 =>
      'దయగా ఉండండి. ఇక్కడ అందరూ నిజమైన రోజును గడుపుతున్నారు.';

  @override
  String get rooms_rule2 =>
      'కులం, మతం, లింగం, లైంగికత లేదా మరేదైనా గురించి ద్వేషం వద్దు.';

  @override
  String get rooms_rule3 => 'లైంగిక కంటెంట్ వద్దు.';

  @override
  String get rooms_rule4 =>
      'కాంటాక్ట్ వివరాలు, కలవడాలు, లేదా ఎవరి వయసు, స్కూల్, ఊరు, ఫోటోలు అడగవద్దు, పంచుకోవద్దు.';

  @override
  String get rooms_rule5 => 'అమ్మకాలు, స్పామ్ వద్దు.';

  @override
  String get rooms_rule6 =>
      'ఎవరినీ తమను తాము బాధపెట్టుకోమని ప్రోత్సహించవద్దు. మీకు ఎలా అనిపిస్తోందో మాట్లాడటం ఎప్పుడూ సరే.';

  @override
  String get rooms_guidelinesSafety =>
      'ఎవరినైనా రిపోర్ట్, బ్లాక్ లేదా మ్యూట్ చేయవచ్చు, సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలో ఉంటుంది.';

  @override
  String get rooms_guidelinesAgree => 'నేను వీటిని పాటిస్తాను';

  @override
  String get rooms_guidelinesUpdate =>
      'రూమ్‌ల కమ్యూనిటీ మార్గదర్శకాలు మారాయి. మీ తర్వాతి రూమ్‌కి ముందు వాటిని చదవడానికి Auraని అప్‌డేట్ చేయండి.';

  @override
  String rooms_sendTo(String pseudonym) {
    return '$pseudonymకి కొంచెం ఆత్మీయత పంపండి';
  }

  @override
  String rooms_gestureHintMember(String pseudonym) {
    return '$pseudonymకి పంపుతుంది';
  }

  @override
  String get rooms_report => 'రిపోర్ట్';

  @override
  String get rooms_block => 'బ్లాక్';

  @override
  String get rooms_mute => 'మ్యూట్';

  @override
  String get rooms_unmute => 'అన్‌మ్యూట్';

  @override
  String get rooms_safetyNote =>
      'ఎవరు రిపోర్ట్, బ్లాక్ లేదా మ్యూట్ చేశారో వాళ్ళకు ఎప్పుడూ తెలియదు.';

  @override
  String rooms_blockTitle(String pseudonym) {
    return '$pseudonymని బ్లాక్ చేయాలా?';
  }

  @override
  String get rooms_blockBody =>
      'మీరిద్దరూ మళ్ళీ ఒకే రూమ్‌లో ఉండరు, మీ మధ్య సంజ్ఞలు ఆగిపోతాయి. వాళ్ళకు ఈ విషయం చెప్పము.';

  @override
  String rooms_blocked(String pseudonym) {
    return '$pseudonymని బ్లాక్ చేశారు. మీరు మళ్ళీ ఒకే రూమ్‌లో ఉండరు.';
  }

  @override
  String rooms_muted(String pseudonym) {
    return '$pseudonymని మీ కోసం మ్యూట్ చేశాం. వాళ్ళ సంజ్ఞలు ఇక్కడ మీకు చేరవు.';
  }

  @override
  String rooms_unmuted(String pseudonym) {
    return '$pseudonymని అన్‌మ్యూట్ చేశాం.';
  }

  @override
  String get rooms_undo => 'వెనక్కి తీసుకోండి';

  @override
  String get rooms_actionFailed =>
      'అది జరగలేదు. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.';

  @override
  String rooms_reportMember(String pseudonym) {
    return '$pseudonymని రిపోర్ట్ చేయండి';
  }

  @override
  String get rooms_reportGesture => 'ఈ సంజ్ఞను రిపోర్ట్ చేయండి';

  @override
  String get rooms_reportWhy => 'ఏం జరుగుతోంది?';

  @override
  String get rooms_reason1 =>
      'ఎవరైనా ప్రమాదంలో ఉండొచ్చు లేదా తమను తాము బాధపెట్టుకుంటూ ఉండొచ్చు';

  @override
  String get rooms_reason2 => 'వేధింపులు లేదా బెదిరింపులు';

  @override
  String get rooms_reason3 => 'లైంగిక కంటెంట్ లేదా ప్రవర్తన';

  @override
  String get rooms_reason4 => 'ద్వేషం లేదా దూషణలు';

  @override
  String get rooms_reason5 => 'కాంటాక్ట్ వివరాలు లేదా వ్యక్తిగత సమాచారం';

  @override
  String get rooms_reason6 => 'స్పామ్ లేదా అమ్మకాలు';

  @override
  String get rooms_reason7 => 'ఎవరైనా 13 ఏళ్ల లోపు వారు కావచ్చు';

  @override
  String get rooms_reason8 => 'ఇంకేదైనా';

  @override
  String get rooms_reason9 =>
      'చిన్న వయసు వారిని లక్ష్యంగా చేసుకుంటున్నట్టు అనిపిస్తోంది';

  @override
  String get rooms_reportNoteLabel =>
      'మోడరేటర్‌కు తెలియాల్సింది ఏదైనా ఉందా? (ఐచ్ఛికం)';

  @override
  String get rooms_reportNoteHelp =>
      'దీన్ని Aura మోడరేటర్‌లు మాత్రమే చదువుతారు. దయచేసి ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ రాయకండి.';

  @override
  String get rooms_reportNoteContact =>
      'ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ ఇక్కడ పంచుకోలేరు. ఇది అందరినీ సురక్షితంగా ఉంచుతుంది.';

  @override
  String get rooms_reportSend => 'రిపోర్ట్ పంపండి';

  @override
  String get rooms_reportThanks =>
      'మాకు చెప్పినందుకు ధన్యవాదాలు. ఒక మోడరేటర్ సాధారణంగా ఒక రోజులో దీన్ని చూస్తారు.';

  @override
  String get rooms_reportHidden =>
      'చెప్పినందుకు ధన్యవాదాలు. మోడరేటర్ చూసే వరకు ఈ రూమ్‌లో వాళ్ళ సంజ్ఞలు మీకు రావు.';

  @override
  String get rooms_reportGestureHidden =>
      'చెప్పినందుకు ధన్యవాదాలు. ఆ సంజ్ఞ ఇప్పుడు మీకు కనిపించదు.';

  @override
  String get rooms_reportCrisis =>
      'చెప్పినందుకు ధన్యవాదాలు. ఒక మోడరేటర్ త్వరలో చూస్తారు, సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలో ఉంటుంది.';

  @override
  String get rooms_reportLimit =>
      'ఈ రోజు చాలా రిపోర్ట్‌లు వచ్చాయి. ఎవరైనా ప్రమాదంలో ఉంటే, సహాయం బటన్ ఎప్పుడూ ఇక్కడే ఉంటుంది.';

  @override
  String get rooms_reportFailed =>
      'అది జరగలేదు, కాబట్టి ఏదీ పంపలేదు. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.';

  @override
  String get rooms_reportOffline =>
      'రిపోర్ట్‌లకు కనెక్షన్ కావాలి. ఇంకా ఏదీ పంపలేదు.';

  @override
  String get rooms_surveyTitle =>
      'మీకు కొంచెం ఒంటరితనం తగ్గినట్టు అనిపించిందా?';

  @override
  String get rooms_surveyYes => 'అవును';

  @override
  String get rooms_surveyNo => 'అంతగా లేదు';

  @override
  String get rooms_surveySkip => 'వదిలేయండి';

  @override
  String get sanctuary_title => 'ప్రశాంత నిలయం';

  @override
  String get sanctuary_intro =>
      'మీ కోసమే ఒక ప్రశాంతమైన చోటు. మీ వేగంతోనే వెళ్ళండి. ఇక్కడ దేనికీ స్కోర్ లేదు.';

  @override
  String get sanctuary_todayTitle => 'ఈరోజు ఒక నిమిషం';

  @override
  String get sanctuary_breatheSection => 'శ్వాస';

  @override
  String get sanctuary_breatheCard => 'మీ Auraతో కలిసి శ్వాస తీసుకోండి';

  @override
  String get sanctuary_breatheCardBody =>
      'ప్రశాంతమైన, బాక్స్ లేదా 4-7-8 శ్వాస. మీకు ఎంతసేపు కావాలంటే అంతసేపు.';

  @override
  String get sanctuary_groundingSection => 'మనసు నిలకడకు';

  @override
  String get sanctuary_begin => 'మొదలుపెట్టండి';

  @override
  String get sanctuary_start => 'మొదలుపెట్టండి';

  @override
  String get sanctuary_pause => 'ఆపండి';

  @override
  String get sanctuary_resume => 'మళ్ళీ కొనసాగించండి';

  @override
  String get sanctuary_finish => 'ముగించండి';

  @override
  String get sanctuary_next => 'తర్వాత';

  @override
  String get sanctuary_progress => 'ఈ సెషన్‌లో ఎంతవరకు వచ్చారు';

  @override
  String get sanctuary_progressBegun => 'ఇప్పుడే మొదలైంది';

  @override
  String get sanctuary_progressHalf => 'దాదాపు సగం';

  @override
  String get sanctuary_progressNearly => 'దాదాపు పూర్తయింది';

  @override
  String get sanctuary_progressDone => 'పూర్తయింది';

  @override
  String habits_autoLogged(String habit) {
    return 'ఈరోజు $habit అయినట్టు గుర్తించాం.';
  }

  @override
  String get breathe_rhythm => 'లయ';

  @override
  String get breathe_calm => 'ప్రశాంతం';

  @override
  String get breathe_calmBody =>
      '4 లెక్కలు లోపలికి, 6 బయటకు. మెల్లగా, స్థిరంగా.';

  @override
  String get breathe_box => 'బాక్స్';

  @override
  String get breathe_boxBody =>
      'లోపలికి, ఆపి, బయటకు, ఆపి. ఒక్కోటి నాలుగు లెక్కలు.';

  @override
  String get breathe_478 => '4-7-8';

  @override
  String get breathe_478Body => '4 లెక్కలు లోపలికి, 7 ఆపి, 8 బయటకు.';

  @override
  String get breathe_lightHeaded =>
      'తల తిరుగుతున్నట్టు అనిపిస్తే, ఆపేసి మామూలుగా శ్వాస తీసుకోండి.';

  @override
  String get breathe_length => 'ఎంతసేపు';

  @override
  String breathe_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count నిమిషాలు',
      one: '1 నిమిషం',
    );
    return '$_temp0';
  }

  @override
  String get breathe_openEnded => 'నేను ఆపేవరకు';

  @override
  String get breathe_in => 'శ్వాస లోపలికి';

  @override
  String get breathe_hold => 'ఆపి ఉంచండి';

  @override
  String get breathe_out => 'శ్వాస బయటకు';

  @override
  String get breathe_paused => 'ఆగింది. మీకు కావలసినంత సమయం తీసుకోండి.';

  @override
  String get breathe_done => 'ఇది మీ కోసమే తీసుకున్న సమయం.';

  @override
  String get breathe_again => 'మళ్ళీ';

  @override
  String get breathe_land1 => 'మీ పాదాలు నేలను తాకుతున్నట్టు గమనించండి.';

  @override
  String get breathe_land2 =>
      'మీ చుట్టూ వినిపిస్తున్న మూడు శబ్దాలను గమనించండి.';

  @override
  String get breathe_keepGoing => 'కొనసాగిద్దాం';

  @override
  String get breathe_land3 => 'భుజాలను వదులుగా వదిలేయండి.';

  @override
  String get senses_title => 'ఐదు ఇంద్రియాలు';

  @override
  String get senses_card => 'మీ చుట్టూ ఉన్నవాటిని ఒక్కో ఇంద్రియంతో గమనించండి.';

  @override
  String get senses_intro =>
      'మీ చుట్టూ ఉన్నవాటిని ఒక్కో ఇంద్రియంతో గమనిద్దాం. మీ వేగంతోనే వెళ్ళండి.';

  @override
  String get senses_see => 'మీకు కనిపిస్తున్న ఐదు వస్తువులు';

  @override
  String get senses_seeBody =>
      'నెమ్మదిగా చుట్టూ చూడండి. మనసులో గానీ, పైకి గానీ వాటి పేర్లు చెప్పండి.';

  @override
  String get senses_touch => 'మీరు తాకగలిగే నాలుగు విషయాలు';

  @override
  String get senses_touchBody =>
      'మీ కింద కుర్చీ, మీ బట్టలు, మీ చర్మాన్ని తాకే గాలి.';

  @override
  String get senses_hear => 'మీకు వినిపిస్తున్న మూడు శబ్దాలు';

  @override
  String get senses_hearBody =>
      'దగ్గరివైనా, దూరానివైనా, పెద్దవైనా, మెల్లనివైనా.';

  @override
  String get senses_smell => 'మీకు వాసన తెలుస్తున్న రెండు విషయాలు';

  @override
  String get senses_smellBody =>
      'దగ్గర ఏమీ లేకపోతే, మీకు నచ్చిన రెండు వాసనలు గుర్తు చేసుకోండి.';

  @override
  String get senses_taste => 'మీకు రుచి తెలుస్తున్న ఒక్క విషయం';

  @override
  String get senses_tasteBody => 'లేదా కొంచెం నీళ్ళు తాగి ఆ రుచిని గమనించండి.';

  @override
  String senses_step(int step, int total) {
    return '$totalలో $stepవ అడుగు';
  }

  @override
  String get senses_done => 'మీరు ఇక్కడే, ఈ క్షణంలోనే ఉన్నారు. బాగా చేశారు.';

  @override
  String get heart_title => 'గుండెపై చేయి';

  @override
  String get heart_card => 'మీ కోసమే ఒక నిమిషం వెచ్చదనం.';

  @override
  String get heart_intro =>
      'మీ చేతిని గుండెపై, లేదా మీకు హాయిగా అనిపించే చోట ఉంచండి.';

  @override
  String get heart_1 => 'మీ చేతి వెచ్చదనాన్ని గమనించండి.';

  @override
  String get heart_2 => 'మెల్లగా శ్వాస తీసుకోండి. తొందర ఏమీ లేదు.';

  @override
  String get heart_3 => 'మీకు ఏం అనిపిస్తున్నా, ఇక్కడ దానికి చోటు ఉంది.';

  @override
  String get heart_4 =>
      'స్నేహితుల పట్ల ఎంత దయగా ఉంటారో, మీ పట్ల కూడా అంతే దయగా ఉండండి.';

  @override
  String get heart_done => 'మీ పట్ల మీరు మృదువుగా ఉన్నందుకు ధన్యవాదాలు.';

  @override
  String get gratitude_title => 'మూడు చిన్న విషయాలు';

  @override
  String get gratitude_card => 'ఈరోజు బాగానే జరిగిన మూడు చిన్న విషయాలు.';

  @override
  String get gratitude_intro =>
      'ఈరోజు జరిగిన మూడు చిన్న విషయాలను ఒక్కొక్కటిగా గుర్తు తెచ్చుకోండి. ఏమీ రాయనక్కర్లేదు.';

  @override
  String get gratitude_1 => 'బాగానే జరిగిన ఒక చిన్న విషయం';

  @override
  String get gratitude_1Body =>
      'అది చాలా చిన్నదైనా పర్వాలేదు, ఒక వేడి పానీయం లేదా ఒక మంచి మాట లాంటిది.';

  @override
  String get gratitude_2 => 'ఇంకొక చిన్న విషయం';

  @override
  String get gratitude_2Body => 'మీరు చూసినది, విన్నది లేదా చేసినది ఏదైనా.';

  @override
  String get gratitude_3 => 'మరొక్క చిన్న విషయం';

  @override
  String get gratitude_3Body => 'బహుశా మీ గురించే ఏదైనా.';

  @override
  String get gratitude_done => 'వాటిని ఒక క్షణం పట్టుకుని ఉండండి. అవి మీవే.';

  @override
  String get savour_intro =>
      'ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని మెల్లగా మళ్ళీ గుర్తు చేసుకుందాం.';

  @override
  String get savour_1 =>
      'ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని గుర్తు తెచ్చుకోండి, ఎంత చిన్నదైనా.';

  @override
  String get savour_2 =>
      'అప్పుడు మీరు ఎక్కడ ఉన్నారు? ఏం కనిపించింది, ఏం వినిపించింది?';

  @override
  String get savour_3 =>
      'ఇప్పుడు దాన్ని గుర్తు చేసుకుంటే ఎలా అనిపిస్తోందో గమనించండి.';

  @override
  String get savour_done => 'అది మీతో ఇంకొంచెం సేపు ఉండనివ్వండి.';

  @override
  String get minute_forYou => 'మీ కోసం ఒక నిమిషం';

  @override
  String get minute_calmTitle => 'ఒక ప్రశాంత నిమిషం';

  @override
  String get minute_boxTitle => 'బాక్స్ శ్వాస';

  @override
  String get minute_478Title => '4-7-8 శ్వాస';

  @override
  String get minute_stillnessTitle => 'ఒక నిమిషం నిశ్చలత';

  @override
  String get minute_stillnessBody => 'గోళంతో కలిసి ఒక నిశ్శబ్ద నిమిషం.';

  @override
  String get minute_landTitle => 'నిలదొక్కుకోవడానికి ముప్పై సెకన్లు';

  @override
  String get minute_landBody => 'గోళంతో కలిసి మూడు నెమ్మది శ్వాసలు.';

  @override
  String get minute_comfortTitle => 'కొంచెం ఊరట';

  @override
  String get minute_comfortBody => 'గుండెపై ఒక చేయి, ఒక నిమిషం వెచ్చదనం.';

  @override
  String get minute_savourTitle => 'దీన్ని ఆస్వాదించండి';

  @override
  String get minute_savourBody =>
      'ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని మళ్ళీ గుర్తు చేసుకోండి.';

  @override
  String get companion_storm1 =>
      'ఒకేసారి చాలా అనిపిస్తోంది. మీ వెలుగు ఇంకా ఇక్కడే ఉంది.';

  @override
  String get companion_storm2 =>
      'తుఫానుకు పేరు పెట్టడానికి ధైర్యం కావాలి. మీరు మీ కోసం వచ్చారు.';

  @override
  String get companion_storm3 =>
      'పెద్ద, గట్టి భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.';

  @override
  String get companion_storm4 =>
      'తుఫాను రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get companion_storm5 => 'మీరు దీన్ని నిజాయితీగా చెప్పారు. అది ముఖ్యం.';

  @override
  String get companion_storm6 => 'తుఫానులు కూడా మీ ఆకాశంలో భాగమే.';

  @override
  String get companion_storm7 =>
      'లోపల ఏం సుడులు తిరుగుతున్నా, మీరు దాన్ని గమనించారు. అది విలువైనది.';

  @override
  String get companion_storm8 => 'తుఫానులో కూడా, మీ వెలుగు మీదే.';

  @override
  String get companion_rain1 =>
      'ఇది భారంగా అనిపిస్తోంది. మీ వెలుగు ఇంకా మీతోనే ఉంది.';

  @override
  String get companion_rain2 =>
      'నిరుత్సాహమైన రోజు గురించి నిజాయితీగా ఉండటానికి ధైర్యం కావాలి. మీరు మీ కోసం వచ్చారు.';

  @override
  String get companion_rain3 =>
      'నెమ్మదైన, బరువైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.';

  @override
  String get companion_rain4 =>
      'వాన రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get companion_rain5 =>
      'ఈరోజు మీతో మీరు నిజాయితీగా ఉన్నారు. అది ముఖ్యం.';

  @override
  String get companion_rain6 => 'వాన కూడా మీ ఆకాశంలో భాగమే.';

  @override
  String get companion_rain7 =>
      'ఎంత భారంగా ఉన్నా, మీరు దాన్ని గమనించారు. అది విలువైనది.';

  @override
  String get companion_rain8 => 'మబ్బు పట్టిన రోజుల్లో కూడా, మీ వెలుగు మీదే.';

  @override
  String get companion_moonlight1 =>
      'నిశ్శబ్దమైన, స్థిరమైన క్షణం. మీ వెలుగు హాయిగా విశ్రాంతి తీసుకుంటోంది.';

  @override
  String get companion_moonlight2 =>
      'ఒక ప్రశాంత క్షణాన్ని గమనించడం విలువైనది. మీరు మీ కోసం వచ్చారు.';

  @override
  String get companion_moonlight3 =>
      'మెత్తని, హాయైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.';

  @override
  String get companion_moonlight4 =>
      'మెల్లని రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get companion_moonlight5 =>
      'దీన్ని గమనించడానికి మీరు ఒక క్షణం తీసుకున్నారు. అది ముఖ్యం.';

  @override
  String get companion_moonlight6 => 'వెన్నెల కూడా మీ ఆకాశంలో భాగమే.';

  @override
  String get companion_moonlight7 =>
      'ఈ ప్రశాంతత ఎంత చిన్నదైనా, మీరు దాన్ని గమనించారు. అది విలువైనది.';

  @override
  String get companion_moonlight8 => 'ఈ నిశ్శబ్దంలో, మీ వెలుగు మీదే.';

  @override
  String get companion_sunrise1 =>
      'వెలుగుతో నిండిన క్షణం. మీ వెలుగు ప్రకాశిస్తోంది.';

  @override
  String get companion_sunrise2 =>
      'ఒక మంచి క్షణాన్ని గమనించడం విలువైనది. మీరు మీ కోసం వచ్చారు.';

  @override
  String get companion_sunrise3 =>
      'పెద్ద, ప్రకాశవంతమైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.';

  @override
  String get companion_sunrise4 =>
      'వెలుగు రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get companion_sunrise5 =>
      'దీన్ని గమనించడానికి మీకు మీరు అవకాశం ఇచ్చారు. అది ముఖ్యం.';

  @override
  String get companion_sunrise6 => 'సూర్యోదయం కూడా మీ ఆకాశంలో భాగమే.';

  @override
  String get companion_sunrise7 =>
      'ఇది పెద్దదైనా, చిన్నదైనా, మీరు దాన్ని గమనించారు. అది విలువైనది.';

  @override
  String get companion_sunrise8 => 'ఈ సంతోషంలో, మీ వెలుగు మీదే.';

  @override
  String get companion_neutral1 => 'చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.';

  @override
  String get companion_neutral2 => 'మీరు మీ కోసం వచ్చారు.';

  @override
  String get companion_neutral3 => 'మీ వెలుగు ఇంకా ఇక్కడే ఉంది.';

  @override
  String get companion_neutral4 => 'ఇక్కడ తొందర ఏమీ లేదు.';

  @override
  String get prompt_note1 => 'ఈరోజు కొంచెం సహాయపడిన ఒక చిన్న విషయం ఏది?';

  @override
  String get prompt_note2 => 'ఇప్పుడు మీ మనసులో ఏముంది?';

  @override
  String get prompt_note3 =>
      'ఈరోజు గురించి మీరు ఏం గుర్తుంచుకోవాలనుకుంటున్నారు?';

  @override
  String get prompt_storm1 =>
      'ఇప్పుడు మీ మనసులో ఎక్కువ చోటు తీసుకుంటున్నది ఏది?';

  @override
  String get prompt_storm2 => 'ఈ భావన మాట్లాడగలిగితే, అది ఏం చెబుతుంది?';

  @override
  String get prompt_storm3 => 'ఒక్క నిమిషమైనా పక్కన పెట్టగలిగే ఒక విషయం ఏది?';

  @override
  String get prompt_rain1 => 'ఇప్పుడు మీకు ఏది హాయిగా అనిపిస్తుంది?';

  @override
  String get prompt_rain2 => 'ఈరోజు మీ మనసుపై బరువుగా ఉన్నది ఏది?';

  @override
  String get prompt_rain3 => 'ఈ మధ్య మీ పట్ల దయగా అనిపించింది ఎవరు, లేదా ఏది?';

  @override
  String get prompt_moonlight1 => 'మీరు స్థిరంగా ఉండటానికి ఏది సహాయపడుతోంది?';

  @override
  String get prompt_moonlight2 => 'ఈరోజు ఏది హాయిగా అనిపించేలా చేసింది?';

  @override
  String get prompt_moonlight3 =>
      'ఈ క్షణం నుంచి మీరు ఏం దాచుకోవాలనుకుంటున్నారు?';

  @override
  String get prompt_sunrise1 => 'ఈరోజు మీలో ఉత్సాహం నింపుతున్నది ఏది?';

  @override
  String get prompt_sunrise2 =>
      'బాగా జరిగిన ఏ విషయాన్ని మీరు గుర్తుంచుకోవాలనుకుంటున్నారు?';

  @override
  String get prompt_sunrise3 => 'దీన్ని మీరు ఎవరితో పంచుకోవాలనుకుంటున్నారు?';

  @override
  String get prompt_capsule1 =>
      'భవిష్యత్తులోని మీకు మీరు ఏం తెలియజేయాలనుకుంటున్నారు?';

  @override
  String get prompt_capsule2 =>
      'ఇప్పుడు మీకు సహాయపడుతున్న, తర్వాత మర్చిపోయే అవకాశం ఉన్న విషయం ఏది?';

  @override
  String get prompt_capsule3 => 'కష్టమైన రోజున మీకు మీరు ఏం చెప్పుకుంటారు?';

  @override
  String get prompt_capsuleStorm =>
      'అంతా ఎక్కువైపోయినట్టు అనిపించినప్పుడు ఏది సహాయపడుతుంది?';

  @override
  String get prompt_capsuleRain => 'భారమైన రోజున మీరు ఏం వినాలనుకుంటారు?';

  @override
  String get prompt_capsuleMoonlight =>
      'ఈ ప్రశాంతతను మళ్ళీ పొందడానికి ఏది సహాయపడుతుంది?';

  @override
  String get prompt_capsuleSunrise =>
      'భవిష్యత్తులోని మీతో మీరు ఏ సంతోషాన్ని పంచుకోవాలనుకుంటున్నారు?';

  @override
  String get prompt_another => 'ఇంకో ప్రశ్న';

  @override
  String get prompt_settingsTitle => 'రాయడానికి సూచనలు';

  @override
  String get prompt_settingsBody =>
      'ఖాళీ నోట్‌లో ఒక మృదువైన ప్రశ్న. ఇది ఎప్పుడూ సేవ్ అవ్వదు.';

  @override
  String get backfill_add => 'గత చెక్-ఇన్ జోడించండి';

  @override
  String get backfill_pickTitle => 'ఏ రోజు?';

  @override
  String backfill_pickBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'గత $count రోజుల్లో ఏ రోజుకైనా చెక్-ఇన్ జోడించవచ్చు.',
      one: 'నిన్నటి కోసం చెక్-ఇన్ జోడించవచ్చు.',
    );
    return '$_temp0';
  }

  @override
  String get backfill_title => 'అప్పుడు మీకు ఎలా అనిపించింది?';

  @override
  String backfill_forDay(String day) {
    return '$day కోసం చెక్-ఇన్';
  }

  @override
  String get backfill_changeDay => 'రోజు మార్చండి';

  @override
  String get backfill_outOfRange =>
      'గత చెక్-ఇన్‌లు ఒక వారం వెనక్కి వరకే జోడించగలం. వేరే రోజు ఎంచుకుంటారా?';

  @override
  String get backfill_savedTitle => 'మీ ఆకాశంలో చేరింది';

  @override
  String backfill_savedDay(String day) {
    return '$day కోసం సేవ్ అయింది.';
  }

  @override
  String get backfill_savedBody =>
      'Starlight ఆ రోజే చేసిన చెక్-ఇన్‌ల నుంచి వస్తుంది.';

  @override
  String get history_addedLater => 'తర్వాత జోడించింది';

  @override
  String history_whenAddedLater(String day) {
    return '$day · తర్వాత జోడించింది';
  }

  @override
  String get shell_tabHome => 'హోమ్';

  @override
  String get shell_tabSanctuary => 'ప్రశాంత నిలయం';

  @override
  String get shell_tabRooms => 'రూమ్‌లు';

  @override
  String get shell_tabInsights => 'అవగాహన';

  @override
  String get shell_checkIn => 'చెక్-ఇన్';

  @override
  String get shell_checkInHint => 'కొత్త చెక్-ఇన్ మొదలవుతుంది';

  @override
  String get safety_emergencyWhen =>
      'మీరు గానీ, మీ దగ్గర ఉన్నవారు గానీ తక్షణ ప్రమాదంలో ఉన్నా, తీవ్రంగా గాయపడినా, సురక్షితంగా ఉండలేకపోయినా వెంటనే అత్యవసర సేవలకు కాల్ చేయండి.';

  @override
  String get safety_settingsLink => 'సెట్టింగ్‌లలో సహాయం & భద్రత';

  @override
  String get safety_settingsHint =>
      'సపోర్ట్ సంప్రదింపు, గ్రీవెన్స్ ఆఫీసర్, విధానాలు';

  @override
  String get sounds_title => 'శబ్దాలు';

  @override
  String get sounds_cardBody =>
      'వర్షం, సముద్రం, గాలి ఇంకా మరెన్నో. మీరు ఎంచుకునే వరకు ఏదీ వినిపించదు.';

  @override
  String get sounds_cardPlaying => 'ఇప్పుడు వినిపిస్తోంది';

  @override
  String get sounds_intro =>
      'మొదలుపెట్టడానికి ఒక శబ్దం ఎంచుకోండి, లేదా నాలుగు వరకు కలపండి. మీరు నొక్కే వరకు ఏదీ వినిపించదు.';

  @override
  String get sounds_nothingPlaying => 'ఏదీ వినిపించడం లేదు';

  @override
  String get sounds_statePlaying => 'వినిపిస్తోంది';

  @override
  String get sounds_statePaused => 'ఆగింది';

  @override
  String get sounds_backgroundNote =>
      'స్క్రీన్ ఆఫ్ అయినా శబ్దాలు వినిపిస్తూనే ఉంటాయి. హెడ్‌ఫోన్లు డిస్‌కనెక్ట్ అయినా, కాల్ వచ్చినా ఆగుతాయి.';

  @override
  String get sounds_notificationChannel => 'శబ్దాల ప్లేబ్యాక్';

  @override
  String get sounds_windDownTitle => 'రాత్రి ప్రశాంత శబ్దాలు';

  @override
  String get sounds_windDownBody =>
      'సుమారు 20 నిమిషాల శబ్దాలు, మెల్లగా తగ్గుతూ నిశ్శబ్దంలోకి వెళ్తాయి. ప్రతి రాత్రి వాటి క్రమం మారుతుంది.';

  @override
  String get sounds_windDownBegin => 'మొదలుపెట్టండి';

  @override
  String sounds_windDownLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'సుమారు $minutes నిమిషాలు మిగిలాయి',
      one: 'సుమారు 1 నిమిషం మిగిలింది',
    );
    return '$_temp0';
  }

  @override
  String get sounds_windDownBusy =>
      'రాత్రి శబ్దాలు వినిపిస్తున్నాయి. మీ సొంత మిక్స్ కోసం ముందు వాటిని ఆపండి.';

  @override
  String get sounds_mixSection => 'మీకు నచ్చినట్టు కలపండి';

  @override
  String get sounds_mixHint =>
      'ఒకేసారి నాలుగు వరకు, ఒక్కోదానికి వేరే వాల్యూమ్.';

  @override
  String get sounds_stemRain => 'వర్షం';

  @override
  String get sounds_stemOcean => 'సముద్రం';

  @override
  String get sounds_stemWind => 'గాలి';

  @override
  String get sounds_stemNightInsects => 'రాత్రి కీటకాలు';

  @override
  String get sounds_stemSingingBowl => 'సింగింగ్ బౌల్';

  @override
  String get sounds_stemChimes => 'గాలి గంటలు';

  @override
  String get sounds_stemBrownNoise => 'బ్రౌన్ నాయిస్';

  @override
  String get sounds_stemPinkNoise => 'పింక్ నాయిస్';

  @override
  String get sounds_stemDeepBell => 'దూరపు గంట';

  @override
  String get sounds_stemMonsoonRoof => 'పైకప్పు మీద వాన';

  @override
  String get sounds_stemStream => 'వాగు';

  @override
  String get sounds_stemFireplace => 'మంట చిటపటలు';

  @override
  String get sounds_stemDistantThunder => 'దూరపు ఉరుములు';

  @override
  String sounds_stemOn(String name, int percent) {
    return '$name, వినిపిస్తోంది, వాల్యూమ్ $percent%';
  }

  @override
  String sounds_stemPaused(String name, int percent) {
    return '$name, ఆగింది, వాల్యూమ్ $percent%';
  }

  @override
  String sounds_stemOff(String name) {
    return '$name, ఆఫ్';
  }

  @override
  String sounds_stemLocked(String name) {
    return '$name, Aura Plusలో భాగం';
  }

  @override
  String sounds_stemNeedsDownload(String name, String size) {
    return '$name, ఒకసారి $size డౌన్‌లోడ్ చేయాలి';
  }

  @override
  String sounds_stemDownloading(String name) {
    return '$name, డౌన్‌లోడ్ అవుతోంది';
  }

  @override
  String sounds_volume(String name) {
    return '$name వాల్యూమ్';
  }

  @override
  String get sounds_plusBadge => 'Aura Plus';

  @override
  String get sounds_plusNote => 'Aura Plusతో వస్తుంది.';

  @override
  String get sounds_full =>
      'నాలుగు శబ్దాలు వినిపిస్తున్నాయి. ఇంకొకటి జోడించడానికి ఒకదాన్ని ఆపండి.';

  @override
  String get sounds_play => 'వినిపించండి';

  @override
  String get sounds_pause => 'ఆపండి';

  @override
  String get sounds_stop => 'ముగించండి';

  @override
  String get sounds_timer => 'టైమర్';

  @override
  String get sounds_timerTitle => 'ఇంత సమయం తర్వాత మెల్లగా ఆగుతుంది';

  @override
  String get sounds_timerOff => 'ఆఫ్';

  @override
  String sounds_timerValue(String value) {
    return 'టైమర్ · $value';
  }

  @override
  String sounds_timerLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'సుమారు $minutes నిమిషాల్లో మెల్లగా ఆగుతుంది',
      one: 'సుమారు 1 నిమిషంలో మెల్లగా ఆగుతుంది',
    );
    return '$_temp0';
  }

  @override
  String get sounds_fadingOut => 'మెల్లగా ఆగుతోంది';

  @override
  String get sounds_saveMix => 'ఈ మిక్స్ సేవ్ చేయండి';

  @override
  String get sounds_savedMixes => 'సేవ్ చేసిన మిక్స్‌లు';

  @override
  String get sounds_mixSaved => 'ఈ ఫోన్‌లో సేవ్ అయింది.';

  @override
  String get sounds_mixAlreadySaved => 'ఈ మిక్స్ ఇప్పటికే సేవ్ అయి ఉంది.';

  @override
  String sounds_playMix(String mix) {
    return '$mix వినిపించండి';
  }

  @override
  String sounds_removeMix(String mix) {
    return '$mix తీసేయండి';
  }

  @override
  String get sounds_mixUnavailable => 'ఈ మిక్స్ ఇప్పుడు వినిపించదు.';

  @override
  String get sounds_downloadTitle => 'రికార్డ్ చేసిన శబ్దాలు';

  @override
  String sounds_downloadBody(String size) {
    return 'ఒకసారి $size డౌన్‌లోడ్ చేయాలి. ఆ తర్వాత ఇంటర్నెట్ లేకుండానే వినిపిస్తాయి. అప్పటివరకు మీ ఫోన్‌లోనే తయారైన శబ్దాలు వినిపిస్తాయి.';
  }

  @override
  String get sounds_download => 'డౌన్‌లోడ్ చేయండి';

  @override
  String get sounds_downloading => 'డౌన్‌లోడ్ అవుతోంది…';

  @override
  String get sounds_downloadOffline =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. బ్రౌన్ నాయిస్, మీ ఫోన్‌లో తయారైన శబ్దాలు ఇప్పుడే వినిపిస్తాయి; రికార్డింగ్‌లు తర్వాత డౌన్‌లోడ్ చేసుకోవచ్చు.';

  @override
  String get sounds_downloadFailed =>
      'డౌన్‌లోడ్ పూర్తి కాలేదు. ఏదీ పోలేదు; తర్వాత మళ్ళీ డౌన్‌లోడ్ చేసుకోవచ్చు.';

  @override
  String sounds_noSpace(String size) {
    return 'శబ్దాలకు సుమారు $size కావాలి. కొంత స్థలం ఖాళీ చేయండి, లేదా బ్రౌన్ నాయిస్ వినండి, దానికి ఏమీ అవసరం లేదు.';
  }

  @override
  String sounds_megabytes(String size) {
    return '$size MB';
  }

  @override
  String get sounds_removeDownloads => 'డౌన్‌లోడ్ చేసిన శబ్దాలు తీసేయండి';

  @override
  String get sounds_downloadsRemoved =>
      'డౌన్‌లోడ్ చేసిన శబ్దాలు తీసేశాం. మీ ఫోన్‌లో తయారైన శబ్దాలు ఇంకా వినిపిస్తాయి.';

  @override
  String get voice_record => 'వాయిస్ నోట్ రికార్డ్ చేయండి';

  @override
  String get voice_recordHint =>
      'ఒక నిమిషం వరకు. ఇది మీకు మాత్రమే వినిపిస్తుంది.';

  @override
  String get voice_rationaleTitle => 'మీ గొంతు కూడా జోడిస్తారా?';

  @override
  String get voice_rationaleBody =>
      'వాయిస్ నోట్ రికార్డ్ చేయడానికి Auraకి మీ మైక్రోఫోన్ కావాలి. రికార్డింగ్‌లు మీకు మాత్రమే ఉంటాయి, రూమ్‌లలో ఎప్పుడూ షేర్ కావు.';

  @override
  String get voice_rationaleAllow => 'అనుమతించండి';

  @override
  String get voice_denied =>
      'వాయిస్ ఆఫ్‌లో ఉంది. బదులుగా టైప్ చేయండి, లేదా సెట్టింగ్‌లలో ఆన్ చేయండి.';

  @override
  String get voice_openSettings => 'సెట్టింగ్‌లు';

  @override
  String get voice_recording => 'రికార్డ్ అవుతోంది';

  @override
  String voice_elapsed(String time, String limit) {
    return '$time · $limit వరకు';
  }

  @override
  String voice_recordingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'రికార్డ్ అవుతోంది, $seconds సెకన్లు',
      one: 'రికార్డ్ అవుతోంది, 1 సెకను',
    );
    return '$_temp0';
  }

  @override
  String get voice_stop => 'రికార్డింగ్ ఆపండి';

  @override
  String get voice_started => 'రికార్డింగ్ మొదలైంది';

  @override
  String voice_recorded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'వాయిస్ నోట్ రికార్డ్ అయింది, $seconds సెకన్లు',
      one: 'వాయిస్ నోట్ రికార్డ్ అయింది, 1 సెకను',
    );
    return '$_temp0';
  }

  @override
  String get voice_limitReached =>
      'ఒక నిమిషం పూర్తయింది, అందుకే రికార్డింగ్ ఆగింది. మీ వాయిస్ నోట్ సిద్ధంగా ఉంది.';

  @override
  String get voice_recordFailed =>
      'ఇప్పుడు వాయిస్ రికార్డ్ కాలేదు. మీ మాటలు మాత్రం సేవ్ అవుతాయి.';

  @override
  String get voice_note => 'వాయిస్ నోట్';

  @override
  String voice_length(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds సెకన్లు',
      one: '1 సెకను',
    );
    return '$_temp0';
  }

  @override
  String get voice_play => 'వాయిస్ నోట్ ప్లే చేయండి';

  @override
  String get voice_pause => 'వాయిస్ నోట్ ఆపండి';

  @override
  String get voice_reRecord => 'మళ్ళీ రికార్డ్ చేయండి';

  @override
  String get voice_remove => 'తీసేయండి';

  @override
  String get voice_removeSemantic => 'వాయిస్ నోట్ తీసేయండి';

  @override
  String get voice_dropped =>
      'మీ చెక్-ఇన్ సేవ్ అయింది. ఫోన్‌లో స్థలం తక్కువగా ఉండటం వల్ల వాయిస్ నోట్ ఉంచలేకపోయాం.';

  @override
  String get voice_loading => 'మీ వాయిస్ నోట్ తెస్తున్నాం…';

  @override
  String get voice_offline =>
      'మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక వాయిస్ నోట్ ప్లే అవుతుంది.';

  @override
  String get voice_failed =>
      'ఈ వాయిస్ నోట్ ఇప్పుడు ప్లే కాలేదు. కాసేపాగి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get voice_section => 'మీ గొంతు';

  @override
  String get voice_hasVoice => 'ఒక వాయిస్ నోట్ ఉంది';
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
  String get habit_breathe => 'Shwaasa';

  @override
  String get habit_journal => 'Diary';

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
  String get signin_busy => 'Oka kshanam';

  @override
  String signin_resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds lo kotta code adagochu',
      one: '1 second lo kotta code adagochu',
    );
    return '$_temp0';
  }

  @override
  String get signin_freshSent => 'Kotta code vastondi.';

  @override
  String get acct_pendingTitle => 'Mee account ni unchukuntaara?';

  @override
  String acct_pendingBody(String date) {
    return 'Mee account $date na delete ayyela set ayyi undi. Daanni unchukuntaara?';
  }

  @override
  String get acct_pendingBodySoon =>
      'Mee account tvaralo delete ayyela set ayyi undi. Daanni unchukuntaara?';

  @override
  String get acct_keep => 'Naa account ni unchandi';

  @override
  String get acct_letGo => 'Vadileyandi';

  @override
  String get acct_keepFailed =>
      'Adi jaragaledu, kabatti inka emi maaraledu. Connect ayyaaka malli try cheyandi.';

  @override
  String get acct_deleteTitle => 'Naa account ni delete cheyandi';

  @override
  String get acct_deleteIntro => 'Mee account delete cheste ivi pothaayi:';

  @override
  String get acct_itemCheckIns => 'Mee check-ins, notes';

  @override
  String get acct_itemHabits => 'Mee habits';

  @override
  String get acct_itemProgress => 'Mee Starlight, mee Aura edugudala';

  @override
  String get acct_itemAccount => 'Mee account, meeru sign in chese email';

  @override
  String get acct_grace =>
      'Manasu maarchukovadaaniki meeku 7 rojulu unnaayi. Aalopu malli sign in cheste anni alaage untaayi. Aa tarvaata adi shaashvatanga delete aipotundi, tirigi teesukuraalemu.';

  @override
  String get acct_store =>
      'Meeru App Store leda Google Play dwaara subscription pay chestunte, account delete chesina adi cancel avvadu. Daanni mee store subscription settings lo manage cheyandi leda cancel cheyandi.';

  @override
  String get acct_phone =>
      'Ee phone lo mee data ventane clear avutundi, sign out avutundi.';

  @override
  String get acct_needsConnection =>
      'Account delete cheyadaaniki internet connection kaavali. Connect ayyaaka malli try cheyandi.';

  @override
  String get acct_confirmTitle => 'Mee account ni delete cheyaalaa?';

  @override
  String get acct_confirmBody =>
      'Mee account, andulo unna pratidi 7 rojullo delete avutaayi. Daanni unchukovaalante aalopu malli sign in cheyandi. Ee phone ippude clear avutundi.';

  @override
  String get acct_failed =>
      'Adi jaragaledu, edi delete avvaledu. Koddisepatlo malli try cheyandi.';

  @override
  String get acct_failedOffline =>
      'Aura ni reach avvalekapoyaam, edi delete avvaledu. Mee connection choosukuni malli try cheyandi.';

  @override
  String get acct_retry => 'Malli try cheyandi';

  @override
  String get acct_scheduledTitle => 'Mee account delete ki set ayyindi';

  @override
  String acct_scheduledBody(String date) {
    return 'Adi $date na delete avutundi. Daanni unchukovaalante aalopu malli sign in cheyandi.';
  }

  @override
  String get acct_phoneCleared => 'Ee phone clear ayyindi, sign out ayyindi.';

  @override
  String get acct_signedOut =>
      'Meeru sign in cheyaledu, kabatti delete cheyadaaniki account ledu. Meeru save chesinavi ee phone lo maatrame unnaayi.';

  @override
  String get acct_unavailable =>
      'Ee build lo account delete inka set avvaledu.';

  @override
  String get set_comfort => 'Comfort';

  @override
  String get set_reduceMotion => 'Motion tagginchandi';

  @override
  String get set_reduceMotionNote =>
      'Mee phone setting ni kooda follow avutundi';

  @override
  String get set_haptics => 'Haptics';

  @override
  String get set_hapticsNote =>
      'Meeru edaina select chesinappudu mellani vibration';

  @override
  String get set_hideStreak => 'Streak number daachandi';

  @override
  String get set_hideStreakNote =>
      'Mee glow perugutune untundi. Home lo rojula lekka maatram kanipinchadu.';

  @override
  String get set_signOutTitle => 'Aura nundi sign out cheyaalaa?';

  @override
  String get set_helpSafety => 'Help & Safety';

  @override
  String get set_grievanceOfficer => 'Grievance Officer';

  @override
  String get set_grievanceSubject => 'Aura gurinchi complaint';

  @override
  String get set_contactSupport => 'Support ni contact cheyandi';

  @override
  String get set_supportSubject => 'Aura support';

  @override
  String get set_opensEmail => 'Mee email app open avutundi';

  @override
  String set_emailFailed(String email) {
    return 'Email app open cheyalekapoyaam. Meeru $email ki raayochu.';
  }

  @override
  String get acct_inProgress =>
      'Ee account delete avvadam ippatike modalaindi, kabatti daanni inka unchalemu. Ee phone clear ayyi sign out avutundi.';

  @override
  String get signin_or => 'leda';

  @override
  String get signin_socialNotReady =>
      'Aa sign-in option inka ready ga ledu. Prastutaaniki mee email vaadandi.';

  @override
  String get signin_socialOffline =>
      'Meeru offline lo unnattunnaru. Connect ayyaaka malli try cheyandi.';

  @override
  String get capsules_title => 'Future you';

  @override
  String get capsules_emptyBody =>
      'Future lo unna meeku raayandi. Oka date kosam, leda oka feeling kosam daachi pettandi.';

  @override
  String get capsules_emptyCta => 'Mee first capsule seal cheyandi';

  @override
  String get capsules_new => 'Oka capsule raayandi';

  @override
  String capsules_entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules daachaaru',
      one: '1 capsule daachaaru',
      zero: 'Inka emi daachaledu',
    );
    return '$_temp0';
  }

  @override
  String capsules_entryReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open cheyyadaaniki ready ga unnaayi',
      one: '1 open cheyyadaaniki ready ga undi',
    );
    return '$_temp0';
  }

  @override
  String get capsules_sectionReady => 'Open cheyyadaaniki ready';

  @override
  String get capsules_sectionSealed => 'Seal chesinavi';

  @override
  String get capsules_sectionOpened => 'Open chesinavi';

  @override
  String capsules_sealedUntil(String date) {
    return '$date varaku seal ayyi undi. Bhadranga untundi.';
  }

  @override
  String get capsules_waitingFeeling => 'Oka feeling kosam wait chestondi';

  @override
  String get capsules_readyRow => 'Meeru ready ainappudu open cheyandi';

  @override
  String capsules_untitled(String date) {
    return '$date naati capsule';
  }

  @override
  String get capsules_lockedTitle => 'Seal chesina oka capsule';

  @override
  String capsules_sealedOn(String date) {
    return '$date na seal chesaaru';
  }

  @override
  String capsules_openedOn(String date) {
    return '$date na open chesaaru';
  }

  @override
  String get capsules_draftTitle => 'Mee draft ikkade undi';

  @override
  String get capsules_draftBody => 'Aapina chotu nundi continue cheyandi.';

  @override
  String get capsules_composeTitle => 'Future lo unna meeku raayandi';

  @override
  String get capsules_titleLabel => 'Title';

  @override
  String get capsules_titleHelper =>
      'Seal ayyi unnappudu capsule meeda idi kanipistundi.';

  @override
  String get capsules_textLabel => 'Mee note';

  @override
  String get capsules_textHelper =>
      'Idi open ainappudu meeru maatrame chaduvutaaru.';

  @override
  String get capsules_photosTitle => 'Photos';

  @override
  String get capsules_addPhoto => 'Oka photo add cheyandi';

  @override
  String get capsules_photoHint =>
      '3 varaku. Location, camera details teesestaam.';

  @override
  String get capsules_photoAdding => 'Mee photo add chestunnaam…';

  @override
  String get capsules_photoFailed =>
      'Aa photo add cheyyalekapoyaam. Inkokati try cheyandi.';

  @override
  String capsules_photoRemove(int index) {
    return 'Photo $index teeseyandi';
  }

  @override
  String capsules_photoSemantic(int index, int count) {
    return '$count lo photo $index';
  }

  @override
  String get capsules_voiceHint =>
      '2 nimishaala varaku. Idi meeku maatrame vinipistundi.';

  @override
  String get capsules_voiceLimit =>
      'Rendu nimishaalu purthayyaayi, anduke recording aagindi. Mee voice note ready ga undi.';

  @override
  String get capsules_unlockTitle => 'Idi eppudu open avvaali?';

  @override
  String get capsules_unlockDate => 'Oka date na';

  @override
  String get capsules_unlockFeeling => 'Oka feeling kosam';

  @override
  String get capsules_pickDate => 'Date select cheyandi';

  @override
  String get capsules_changeDate => 'Date maarchandi';

  @override
  String capsules_dateChosen(String date, String time) {
    return '$date $time ki open avutundi';
  }

  @override
  String get capsules_dateHelp =>
      'Oka vaaram nundi aidu ella lopu e roju aina.';

  @override
  String get capsules_datePickerHelp => 'Aa roju 10:00 ki open avutundi';

  @override
  String get capsules_feelingHelp =>
      'Seal chesina 24 gantala tarvaata nundi, meeru next time ila feel avutu check-in chesinappudu open avvochu.';

  @override
  String capsules_anyQuadrant(String quadrant) {
    return 'Edaina $quadrant feeling';
  }

  @override
  String capsules_feelingChosen(String feeling) {
    return 'Deeni kosam wait chestundi: $feeling';
  }

  @override
  String get capsules_seal => 'Seal cheyandi';

  @override
  String get capsules_needContent =>
      'Mundu konni maatalu, oka voice note leda oka photo add cheyandi.';

  @override
  String get capsules_needUnlock => 'Idi eppudu open avvaalo select cheyandi.';

  @override
  String get capsules_sealFailed =>
      'Ippudu seal avvaledu. Mee capsule ikkade undi. Malli try cheyandi.';

  @override
  String get capsules_sealedTitle => 'Seal ayyindi';

  @override
  String get capsules_sealedFeeling =>
      'Seal chesaam. Aa feeling kosam wait chestundi.';

  @override
  String get capsules_mediaLater =>
      'Ee phone lo bhadranga seal chesaam. Meeru online ki vachaaka photos, voice backup avutaayi.';

  @override
  String get capsules_limitBody =>
      'Free account lo 3 mood capsules varaku wait cheyyochu. Date capsules ki limit ledu.';

  @override
  String get capsules_limitPickDate => 'Badulu ga oka date select cheyandi';

  @override
  String get capsules_makeDate => 'Deenni date capsule ga maarchandi';

  @override
  String get capsules_leaveTitle => 'Ee draft unchaalaa?';

  @override
  String get capsules_leaveBody =>
      'Meeru deenni seal chese varaku leda vadilese varaku idi ee phone lone untundi.';

  @override
  String get capsules_leaveEditing => 'Raayadam continue cheyandi';

  @override
  String get capsules_leaveKeep => 'Draft unchandi';

  @override
  String get capsules_leaveDiscard => 'Vadileyandi';

  @override
  String capsules_detailFeeling(String feeling) {
    return 'Oka feeling kosam wait chestondi: $feeling.';
  }

  @override
  String capsules_detailArming(String date) {
    return '$date nundi open avvochu.';
  }

  @override
  String get capsules_detailNoEarly =>
      'Seal ante seal: deenni mundugaa open cheyyaleru, maarchaleru.';

  @override
  String get capsules_delete => 'Capsule delete cheyandi';

  @override
  String get capsules_deleteTitle => 'Ee capsule delete cheyyaalaa?';

  @override
  String get capsules_deleteBody =>
      'Idi open cheyyakundaane shaashvatanga potundi.';

  @override
  String get capsules_deleteBodyOpened => 'Idi shaashvatanga potundi.';

  @override
  String get capsules_deleteConfirm => 'Delete cheyandi';

  @override
  String get capsules_deleteKeep => 'Unchandi';

  @override
  String get capsules_deleted => 'Capsule delete chesaam.';

  @override
  String get capsules_triggerTitle =>
      'Ilanti moment kosam meeru oka note raasukunnaru. Ippude open cheyyala, tarvatha na?';

  @override
  String get capsules_holdTitle =>
      'Gatam lo mee nundi oka note wait chestondi. Ippude open cheyyala, tarvatha na?';

  @override
  String get capsules_now => 'Ippude';

  @override
  String get capsules_later => 'Tarvatha';

  @override
  String get capsules_readyTitle =>
      'Meeru daachukunnadi ippudu open cheyyochu.';

  @override
  String capsules_readyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules ready ga unnaayi.',
      one: '1 capsule ready ga undi.',
    );
    return '$_temp0';
  }

  @override
  String get capsules_readyOpen => 'Open cheyandi';

  @override
  String get capsules_channelName => 'Capsules';

  @override
  String get capsules_notifyAskTitle =>
      'Idi eppudu open avutundo telusukovaalanukuntunnaaraa?';

  @override
  String get capsules_notifyAskBody =>
      'Adi open ayye roju oka quiet note. Lopala emundo mee lock screen eppudu cheppadu.';

  @override
  String get capsules_channelDescription =>
      'Meeru daachukunnadi open cheyyadaaniki ready ainappudu.';

  @override
  String get capsules_hardMoment =>
      'Meeru idi oka kashtamaina samayam lo raasaaru. Meeru ready ainappudu open cheyandi.';

  @override
  String get capsules_skip => 'Skip cheyandi';

  @override
  String get capsules_opening => 'Mee capsule open avutondi';

  @override
  String get capsules_openedTitle => 'Gatam lo mee nundi';

  @override
  String get capsules_keepNextTime => 'Next time kosam unchandi';

  @override
  String get capsules_keptNextTime =>
      'Idi malli aa feeling kosam wait chestundi.';

  @override
  String get capsules_voiceOffline =>
      'Mee capsule open ayyindi. Meeru malli online ki vachaaka voice note vastundi.';

  @override
  String get capsules_photosOffline =>
      'Meeru malli online ki vachaaka photos vastaayi.';

  @override
  String get capsules_mediaFailed =>
      'Idi ippudu load avvaledu. Kaasepaagi malli try cheyandi.';

  @override
  String get capsules_retry => 'Malli try cheyandi';

  @override
  String get capsules_cantRead =>
      'Ee capsule ni ee phone lo inka chadavalemu. Meeru online ki vachaaka open avutundi.';

  @override
  String capsules_accountDeletionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seal chesina $count capsules potaayi.',
      one: 'Seal chesina 1 capsule potundi.',
    );
    return '$_temp0';
  }

  @override
  String get checkin_discardTitle => 'Save cheyakunda vellipotaara?';

  @override
  String get checkin_discardKeep => 'Ikkade continue chestaanu';

  @override
  String get checkin_discardConfirm => 'Vadileyandi';

  @override
  String checkin_tagLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags varaku',
      one: '1 tag varaku',
    );
    return '$_temp0';
  }

  @override
  String checkin_quadrantAxes(String energy, String feel) {
    return '$energy · $feel';
  }

  @override
  String get history_title => 'Mee check-ins';

  @override
  String get history_private => 'Ivi meeku maatrame kanipistaayi.';

  @override
  String get history_empty =>
      'Ikkada inka emi ledu. Mee check-ins ikkada cherutaayi, avi meeku maatrame kanipistaayi.';

  @override
  String get history_today => 'Ee roju';

  @override
  String get history_yesterday => 'Ninna';

  @override
  String history_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0';
  }

  @override
  String get history_hasNote => 'Oka note undi';

  @override
  String get history_entryTitle => 'Mee check-in';

  @override
  String history_when(String day, String time) {
    return '$day, $time';
  }

  @override
  String get history_tags => 'Tags';

  @override
  String get history_note => 'Mee maatalu';

  @override
  String get history_synced => 'Sync ayyindi';

  @override
  String get history_edit => 'Edit cheyandi';

  @override
  String get history_editWindowOver =>
      'Check-in chesina oka roju varaku daanni maarchukovachu.';

  @override
  String get history_delete => 'Delete cheyandi';

  @override
  String get history_deleteTitle => 'Ee check-in delete cheyyaalaa?';

  @override
  String get history_deleteBody =>
      'Deeni valla mee Starlight gaani glow days gaani maaravu.';

  @override
  String get history_missing => 'Ee check-in ippudu ikkada ledu.';

  @override
  String get history_editNoteLocked =>
      'Ee check-in note inka ee phone ki raaledu. Adi vachaaka meeru dinni edit cheyochu.';

  @override
  String get legal_privacy => 'Privacy policy';

  @override
  String get legal_terms => 'Terms of use';

  @override
  String get legal_opensInBrowser => 'Mee browser lo open avutundi';

  @override
  String get help_crisisSubtitleCapsule =>
      'Idi meeru okkare moyyalsina avasaram ledu. Mee capsule seal ayyindi.';

  @override
  String get help_backToCapsule => 'Naa capsule ki tirigi';

  @override
  String get flows_startOverTitle => 'Malli modati nunchi modalupedadaamaa?';

  @override
  String get flows_startOverBody =>
      'Ippativaraku meeru select chesinavi, raasinavi clear avutaayi.';

  @override
  String get flows_startOver => 'Malli modalupedadaam';

  @override
  String get closed_title => 'Ee account close cheyabadindi';

  @override
  String get closed_body =>
      'Aura rules paatinchananduku ee account close cheyabadindi.';

  @override
  String get closed_review =>
      'Idi porapaatu ani meeku anipiste, malli review cheyamani adagochu. 7 rojullo reply istaam.';

  @override
  String get closed_askReview => 'Review adagandi';

  @override
  String get closed_reviewSubject => 'Closed account review';

  @override
  String get closed_deleteNote =>
      'Mee account ni, andulo unna pratidaanni meeru ippatiki delete cheyochu.';

  @override
  String get closed_signOutNote =>
      'Sign out cheste ee phone nundi ee account clear avutundi.';

  @override
  String get notif_roomsPoolBanner =>
      'Hindi, Hinglish rooms ippudu modalayyaayi.';

  @override
  String get notif_roomsPoolAction => 'Rooms chudandi';

  @override
  String get notif_channelRooms => 'Rooms & Lantern Hour';

  @override
  String get notif_channelRoomsDescription =>
      'Meeru adigina rooms modalainappudu.';

  @override
  String home_stageProgress(String stage, String next, int count, int target) {
    return '$stage, $next vaipu $target lo $count Starlight';
  }

  @override
  String home_constellationProgress(String stage, int count, int max) {
    return '$stage, mee constellation lo $max lo $count stars';
  }

  @override
  String get home_glowTitle => 'Mee glow';

  @override
  String get home_restDaysHint => 'Rest days ela pani chestaayo telusukondi';

  @override
  String get home_restInfoTitle => 'Rest days';

  @override
  String home_restInfoEarn(int days, int max) {
    return 'Prati $days glow days ki oka rest day vastundi. $max varaku daachukovachu.';
  }

  @override
  String get home_restInfoUse =>
      'Meeru konchem break teesukunnappudu, avi aa rojulni vaatantha avey nimputaayi. Meeru emi cheyyalsina avasaram ledu.';

  @override
  String get home_restInfoKeep =>
      'Meeku vachina prati glow day meethone untundi.';

  @override
  String home_checkInsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ee roju $count check-ins',
      one: 'Ee roju 1 check-in',
    );
    return '$_temp0';
  }

  @override
  String get home_seeAll => 'Anni choodandi';

  @override
  String get home_yourCheckIns => 'Mee check-ins';

  @override
  String get home_syncExplainIdle =>
      'Anni ee phone lo, mee account lo save ayyaayi.';

  @override
  String get home_syncExplainPending =>
      'Avi ee phone lo safe ga unnaayi, vaatante sync avutaayi.';

  @override
  String get home_syncExplainOffline =>
      'Meeru offline lo unnaru. Anni ee phone lo safe ga unnaayi, malli online ayyaaka sync avutaayi.';

  @override
  String get home_syncExplainSignedOut =>
      'Meeru sign in avvaledu, kabatti prastutaaniki anni ee phone lone untaayi.';

  @override
  String get home_syncExplainUnavailable =>
      'Ee version anni ee phone lone unchutundi.';

  @override
  String get home_syncNow => 'Ippude sync cheyandi';

  @override
  String get home_syncing => 'Sync avutondi…';

  @override
  String get home_syncHint => 'Sync details choopinchandi';

  @override
  String get habits_edit => 'Edit cheyandi';

  @override
  String get habits_editSemantic => 'Chinna panulni edit cheyandi';

  @override
  String get habits_sheetTitle => 'Mee chinna panulu';

  @override
  String get habits_sheetBody =>
      'Home lo evi kanipinchaalo select cheyandi. Elaagaina check-ins tho mee Aura perugutundi.';

  @override
  String get habits_presetsTitle => 'Suggestions';

  @override
  String get habits_customTitle => 'Mee sontavi';

  @override
  String get habits_addLabel => 'Mee sontadi add cheyandi';

  @override
  String get habits_addHint => 'Udaaharanaki, mokkalaki neellu';

  @override
  String get habits_add => 'Add cheyandi';

  @override
  String habits_limit(int count) {
    return 'Meeku $count custom habits unnaayi. Inkokati add cheyadaaniki okadaanni swap cheyandi.';
  }

  @override
  String get habits_saveFailed => 'Adi save avvaledu. Malli try chestaara?';

  @override
  String habits_remove(String name) {
    return '$name teeseyandi';
  }

  @override
  String habits_removeTitle(String name) {
    return '$name teeseyaalaa?';
  }

  @override
  String get habits_removeBody =>
      'Idi mee list nundi vellipotundi. Deenitho vachina Starlight, glow days alaage untaayi.';

  @override
  String get habits_removeConfirm => 'Teeseyandi';

  @override
  String get habits_empty =>
      'Modalupettadaaniki oka chinna pani select cheyandi.';

  @override
  String get help_groundingProgress => 'Ee nimisham lo entavaraku vachaaru';

  @override
  String get help_progressBegun => 'Ippude modalaindi';

  @override
  String get help_progressHalf => 'Daadaapu sagam';

  @override
  String get help_progressNearly => 'Daadaapu purtayindi';

  @override
  String get help_progressDone => 'Purtayindi';

  @override
  String help_breatheLogged(String habit) {
    return 'Ee roju $habit ayyindani mark chesaam.';
  }

  @override
  String get insights_title => 'Aura Sky';

  @override
  String get insights_private =>
      'Mee sky meeku maatrame kanipistundi. Idantaa ee phone lone lekkistaam.';

  @override
  String get insights_empty =>
      'Meeru check-in chestunna koddi mee sky nindutundi.';

  @override
  String get insights_allCheckIns => 'Anni check-ins';

  @override
  String get insights_viewMonth => 'Nela';

  @override
  String get insights_viewYear => 'Samvatsaram';

  @override
  String get insights_prevMonth => 'Mundu nela';

  @override
  String get insights_nextMonth => 'Tarvaati nela';

  @override
  String get insights_prevYear => 'Mundu samvatsaram';

  @override
  String get insights_nextYear => 'Tarvaati samvatsaram';

  @override
  String insights_dayEmpty(String date) {
    return '$date, quiet sky';
  }

  @override
  String insights_dayRest(String date) {
    return '$date, rest day';
  }

  @override
  String insights_daySingle(String date, String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$date, $quadrant, $_temp0';
  }

  @override
  String insights_dayPair(String date, String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$date, $first and $second samaanamga, $_temp0';
  }

  @override
  String insights_dayMixed(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$date, samaanamaina mix, $_temp0';
  }

  @override
  String get insights_dayHint => 'Ee roju check-ins chupistundi';

  @override
  String get insights_dayNone =>
      'Ee roju emi note avvaledu. Sky prashaanthanga undi.';

  @override
  String insights_monthSemantic(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rojulu check-in',
      one: '1 roju check-in',
      zero: 'quiet sky',
    );
    return '$month, $_temp0';
  }

  @override
  String get insights_legendRest => 'Rest day';

  @override
  String get insights_legendMixed => 'Mixed day';

  @override
  String get insights_patternsTitle => 'Patterns';

  @override
  String get insights_patternsLast30 => 'Mee last 30 rojula nundi';

  @override
  String insights_patternsNeedCheckIns(int count) {
    return '7 check-ins tarvaata patterns kanipistaayi ($count/7)';
  }

  @override
  String insights_patternsNeedDays(int count) {
    return '5 veru veru rojullo check-in chesaaka patterns kanipistaayi ($count/5)';
  }

  @override
  String get insights_patternsNone =>
      'Ippudu clear patterns emi levu. Mee sky ikkade undi.';

  @override
  String insights_patternTag(String tag, String quadrant) {
    return '$tag unna check-ins lo $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternHabit(String habit, String quadrant) {
    return 'Meeru $habit chesina rojullo $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternMorning(String quadrant) {
    return 'Morning lo $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternAfternoon(String quadrant) {
    return 'Madhyaahnam lo $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternEvening(String quadrant) {
    return 'Evening lo $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternNight(String quadrant) {
    return 'Raatri $quadrant ekkuvaga kanipinchindi.';
  }

  @override
  String insights_patternMix(String quadrant) {
    return 'Mee sky lo $quadrant anni kante ekkuvaga kanipinchindi.';
  }

  @override
  String get insights_plusBadge => 'Aura Plus';

  @override
  String get insights_rangeLocked =>
      'Any range, moods tho paatu habits Aura Plus tho vastaayi. Mee sky, 30 rojula patterns eppudu free.';

  @override
  String get insights_rangeLabel => 'Ee kaalam nundi patterns';

  @override
  String get insights_range7 => '7 rojulu';

  @override
  String get insights_range30 => '30 rojulu';

  @override
  String get insights_range90 => '90 rojulu';

  @override
  String get insights_range365 => '1 samvatsaram';

  @override
  String get insights_rangeAll => 'Mottham';

  @override
  String get insights_weeklyTitle => 'Mee last week nundi';

  @override
  String get insights_weeklyHide => 'Ee vaaraaniki daachandi';

  @override
  String get insights_careTitle => 'Last rendu vaaraalu bhaaranga gadichaayi';

  @override
  String get insights_careBody =>
      'Idi meeru okkare moyyalsina avasaram ledu. Meeku eppudu kaavaalante appudu support, oka room ikkade unnaayi.';

  @override
  String get insights_careSupport => 'Support chudandi';

  @override
  String get insights_careRoom => 'Oka room vetakandi';

  @override
  String get insights_monthTitle => 'Stars lo mee nela';

  @override
  String insights_monthCardBody(String month) {
    return 'Mee sky lo $month';
  }

  @override
  String get insights_monthOpen => 'Open cheyandi';

  @override
  String get insights_monthHide => 'Daachandi';

  @override
  String insights_monthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rojulu check-in chesaaru',
      one: '1 roju check-in chesaaru',
    );
    return '$_temp0';
  }

  @override
  String get insights_monthMixTitle => 'Ee nela mee skies';

  @override
  String insights_monthMixItem(String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$quadrant: $_temp0';
  }

  @override
  String insights_monthSkySemantic(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$month lo prati check-in ki oka star, mottham $_temp0';
  }

  @override
  String get insights_deeperTitle => 'Deeper monthly review';

  @override
  String get insights_deeperLocked =>
      'Nela mottham patterns, moods tho paatu habits Aura Plus tho vastaayi.';

  @override
  String get insights_deeperNone => 'Ee nela clear patterns emi levu.';

  @override
  String get insights_statsTitle => 'Ippativaraku';

  @override
  String insights_statsCheckIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$_temp0';
  }

  @override
  String insights_statsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mee sky lo $count rojulu',
      one: 'Mee sky lo 1 roju',
    );
    return '$_temp0';
  }

  @override
  String get notif_reminderBanner =>
      'Mee kosam oka quiet minute. Ee roju ela anipistondi?';

  @override
  String get notif_reminderAction => 'Check in cheyandi';

  @override
  String get notif_capsuleBanner =>
      'Meeru daachukunnadi ippudu open cheyyochu.';

  @override
  String get notif_capsuleAction => 'Open cheyandi';

  @override
  String get notif_channelReminders => 'Reminders';

  @override
  String get notif_channelRemindersDescription =>
      'Mee daily check-in reminder.';

  @override
  String get set_notifications => 'Notifications';

  @override
  String get set_notifMaster => 'Aura nundi notifications';

  @override
  String get set_notifMasterNote =>
      'Rojuki rendu minchi raavu. Meeru ela feel avutunnaro mee lock screen eppudu cheppadu.';

  @override
  String get set_notifReminder => 'Daily check-in reminder';

  @override
  String set_notifReminderNote(String time) {
    return 'Rojuki okka gentle nudge, $time ki. Meeru check-in chesaaka raadu.';
  }

  @override
  String get set_notifReminderOffNote =>
      'Off lo undi. Rojuki okka gentle nudge kaavaalante on cheyandi.';

  @override
  String get set_notifReminderTime => 'Reminder time';

  @override
  String get set_notifCapsule => 'Capsule open cheyyadaaniki ready ainappudu';

  @override
  String get set_notifCapsuleNote =>
      'Meeru daachukunnadaaniki meeru select chesina roju.';

  @override
  String set_notifQuietNote(String start, String end) {
    return 'Quiet hours: $start–$end madhya edi pampam.';
  }

  @override
  String get set_notifQuietFrom => 'Quiet modalu';

  @override
  String get set_notifQuietUntil => 'Quiet mugimpu';

  @override
  String get set_notifDiscreet => 'Discreet mode';

  @override
  String get set_notifDiscreetNote =>
      'Prati notification “Aura · Meeku oka gentle update undi” ani maatrame cheptundi.';

  @override
  String get set_notifOffNote =>
      'Ee phone lo Aura notifications off lo unnaayi. Avi on ayyaaka ikkadi mee choices ey apply avutaayi.';

  @override
  String get set_notifTurnOn => 'On cheyandi';

  @override
  String get set_notifOpenSettings => 'Phone settings open cheyandi';

  @override
  String get set_notifQuietConfirmTitle => 'Ee time mee quiet hours lo undi';

  @override
  String set_notifQuietConfirmBody(String start, String end, String time) {
    return 'Aura $start–$end madhya quiet ga untundi. Ayinaa mee reminder ni $time ki pampaala?';
  }

  @override
  String get set_notifQuietConfirmYes => 'Ayinaa pampandi';

  @override
  String get set_notifQuietConfirmNo => 'Quiet gaane unchandi';

  @override
  String push_timeRow(String time) {
    return 'Prati saayantram $time ki';
  }

  @override
  String get push_changeTime => 'Time maarchandi';

  @override
  String get push_discreet => 'Discreet ga unchandi';

  @override
  String get onb_trustTitle => 'Modalupette mundu';

  @override
  String get onb_trustBody =>
      'Aura mimmalni ela choosukuntundo konni vishayaalu.';

  @override
  String get onb_trustPrivateTitle => 'Modati nunchi private ga';

  @override
  String get onb_trustPrivateBody =>
      'Mee check-ins, notes meeve. Notes encrypt avutaayi. Meeru share cheyaalani enchukunte tappa, meeku ela anipistondo vere evariki kanipinchadu.';

  @override
  String get onb_trustCareTitle => 'Idi wellness support, therapy kaadu';

  @override
  String get onb_trustCareBody =>
      'Meeku ela anipistondo gamaninchukovadaaniki Aura help chestundi. Idi e diagnosis gaani, treatment gaani cheyadu.';

  @override
  String get onb_trustHelpTitle => 'Help eppudu oka tap dooramlone';

  @override
  String onb_trustHelpBody(String button) {
    return 'Helpline ki call cheyadaaniki leda oka nimisham breath meeda dhyaasa pettadaaniki, eppudaina “$button” tap cheyandi.';
  }

  @override
  String get onb_dobYearType => 'Samvatsaram type cheyandi';

  @override
  String get onb_dobYearNoMatch =>
      'Daaniki saripoye samvatsaram list lo ledu. Okasari choosukuntaara?';

  @override
  String get onb_blockedWrongDate => 'Tappu date icchaara?';

  @override
  String get onb_blockedWrongDateHint => 'Mee email app open avutundi';

  @override
  String get onb_blockedMailSubject => 'Aura: nenu tappu date icchaanu';

  @override
  String onb_blockedMailFailed(String email) {
    return 'Email app open cheyyalekapoyaam. $email ki maaku raayochu.';
  }

  @override
  String polish_legalOpenFailed(String url) {
    return 'Mee browser open avvaledu. Aa page $url lo undi.';
  }

  @override
  String get polish_legalCopyLink => 'Link copy cheyandi';

  @override
  String get polish_legalLinkCopied => 'Link copy ayyindi';

  @override
  String polish_helpCallFailed(String number) {
    return 'Ee phone nundi call cheyyadam kudaratledu. Number $number.';
  }

  @override
  String get polish_helpCopyNumber => 'Number copy cheyandi';

  @override
  String get polish_helpNumberCopied => 'Number copy ayyindi';

  @override
  String get reflections_title => 'Reflections';

  @override
  String get reflections_intro =>
      'Ikkada unnavaalla konni maatalu. Veetiki gestures tho maatrame respond avvochu.';

  @override
  String get reflections_share => 'Oka reflection share cheyandi';

  @override
  String get reflections_empty =>
      'Ikkada inka e reflections levu. Meeru okati share cheyochu, leda chadivi gestures pampochu.';

  @override
  String get reflections_emptyMemory =>
      'Ee room lo e reflections share cheyyaledu.';

  @override
  String get reflections_loadFailed => 'Ippudu reflections load kaaledu.';

  @override
  String get reflections_offline =>
      'Reflections ki connection kaavaali. Meeru raasindi ee phone lone untundi.';

  @override
  String get reflections_memory =>
      'Ee room oka memory: indulo reflections chadavochu, kothavi add cheyyaleru.';

  @override
  String get reflections_paused =>
      'Reflections konchem sepu rest teesukuntunnaayi. Gestures pani chestune untaayi.';

  @override
  String reflections_limit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ee roju ki $count reflections ayipoyaayi. Gestures eppudu open ae untaayi.',
      one: 'Ee roju ki 1 reflection ayipoyindi. Gestures eppudu open ae untaayi.',
    );
    return '$_temp0';
  }

  @override
  String get reflections_slow =>
      'Ippudu reflections konchem slow ga velthunnaayi';

  @override
  String reflections_left(int remaining, int total) {
    return 'Ee roju $total lo $remaining migilaayi';
  }

  @override
  String reflections_cardLabel(String pseudonym) {
    return '$pseudonym raasina reflection';
  }

  @override
  String get reflections_mine => 'Mee reflection';

  @override
  String get reflections_onlyYou => 'Idi meeku maatrame kanipistundi';

  @override
  String get reflections_pending =>
      'Inka chustunnaam. Meeru chaduvutu undochu.';

  @override
  String get reflections_heldSoon => 'Oka chinna check kosam wait chestondi';

  @override
  String get reflections_heldOvernight =>
      'Oka chinna check kosam wait chestondi. Podduna varaku pattochu.';

  @override
  String get reflections_rejectedCard => 'Idi ikkada pettalekapoyaam.';

  @override
  String get reflections_removedCard =>
      'Oka review tarvaatha deenni teesesaam.';

  @override
  String reflections_gestureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gestures',
      one: '1 gesture',
      zero: 'Inka gestures levu',
    );
    return '$_temp0';
  }

  @override
  String get reflections_countPrivate => 'Ee count meeku maatrame kanipistundi';

  @override
  String get reflections_options => 'Reflection options';

  @override
  String reflections_gestureHint(String pseudonym) {
    return 'Ee reflection kosam $pseudonym ki pamputundi';
  }

  @override
  String reflections_gestureSent(String gesture, String pseudonym) {
    return '$pseudonym ki $gesture pampaaru';
  }

  @override
  String get reflections_delete => 'Delete';

  @override
  String get reflections_withdraw => 'Withdraw';

  @override
  String get reflections_deleteTitle => 'Ee reflection ni delete cheyaala?';

  @override
  String get reflections_deleteBody =>
      'Idi ikkada andariki kanipinchadu. Reflections edit cheyyaleru, kaani kothadi share cheyochu.';

  @override
  String get reflections_withdrawTitle => 'Ee reflection ni withdraw cheyaala?';

  @override
  String get reflections_withdrawBody =>
      'Idi pettabadadu. Meeru eppudaina kothadi share cheyochu.';

  @override
  String get reflections_deleted => 'Mee reflection teesesaam.';

  @override
  String get reflections_reportTitle => 'Ee reflection ni report cheyandi';

  @override
  String get reflections_reportHidden =>
      'Cheppinanduku thanks. Aa reflection ippudu meeku kanipinchadu.';

  @override
  String get reflections_composeTitle => 'Oka reflection share cheyandi';

  @override
  String get reflections_composeLabel => 'Mee manasulo emundi?';

  @override
  String get reflections_composeNote =>
      'Ee room kosam konni maatalu. Itarulu gestures tho maatrame respond avutaaru, replies undavu.';

  @override
  String reflections_counter(int count, int max) {
    return '$count/$max';
  }

  @override
  String reflections_counterSemantic(int count, int max) {
    return '$max lo $count characters';
  }

  @override
  String reflections_tooLong(int max) {
    return 'Konchem chinnaga raayandi: $max characters varaku.';
  }

  @override
  String get reflections_send => 'Pampandi';

  @override
  String get reflections_sending => 'Nemmadiga pamputunnaam…';

  @override
  String get reflections_contactBlocked =>
      'Phone numbers, links, handles ikkada share cheyyaleru. Idi andarini safe ga unchutundi.';

  @override
  String get reflections_draftKept =>
      'Draft safe ga undi. Malli online ki vachaaka pampochu.';

  @override
  String get reflections_sendFailed =>
      'Ippudu pampalekapoyaam. Mee maatalu ikkade unnaayi: kaasepatlo malli try cheyandi.';

  @override
  String get reflections_rejectedContact =>
      'Reflections lo contact details undakoodadu. Avi lekunda malli try chestaara?';

  @override
  String get reflections_rejectedLink =>
      'Reflections lo links undakoodadu. Adi lekunda malli try chestaara?';

  @override
  String get reflections_rejectedPersonal =>
      'Evarivaina personal details gurinchi questions ikkada pettaleru. Avi lekunda try chestaara?';

  @override
  String get reflections_rejectedGeneral =>
      'Idi ikkada pettalemu. Idi evarinaina baadha pettochu leda personal details share cheyochu. Mee maatalu edit cheyyadaniki ikkade unnaayi.';

  @override
  String get reflections_supportSubtitle =>
      'Meeru deenni okkare moyaalsina avasaram ledu.';

  @override
  String get reflections_backToRoom => 'Room ki tirigi vellandi';

  @override
  String get device_bannedTitle => 'Ee device lo Aura use cheyyalemu';

  @override
  String get device_bannedBody => 'Ee phone lo Aura available ledu.';

  @override
  String get device_bannedReviewSubject => 'Device review';

  @override
  String get rooms_paused =>
      'Rooms konchem sepu rest teesukuntunnayi. Taruvaata malli try cheyandi.';

  @override
  String get rooms_pausedJoin =>
      'Rooms konchem sepu rest teesukuntunnayi. Mee check-in save ayyindi.';

  @override
  String get rooms_title => 'Rooms';

  @override
  String get rooms_yourRooms => 'Mee rooms';

  @override
  String get rooms_memories => 'Memories';

  @override
  String get rooms_whatTitle => 'Rooms ante enti';

  @override
  String get rooms_whatBody =>
      'Ippudu meelaage anipistunna konta mandi unde oka chinna room, oka roju kosam.';

  @override
  String get rooms_pointName =>
      'Prati room lo oka kotha peru. Mee account evariki kanipinchadu.';

  @override
  String get rooms_pointGestures =>
      'Messages, DMs undavu: enimidi warm gestures maatrame.';

  @override
  String get rooms_pointTime =>
      'Room oka roju untundi, tarvaatha 7 rojulu memory ga untundi.';

  @override
  String get rooms_lanternNote =>
      'Lantern Hour: mee region time prakaaram prati raatri 9 nundi 11 varaku, rooms kalisi oka lantern veligistaayi, ekkuva mandi vastaaru.';

  @override
  String get rooms_lanternNow => 'Ippudu Lantern Hour nadustondi';

  @override
  String get rooms_checkInCta => 'Room kosam check-in cheyandi';

  @override
  String get rooms_empty =>
      'Meeru ippudu e room lonu leru. Check-in tarvaatha, meelaage anipistunna vaallatho kalavochu.';

  @override
  String get rooms_offline =>
      'Rooms ki connection kaavaali. Mee check-ins ee phone lo save avutune untaayi.';

  @override
  String get rooms_loadFailed => 'Ippudu rooms ni reach cheyyalekapoyaam.';

  @override
  String get rooms_tryAgain => 'Malli try cheyandi';

  @override
  String get rooms_signedOut => 'Sign in chesaaka rooms open avutaayi.';

  @override
  String get rooms_signIn => 'Sign in cheyandi';

  @override
  String get rooms_suspended =>
      'Prastutam mee account ki rooms aapi unchaam. Help eppudu ikkade untundi.';

  @override
  String rooms_suspendedUntil(String date) {
    return 'Mee account ki $date varaku rooms aapi unchaam. Help eppudu ikkade untundi.';
  }

  @override
  String get rooms_accountClosed =>
      'Aura rules break chesinanduku ee account close chesaamu.';

  @override
  String get rooms_profilePending =>
      'Mee account setup complete ayyaaka rooms open avutaayi. Kaasepatlo malli try cheyandi.';

  @override
  String get rooms_openHint => 'Room open avutundi';

  @override
  String rooms_memoryUntil(String date) {
    return '$date varaku memory';
  }

  @override
  String get rooms_theme_lighthouse => 'The Lighthouse';

  @override
  String get rooms_theme_rain_sanctuary => 'The Rain Sanctuary';

  @override
  String get rooms_theme_midnight_observatory => 'The Midnight Observatory';

  @override
  String get rooms_theme_sunrise_deck => 'The Sunrise Deck';

  @override
  String get rooms_gesture_warm_tea => 'Oka cup chai';

  @override
  String get rooms_gesture_light_a_candle => 'Oka deepam';

  @override
  String get rooms_gesture_hug => 'Hug';

  @override
  String get rooms_gesture_me_too => 'Naaku kooda';

  @override
  String get rooms_gesture_soft_rain => 'Chiru jallu';

  @override
  String get rooms_gesture_stargaze => 'Stars choodham';

  @override
  String get rooms_gesture_deep_breath => 'Deep breath';

  @override
  String get rooms_gesture_youre_not_alone => 'Meeru okkaru kaadu';

  @override
  String rooms_hereNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ippudu $count mandi unnaru',
      one: 'Ippudu 1 unnaru',
      zero: 'Ippudu evaru leru',
    );
    return '$_temp0';
  }

  @override
  String rooms_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ee roju $count mandi ikkadiki vachaaru',
      one: 'Ee roju 1 person ikkadiki vachaaru',
    );
    return '$_temp0';
  }

  @override
  String rooms_countsSemantic(int now, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      now,
      locale: localeName,
      other: 'Ippudu $now mandi',
      one: 'Ippudu 1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      today,
      locale: localeName,
      other: 'ee roju $today',
      one: 'ee roju 1',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String rooms_stripSemantic(String theme, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ippudu $count mandi',
      one: 'Ippudu 1 person',
    );
    return '$theme, $_temp0';
  }

  @override
  String get rooms_opening => 'Room open chestunnaam…';

  @override
  String rooms_youAre(String pseudonym) {
    return 'Ikkada meeru $pseudonym';
  }

  @override
  String rooms_coldStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ee roju $count mandi ikkadiki vachaaru. Tarvaatha vacchevaari kosam oka deepam vadili vellandi.',
      one: 'Ee roju ikkadiki vachina modativaaru meere. Tarvaatha vacchevaari kosam oka deepam vadili vellandi.',
    );
    return '$_temp0';
  }

  @override
  String rooms_lanternOn(String time) {
    return 'Lantern Hour · $time varaku';
  }

  @override
  String rooms_closing(String time) {
    return 'Ee room $time ki memory ga maarutundi.';
  }

  @override
  String get rooms_memory =>
      'Ee room ippudu oka memory. 7 rojula paatu venakki choosukovachu.';

  @override
  String get rooms_findNew => 'Kotha room vetakandi';

  @override
  String get rooms_reconnecting => 'Malli connect avutondi…';

  @override
  String get rooms_membersTitle => 'Meetho ikkada';

  @override
  String get rooms_you => 'Meeru';

  @override
  String get rooms_memberHereNow => 'ippudu ikkada unnaru';

  @override
  String get rooms_memberAway => 'prastutam dooranga unnaru';

  @override
  String get rooms_memberMuted => 'meekosam mute chesaaru';

  @override
  String rooms_memberLabel(String pseudonym, String mood, String status) {
    return '$pseudonym, $mood, $status';
  }

  @override
  String rooms_youLabel(String pseudonym, String mood) {
    return 'Meeru, $pseudonym, $mood';
  }

  @override
  String get rooms_memberHint => 'Options open avutaayi';

  @override
  String get rooms_recentTitle => 'Ee room lo warmth';

  @override
  String rooms_receivedLine(String pseudonym, String gesture) {
    return '$pseudonym meeku $gesture pampaaru';
  }

  @override
  String rooms_sentToMember(String gesture, String pseudonym) {
    return '$pseudonym ki $gesture pampaaru';
  }

  @override
  String rooms_sentToRoom(String gesture) {
    return 'Ikkada andariki $gesture pampaaru';
  }

  @override
  String rooms_someoneSent(String gesture) {
    return 'Evaro $gesture pampaaru';
  }

  @override
  String rooms_someoneSentRoom(String gesture) {
    return 'Evaro ikkada andariki $gesture pampaaru';
  }

  @override
  String rooms_youSentMember(String gesture, String pseudonym) {
    return 'Meeru $pseudonym ki $gesture pampaaru';
  }

  @override
  String rooms_youSentRoom(String gesture) {
    return 'Meeru ikkada andariki $gesture pampaaru';
  }

  @override
  String get rooms_trayTitle => 'Ikkada andariki warmth pampandi';

  @override
  String get rooms_trayHint => 'Ikkada andariki pamputundi';

  @override
  String get rooms_trayResting =>
      'Memory lo gestures rest lo untaayi. Report, block, mute inka panichestaayi.';

  @override
  String get rooms_roomOptions => 'Room options';

  @override
  String get rooms_reportRoom => 'Ikkada oka problem report cheyandi';

  @override
  String get rooms_leave => 'Ee room nundi vellipondi';

  @override
  String get rooms_removeMemory => 'Naa rooms nundi teeseyandi';

  @override
  String get rooms_leaveTitle => 'Ee room nundi vellipotaara?';

  @override
  String get rooms_leaveBody =>
      'Malli ee room ki raaleru, mee seat inkokariki dorukutundi. Mee next check-in meeku kotha room vetiki pedutundi.';

  @override
  String get rooms_leaveConfirm => 'Vellipotaanu';

  @override
  String get rooms_stay => 'Ikkade untaanu';

  @override
  String get rooms_removeTitle => 'Ee memory ni teeseyaala?';

  @override
  String get rooms_removeBody =>
      'Idi ippude mee rooms nundi vellipotundi. Elaagu 7 rojula tarvaatha memories poortiga moosukupotaayi.';

  @override
  String get rooms_removeConfirm => 'Teeseyandi';

  @override
  String get rooms_keep => 'Unchandi';

  @override
  String get rooms_leaveFailed =>
      'Adi jaragaledu. Meeru inka room lone unnaru.';

  @override
  String get rooms_gone =>
      'Ee room moosukupoyindi. Rooms 7 rojulu memories ga undi, tarvaatha potaayi.';

  @override
  String get rooms_backToRooms => 'Mee rooms ki vellandi';

  @override
  String get rooms_offlineRoom =>
      'Rooms ki connection kaavaali. Meeru malli online ki raagaane ee room open avutundi.';

  @override
  String get rooms_joinTitle => 'Mee room vetukutunnaam';

  @override
  String get rooms_finding =>
      'Ippudu ilaage anipistunna vaallani vetukutunnaam…';

  @override
  String get rooms_offlineJoin =>
      'Rooms ki connection kaavaali. Mee check-in save ayyindi.';

  @override
  String get rooms_joinFailed =>
      'Ippudu rooms ni reach cheyyalekapoyaam. Mee check-in save ayyindi.';

  @override
  String get rooms_joinLimit =>
      'Ee roju ee feeling ki ippatike 3 kotha rooms ayyaayi. Meeru unna rooms inka meekosam open ga unnaayi.';

  @override
  String get rooms_seeYourRooms => 'Mee rooms choodandi';

  @override
  String get rooms_poolUnavailable =>
      'Hindi, Hinglish rooms tvaralo modalavutaayi. Prastutaaniki English room lo cherataara?';

  @override
  String get rooms_poolJoinEnglish => 'English room lo cherandi';

  @override
  String get rooms_poolNotify => 'Avi modalainappudu cheppandi';

  @override
  String get rooms_poolNotifyDone =>
      'Hindi, Hinglish rooms modalainappudu ikkade cheptaam.';

  @override
  String get rooms_noRequest => 'Rooms check-in nundi open avutaayi.';

  @override
  String get rooms_offer => 'Ilaage anipistunna vaalla room lo cherandi';

  @override
  String get rooms_offerHint =>
      'Daani kosame kotha peruto oka room open avutundi';

  @override
  String get rooms_offerOffline =>
      'Meeru malli online ki vachaaka rooms open avutaayi';

  @override
  String get rooms_offerLater =>
      'Thodu kaavaalanipinchinappudu, rooms Rooms tab lo untaayi.';

  @override
  String get rooms_guidelinesTitle => 'Mee first room ki mundu';

  @override
  String get rooms_guidelinesIntro =>
      'Andaru ee konni chinna vishayaalu paatistaaru kaabatte rooms prashaanthanga untaayi:';

  @override
  String get rooms_rule1 =>
      'Dayaga undandi. Ikkada andaru nijamaina rojuni gaduputunnaru.';

  @override
  String get rooms_rule2 =>
      'Kulam, matham, gender, sexuality leda inkedaina gurinchi hate vaddu.';

  @override
  String get rooms_rule3 => 'Sexual content vaddu.';

  @override
  String get rooms_rule4 =>
      'Contact details, meet-ups, leda evari vayasu, school, ooru, photos adagavaddu, share cheyyavaddu.';

  @override
  String get rooms_rule5 => 'Selling, spam vaddu.';

  @override
  String get rooms_rule6 =>
      'Evarini tamani taamu baadha pettukomani protsahinchavaddu. Meeku ela anipistondo maatlaadatam eppudu okay.';

  @override
  String get rooms_guidelinesSafety =>
      'Evarinaina report, block leda mute cheyochu, help eppudu oka tap dooram lo untundi.';

  @override
  String get rooms_guidelinesAgree => 'Nenu veetini paatistaanu';

  @override
  String get rooms_guidelinesUpdate =>
      'Rooms community guidelines maaraayi. Mee next room ki mundu vaatini chadavadaaniki Aura ni update cheyandi.';

  @override
  String rooms_sendTo(String pseudonym) {
    return '$pseudonym ki konchem warmth pampandi';
  }

  @override
  String rooms_gestureHintMember(String pseudonym) {
    return '$pseudonym ki pamputundi';
  }

  @override
  String get rooms_report => 'Report';

  @override
  String get rooms_block => 'Block';

  @override
  String get rooms_mute => 'Mute';

  @override
  String get rooms_unmute => 'Unmute';

  @override
  String get rooms_safetyNote =>
      'Evaru report, block leda mute chesaaro vaallaki eppudu teliyadu.';

  @override
  String rooms_blockTitle(String pseudonym) {
    return '$pseudonym ni block cheyaala?';
  }

  @override
  String get rooms_blockBody =>
      'Meeriddaru malli oke room lo undaru, mee madhya gestures aagipotaayi. Vaallaki ee vishayam cheppamu.';

  @override
  String rooms_blocked(String pseudonym) {
    return '$pseudonym ni block chesaaru. Meeru malli oke room lo undaru.';
  }

  @override
  String rooms_muted(String pseudonym) {
    return '$pseudonym ni meekosam mute chesaam. Vaalla gestures ikkada meeku cheravu.';
  }

  @override
  String rooms_unmuted(String pseudonym) {
    return '$pseudonym ni unmute chesaam.';
  }

  @override
  String get rooms_undo => 'Undo';

  @override
  String get rooms_actionFailed =>
      'Adi jaragaledu. Kaasepatlo malli try cheyandi.';

  @override
  String rooms_reportMember(String pseudonym) {
    return '$pseudonym ni report cheyandi';
  }

  @override
  String get rooms_reportGesture => 'Ee gesture ni report cheyandi';

  @override
  String get rooms_reportWhy => 'Em jarugutondi?';

  @override
  String get rooms_reason1 =>
      'Evaraina danger lo undochu leda tamani taamu baadha pettukuntu undochu';

  @override
  String get rooms_reason2 => 'Harassment leda bullying';

  @override
  String get rooms_reason3 => 'Sexual content leda advances';

  @override
  String get rooms_reason4 => 'Hate leda slurs';

  @override
  String get rooms_reason5 => 'Contact details leda personal info';

  @override
  String get rooms_reason6 => 'Spam leda selling';

  @override
  String get rooms_reason7 => 'Evaraina 13 ella lopu vaallu kaavochu';

  @override
  String get rooms_reason8 => 'Inkedaina';

  @override
  String get rooms_reason9 =>
      'Chinna vayasu vaallani target chestunnattu anipistondi';

  @override
  String get rooms_reportNoteLabel =>
      'Moderator ki teliyaalsindi edaina undaa? (optional)';

  @override
  String get rooms_reportNoteHelp =>
      'Deenni Aura moderators maatrame chaduvutaaru. Dayachesi phone numbers, links, handles raayakandi.';

  @override
  String get rooms_reportNoteContact =>
      'Phone numbers, links, handles ikkada share cheyyaleru. Idi andarini safe ga unchutundi.';

  @override
  String get rooms_reportSend => 'Report pampandi';

  @override
  String get rooms_reportThanks =>
      'Maaku cheppinanduku thanks. Oka moderator saadhaaranamga oka roju lo deenni chustaaru.';

  @override
  String get rooms_reportHidden =>
      'Cheppinanduku thanks. Moderator chuse varaku ee room lo vaalla gestures meeku raavu.';

  @override
  String get rooms_reportGestureHidden =>
      'Cheppinanduku thanks. Aa gesture ippudu meeku kanipinchadu.';

  @override
  String get rooms_reportCrisis =>
      'Cheppinanduku thanks. Oka moderator tvaralo chustaaru, help eppudu oka tap dooram lo untundi.';

  @override
  String get rooms_reportLimit =>
      'Ee roju chaala reports vachaayi. Evaraina danger lo unte, help button eppudu ikkade untundi.';

  @override
  String get rooms_reportFailed =>
      'Adi jaragaledu, kaabatti emi pampaledu. Kaasepatlo malli try cheyandi.';

  @override
  String get rooms_reportOffline =>
      'Reports ki connection kaavaali. Inka emi pampaledu.';

  @override
  String get rooms_surveyTitle => 'Meeku konchem ontaritanam taggindaa?';

  @override
  String get rooms_surveyYes => 'Avunu';

  @override
  String get rooms_surveyNo => 'Antaga ledu';

  @override
  String get rooms_surveySkip => 'Skip';

  @override
  String get sanctuary_title => 'Sanctuary';

  @override
  String get sanctuary_intro =>
      'Mee kosame oka prashaanthamaina chotu. Mee speed lone vellandi. Ikkada deeniki score ledu.';

  @override
  String get sanctuary_todayTitle => 'Ee roju oka nimisham';

  @override
  String get sanctuary_breatheSection => 'Shwaasa';

  @override
  String get sanctuary_breatheCard => 'Mee Aura tho kalisi breathe cheyandi';

  @override
  String get sanctuary_breatheCardBody =>
      'Calm, box leda 4-7-8 breathing. Meeku entasepu kaavaalante antasepu.';

  @override
  String get sanctuary_groundingSection => 'Grounding';

  @override
  String get sanctuary_begin => 'Modalupettandi';

  @override
  String get sanctuary_start => 'Start cheyandi';

  @override
  String get sanctuary_pause => 'Aapandi';

  @override
  String get sanctuary_resume => 'Malli continue cheyandi';

  @override
  String get sanctuary_finish => 'Muginchandi';

  @override
  String get sanctuary_next => 'Next';

  @override
  String get sanctuary_progress => 'Ee session lo entavaraku vachaaru';

  @override
  String get sanctuary_progressBegun => 'Ippude modalaindi';

  @override
  String get sanctuary_progressHalf => 'Daadaapu sagam';

  @override
  String get sanctuary_progressNearly => 'Daadaapu purtayindi';

  @override
  String get sanctuary_progressDone => 'Purtayindi';

  @override
  String habits_autoLogged(String habit) {
    return 'Ee roju $habit ayyindani mark chesaam.';
  }

  @override
  String get breathe_rhythm => 'Rhythm';

  @override
  String get breathe_calm => 'Calm';

  @override
  String get breathe_calmBody =>
      '4 counts lopaliki, 6 bayataki. Mellaga, sthiranga.';

  @override
  String get breathe_box => 'Box';

  @override
  String get breathe_boxBody =>
      'Lopaliki, aapi, bayataki, aapi. Okkokati naalugu counts.';

  @override
  String get breathe_478 => '4-7-8';

  @override
  String get breathe_478Body => '4 counts lopaliki, 7 aapi, 8 bayataki.';

  @override
  String get breathe_lightHeaded =>
      'Tala tirugutunnattu anipiste, aapesi maamooluga breathe cheyandi.';

  @override
  String get breathe_length => 'Entasepu';

  @override
  String breathe_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nimishaalu',
      one: '1 nimisham',
    );
    return '$_temp0';
  }

  @override
  String get breathe_openEnded => 'Nenu aapevaraku';

  @override
  String get breathe_in => 'Lopaliki breathe cheyandi';

  @override
  String get breathe_hold => 'Aapi unchandi';

  @override
  String get breathe_out => 'Bayataki vadalandi';

  @override
  String get breathe_paused => 'Aagindi. Meeku kaavalsinanta time teesukondi.';

  @override
  String get breathe_done => 'Idi mee kosame teesukunna samayam.';

  @override
  String get breathe_again => 'Malli';

  @override
  String get breathe_land1 =>
      'Mee paadaalu nelani taakutunnattu gamaninchandi.';

  @override
  String get breathe_land2 =>
      'Mee chuttu vinipistunna moodu sounds gamaninchandi.';

  @override
  String get breathe_keepGoing => 'Continue cheddaam';

  @override
  String get breathe_land3 => 'Bhujaalu loose ga vadileyandi.';

  @override
  String get senses_title => 'Aidu indriyaalu';

  @override
  String get senses_card =>
      'Mee chuttu unnavaatini okko indriyam tho gamaninchandi.';

  @override
  String get senses_intro =>
      'Mee chuttu unnavaatini okko indriyam tho gamaniddaam. Mee speed lone vellandi.';

  @override
  String get senses_see => 'Meeku kanipistunna aidu vastuvulu';

  @override
  String get senses_seeBody =>
      'Nemmadiga chuttu choodandi. Manasulo gaani, paiki gaani vaati perlu cheppandi.';

  @override
  String get senses_touch => 'Meeru taakagalige naalugu vishayaalu';

  @override
  String get senses_touchBody =>
      'Mee kinda kurchi, mee battalu, mee charmaanni taake gaali.';

  @override
  String get senses_hear => 'Meeku vinipistunna moodu sounds';

  @override
  String get senses_hearBody =>
      'Daggarivainaa, dooraanivainaa, peddavainaa, mellanivainaa.';

  @override
  String get senses_smell => 'Meeku vaasana telustunna rendu vishayaalu';

  @override
  String get senses_smellBody =>
      'Daggara emi lekapote, meeku nachina rendu vaasanalu gurtu chesukondi.';

  @override
  String get senses_taste => 'Meeku ruchi telustunna okka vishayam';

  @override
  String get senses_tasteBody =>
      'Leda konchem neellu taagi aa ruchini gamaninchandi.';

  @override
  String senses_step(int step, int total) {
    return '$total lo $step va step';
  }

  @override
  String get senses_done =>
      'Meeru ikkade, ee kshanam lone unnaru. Baaga chesaaru.';

  @override
  String get heart_title => 'Gunde meeda cheyyi';

  @override
  String get heart_card => 'Mee kosame oka nimisham vecchadanam.';

  @override
  String get heart_intro =>
      'Mee cheyyini gunde meeda, leda meeku haayiga anipinche chota unchandi.';

  @override
  String get heart_1 => 'Mee cheti vecchadanaanni gamaninchandi.';

  @override
  String get heart_2 => 'Mellaga breathe cheyandi. Tondara emi ledu.';

  @override
  String get heart_3 => 'Meeku em anipistunnaa, ikkada daaniki chotu undi.';

  @override
  String get heart_4 =>
      'Friends patla entha dayaga untaaro, mee patla kooda ante dayaga undandi.';

  @override
  String get heart_done => 'Mee patla meeru mruduvuga unnanduku thanks.';

  @override
  String get gratitude_title => 'Moodu chinna vishayaalu';

  @override
  String get gratitude_card =>
      'Ee roju baagaane jarigina moodu chinna vishayaalu.';

  @override
  String get gratitude_intro =>
      'Ee roju jarigina moodu chinna vishayaalanu okkokkatiga gurtu techukondi. Emi raayanakkarledu.';

  @override
  String get gratitude_1 => 'Baagaane jarigina oka chinna vishayam';

  @override
  String get gratitude_1Body =>
      'Adi chaala chinnadainaa parvaaledu, oka vedi drink leda oka manchi maata laantidi.';

  @override
  String get gratitude_2 => 'Inkoka chinna vishayam';

  @override
  String get gratitude_2Body =>
      'Meeru choosinadi, vinnadi leda chesinadi edainaa.';

  @override
  String get gratitude_3 => 'Marokka chinna vishayam';

  @override
  String get gratitude_3Body => 'Bahusha mee gurinche edainaa.';

  @override
  String get gratitude_done =>
      'Vaatini oka kshanam pattukuni undandi. Avi meeve.';

  @override
  String get savour_intro =>
      'Ee roju jarigina oka manchi kshanaanni mellaga malli gurtu chesukundaam.';

  @override
  String get savour_1 =>
      'Ee roju jarigina oka manchi kshanaanni gurtu techukondi, entha chinnadainaa.';

  @override
  String get savour_2 =>
      'Appudu meeru ekkada unnaru? Em kanipinchindi, em vinipinchindi?';

  @override
  String get savour_3 =>
      'Ippudu daanni gurtu chesukunte ela anipistondo gamaninchandi.';

  @override
  String get savour_done => 'Adi meetho inkonchem sepu undanivvandi.';

  @override
  String get minute_forYou => 'Mee kosam oka nimisham';

  @override
  String get minute_calmTitle => 'Oka prashaanta nimisham';

  @override
  String get minute_boxTitle => 'Box breathing';

  @override
  String get minute_478Title => '4-7-8 breathing';

  @override
  String get minute_stillnessTitle => 'Oka nimisham nishchalata';

  @override
  String get minute_stillnessBody => 'Orb tho kalisi oka nishabda nimisham.';

  @override
  String get minute_landTitle => 'Niladokkukovadaaniki muppai seconds';

  @override
  String get minute_landBody => 'Orb tho kalisi moodu nemmadi shwaasalu.';

  @override
  String get minute_comfortTitle => 'Konchem oorata';

  @override
  String get minute_comfortBody =>
      'Gunde meeda oka cheyyi, oka nimisham vecchadanam.';

  @override
  String get minute_savourTitle => 'Deenni aaswaadinchandi';

  @override
  String get minute_savourBody =>
      'Ee roju jarigina oka manchi kshanaanni malli gurtu chesukondi.';

  @override
  String get companion_storm1 =>
      'Okesaari chaala anipistondi. Mee velugu inka ikkade undi.';

  @override
  String get companion_storm2 =>
      'Storm ki peru pettadaaniki dhairyam kaavaali. Meeru mee kosam vachaaru.';

  @override
  String get companion_storm3 =>
      'Pedda, gatti feelings ki ikkada chotu undi. Meeku kooda.';

  @override
  String get companion_storm4 =>
      'Storm rojulu kooda mukhyamainave. Check-in chesinanduku thanks.';

  @override
  String get companion_storm5 =>
      'Meeru deenni nijaayiteega cheppaaru. Adi mukhyam.';

  @override
  String get companion_storm6 => 'Storms kooda mee aakaasham lo bhaagame.';

  @override
  String get companion_storm7 =>
      'Lopala em sudulu tirugutunnaa, meeru daanni gamaninchaaru. Adi viluvainadi.';

  @override
  String get companion_storm8 => 'Storm lo kooda, mee velugu meede.';

  @override
  String get companion_rain1 =>
      'Idi bhaaranga anipistondi. Mee velugu inka meethone undi.';

  @override
  String get companion_rain2 =>
      'Low day gurinchi nijaayiteega undadaaniki dhairyam kaavaali. Meeru mee kosam vachaaru.';

  @override
  String get companion_rain3 =>
      'Nemmadaina, baruvaina feelings ki ikkada chotu undi. Meeku kooda.';

  @override
  String get companion_rain4 =>
      'Vaana rojulu kooda mukhyamainave. Check-in chesinanduku thanks.';

  @override
  String get companion_rain5 =>
      'Ee roju meetho meeru nijaayiteega unnaru. Adi mukhyam.';

  @override
  String get companion_rain6 => 'Vaana kooda mee aakaasham lo bhaagame.';

  @override
  String get companion_rain7 =>
      'Entha bhaaranga unnaa, meeru daanni gamaninchaaru. Adi viluvainadi.';

  @override
  String get companion_rain8 =>
      'Mabbu pattina rojullo kooda, mee velugu meede.';

  @override
  String get companion_moonlight1 =>
      'Nishabdamaina, sthiramaina kshanam. Mee velugu haayiga rest teesukuntondi.';

  @override
  String get companion_moonlight2 =>
      'Oka prashaanta kshanaanni gamaninchadam viluvainadi. Meeru mee kosam vachaaru.';

  @override
  String get companion_moonlight3 =>
      'Mettani, haayaina feelings ki ikkada chotu undi. Meeku kooda.';

  @override
  String get companion_moonlight4 =>
      'Mellani rojulu kooda mukhyamainave. Check-in chesinanduku thanks.';

  @override
  String get companion_moonlight5 =>
      'Deenni gamaninchadaaniki meeru oka kshanam teesukunnaru. Adi mukhyam.';

  @override
  String get companion_moonlight6 => 'Vennela kooda mee aakaasham lo bhaagame.';

  @override
  String get companion_moonlight7 =>
      'Ee prashaanthata entha chinnadainaa, meeru daanni gamaninchaaru. Adi viluvainadi.';

  @override
  String get companion_moonlight8 => 'Ee nishabdam lo, mee velugu meede.';

  @override
  String get companion_sunrise1 =>
      'Velugu tho nindina kshanam. Mee velugu prakaashistondi.';

  @override
  String get companion_sunrise2 =>
      'Oka manchi kshanaanni gamaninchadam viluvainadi. Meeru mee kosam vachaaru.';

  @override
  String get companion_sunrise3 =>
      'Pedda, prakaashavantamaina feelings ki ikkada chotu undi. Meeku kooda.';

  @override
  String get companion_sunrise4 =>
      'Velugu rojulu kooda mukhyamainave. Check-in chesinanduku thanks.';

  @override
  String get companion_sunrise5 =>
      'Deenni gamaninchadaaniki meeku meeru chance ichaaru. Adi mukhyam.';

  @override
  String get companion_sunrise6 => 'Sunrise kooda mee aakaasham lo bhaagame.';

  @override
  String get companion_sunrise7 =>
      'Idi peddadainaa, chinnadainaa, meeru daanni gamaninchaaru. Adi viluvainadi.';

  @override
  String get companion_sunrise8 => 'Ee santosham lo, mee velugu meede.';

  @override
  String get companion_neutral1 => 'Check-in chesinanduku thanks.';

  @override
  String get companion_neutral2 => 'Meeru mee kosam vachaaru.';

  @override
  String get companion_neutral3 => 'Mee velugu inka ikkade undi.';

  @override
  String get companion_neutral4 => 'Ikkada tondara emi ledu.';

  @override
  String get prompt_note1 =>
      'Ee roju konchem help chesina oka chinna vishayam edi?';

  @override
  String get prompt_note2 => 'Ippudu mee manasulo emundi?';

  @override
  String get prompt_note3 =>
      'Ee roju gurinchi meeru em gurtunchukovaalanukuntunnaru?';

  @override
  String get prompt_storm1 =>
      'Ippudu mee manasulo ekkuva chotu teesukuntunnadi edi?';

  @override
  String get prompt_storm2 =>
      'Ee feeling maatlaadagaligite, adi em chebutundi?';

  @override
  String get prompt_storm3 =>
      'Okka nimishamainaa pakkana pettagalige oka vishayam edi?';

  @override
  String get prompt_rain1 => 'Ippudu meeku edi haayiga anipistundi?';

  @override
  String get prompt_rain2 => 'Ee roju mee manasu meeda baruvuga unnadi edi?';

  @override
  String get prompt_rain3 =>
      'Ee madhya mee patla dayaga anipinchindi evaru, leda edi?';

  @override
  String get prompt_moonlight1 =>
      'Meeru sthiranga undadaaniki edi help chestondi?';

  @override
  String get prompt_moonlight2 => 'Ee roju edi haayiga anipinchela chesindi?';

  @override
  String get prompt_moonlight3 =>
      'Ee kshanam nunchi meeru em daachukovaalanukuntunnaru?';

  @override
  String get prompt_sunrise1 => 'Ee roju meelo utsaaham nimputunnadi edi?';

  @override
  String get prompt_sunrise2 =>
      'Baaga jarigina e vishayaanni meeru gurtunchukovaalanukuntunnaru?';

  @override
  String get prompt_sunrise3 =>
      'Deenni meeru evaritho panchukovaalanukuntunnaru?';

  @override
  String get prompt_capsule1 =>
      'Future lo unna meeku meeru em teliyajeyaalanukuntunnaru?';

  @override
  String get prompt_capsule2 =>
      'Ippudu meeku help chestunna, tarvaata marchipoye avakaasham unna vishayam edi?';

  @override
  String get prompt_capsule3 =>
      'Kashtamaina roju na meeku meeru em cheppukuntaaru?';

  @override
  String get prompt_capsuleStorm =>
      'Antaa ekkuvaipoyinattu anipinchinappudu edi help chestundi?';

  @override
  String get prompt_capsuleRain =>
      'Bhaaramaina roju na meeru em vinaalanukuntaaru?';

  @override
  String get prompt_capsuleMoonlight =>
      'Ee prashaanthatanu malli pondadaaniki edi help chestundi?';

  @override
  String get prompt_capsuleSunrise =>
      'Future lo unna meetho meeru e santoshaanni panchukovaalanukuntunnaru?';

  @override
  String get prompt_another => 'Inko prashna';

  @override
  String get prompt_settingsTitle => 'Raayadaaniki prompts';

  @override
  String get prompt_settingsBody =>
      'Khaali note lo oka gentle prashna. Idi eppudu save avvadu.';

  @override
  String get backfill_add => 'Past check-in add cheyandi';

  @override
  String get backfill_pickTitle => 'Ye roju?';

  @override
  String backfill_pickBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gata $count rojullo ye roju kainaa check-in add cheyochu.',
      one: 'Ninnati kosam check-in add cheyochu.',
    );
    return '$_temp0';
  }

  @override
  String get backfill_title => 'Appudu meeku ela anipinchindi?';

  @override
  String backfill_forDay(String day) {
    return '$day kosam check-in';
  }

  @override
  String get backfill_changeDay => 'Roju maarchandi';

  @override
  String get backfill_outOfRange =>
      'Past check-ins oka vaaram venakki varake add cheyagalam. Vere roju select chesukuntaara?';

  @override
  String get backfill_savedTitle => 'Mee aakaasham lo cherindi';

  @override
  String backfill_savedDay(String day) {
    return '$day kosam save ayyindi.';
  }

  @override
  String get backfill_savedBody =>
      'Starlight aa roje chesina check-ins nunchi vastundi.';

  @override
  String get history_addedLater => 'Tarvaata add chesindi';

  @override
  String history_whenAddedLater(String day) {
    return '$day · tarvaata add chesindi';
  }

  @override
  String get shell_tabHome => 'Home';

  @override
  String get shell_tabSanctuary => 'Sanctuary';

  @override
  String get shell_tabRooms => 'Rooms';

  @override
  String get shell_tabInsights => 'Insights';

  @override
  String get shell_checkIn => 'Check in';

  @override
  String get shell_checkInHint => 'Kotha check-in modalavutundi';

  @override
  String get safety_emergencyWhen =>
      'Meeru gaani, mee daggara unnavaallu gaani ventane danger lo unna, baaga gaayapadina, leda safe ga undaleka poyina, ventane emergency services ki call cheyandi.';

  @override
  String get safety_settingsLink => 'Settings lo Help & Safety';

  @override
  String get safety_settingsHint =>
      'Support contact, Grievance Officer, policies';

  @override
  String get sounds_title => 'Sounds';

  @override
  String get sounds_cardBody =>
      'Rain, ocean, wind inka marenno. Meeru select chese varaku edi vinipinchadu.';

  @override
  String get sounds_cardPlaying => 'Ippudu play avutondi';

  @override
  String get sounds_intro =>
      'Modalupettadaaniki oka sound select cheyandi, leda naalugu varaku kalapandi. Meeru tap chese varaku edi vinipinchadu.';

  @override
  String get sounds_nothingPlaying => 'Edi play avvadam ledu';

  @override
  String get sounds_statePlaying => 'Play avutondi';

  @override
  String get sounds_statePaused => 'Aagindi';

  @override
  String get sounds_backgroundNote =>
      'Screen off ayina sounds vinipistune untaayi. Headphones disconnect ayina, call vachina aagutaayi.';

  @override
  String get sounds_notificationChannel => 'Sounds playback';

  @override
  String get sounds_windDownTitle => 'Night wind-down';

  @override
  String get sounds_windDownBody =>
      'Sumaaru 20 nimishaala sounds, mellaga taggutu nishabdam loki veltaayi. Prati raatri vaati order maarutundi.';

  @override
  String get sounds_windDownBegin => 'Wind-down modalupettandi';

  @override
  String sounds_windDownLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Sumaaru $minutes nimishaalu migilaayi',
      one: 'Sumaaru 1 nimisham migilindi',
    );
    return '$_temp0';
  }

  @override
  String get sounds_windDownBusy =>
      'Wind-down play avutondi. Mee sonta mix kosam mundu daanni aapandi.';

  @override
  String get sounds_mixSection => 'Mee sonta mix';

  @override
  String get sounds_mixHint =>
      'Okesaari naalugu varaku, okkodaaniki vere volume.';

  @override
  String get sounds_stemRain => 'Rain';

  @override
  String get sounds_stemOcean => 'Ocean';

  @override
  String get sounds_stemWind => 'Gaali';

  @override
  String get sounds_stemNightInsects => 'Night keetakaalu';

  @override
  String get sounds_stemSingingBowl => 'Singing bowl';

  @override
  String get sounds_stemChimes => 'Chimes';

  @override
  String get sounds_stemBrownNoise => 'Brown noise';

  @override
  String get sounds_stemPinkNoise => 'Pink noise';

  @override
  String get sounds_stemDeepBell => 'Doorapu ganta';

  @override
  String get sounds_stemMonsoonRoof => 'Paikappu meeda vaana';

  @override
  String get sounds_stemStream => 'Vaagu';

  @override
  String get sounds_stemFireplace => 'Manta chitapatalu';

  @override
  String get sounds_stemDistantThunder => 'Doorapu urumulu';

  @override
  String sounds_stemOn(String name, int percent) {
    return '$name, play avutondi, volume $percent%';
  }

  @override
  String sounds_stemPaused(String name, int percent) {
    return '$name, aagindi, volume $percent%';
  }

  @override
  String sounds_stemOff(String name) {
    return '$name, off';
  }

  @override
  String sounds_stemLocked(String name) {
    return '$name, Aura Plus lo bhaagam';
  }

  @override
  String sounds_stemNeedsDownload(String name, String size) {
    return '$name, okasaari $size download cheyaali';
  }

  @override
  String sounds_stemDownloading(String name) {
    return '$name, download avutondi';
  }

  @override
  String sounds_volume(String name) {
    return '$name volume';
  }

  @override
  String get sounds_plusBadge => 'Aura Plus';

  @override
  String get sounds_plusNote => 'Aura Plus tho vastundi.';

  @override
  String get sounds_full =>
      'Naalugu sounds play avutunnaayi. Inkokati add cheyadaaniki okadaanni aapandi.';

  @override
  String get sounds_play => 'Play';

  @override
  String get sounds_pause => 'Pause';

  @override
  String get sounds_stop => 'Stop';

  @override
  String get sounds_timer => 'Timer';

  @override
  String get sounds_timerTitle => 'Inta time tarvaata mellaga aagutundi';

  @override
  String get sounds_timerOff => 'Off';

  @override
  String sounds_timerValue(String value) {
    return 'Timer · $value';
  }

  @override
  String sounds_timerLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Sumaaru $minutes nimishaallo mellaga aagutundi',
      one: 'Sumaaru 1 nimisham lo mellaga aagutundi',
    );
    return '$_temp0';
  }

  @override
  String get sounds_fadingOut => 'Mellaga aagutondi';

  @override
  String get sounds_saveMix => 'Ee mix save cheyandi';

  @override
  String get sounds_savedMixes => 'Save chesina mixes';

  @override
  String get sounds_mixSaved => 'Ee phone lo save ayyindi.';

  @override
  String get sounds_mixAlreadySaved => 'Ee mix ippatike save ayyi undi.';

  @override
  String sounds_playMix(String mix) {
    return '$mix play cheyandi';
  }

  @override
  String sounds_removeMix(String mix) {
    return '$mix teeseyandi';
  }

  @override
  String get sounds_mixUnavailable => 'Ee mix ippudu play avvadu.';

  @override
  String get sounds_downloadTitle => 'Recorded sounds';

  @override
  String sounds_downloadBody(String size) {
    return 'Okasaari $size download cheyaali. Aa tarvaata internet lekundaane vinipistaayi. Appativaraku mee phone lone tayaaraina sounds vinipistaayi.';
  }

  @override
  String get sounds_download => 'Download cheyandi';

  @override
  String get sounds_downloading => 'Download avutondi…';

  @override
  String get sounds_downloadOffline =>
      'Meeru offline lo unnaru. Brown noise, mee phone lo tayaaraina sounds ippude vinipistaayi; recordings tarvaata download chesukovachu.';

  @override
  String get sounds_downloadFailed =>
      'Download purti kaaledu. Edi poledu; tarvaata malli download chesukovachu.';

  @override
  String sounds_noSpace(String size) {
    return 'Sounds ki sumaaru $size kaavaali. Konta space khaali cheyandi, leda brown noise vinandi, daaniki emi avasaram ledu.';
  }

  @override
  String sounds_megabytes(String size) {
    return '$size MB';
  }

  @override
  String get sounds_removeDownloads => 'Download chesina sounds teeseyandi';

  @override
  String get sounds_downloadsRemoved =>
      'Download chesina sounds teesesaam. Mee phone lo tayaaraina sounds inka vinipistaayi.';

  @override
  String get voice_record => 'Voice note record cheyandi';

  @override
  String get voice_recordHint =>
      'Oka nimisham varaku. Idi meeku maatrame vinipistundi.';

  @override
  String get voice_rationaleTitle => 'Mee gonthu kooda jodistaara?';

  @override
  String get voice_rationaleBody =>
      'Voice note record cheyadaaniki Aura ki mee microphone kaavaali. Recordings meeku maatrame untaayi, rooms lo eppudu share kaavu.';

  @override
  String get voice_rationaleAllow => 'Allow cheyandi';

  @override
  String get voice_denied =>
      'Voice off lo undi. Badulu ga type cheyandi, leda Settings lo on cheyandi.';

  @override
  String get voice_openSettings => 'Settings';

  @override
  String get voice_recording => 'Record avutondi';

  @override
  String voice_elapsed(String time, String limit) {
    return '$time · $limit varaku';
  }

  @override
  String voice_recordingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Record avutondi, $seconds seconds',
      one: 'Record avutondi, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_stop => 'Recording aapandi';

  @override
  String get voice_started => 'Recording modalaindi';

  @override
  String voice_recorded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Voice note record ayyindi, $seconds seconds',
      one: 'Voice note record ayyindi, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_limitReached =>
      'Oka nimisham purthayyindi, anduke recording aagindi. Mee voice note ready ga undi.';

  @override
  String get voice_recordFailed =>
      'Ippudu voice record avvaledu. Mee maatalu maatram save avutaayi.';

  @override
  String get voice_note => 'Voice note';

  @override
  String voice_length(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_play => 'Voice note play cheyandi';

  @override
  String get voice_pause => 'Voice note pause cheyandi';

  @override
  String get voice_reRecord => 'Malli record cheyandi';

  @override
  String get voice_remove => 'Teeseyandi';

  @override
  String get voice_removeSemantic => 'Voice note teeseyandi';

  @override
  String get voice_dropped =>
      'Mee check-in save ayyindi. Phone lo space takkuva ga undatam valla voice note unchalekapoyaam.';

  @override
  String get voice_loading => 'Mee voice note testunnaam…';

  @override
  String get voice_offline =>
      'Meeru malli online ki vachaaka voice note play avutundi.';

  @override
  String get voice_failed =>
      'Ee voice note ippudu play avvaledu. Kaasepaagi malli try cheyandi.';

  @override
  String get voice_section => 'Mee gonthu';

  @override
  String get voice_hasVoice => 'Oka voice note undi';
}
