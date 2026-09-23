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
  String get flows_startOverTitle => 'మళ్ళీ మొదటి నుంచి మొదలుపెడదామా?';

  @override
  String get flows_startOverBody =>
      'ఇప్పటివరకు మీరు ఎంచుకున్నవి, రాసినవి క్లియర్ అవుతాయి.';

  @override
  String get flows_startOver => 'మళ్ళీ మొదలుపెడదాం';

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
  String get flows_startOverTitle => 'Malli modati nunchi modalupedadaamaa?';

  @override
  String get flows_startOverBody =>
      'Ippativaraku meeru select chesinavi, raasinavi clear avutaayi.';

  @override
  String get flows_startOver => 'Malli modalupedadaam';

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
