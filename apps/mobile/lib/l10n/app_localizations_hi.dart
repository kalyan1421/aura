// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Aura';

  @override
  String get common_continue => 'आगे बढ़ें';

  @override
  String get common_back => 'वापस';

  @override
  String get common_done => 'हो गया';

  @override
  String get common_notNow => 'अभी नहीं';

  @override
  String get common_cancel => 'रद्द करें';

  @override
  String get common_close => 'बंद करें';

  @override
  String get common_comingSoon => 'जल्द आ रहा है';

  @override
  String get help_button => 'मुझे अभी मदद चाहिए';

  @override
  String get help_title => 'मदद यहाँ है';

  @override
  String get help_subtitle =>
      'आपको इसे अकेले नहीं सहना है। अभी किसी से संपर्क करें, या एक मिनट रुककर साँस लें।';

  @override
  String get help_crisisTitle => 'लगता है अभी बहुत कुछ चल रहा है।';

  @override
  String get help_crisisSubtitle =>
      'आपको इसे अकेले नहीं सहना है। आपका चेक-इन सेव हो गया है।';

  @override
  String get help_teleManas => 'Tele-MANAS · मुफ़्त, 24×7';

  @override
  String get help_teleManasTollFree => 'Tele-MANAS टोल-फ़्री';

  @override
  String get help_emergency112 => 'इमरजेंसी';

  @override
  String get help_childline => 'Childline · 18 साल से कम उम्र वालों के लिए';

  @override
  String get help_us988 => 'Suicide & Crisis Lifeline · कॉल या टेक्स्ट करें';

  @override
  String get help_otherEmergency =>
      'अगर आप अभी खतरे में हैं, तो कृपया अपने इलाके के इमरजेंसी नंबर पर कॉल करें।';

  @override
  String help_callSemantic(String name, String number) {
    return '$name को कॉल करें, $number';
  }

  @override
  String get help_groundingTitle => 'ठहरने के लिए साठ सेकंड';

  @override
  String get help_groundingBody =>
      'घेरे के साथ साँस लें। बाकी सब एक मिनट रुक सकता है।';

  @override
  String get help_groundingStart => 'शुरू करें';

  @override
  String get help_groundingPause => 'रोकें';

  @override
  String get help_groundingResume => 'फिर से शुरू करें';

  @override
  String get help_breatheIn => 'साँस अंदर लें';

  @override
  String get help_breatheOut => 'साँस बाहर छोड़ें';

  @override
  String get help_ground1 => 'ज़मीन पर अपने पैरों को महसूस करें।';

  @override
  String get help_ground2 => 'आसपास दिखने वाली पाँच चीज़ों पर ध्यान दें।';

  @override
  String get help_ground3 => 'आसपास की तीन आवाज़ों पर ध्यान दें।';

  @override
  String get help_ground4 => 'अपने कंधों को ढीला छोड़ दें।';

  @override
  String get help_ground5 => 'आप यहाँ हैं। अभी के लिए इतना काफ़ी है।';

  @override
  String get help_groundingDone =>
      'बहुत अच्छा। जितनी देर ज़रूरत हो, यहीं रहें।';

  @override
  String help_secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds सेकंड बाकी',
      one: '1 सेकंड बाकी',
    );
    return '$_temp0';
  }

  @override
  String get help_disclaimer =>
      'Aura कोई मेडिकल डिवाइस या इमरजेंसी सेवा नहीं है।';

  @override
  String get help_backToCheckin => 'मेरे चेक-इन पर वापस';

  @override
  String get welcome_title => 'Aura में आपका स्वागत है';

  @override
  String get welcome_body =>
      'अपने मन का हाल देखने की एक शांत जगह। आपके चेक-इन प्राइवेट रहते हैं, और हर बार आपके आने पर आपका Aura थोड़ा बढ़ता है।';

  @override
  String get welcome_begin => 'शुरू करें';

  @override
  String get dob_title => 'आपका जन्मदिन कब है?';

  @override
  String get dob_body =>
      'यह हम सबसे पूछते हैं। यह प्राइवेट रहता है और किसी को कभी नहीं दिखाया जाता।';

  @override
  String get dob_day => 'दिन';

  @override
  String get dob_month => 'महीना';

  @override
  String get dob_year => 'साल';

  @override
  String get dob_invalid => 'ऐसी कोई तारीख नहीं होती। एक बार देख लें?';

  @override
  String get dob_future => 'यह तारीख अभी आई नहीं है। एक बार देख लें?';

  @override
  String get blocked_title =>
      'Aura 13 साल और उससे ज़्यादा उम्र के लोगों के लिए बना है।';

  @override
  String get blocked_body => 'तब आपसे मिलकर हमें बहुत खुशी होगी।';

  @override
  String get blocked_helpIndia =>
      'अगर अभी किसी से बात करने का मन है, तो Childline 1098 पर मुफ़्त है। इमरजेंसी में 112 पर कॉल करें।';

  @override
  String get blocked_helpOther =>
      'अगर अभी किसी से बात करने का मन है, तो कृपया किसी ऐसे बड़े से बात करें जिस पर आपको भरोसा हो।';

  @override
  String get language_title => 'कौन-सी भाषा अपनी-सी लगती है?';

  @override
  String get language_body => 'इसे सेटिंग्स में कभी भी बदला जा सकता है।';

  @override
  String get language_teLatnHint => 'अंग्रेज़ी अक्षरों में तेलुगु';

  @override
  String get language_hiLatnHint => 'अंग्रेज़ी अक्षरों में हिंदी';

  @override
  String get language_beta => 'बीटा';

  @override
  String get signin_title => 'अपने Aura को सुरक्षित रखें';

  @override
  String get signin_body =>
      'अपने ईमेल से साइन इन करें, ताकि नए फ़ोन में भी आपका Aura आपके साथ रहे। न नाम, न फ़ोन नंबर, न पासवर्ड।';

  @override
  String get signin_emailLabel => 'ईमेल';

  @override
  String get signin_sendCode => 'मुझे ईमेल पर कोड भेजें';

  @override
  String signin_codeSent(String email) {
    return 'हमने $email पर 6 अंकों का कोड भेजा है। चाहें तो उस ईमेल के लिंक पर भी टैप करें।';
  }

  @override
  String get signin_codeLabel => '6 अंकों का कोड';

  @override
  String get signin_verify => 'आगे बढ़ें';

  @override
  String get signin_resend => 'नया कोड भेजें';

  @override
  String get signin_changeEmail => 'दूसरा ईमेल इस्तेमाल करें';

  @override
  String get signin_error =>
      'यह हो नहीं पाया। फिर से कोशिश करें, या किसी और तरीके से साइन इन करें।';

  @override
  String get signin_codeExpired =>
      'इस कोड का समय खत्म हो गया है। हम नया कोड भेज देंगे।';

  @override
  String get signin_invalidCode => 'यह कोड मेल नहीं खा रहा। एक बार देख लें?';

  @override
  String get signin_invalidEmail => 'यह ईमेल कुछ ठीक नहीं लग रहा।';

  @override
  String get signin_apple => 'Apple के साथ जारी रखें';

  @override
  String get signin_google => 'Google के साथ जारी रखें';

  @override
  String get signin_offline =>
      'आप ऑफ़लाइन हैं। अभी अपना पहला मूड चुनें। कनेक्ट होने पर हम सेटअप पूरा कर देंगे।';

  @override
  String get signin_offlineContinue => 'अभी चेक-इन करें';

  @override
  String get signin_unavailable =>
      'इस बिल्ड में साइन-इन अभी सेट नहीं हुआ है। फ़िलहाल आपके चेक-इन इसी फ़ोन पर रहेंगे।';

  @override
  String get signin_continueLocal => 'इसी फ़ोन पर आगे बढ़ें';

  @override
  String get checkin_title => 'अभी कैसा लग रहा है?';

  @override
  String get checkin_subtitle =>
      'जो सबसे करीब लगे, उसे चुनें। कोई जवाब गलत नहीं है।';

  @override
  String get checkin_moreEnergy => 'ज़्यादा एनर्जी';

  @override
  String get checkin_lessEnergy => 'कम एनर्जी';

  @override
  String get checkin_pleasant => 'सुखद';

  @override
  String get checkin_unpleasant => 'असहज';

  @override
  String get quadrant_storm => 'तूफ़ान';

  @override
  String get quadrant_rain => 'बारिश';

  @override
  String get quadrant_moonlight => 'चाँदनी';

  @override
  String get quadrant_sunrise => 'सूर्योदय';

  @override
  String mood_semantic(
    String mood,
    String quadrant,
    String energy,
    String feel,
  ) {
    return '$mood, $quadrant समूह, $energy, $feel';
  }

  @override
  String get semantic_highEnergy => 'ज़्यादा एनर्जी';

  @override
  String get semantic_lowEnergy => 'कम एनर्जी';

  @override
  String get semantic_pleasant => 'सुखद';

  @override
  String get semantic_unpleasant => 'असहज';

  @override
  String get checkin_addDetails => 'कोई टैग या कुछ शब्द जोड़ें';

  @override
  String get checkin_tagsTitle => 'यह किस बारे में है?';

  @override
  String get tag_study => 'पढ़ाई';

  @override
  String get tag_work => 'काम';

  @override
  String get tag_family => 'परिवार';

  @override
  String get tag_friends => 'दोस्त';

  @override
  String get tag_sleep => 'नींद';

  @override
  String get tag_health => 'सेहत';

  @override
  String get tag_money => 'पैसे';

  @override
  String get tag_love => 'प्यार';

  @override
  String get tag_alone => 'अकेले';

  @override
  String get tag_commute => 'आना-जाना';

  @override
  String get checkin_customTag => 'अपना टैग';

  @override
  String get checkin_customTagAdd => 'टैग जोड़ें';

  @override
  String get checkin_noteLabel => 'चाहें तो कुछ शब्द';

  @override
  String get checkin_noteHint => 'यह सिर्फ़ आपको दिखेगा।';

  @override
  String get checkin_save => 'सेव करें';

  @override
  String get checkin_saveFailed =>
      'यह सेव नहीं हो पाया। शायद आपके फ़ोन में जगह कम है।';

  @override
  String checkin_savedStarlight(int amount) {
    return '+$amount Starlight';
  }

  @override
  String get checkin_saved => 'सेव हो गया';

  @override
  String get checkin_savedOffline => 'इस फ़ोन पर सेव हो गया';

  @override
  String get checkin_savedThanks => 'चेक-इन करने के लिए शुक्रिया।';

  @override
  String get checkin_savedFull =>
      'आज की सारी Starlight मिल चुकी है। आपका चेक-इन फिर भी गिना जाता है।';

  @override
  String get checkin_roomButton => 'ऐसा ही महसूस करने वालों के रूम में जुड़ें';

  @override
  String get home_checkIn => 'चेक-इन करें';

  @override
  String home_todayStarlight(int count) {
    return 'आज $count Starlight';
  }

  @override
  String home_totalStarlight(int count) {
    return 'कुल $count';
  }

  @override
  String get home_empty =>
      'यह आपका Aura है। इसे रोशनी देने के लिए चेक-इन करें।';

  @override
  String get home_resting =>
      'आपका Aura कुछ समय से आराम कर रहा है। जब मन हो, हाय कहें।';

  @override
  String home_glowStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'चमक का सिलसिला · $count दिन',
      one: 'चमक का सिलसिला · 1 दिन',
    );
    return '$_temp0';
  }

  @override
  String home_restDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आराम के दिन जमा हैं',
      one: '1 आराम का दिन जमा है',
      zero: 'अभी कोई आराम का दिन जमा नहीं है',
    );
    return '$_temp0';
  }

  @override
  String get home_restingSafe => 'आराम · आपकी चमक सुरक्षित है';

  @override
  String get home_glowCarriesOn => 'आपकी चमक जारी है';

  @override
  String home_lifetimeGlow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कुल $count चमक वाले दिन',
      one: 'कुल 1 चमक वाला दिन',
    );
    return '$_temp0';
  }

  @override
  String get home_habitsTitle => 'आज की छोटी-छोटी चीज़ें';

  @override
  String home_habitDone(String habit) {
    return '$habit, आज हो गया';
  }

  @override
  String home_habitNotYet(String habit) {
    return '$habit, आज अभी नहीं';
  }

  @override
  String get home_offline =>
      'आप ऑफ़लाइन हैं। आपकी अपनी चीज़ें फिर भी यहाँ सेव होती रहेंगी।';

  @override
  String get home_finishSetup =>
      'सेटअप पूरा करें, ताकि आपका Aura सुरक्षित रहे।';

  @override
  String get home_signIn => 'साइन इन करें';

  @override
  String get home_syncIdle => 'सब सेव हो गया';

  @override
  String home_syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चीज़ें सिंक होनी बाकी हैं',
      one: '1 चीज़ सिंक होनी बाकी है',
    );
    return '$_temp0';
  }

  @override
  String get home_syncLocal => 'इस फ़ोन पर सेव हो गया';

  @override
  String get home_settings => 'सेटिंग्स';

  @override
  String get home_welcomeBack =>
      'फिर से स्वागत है। आज एक छोटी-सी चीज़ ही काफ़ी है।';

  @override
  String home_evolved(String stage) {
    return 'आपका Aura बढ़कर $stage बन गया।';
  }

  @override
  String get stage_spark => 'चिंगारी';

  @override
  String get stage_ember => 'अंगारा';

  @override
  String get stage_glow => 'चमक';

  @override
  String get stage_radiance => 'आभा';

  @override
  String get stage_constellation => 'तारामंडल';

  @override
  String get habit_hydrate => 'पानी पीना';

  @override
  String get habit_sleep_on_time => 'समय पर सोना';

  @override
  String get habit_move => 'चलना-फिरना';

  @override
  String get habit_breathe => 'साँस लेना';

  @override
  String get habit_journal => 'डायरी लिखना';

  @override
  String get habit_go_outside => 'बाहर जाना';

  @override
  String avatar_semantic(String stage, String hue) {
    return 'आपका Aura, $stage स्टेज, चमक का रंग $hue';
  }

  @override
  String get avatar_semanticResting => 'नरम नेबुला में आराम करता हुआ';

  @override
  String avatar_semanticRings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'चारों ओर घूमती $count रोशनियाँ',
      one: 'चारों ओर घूमती एक रोशनी',
    );
    return '$_temp0';
  }

  @override
  String avatar_semanticStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इसके तारामंडल में $count तारे',
      one: 'इसके तारामंडल में एक तारा',
    );
    return '$_temp0';
  }

  @override
  String get hue_gold => 'सुनहरा';

  @override
  String get hue_green => 'हरा';

  @override
  String get hue_teal => 'टील';

  @override
  String get hue_silverBlue => 'सिल्वर-नीला';

  @override
  String get hue_violet => 'बैंगनी';

  @override
  String get hue_rose => 'गुलाबी';

  @override
  String get settings_title => 'सेटिंग्स';

  @override
  String get settings_language => 'भाषा';

  @override
  String get settings_account => 'अकाउंट';

  @override
  String settings_signedInAs(String email) {
    return '$email से साइन इन है';
  }

  @override
  String get settings_signOut => 'साइन आउट करें';

  @override
  String settings_signOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count चीज़ें अभी सिंक नहीं हुई हैं। उनके सिंक होने तक साइन इन रहें?',
      one: '1 चीज़ अभी सिंक नहीं हुई है। उसके सिंक होने तक साइन इन रहें?',
    );
    return '$_temp0';
  }

  @override
  String get settings_stay => 'साइन इन रहें';

  @override
  String get settings_signOutAnyway => 'फिर भी साइन आउट करें';

  @override
  String get settings_signIn => 'अपना Aura सुरक्षित रखने के लिए साइन इन करें';

  @override
  String get settings_avatarLab => 'अवतार लैब';

  @override
  String get settings_about => 'बारे में';

  @override
  String settings_version(String version) {
    return 'वर्ज़न $version';
  }

  @override
  String get push_title => 'हर शाम एक हल्का-सा रिमाइंडर चाहिए?';

  @override
  String get push_body =>
      'दिन में ज़्यादा से ज़्यादा एक, और स्ट्रीक के बारे में कभी नहीं। आपकी लॉक स्क्रीन पर कभी नहीं दिखेगा कि आपका मन कैसा है।';

  @override
  String get push_allow => 'अनुमति दें';

  @override
  String get signin_busy => 'एक पल';

  @override
  String signin_resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds सेकंड में नया कोड माँगा जा सकता है',
      one: '1 सेकंड में नया कोड माँगा जा सकता है',
    );
    return '$_temp0';
  }

  @override
  String get signin_freshSent => 'नया कोड आ रहा है।';

  @override
  String get acct_pendingTitle => 'अपना अकाउंट रखना है?';

  @override
  String acct_pendingBody(String date) {
    return 'आपका अकाउंट $date को डिलीट होना तय है। क्या इसे रखना है?';
  }

  @override
  String get acct_pendingBodySoon =>
      'आपका अकाउंट जल्द ही डिलीट होना तय है। क्या इसे रखना है?';

  @override
  String get acct_keep => 'मेरा अकाउंट रखें';

  @override
  String get acct_letGo => 'जाने दें';

  @override
  String get acct_keepFailed =>
      'यह नहीं हो पाया, इसलिए अभी कुछ नहीं बदला है। कनेक्ट होने पर फिर से कोशिश करें।';

  @override
  String get acct_deleteTitle => 'मेरा अकाउंट डिलीट करें';

  @override
  String get acct_deleteIntro => 'अकाउंट डिलीट करने पर ये सब हट जाएगा:';

  @override
  String get acct_itemCheckIns => 'आपके चेक-इन और नोट';

  @override
  String get acct_itemHabits => 'आपकी आदतें';

  @override
  String get acct_itemProgress => 'आपका Starlight और आपके Aura का बढ़ना';

  @override
  String get acct_itemAccount => 'आपका अकाउंट और साइन इन वाला ईमेल';

  @override
  String get acct_grace =>
      'मन बदलने के लिए आपके पास 7 दिन हैं। उससे पहले फिर से साइन इन करें, तो सब कुछ बना रहेगा। उसके बाद यह हमेशा के लिए डिलीट हो जाएगा और वापस नहीं लाया जा सकेगा।';

  @override
  String get acct_store =>
      'अगर किसी सब्सक्रिप्शन का पेमेंट App Store या Google Play से होता है, तो अकाउंट डिलीट करने से वह रद्द नहीं होता। उसे अपने स्टोर की सब्सक्रिप्शन सेटिंग्स में मैनेज या रद्द करें।';

  @override
  String get acct_phone =>
      'यह फ़ोन तुरंत क्लियर हो जाएगा और इससे साइन आउट हो जाएगा।';

  @override
  String get acct_needsConnection =>
      'अकाउंट डिलीट करने के लिए कनेक्शन चाहिए। इंटरनेट से कनेक्ट करके फिर से कोशिश करें।';

  @override
  String get acct_confirmTitle => 'अपना अकाउंट डिलीट करें?';

  @override
  String get acct_confirmBody =>
      'आपका अकाउंट और उसमें मौजूद सब कुछ 7 दिनों में डिलीट हो जाएगा। इसे रखना हो तो उससे पहले फिर से साइन इन करें। यह फ़ोन अभी क्लियर हो जाएगा।';

  @override
  String get acct_failed =>
      'यह नहीं हो पाया, और कुछ भी डिलीट नहीं हुआ है। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get acct_failedOffline =>
      'Aura तक पहुँचा नहीं जा सका, और कुछ भी डिलीट नहीं हुआ है। अपना कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get acct_retry => 'फिर से कोशिश करें';

  @override
  String get acct_scheduledTitle => 'आपका अकाउंट डिलीट होना तय हो गया है';

  @override
  String acct_scheduledBody(String date) {
    return 'यह $date को डिलीट हो जाएगा। इसे रखना हो तो उससे पहले फिर से साइन इन करें।';
  }

  @override
  String get acct_phoneCleared =>
      'यह फ़ोन क्लियर कर दिया गया है और इससे साइन आउट हो गया है।';

  @override
  String get acct_signedOut =>
      'अभी साइन इन नहीं है, इसलिए डिलीट करने के लिए कोई अकाउंट नहीं है। आपका सेव किया हुआ सब कुछ सिर्फ़ इसी फ़ोन पर है।';

  @override
  String get acct_unavailable =>
      'इस बिल्ड में अकाउंट डिलीट करने की सुविधा सेट नहीं है।';

  @override
  String get set_comfort => 'सहूलियत';

  @override
  String get set_reduceMotion => 'मोशन कम करें';

  @override
  String get set_reduceMotionNote => 'आपके फ़ोन की सेटिंग को भी मानता है';

  @override
  String get set_haptics => 'हैप्टिक्स';

  @override
  String get set_hapticsNote => 'कुछ चुनने पर हल्का वाइब्रेशन';

  @override
  String get set_hideStreak => 'स्ट्रीक नंबर छिपाएँ';

  @override
  String get set_hideStreakNote =>
      'आपकी चमक बढ़ती रहेगी। बस होम पर दिन नहीं गिने जाएँगे।';

  @override
  String get set_signOutTitle => 'Aura से साइन आउट करें?';

  @override
  String get set_helpSafety => 'मदद और सुरक्षा';

  @override
  String get set_grievanceOfficer => 'शिकायत अधिकारी';

  @override
  String get set_grievanceSubject => 'Aura के बारे में शिकायत';

  @override
  String get set_contactSupport => 'सपोर्ट से संपर्क करें';

  @override
  String get set_supportSubject => 'Aura सपोर्ट';

  @override
  String get set_opensEmail => 'आपका ईमेल ऐप खुलेगा';

  @override
  String set_emailFailed(String email) {
    return 'कोई ईमेल ऐप नहीं खुल पाया। $email पर लिखें।';
  }

  @override
  String get acct_inProgress =>
      'इस अकाउंट को डिलीट करने का काम शुरू हो चुका है, इसलिए अब इसे रखा नहीं जा सकता। यह फ़ोन क्लियर हो जाएगा और इससे साइन आउट हो जाएगा।';

  @override
  String get signin_or => 'या';

  @override
  String get signin_socialNotReady =>
      'साइन-इन का यह तरीका अभी तैयार नहीं है। फ़िलहाल अपना ईमेल इस्तेमाल करें।';

  @override
  String get signin_socialOffline =>
      'लगता है आप ऑफ़लाइन हैं। कनेक्ट होने पर फिर से कोशिश करें।';

  @override
  String get capsules_title => 'भविष्य के आप';

  @override
  String get capsules_emptyBody =>
      'भविष्य के आपके लिए कुछ लिखें। इसे किसी तारीख के लिए सील करें, या किसी एहसास के लिए।';

  @override
  String get capsules_emptyCta => 'अपना पहला कैप्सूल सील करें';

  @override
  String get capsules_new => 'कैप्सूल लिखें';

  @override
  String capsules_entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कैप्सूल सील हैं',
      one: '1 कैप्सूल सील है',
      zero: 'अभी कुछ सील नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String capsules_entryReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खुलने के लिए तैयार हैं',
      one: '1 खुलने के लिए तैयार है',
    );
    return '$_temp0';
  }

  @override
  String get capsules_sectionReady => 'खुलने के लिए तैयार';

  @override
  String get capsules_sectionSealed => 'सील किए हुए';

  @override
  String get capsules_sectionOpened => 'खुले हुए';

  @override
  String capsules_sealedUntil(String date) {
    return '$date तक सील है। यह सुरक्षित रहेगा।';
  }

  @override
  String get capsules_waitingFeeling => 'किसी एहसास का इंतज़ार';

  @override
  String get capsules_readyRow => 'जब आप तैयार हों';

  @override
  String capsules_untitled(String date) {
    return '$date का एक कैप्सूल';
  }

  @override
  String get capsules_lockedTitle => 'एक सील किया हुआ कैप्सूल';

  @override
  String capsules_sealedOn(String date) {
    return '$date को सील किया';
  }

  @override
  String capsules_openedOn(String date) {
    return '$date को खोला';
  }

  @override
  String get capsules_draftTitle => 'आपका ड्राफ़्ट यहाँ है';

  @override
  String get capsules_draftBody => 'जहाँ छोड़ा था, वहीं से आगे लिखें।';

  @override
  String get capsules_composeTitle => 'भविष्य के आपके लिए लिखें';

  @override
  String get capsules_titleLabel => 'टाइटल';

  @override
  String get capsules_titleHelper => 'सील रहने तक कैप्सूल पर यही दिखेगा।';

  @override
  String get capsules_textLabel => 'आपका नोट';

  @override
  String get capsules_textHelper => 'खुलने पर यह सिर्फ़ आपके लिए होगा।';

  @override
  String get capsules_photosTitle => 'फ़ोटो';

  @override
  String get capsules_addPhoto => 'फ़ोटो जोड़ें';

  @override
  String get capsules_photoHint =>
      'ज़्यादा से ज़्यादा 3। लोकेशन और कैमरे की जानकारी हटा दी जाती है।';

  @override
  String get capsules_photoAdding => 'आपकी फ़ोटो जोड़ी जा रही है…';

  @override
  String get capsules_photoFailed =>
      'यह फ़ोटो नहीं जुड़ पाई। कोई दूसरी आज़माएँ।';

  @override
  String capsules_photoRemove(int index) {
    return 'फ़ोटो $index हटाएँ';
  }

  @override
  String capsules_photoSemantic(int index, int count) {
    return '$count में से फ़ोटो $index';
  }

  @override
  String get capsules_voiceHint =>
      'ज़्यादा से ज़्यादा 2 मिनट। यह सिर्फ़ आपके लिए है।';

  @override
  String get capsules_voiceLimit =>
      'पूरे दो मिनट हो गए, इसलिए रिकॉर्डिंग रुक गई। आपका वॉइस नोट तैयार है।';

  @override
  String get capsules_unlockTitle => 'यह कब खुले?';

  @override
  String get capsules_unlockDate => 'किसी तारीख को';

  @override
  String get capsules_unlockFeeling => 'किसी एहसास के लिए';

  @override
  String get capsules_pickDate => 'तारीख चुनें';

  @override
  String get capsules_changeDate => 'तारीख बदलें';

  @override
  String capsules_dateChosen(String date, String time) {
    return '$date को $time पर खुलेगा';
  }

  @override
  String get capsules_dateHelp =>
      'आज से एक हफ़्ते से लेकर पाँच साल तक का कोई भी दिन।';

  @override
  String get capsules_datePickerHelp => 'उस दिन 10:00 बजे खुलेगा';

  @override
  String get capsules_feelingHelp =>
      'सील करने के 24 घंटे बाद से, अगली बार यही एहसास होने पर चेक-इन करते ही यह खुल सकता है।';

  @override
  String capsules_anyQuadrant(String quadrant) {
    return '$quadrant वाला कोई भी एहसास';
  }

  @override
  String capsules_feelingChosen(String feeling) {
    return 'इसका इंतज़ार: $feeling';
  }

  @override
  String get capsules_seal => 'सील करें';

  @override
  String get capsules_needContent =>
      'पहले कुछ शब्द, एक वॉइस नोट या एक फ़ोटो जोड़ें।';

  @override
  String get capsules_needUnlock => 'चुनें कि यह कब खुले।';

  @override
  String get capsules_sealFailed =>
      'अभी सील नहीं हो पाया। आपका कैप्सूल यहीं है। फिर से कोशिश करें।';

  @override
  String get capsules_sealedTitle => 'सील हो गया';

  @override
  String get capsules_sealedFeeling =>
      'सील हो गया। यह उसी एहसास का इंतज़ार करेगा।';

  @override
  String get capsules_mediaLater =>
      'इस फ़ोन पर सील और सुरक्षित है। ऑनलाइन होने पर फ़ोटो और आवाज़ का बैकअप हो जाएगा।';

  @override
  String get capsules_limitBody =>
      'फ़्री अकाउंट में 3 मूड कैप्सूल इंतज़ार में रखे जा सकते हैं। तारीख वाले कैप्सूल की कोई सीमा नहीं है।';

  @override
  String get capsules_limitPickDate => 'इसके बदले तारीख चुनें';

  @override
  String get capsules_makeDate => 'इसे तारीख वाला कैप्सूल बनाएँ';

  @override
  String get capsules_leaveTitle => 'यह ड्राफ़्ट रखें?';

  @override
  String get capsules_leaveBody =>
      'जब तक आप इसे सील न करें या हटा न दें, यह इसी फ़ोन पर रहेगा।';

  @override
  String get capsules_leaveEditing => 'लिखते रहें';

  @override
  String get capsules_leaveKeep => 'ड्राफ़्ट रखें';

  @override
  String get capsules_leaveDiscard => 'हटा दें';

  @override
  String capsules_detailFeeling(String feeling) {
    return 'किसी एहसास का इंतज़ार: $feeling.';
  }

  @override
  String capsules_detailArming(String date) {
    return 'यह $date से खुल सकता है।';
  }

  @override
  String get capsules_detailNoEarly =>
      'सील का मतलब सील: इसे न पहले खोला जा सकता है, न बदला जा सकता है।';

  @override
  String get capsules_delete => 'कैप्सूल डिलीट करें';

  @override
  String get capsules_deleteTitle => 'यह कैप्सूल डिलीट करें?';

  @override
  String get capsules_deleteBody => 'यह बिना खुले हमेशा के लिए हट जाएगा।';

  @override
  String get capsules_deleteBodyOpened => 'यह हमेशा के लिए हट जाएगा।';

  @override
  String get capsules_deleteConfirm => 'डिलीट करें';

  @override
  String get capsules_deleteKeep => 'रहने दें';

  @override
  String get capsules_deleted => 'कैप्सूल डिलीट हो गया।';

  @override
  String get capsules_triggerTitle =>
      'ऐसे पल के लिए आपने एक नोट छोड़ा था। अभी खोलें या बाद में?';

  @override
  String get capsules_holdTitle =>
      'पहले लिखा आपका एक नोट इंतज़ार में है। अभी खोलें, या बाद में?';

  @override
  String get capsules_now => 'अभी';

  @override
  String get capsules_later => 'बाद में';

  @override
  String get capsules_readyTitle => 'आपने जो सील किया था, वह अब खुल सकता है।';

  @override
  String capsules_readyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कैप्सूल तैयार हैं।',
      one: '1 कैप्सूल तैयार है।',
    );
    return '$_temp0';
  }

  @override
  String get capsules_readyOpen => 'खोलें';

  @override
  String get capsules_channelName => 'कैप्सूल';

  @override
  String get capsules_notifyAskTitle => 'खुलने पर आपको बताया जाए?';

  @override
  String get capsules_notifyAskBody =>
      'खुलने वाले दिन बस एक हल्का-सा नोट। आपकी लॉक स्क्रीन पर यह नहीं दिखेगा कि अंदर क्या है।';

  @override
  String get capsules_channelDescription =>
      'जब आपका सील किया हुआ कुछ खुलने के लिए तैयार हो।';

  @override
  String get capsules_hardMoment =>
      'यह आपने एक मुश्किल घड़ी में लिखा था। जब आप तैयार हों, तब खोलें।';

  @override
  String get capsules_skip => 'छोड़ें';

  @override
  String get capsules_opening => 'आपका कैप्सूल खुल रहा है';

  @override
  String get capsules_openedTitle => 'बीते समय के आप से';

  @override
  String get capsules_keepNextTime => 'अगली बार के लिए रखें';

  @override
  String get capsules_keptNextTime => 'यह फिर से उसी एहसास का इंतज़ार करेगा।';

  @override
  String get capsules_voiceOffline =>
      'आपका कैप्सूल खुल गया है। ऑनलाइन वापस आने पर वॉइस नोट आ जाएगा।';

  @override
  String get capsules_photosOffline => 'ऑनलाइन वापस आने पर फ़ोटो आ जाएँगी।';

  @override
  String get capsules_mediaFailed =>
      'यह अभी लोड नहीं हो पाया। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get capsules_retry => 'फिर से कोशिश करें';

  @override
  String get capsules_cantRead =>
      'यह कैप्सूल अभी इस फ़ोन पर पढ़ा नहीं जा सकता। ऑनलाइन वापस आने पर यह खुल जाएगा।';

  @override
  String capsules_accountDeletionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सील किए हुए $count कैप्सूल हमेशा के लिए मिट जाएँगे।',
      one: 'सील किया हुआ 1 कैप्सूल हमेशा के लिए मिट जाएगा।',
    );
    return '$_temp0';
  }

  @override
  String get checkin_discardTitle => 'सेव किए बिना बाहर निकलें?';

  @override
  String get checkin_discardKeep => 'एडिट करते रहें';

  @override
  String get checkin_discardConfirm => 'हटा दें';

  @override
  String checkin_tagLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ज़्यादा से ज़्यादा $count टैग',
      one: 'ज़्यादा से ज़्यादा 1 टैग',
    );
    return '$_temp0';
  }

  @override
  String checkin_quadrantAxes(String energy, String feel) {
    return '$energy · $feel';
  }

  @override
  String get history_title => 'आपके चेक-इन';

  @override
  String get history_private => 'ये सिर्फ़ आपको दिखते हैं।';

  @override
  String get history_empty =>
      'यहाँ अभी कुछ नहीं है। आपके चेक-इन यहाँ जमा होंगे, और ये सिर्फ़ आपको दिखेंगे।';

  @override
  String get history_today => 'आज';

  @override
  String get history_yesterday => 'कल';

  @override
  String history_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टैग',
      one: '1 टैग',
    );
    return '$_temp0';
  }

  @override
  String get history_hasNote => 'नोट है';

  @override
  String get history_entryTitle => 'आपका चेक-इन';

  @override
  String history_when(String day, String time) {
    return '$day, $time';
  }

  @override
  String get history_tags => 'टैग';

  @override
  String get history_note => 'आपके शब्द';

  @override
  String get history_synced => 'सिंक हो गया';

  @override
  String get history_edit => 'एडिट करें';

  @override
  String get history_editWindowOver =>
      'चेक-इन करने के बाद एक दिन तक उसे एडिट किया जा सकता है।';

  @override
  String get history_delete => 'डिलीट करें';

  @override
  String get history_deleteTitle => 'यह चेक-इन डिलीट करें?';

  @override
  String get history_deleteBody =>
      'इससे आपकी Starlight या चमक वाले दिनों पर कोई असर नहीं पड़ता।';

  @override
  String get history_missing => 'यह चेक-इन अब यहाँ नहीं है।';

  @override
  String get history_editNoteLocked =>
      'इस चेक-इन का नोट अभी इस फ़ोन तक नहीं पहुँचा है। पहुँचने के बाद इसे एडिट किया जा सकता है।';

  @override
  String get legal_privacy => 'प्राइवेसी पॉलिसी';

  @override
  String get legal_terms => 'इस्तेमाल की शर्तें';

  @override
  String get legal_opensInBrowser => 'आपके ब्राउज़र में खुलेगा';

  @override
  String get help_crisisSubtitleCapsule =>
      'आपको इसे अकेले नहीं सहना है। आपका कैप्सूल सील हो गया है।';

  @override
  String get help_backToCapsule => 'मेरे कैप्सूल पर वापस';

  @override
  String get rooms_trayOpen => 'अपनापन भेजें';

  @override
  String get rooms_howRoomsWork => 'रूम कैसे काम करते हैं';

  @override
  String get rooms_reportPickReason => 'चुनें कि क्या हो रहा है';

  @override
  String plus_skyStardustNeeds(int count, int have) {
    return '$count Stardust चाहिए (आपके पास $have हैं)';
  }

  @override
  String get export_settingsRow => 'मेरे डेटा की कॉपी डाउनलोड करें';

  @override
  String get export_title => 'आपके डेटा की कॉपी';

  @override
  String get export_body =>
      'आपके Aura में जो कुछ है, उसकी कॉपी: चेक-इन और नोट्स, आदतें, आपके खोले हुए कैप्सूल, आपके अकाउंट की जानकारी, खरीदारी, Stardust और कीपसेक। सील किए गए कैप्सूल सील ही रहते हैं: सिर्फ़ उनके शीर्षक और तारीखें होती हैं।';

  @override
  String get export_where =>
      'यह इसी फ़ोन पर बनती है और सिर्फ़ वहीं जाती है जहाँ आप इसे सेव करना या भेजना चुनते हैं।';

  @override
  String get export_media =>
      'वॉइस नोट और फ़ोटो ऐप में ही रहते हैं; कॉपी में लिखा होता है कि वे कब बनाए गए।';

  @override
  String get export_private =>
      'ये फ़ाइलें एन्क्रिप्टेड नहीं होतीं। इन्हें किसी निजी जगह पर रखें।';

  @override
  String get export_make => 'मेरी कॉपी बनाएँ';

  @override
  String get export_busy => 'आपका डेटा तैयार हो रहा है…';

  @override
  String get export_done => 'आपकी कॉपी तैयार है।';

  @override
  String get export_failed =>
      'एक्सपोर्ट पूरा नहीं हुआ। आपके अकाउंट की जानकारी जोड़ने के लिए कनेक्शन चाहिए। कनेक्ट होने पर फिर से कोशिश करें।';

  @override
  String get export_shareText => 'मेरा Aura डेटा';

  @override
  String get export_hTitle => 'आपका Aura डेटा';

  @override
  String export_hExported(String date) {
    return '$date को बनाई गई';
  }

  @override
  String get export_hCheckIns => 'चेक-इन';

  @override
  String get export_hHabits => 'आदतें';

  @override
  String get export_hCapsules => 'कैप्सूल';

  @override
  String get export_hAccount => 'अकाउंट';

  @override
  String get export_hReflections => 'आपकी दिल की बातें';

  @override
  String get export_hSanctuary => 'सुकून';

  @override
  String get export_sealed => 'सील है';

  @override
  String get export_voiceNote => 'वॉइस नोट';

  @override
  String get export_nothing => 'यहाँ अभी कुछ नहीं है।';

  @override
  String get flows_startOverTitle => 'फिर से शुरू करें?';

  @override
  String get flows_startOverBody => 'अब तक जो चुना और लिखा है, वह हट जाएगा।';

  @override
  String get flows_startOver => 'फिर से शुरू करें';

  @override
  String get closed_title => 'यह अकाउंट बंद है';

  @override
  String get closed_body =>
      'Aura के नियम तोड़ने की वजह से यह अकाउंट बंद किया गया।';

  @override
  String get closed_review =>
      'अगर आपको लगता है कि यह गलती है, तो रिव्यू माँगा जा सकता है। हम 7 दिनों के अंदर जवाब देते हैं।';

  @override
  String get closed_askReview => 'रिव्यू माँगें';

  @override
  String get closed_reviewSubject => 'बंद अकाउंट का रिव्यू';

  @override
  String get closed_deleteNote =>
      'अपना अकाउंट और उसमें मौजूद सब कुछ अब भी डिलीट किया जा सकता है।';

  @override
  String get closed_signOutNote =>
      'साइन आउट करने से यह अकाउंट इस फ़ोन से हट जाएगा।';

  @override
  String get notif_roomsPoolBanner => 'हिंदी और हिंग्लिश रूम अब खुल गए हैं।';

  @override
  String get notif_roomsPoolAction => 'रूम देखें';

  @override
  String get notif_channelRooms => 'रूम और Lantern Hour';

  @override
  String get notif_channelRoomsDescription =>
      'Lantern Hour, आपके रूम से अपनापन, और वे रूम जिनके बारे में आपने पूछा।';

  @override
  String get grievance_title => 'शिकायत अधिकारी से संपर्क करें';

  @override
  String get grievance_intro =>
      'किसी शिकायत, परेशान करने वाले कंटेंट, आपके डेटा, या आपके अकाउंट पर लिए गए किसी फ़ैसले के बारे में हमें बताएँ। आपको तुरंत एक टिकट नंबर मिलेगा।';

  @override
  String grievance_introNamed(String name) {
    return '$name Aura के शिकायत अधिकारी हैं। किसी शिकायत, परेशान करने वाले कंटेंट, आपके डेटा, या आपके अकाउंट पर लिए गए किसी फ़ैसले के बारे में हमें बताएँ। आपको तुरंत एक टिकट नंबर मिलेगा।';
  }

  @override
  String get grievance_categoryTitle => 'यह किस बारे में है?';

  @override
  String get grievance_catGeneral => 'किसी की पोस्ट या बर्ताव';

  @override
  String get grievance_catUnlawful => 'ऐसा कंटेंट जो गैरकानूनी हो सकता है';

  @override
  String get grievance_catNudity =>
      'नग्नता, यौन कंटेंट या बच्चों के यौन शोषण से जुड़ा कंटेंट';

  @override
  String get grievance_catNcii => 'बिना सहमति के शेयर की गई निजी तस्वीरें';

  @override
  String get grievance_catData => 'मेरा डेटा या मेरा अकाउंट';

  @override
  String get grievance_catAppeal => 'किसी फ़ैसले पर दोबारा विचार का अनुरोध';

  @override
  String get grievance_descriptionLabel => 'क्या हुआ';

  @override
  String get grievance_descriptionHint => 'कुछ वाक्य काफ़ी हैं।';

  @override
  String get grievance_appealHint =>
      'कौन-सा फ़ैसला, और उसे दोबारा क्यों देखा जाए।';

  @override
  String get grievance_whereLabel => 'कहाँ? (वैकल्पिक)';

  @override
  String get grievance_whereHint => 'जैसे: कोई रूम, कोई दिल की बात, या लगभग कब';

  @override
  String get grievance_emailLabel => 'आपका ईमेल';

  @override
  String get grievance_emailHelp =>
      'पावती और हमारा जवाब यहीं भेजा जाएगा। इसे कोई और नहीं देखता।';

  @override
  String get grievance_nameLabel => 'आपका नाम (वैकल्पिक)';

  @override
  String get grievance_send => 'भेजें';

  @override
  String get grievance_timelines =>
      'हम 24 घंटे के अंदर पावती देते हैं और 7 दिनों के अंदर समाधान करते हैं। नग्नता, बच्चों से जुड़े यौन कंटेंट और बिना सहमति शेयर की गई निजी तस्वीरों पर 2 घंटे के अंदर कार्रवाई होती है।';

  @override
  String get grievance_offline =>
      'इसके लिए कनेक्शन चाहिए। आपने जो लिखा है, वह यहीं है।';

  @override
  String get grievance_rateLimited =>
      'पिछले एक घंटे में यहाँ से बहुत सारे संदेश आए हैं। आपने जो लिखा है, वह यहीं है; कृपया थोड़ी देर बाद फिर कोशिश करें।';

  @override
  String get grievance_checkFields =>
      'कृपया ईमेल पता जाँचें और थोड़ा और विवरण लिखें (कम से कम 10 अक्षर)।';

  @override
  String get grievance_failed =>
      'यह नहीं जा पाया। आपने जो लिखा है, वह यहीं है। फिर से कोशिश करें?';

  @override
  String get grievance_noApi =>
      'इस वर्ज़न में यह फ़ॉर्म उपलब्ध नहीं है। शिकायत अधिकारी को ईमेल से लिखा जा सकता है।';

  @override
  String get grievance_sentTitle => 'मिल गया';

  @override
  String grievance_ticket(String ticket) {
    return 'आपका टिकट: $ticket';
  }

  @override
  String grievance_sentBody(String date, String email) {
    return 'हम $date तक जवाब देंगे। इस पावती की एक कॉपी $email पर भेजी जा रही है।';
  }

  @override
  String get grievance_gac =>
      'अगर जवाब से संतुष्टि न हो, तो 30 दिनों के अंदर gac.gov.in पर Grievance Appellate Committee में अपील की जा सकती है।';

  @override
  String get set_grievanceForm => 'शिकायत अधिकारी को लिखें';

  @override
  String get set_grievanceFormNote => 'ऐप में ही, तुरंत टिकट नंबर के साथ';

  @override
  String get closed_askReviewInApp => 'ऐप में ही रिव्यू माँगें';

  @override
  String get closed_askReviewInAppNote => 'आपको तुरंत एक टिकट नंबर मिलेगा।';

  @override
  String home_stageProgress(String stage, String next, int count, int target) {
    return '$stage, $next की ओर $target में से $count Starlight';
  }

  @override
  String home_constellationProgress(String stage, int count, int max) {
    return '$stage, आपके तारामंडल में $max में से $count तारे';
  }

  @override
  String get home_glowTitle => 'आपकी चमक';

  @override
  String get home_restDaysHint => 'जानें कि आराम के दिन कैसे काम करते हैं';

  @override
  String get home_restInfoTitle => 'आराम के दिन';

  @override
  String home_restInfoEarn(int days, int max) {
    return 'हर $days चमक वाले दिनों पर एक आराम का दिन मिलता है। $max तक जमा रखे जा सकते हैं।';
  }

  @override
  String get home_restInfoUse =>
      'छोटे ब्रेक के दौरान ये उन दिनों को अपने-आप भर देते हैं। आपको कुछ नहीं करना है।';

  @override
  String get home_restInfoKeep => 'आपका हर चमक वाला दिन आपके साथ रहता है।';

  @override
  String home_checkInsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count चेक-इन',
      one: 'आज 1 चेक-इन',
    );
    return '$_temp0';
  }

  @override
  String get home_seeAll => 'सब देखें';

  @override
  String get home_yourCheckIns => 'आपके चेक-इन';

  @override
  String get home_syncExplainIdle =>
      'सब कुछ इस फ़ोन पर और आपके अकाउंट में सेव है।';

  @override
  String get home_syncExplainPending =>
      'ये इस फ़ोन पर सुरक्षित हैं और अपने-आप सिंक हो जाएँगे।';

  @override
  String get home_syncExplainOffline =>
      'आप ऑफ़लाइन हैं। सब कुछ इस फ़ोन पर सुरक्षित है और फिर से ऑनलाइन होने पर सिंक हो जाएगा।';

  @override
  String get home_syncExplainSignedOut =>
      'आपने साइन इन नहीं किया है, इसलिए अभी सब कुछ इसी फ़ोन पर रहेगा।';

  @override
  String get home_syncExplainUnavailable =>
      'यह वर्ज़न सब कुछ इसी फ़ोन पर रखता है।';

  @override
  String get home_syncNow => 'अभी सिंक करें';

  @override
  String get home_syncing => 'सिंक हो रहा है…';

  @override
  String get home_syncHint => 'सिंक की जानकारी देखें';

  @override
  String get habits_edit => 'एडिट करें';

  @override
  String get habits_editSemantic => 'छोटे काम एडिट करें';

  @override
  String get habits_sheetTitle => 'आपके छोटे काम';

  @override
  String get habits_sheetBody =>
      'चुनें कि होम पर क्या दिखे। चेक-इन से आपका Aura हर हाल में बढ़ता है।';

  @override
  String get habits_presetsTitle => 'सुझाव';

  @override
  String get habits_customTitle => 'आपके अपने';

  @override
  String get habits_addLabel => 'अपना जोड़ें';

  @override
  String get habits_addHint => 'जैसे, पौधों को पानी देना';

  @override
  String get habits_add => 'जोड़ें';

  @override
  String habits_limit(int count) {
    return 'आपके पास $count कस्टम आदतें हैं। नई जोड़ने के लिए किसी एक को बदलें।';
  }

  @override
  String get habits_saveFailed => 'यह सेव नहीं हुआ। फिर से कोशिश करें?';

  @override
  String habits_remove(String name) {
    return '$name हटाएँ';
  }

  @override
  String habits_removeTitle(String name) {
    return '$name हटाएँ?';
  }

  @override
  String get habits_removeBody =>
      'यह आपकी लिस्ट से हट जाएगा। इससे मिले Starlight और चमक वाले दिन बने रहेंगे।';

  @override
  String get habits_removeConfirm => 'हटाएँ';

  @override
  String get habits_empty => 'शुरू करने के लिए एक छोटा काम चुनें।';

  @override
  String get help_groundingProgress => 'इस एक मिनट में अब तक';

  @override
  String get help_progressBegun => 'अभी शुरू हुआ';

  @override
  String get help_progressHalf => 'लगभग आधा';

  @override
  String get help_progressNearly => 'लगभग पूरा';

  @override
  String get help_progressDone => 'पूरा हुआ';

  @override
  String help_breatheLogged(String habit) {
    return '$habit आज के लिए पूरा मार्क कर दिया गया है।';
  }

  @override
  String get insights_title => 'Aura Sky';

  @override
  String get insights_private =>
      'आपका आसमान सिर्फ़ आपको दिखता है। यह इसी फ़ोन पर तैयार होता है।';

  @override
  String get insights_empty => 'हर चेक-इन के साथ आपका आसमान भरता जाएगा।';

  @override
  String get insights_allCheckIns => 'सभी चेक-इन';

  @override
  String get insights_viewMonth => 'महीना';

  @override
  String get insights_viewYear => 'साल';

  @override
  String get insights_prevMonth => 'पिछला महीना';

  @override
  String get insights_nextMonth => 'अगला महीना';

  @override
  String get insights_prevYear => 'पिछला साल';

  @override
  String get insights_nextYear => 'अगला साल';

  @override
  String insights_dayEmpty(String date) {
    return '$date, शांत आसमान';
  }

  @override
  String insights_dayRest(String date) {
    return '$date, आराम का दिन';
  }

  @override
  String insights_daySingle(String date, String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$date, $quadrant, $_temp0';
  }

  @override
  String insights_dayPair(String date, String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$date, $first और $second बराबर, $_temp0';
  }

  @override
  String insights_dayMixed(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$date, सब बराबर-बराबर, $_temp0';
  }

  @override
  String get insights_dayHint => 'इस दिन के चेक-इन दिखाता है';

  @override
  String get insights_dayNone => 'इस दिन कुछ दर्ज नहीं हुआ। आसमान बस शांत था।';

  @override
  String insights_monthSemantic(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन चेक-इन किया',
      one: '1 दिन चेक-इन किया',
      zero: 'शांत आसमान',
    );
    return '$month, $_temp0';
  }

  @override
  String get insights_legendRest => 'आराम का दिन';

  @override
  String get insights_legendMixed => 'मिला-जुला दिन';

  @override
  String get insights_patternsTitle => 'पैटर्न';

  @override
  String get insights_patternsLast30 => 'आपके पिछले 30 दिनों से';

  @override
  String insights_patternsNeedCheckIns(int count) {
    return '7 चेक-इन के बाद पैटर्न दिखेंगे ($count/7)';
  }

  @override
  String insights_patternsNeedDays(int count) {
    return '5 अलग-अलग दिनों पर चेक-इन के बाद पैटर्न दिखेंगे ($count/5)';
  }

  @override
  String get insights_patternsNone =>
      'अभी कोई साफ़ पैटर्न नहीं है। आपका आसमान यहीं है।';

  @override
  String insights_patternTag(String tag, String quadrant) {
    return 'जब आपने $tag टैग किया, तब $quadrant ज़्यादा दिखा।';
  }

  @override
  String insights_patternHabit(String habit, String quadrant) {
    return '$habit वाले दिनों में $quadrant वाले चेक-इन ज़्यादा रहे।';
  }

  @override
  String insights_patternMorning(String quadrant) {
    return 'सुबह के समय $quadrant वाले चेक-इन ज़्यादा रहे।';
  }

  @override
  String insights_patternAfternoon(String quadrant) {
    return 'दोपहर में $quadrant वाले चेक-इन ज़्यादा रहे।';
  }

  @override
  String insights_patternEvening(String quadrant) {
    return 'शाम को $quadrant वाले चेक-इन ज़्यादा रहे।';
  }

  @override
  String insights_patternNight(String quadrant) {
    return 'रात में $quadrant वाले चेक-इन ज़्यादा रहे।';
  }

  @override
  String insights_patternMix(String quadrant) {
    return 'आपके आसमान में $quadrant वाले चेक-इन सबसे ज़्यादा रहे।';
  }

  @override
  String get insights_plusBadge => 'Aura Plus';

  @override
  String get insights_rangeLocked =>
      'कोई भी समय-सीमा और मूड के साथ आदतें Aura Plus में मिलती हैं। आपका आसमान और 30 दिन के पैटर्न हमेशा मुफ़्त हैं।';

  @override
  String get insights_rangeLabel => 'इस अवधि के पैटर्न';

  @override
  String get insights_range7 => '7 दिन';

  @override
  String get insights_range30 => '30 दिन';

  @override
  String get insights_range90 => '90 दिन';

  @override
  String get insights_range365 => '1 साल';

  @override
  String get insights_rangeAll => 'शुरू से अब तक';

  @override
  String get insights_weeklyTitle => 'आपके पिछले हफ़्ते से';

  @override
  String get insights_weeklyHide => 'इस हफ़्ते के लिए छिपाएँ';

  @override
  String get insights_careTitle => 'पिछले दो हफ़्ते भारी रहे हैं';

  @override
  String get insights_careBody =>
      'यह बोझ अकेले उठाना ज़रूरी नहीं। जब भी मन हो, मदद और एक रूम यहीं हैं।';

  @override
  String get insights_careSupport => 'मदद देखें';

  @override
  String get insights_careRoom => 'एक रूम ढूँढें';

  @override
  String get insights_monthTitle => 'तारों में आपका महीना';

  @override
  String insights_monthCardBody(String month) {
    return 'आपके आसमान में $month';
  }

  @override
  String get insights_monthOpen => 'खोलें';

  @override
  String get insights_monthHide => 'छिपाएँ';

  @override
  String insights_monthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन चेक-इन किया',
      one: '1 दिन चेक-इन किया',
    );
    return '$_temp0';
  }

  @override
  String get insights_monthMixTitle => 'इस महीने आपका आसमान';

  @override
  String insights_monthMixItem(String quadrant, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$quadrant: $_temp0';
  }

  @override
  String insights_monthSkySemantic(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count तारों का आसमान',
      one: '1 तारे का आसमान',
    );
    return '$_temp0, $month के हर चेक-इन के लिए एक तारा';
  }

  @override
  String get insights_deeperTitle => 'महीने की गहरी झलक';

  @override
  String get insights_deeperLocked =>
      'पूरे महीने के पैटर्न, मूड के साथ आदतें, Aura Plus में मिलते हैं।';

  @override
  String get insights_deeperNone => 'इस महीने कोई साफ़ पैटर्न नहीं।';

  @override
  String get insights_statsTitle => 'शुरू से अब तक';

  @override
  String insights_statsCheckIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$_temp0';
  }

  @override
  String insights_statsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपके आसमान में $count दिन',
      one: 'आपके आसमान में 1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get insights_lookBackTitle => 'पीछे देखें';

  @override
  String get insights_lookBackTileBody =>
      'कुछ समय पहले के इसी हफ़्ते का आपका आसमान। जब मन हो, तब खोलें।';

  @override
  String get insights_lookBackIntro =>
      'एक महीने, छह महीने और एक साल पहले का यही हफ़्ता। इसे सिर्फ़ आप देख सकते हैं। यह इसी फ़ोन पर रहता है।';

  @override
  String get insights_lookBackMonth => 'एक महीने पहले';

  @override
  String get insights_lookBackSixMonths => 'छह महीने पहले';

  @override
  String get insights_lookBackYear => 'एक साल पहले';

  @override
  String insights_lookBackWeekOf(String date) {
    return '$date वाला हफ़्ता';
  }

  @override
  String get insights_lookBackEmpty =>
      'अभी पीछे देखने को कुछ नहीं है। जिन हफ़्तों में आपने चेक-इन किया, वे यहाँ दिखेंगे।';

  @override
  String get insights_lookBackClosed => 'पीछे देखें अभी के लिए बंद है।';

  @override
  String get insights_lookBackShowNote => 'नोट दिखाएँ';

  @override
  String get insights_lookBackShowVoice => 'वॉइस नोट दिखाएँ';

  @override
  String get insights_lookBackHideNote => 'छिपाएँ';

  @override
  String get insights_lookBackSettingsHint =>
      'सेटिंग्स में \'पीछे देखें\' बंद कर सकते हैं।';

  @override
  String get insights_lookBackSetting => 'Aura Sky में पीछे देखें';

  @override
  String get insights_lookBackSettingNote =>
      'आपके आसमान के पिछले हफ़्ते, सिर्फ़ जब आप खोलें। कभी नोटिफ़िकेशन बनकर नहीं आते।';

  @override
  String insights_statsLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'चमक का सबसे लंबा सिलसिला · $count दिन',
      one: 'चमक का सबसे लंबा सिलसिला · 1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get keepsakes_title => 'यादगारें';

  @override
  String get keepsakes_intro => 'छोटे पल, सहेजे हुए। ये सिर्फ़ आपको दिखते हैं।';

  @override
  String get keepsakes_empty =>
      'यहाँ अभी कुछ नहीं है। छोटे-छोटे पलों से यादगारें अपने आप आती हैं।';

  @override
  String get keepsakes_privateNote =>
      'यादगारें किसी और को कभी नहीं दिखतीं। कोई यादगार आपके फ़ोन से बाहर तभी जाती है जब आप उसका कार्ड शेयर करें।';

  @override
  String keepsakes_keptOn(String date) {
    return '$date को सहेजा';
  }

  @override
  String keepsakes_sealSemantic(String line, String date) {
    return '$line, $date को सहेजा';
  }

  @override
  String get keepsakes_shareThis => 'यह कार्ड शेयर करें';

  @override
  String get keepsakes_shareAura => 'अपना Aura शेयर करें';

  @override
  String get keepsakes_offline =>
      'आपके फिर से ऑनलाइन आने पर नई यादगारें आएँगी।';

  @override
  String get keepsakes_entry => 'आपकी यादगारें';

  @override
  String get keepsakes_entryNote => 'छोटे पलों की मुहरें, सिर्फ़ आपके लिए।';

  @override
  String get keepsakes_newTitle => 'एक नई यादगार';

  @override
  String get keepsakes_newSeveral => 'नई यादगारें आपके बक्से में हैं।';

  @override
  String get keepsakes_newOpen => 'अपनी यादगारें देखें';

  @override
  String get keepsakes_hideCard => 'यह कार्ड छिपाएँ';

  @override
  String get keepsake_capsuleSealedFirst =>
      'मैंने आगे के अपने लिए एक नोट सील किया';

  @override
  String get keepsake_capsuleOpenedFirst =>
      'मैंने बीते कल के अपने से आया कैप्सूल खोला';

  @override
  String keepsake_glowDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'चमक के $days दिन',
      one: 'चमक का 1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get keepsake_ripplesFirst => 'पहली बार सबके साथ मिलकर साँस ली';

  @override
  String get keepsake_lanternFirst => 'मेरा पहला Lantern Hour';

  @override
  String keepsake_lanternHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lantern Hour की $count शामें',
      one: 'Lantern Hour की 1 शाम',
    );
    return '$_temp0';
  }

  @override
  String keepsake_sanctuaryMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'सुकून में $minutes शांत मिनट',
      one: 'सुकून में 1 शांत मिनट',
    );
    return '$_temp0';
  }

  @override
  String share_evolutionLine(String stage) {
    return 'मेरा Aura $stage तक पहुँचा';
  }

  @override
  String share_anniversaryLine(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years साल पहले एक कैप्सूल सील किया',
      one: '1 साल पहले एक कैप्सूल सील किया',
    );
    return '$_temp0';
  }

  @override
  String get share_storeLine => 'Aura · App Store और Google Play पर';

  @override
  String share_text(String link) {
    return 'Aura, अपने मन का हाल देखने की एक शांत जगह: $link';
  }

  @override
  String get share_sheetTitle => 'एक कार्ड शेयर करें';

  @override
  String get share_sheetNote =>
      'कार्ड पर आपका Aura और यह पल ही दिखता है। आपके मूड, नोट्स या नाम कभी नहीं।';

  @override
  String get share_button => 'शेयर करें';

  @override
  String get share_failed => 'अभी कार्ड नहीं बन पाया। कृपया फिर से कोशिश करें।';

  @override
  String share_cardSemantic(String line, String stage) {
    return 'शेयर करने का कार्ड: $line। $stage चरण में आपका Aura।';
  }

  @override
  String share_promptEvolution(String stage) {
    return 'आपका Aura $stage तक पहुँचा। इसका कार्ड शेयर करें?';
  }

  @override
  String share_promptGlow(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'चमक के $days दिन।',
      one: 'चमक का 1 दिन।',
    );
    return '$_temp0 इसका कार्ड शेयर करें?';
  }

  @override
  String share_promptAnniversary(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: 'आपने अपना पहला कैप्सूल $years साल पहले सील किया था।',
      one: 'आपने अपना पहला कैप्सूल एक साल पहले सील किया था।',
    );
    return '$_temp0 इसका कार्ड शेयर करें?';
  }

  @override
  String get rooms_lanternTitle => 'आज रात की लालटेन';

  @override
  String get rooms_lanternStart => 'यहाँ हर भाव थोड़ी रोशनी जोड़ता है।';

  @override
  String get rooms_lanternGlowing => 'यहाँ हर भाव के साथ यह और रोशन होती है।';

  @override
  String get rooms_lanternFull => 'सबने मिलकर, पूरी रोशन की।';

  @override
  String get rooms_lanternKept => 'आज रात की लालटेन इतनी रोशन हुई।';

  @override
  String rooms_lanternSemantic(int level, int max) {
    return 'आज रात की लालटेन, $max में से $level रोशनियाँ जलीं';
  }

  @override
  String get rooms_lanternRise =>
      'लालटेन पूरी रोशन हो गई। लालटेनें साथ मिलकर ऊपर उठती हैं।';

  @override
  String get rooms_intentionTitle => 'आज रात का इरादा';

  @override
  String get rooms_intentionHold => 'आज रात इसे थामें';

  @override
  String get rooms_intentionHolding => 'आज रात यह इरादा आपके साथ है';

  @override
  String rooms_intentionHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज रात $count ने इसे थामा है',
      one: 'आज रात 1 ने इसे थामा है',
      zero: 'एक टैप से थामें',
    );
    return '$_temp0';
  }

  @override
  String rooms_intentionHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज रात $count ने इसे थामा',
      one: 'आज रात 1 ने इसे थामा',
      zero: 'अगले Lantern Hour तक आराम',
    );
    return '$_temp0';
  }

  @override
  String get rooms_intentionPrivate =>
      'इसे किसने थामा, यह किसी को नहीं दिखता, और कल इसके बारे में कोई नहीं पूछेगा।';

  @override
  String get rooms_intentionFailed =>
      'यह हो नहीं पाया। कृपया फिर से कोशिश करें।';

  @override
  String get rooms_intention_sleep_before_midnight => 'आधी रात से पहले सोना';

  @override
  String get rooms_intention_gentle_with_myself => 'आज रात खुद से नरमी';

  @override
  String get rooms_intention_phone_down_10 => '10 मिनट फ़ोन से दूरी';

  @override
  String get rooms_intention_water_before_bed => 'सोने से पहले एक गिलास पानी';

  @override
  String get rooms_intention_one_kind_thought =>
      'आज के बारे में एक अच्छा ख्याल';

  @override
  String get rooms_intention_slow_breaths => 'सोने से पहले तीन धीमी साँसें';

  @override
  String get notif_reminderBanner =>
      'आपके लिए सुकून का एक मिनट। आज कैसा लग रहा है?';

  @override
  String get notif_reminderAction => 'चेक-इन करें';

  @override
  String get notif_capsuleBanner => 'आपने जो सील किया था, वह अब खुल सकता है।';

  @override
  String get notif_capsuleAction => 'देखें';

  @override
  String get notif_channelReminders => 'रिमाइंडर';

  @override
  String get notif_channelRemindersDescription =>
      'आपके चेक-इन, सोने से पहले के सुकून और आदत के रिमाइंडर।';

  @override
  String get set_notifications => 'नोटिफ़िकेशन';

  @override
  String get set_notifMaster => 'Aura के नोटिफ़िकेशन';

  @override
  String get set_notifMasterNote =>
      'दिन में ज़्यादा से ज़्यादा दो। आपकी लॉक स्क्रीन पर कभी नहीं दिखेगा कि आपको कैसा लग रहा है।';

  @override
  String get set_notifReminder => 'रोज़ का चेक-इन रिमाइंडर';

  @override
  String set_notifReminderNote(String time) {
    return 'दिन में एक हल्की-सी याद, $time पर। चेक-इन हो जाने पर नहीं आती।';
  }

  @override
  String get set_notifReminderOffNote =>
      'बंद है। दिन में एक हल्की-सी याद के लिए इसे चालू करें।';

  @override
  String get set_notifReminderTime => 'रिमाइंडर का समय';

  @override
  String get set_notifCapsule => 'कोई कैप्सूल खुलने के लिए तैयार है';

  @override
  String get set_notifCapsuleNote =>
      'उस दिन, जो आपने अपनी सील की हुई चीज़ के लिए चुना था।';

  @override
  String set_notifQuietNote(String start, String end) {
    return 'शांत समय: $start–$end के बीच कुछ नहीं भेजा जाता।';
  }

  @override
  String get set_notifQuietFrom => 'शांत समय शुरू';

  @override
  String get set_notifQuietUntil => 'शांत समय ख़त्म';

  @override
  String get set_notifDiscreet => 'गोपनीय मोड';

  @override
  String get set_notifDiscreetNote =>
      'हर नोटिफ़िकेशन में बस “Aura · आपके लिए एक हल्का-सा अपडेट है” लिखा होता है।';

  @override
  String get set_notifOffNote =>
      'इस फ़ोन पर Aura के नोटिफ़िकेशन बंद हैं। चालू होने पर यहाँ की आपकी पसंद लागू रहेगी।';

  @override
  String get set_notifTurnOn => 'चालू करें';

  @override
  String get set_notifOpenSettings => 'फ़ोन की सेटिंग्स खोलें';

  @override
  String get set_notifQuietConfirmTitle => 'यह समय आपके शांत समय में आता है';

  @override
  String set_notifQuietConfirmBody(String start, String end, String time) {
    return 'Aura $start–$end तक चुप रहता है। फिर भी $time पर रिमाइंडर भेजें?';
  }

  @override
  String get set_notifQuietConfirmYes => 'फिर भी भेजें';

  @override
  String get set_notifQuietConfirmNo => 'शांत ही रखें';

  @override
  String push_timeRow(String time) {
    return 'हर शाम $time पर';
  }

  @override
  String get push_changeTime => 'समय बदलें';

  @override
  String get push_discreet => 'इन्हें गोपनीय रखें';

  @override
  String get notif_gesturesBanner => 'आपके रूम के लोगों ने आपको अपनापन भेजा।';

  @override
  String get notif_gesturesAction => 'रूम में जाएँ';

  @override
  String get notif_lanternBanner =>
      'Lantern Hour शुरू हो गया है। आज रात और लोग भी यहाँ हैं।';

  @override
  String get notif_lanternAction => 'रूम देखें';

  @override
  String get notif_windDownBanner =>
      'सोने से पहले सुकून के कुछ पल, जब भी मन हो।';

  @override
  String get notif_windDownAction => 'आवाज़ें देखें';

  @override
  String get notif_habitBanner => 'एक-दो छोटी आदतें, जब भी आप तैयार हों।';

  @override
  String get notif_habitAction => 'आदतें देखें';

  @override
  String get notif_crisisFollowUp =>
      'बस हालचाल पूछ रहे हैं। आज जैसा भी लग रहा हो, मदद बस एक टैप दूर है।';

  @override
  String get notif_crisisFollowUpDismiss => 'बंद करें';

  @override
  String get set_notifGestures => 'आपके रूम से अपनापन';

  @override
  String get set_notifGesturesNote =>
      'जब आपके रूम के लोग आपको कोई भाव भेजें। दिन में ज़्यादा से ज़्यादा एक।';

  @override
  String get set_notifLantern => 'Lantern Hour';

  @override
  String get set_notifLanternNote =>
      'जब आपकी शाम में Lantern Hour शुरू हो। अगर उस दिन कोई रूम पहले ही देखा जा चुका है, तो नहीं।';

  @override
  String get set_notifWindDown => 'सोने से पहले के सुकून का रिमाइंडर';

  @override
  String set_notifWindDownNote(String time) {
    return '$time पर सुकून के कुछ मिनट। अगर उस शाम सुकून टैब इस्तेमाल हो चुका है, तो नहीं भेजा जाता।';
  }

  @override
  String get set_notifWindDownOffNote =>
      'बंद है। सोने से पहले एक हल्की-सी याद के लिए समय चुनें।';

  @override
  String get set_notifWindDownTime => 'सोने से पहले के सुकून का समय';

  @override
  String get set_notifWelcomeBack => 'कुछ समय बाद';

  @override
  String get set_notifWelcomeBackNote =>
      'एक हफ़्ते या उससे ज़्यादा की दूरी के बाद, एक हल्का-सा नमस्ते। ज़्यादा से ज़्यादा दो बार।';

  @override
  String get set_notifHabits => 'आदतों की याद';

  @override
  String get set_notifHabitsNote =>
      'होम पर किसी भी आदत के लिए, आपके चुने समय पर एक छोटी-सी याद। दिन में ज़्यादा से ज़्यादा एक।';

  @override
  String get set_notifHabitsNone => 'याद पाने के लिए होम पर कोई आदत जोड़ें।';

  @override
  String get set_notifHabitOff => 'बंद';

  @override
  String get set_notifHabitQuiet =>
      'यह आपके शांत समय में है, इसलिए नहीं भेजा जाएगा।';

  @override
  String get set_notifHabitChange => 'समय बदलें';

  @override
  String get set_notifHabitTurnOff => 'बंद करें';

  @override
  String sounds_windDownRemind(String time) {
    return '$time पर याद दिलाएँ';
  }

  @override
  String sounds_windDownReminderOn(String time) {
    return '$time पर एक हल्की-सी याद आएगी।';
  }

  @override
  String get sounds_windDownReminderOff => 'बंद करें';

  @override
  String get onb_trustTitle => 'शुरू करने से पहले';

  @override
  String get onb_trustBody =>
      'Aura आपका खयाल कैसे रखता है, इसके बारे में कुछ बातें।';

  @override
  String get onb_trustPrivateTitle => 'शुरू से ही प्राइवेट';

  @override
  String get onb_trustPrivateBody =>
      'आपके चेक-इन और नोट सिर्फ़ आपके हैं। नोट एन्क्रिप्ट रहते हैं, और जब तक आप शेयर करना न चुनें, आपका हाल कोई और नहीं देख सकता।';

  @override
  String get onb_trustCareTitle => 'वेलनेस सपोर्ट, थेरेपी नहीं';

  @override
  String get onb_trustCareBody =>
      'Aura आपको यह ध्यान देने में मदद करता है कि आपका मन कैसा है। यह न कोई डायग्नोसिस करता है, न इलाज।';

  @override
  String get onb_trustHelpTitle => 'मदद हमेशा बस एक टैप दूर';

  @override
  String onb_trustHelpBody(String button) {
    return 'हेल्पलाइन पर कॉल करने या एक मिनट साँस पर ध्यान देने के लिए कभी भी “$button” टैप करें।';
  }

  @override
  String get onb_dobYearType => 'साल टाइप करें';

  @override
  String get onb_dobYearNoMatch =>
      'लिस्ट में इससे मिलता कोई साल नहीं है। एक बार देख लें?';

  @override
  String get onb_blockedWrongDate => 'गलत तारीख डाल दी?';

  @override
  String get onb_blockedWrongDateHint => 'आपका ईमेल ऐप खुलेगा';

  @override
  String get onb_blockedMailSubject => 'Aura: मैंने गलत तारीख डाल दी';

  @override
  String onb_blockedMailFailed(String email) {
    return 'ईमेल ऐप नहीं खुल पाया। आप चाहें तो हमें $email पर लिखें।';
  }

  @override
  String get plus_title => 'Aura Plus';

  @override
  String get plus_intro =>
      'जो आपके पास पहले से है, उसी का और ज़्यादा। जो कुछ भी आपको अच्छा महसूस करने में मदद करता है, वह मुफ़्त ही रहेगा।';

  @override
  String get plus_addsTitle => 'Plus के साथ मिलता है';

  @override
  String get plus_addCapsules => 'अनलिमिटेड मूड-ट्रिगर कैप्सूल';

  @override
  String get plus_addVoice => 'कैप्सूल में 10 मिनट तक वॉइस';

  @override
  String get plus_addInsights =>
      'और गहरी समझ: कोई भी अवधि, आदत × मूड, सितारों में महीने की गहरी झलक';

  @override
  String get plus_addSounds => 'ज़्यादा आवाज़ें और दो Plus आसमान';

  @override
  String get plus_freeTitle => 'हमेशा मुफ़्त';

  @override
  String get plus_freeBody =>
      'चेक-इन, आदतें, आराम के दिन, रूम, Breath Ripples, तारीख वाले कैप्सूल, संकट में मदद, साँस लें, ग्राउंडिंग, आज का मिनट, हर बेसिक आवाज़ और रात का सोने से पहले का सुकून।';

  @override
  String get plus_planMonthly => 'मासिक';

  @override
  String get plus_planAnnual => 'सालाना';

  @override
  String plus_trialLineMonthly(String price) {
    return '1 महीना मुफ़्त, फिर $price/महीना';
  }

  @override
  String plus_trialLineAnnual(String price) {
    return '1 महीना मुफ़्त, फिर $price/साल';
  }

  @override
  String plus_priceMonthly(String price) {
    return '$price/महीना';
  }

  @override
  String plus_priceAnnual(String price) {
    return '$price/साल';
  }

  @override
  String plus_trialEnds(String date) {
    return 'आपका मुफ़्त महीना $date को खत्म होगा। उससे पहले रद्द न किया गया, तो पहला चार्ज $date को लगेगा।';
  }

  @override
  String plus_renews(String store) {
    return 'रद्द करने तक यह अपने-आप रिन्यू होता रहेगा। पेमेंट आपके $store अकाउंट से होगा।';
  }

  @override
  String get plus_cancelApple =>
      'रद्द करने के लिए: iPhone Settings › आपका नाम › Subscriptions › Aura. किसी भी चार्ज से कम से कम एक दिन पहले रद्द करें।';

  @override
  String get plus_cancelGoogle =>
      'रद्द करने के लिए: Play Store › आपकी प्रोफ़ाइल › Payments & subscriptions › Subscriptions › Aura.';

  @override
  String get plus_storeApple => 'App Store';

  @override
  String get plus_storeGoogle => 'Google Play';

  @override
  String get plus_startTrial => 'मुफ़्त महीना शुरू करें';

  @override
  String get plus_subscribe => 'सब्सक्राइब करें';

  @override
  String get plus_restore => 'खरीदारी रिस्टोर करें';

  @override
  String get plus_manage => 'स्टोर में मैनेज करें';

  @override
  String get plus_loadingPrices => 'स्टोर से कीमतें लोड हो रही हैं';

  @override
  String get plus_storeUnavailable =>
      'अभी स्टोर तक नहीं पहुँचा जा पा रहा। कोई चार्ज नहीं लिया गया।';

  @override
  String get plus_retry => 'फिर से कोशिश करें';

  @override
  String get plus_confirming => 'स्टोर से पुष्टि हो रही है…';

  @override
  String get plus_confirmingLater =>
      'आपकी रिक्वेस्ट स्टोर तक पहुँच गई है। पुष्टि होते ही Plus खुल जाएगा। इसे बंद किया जा सकता है।';

  @override
  String get plus_validationFailed =>
      'अभी इसकी पुष्टि नहीं हो पाई। अगर आपसे चार्ज लिया गया है, तो वह सुरक्षित है। हम जाँच करते रहेंगे।';

  @override
  String get plus_pendingApproval =>
      'मंज़ूरी का इंतज़ार है। यह पूरा होने तक आपसे कोई चार्ज नहीं लिया जाएगा।';

  @override
  String get plus_declined =>
      'पेमेंट नहीं हो पाया। आपसे कोई चार्ज नहीं लिया गया।';

  @override
  String get plus_welcome => 'Aura Plus चालू हो गया है। शुक्रिया।';

  @override
  String get plus_ownedElsewhere =>
      'यह खरीदारी इस स्टोर अकाउंट पर किसी दूसरे Aura अकाउंट की है, इसलिए यह वहीं रहेगी।';

  @override
  String plus_restored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खरीदारियाँ रिस्टोर हुईं।',
      one: '1 खरीदारी रिस्टोर हुई।',
      zero: 'इस स्टोर अकाउंट पर रिस्टोर करने के लिए कुछ नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String get plus_lockedOnly => 'Aura Plus का हिस्सा';

  @override
  String get plus_about => 'Aura Plus के बारे में';

  @override
  String get plus_seePlus => 'Aura Plus देखें';

  @override
  String get plus_freePath => 'मुफ़्त रास्ता यहीं मौजूद है।';

  @override
  String get plus_explainerCapsules =>
      'मुफ़्त अकाउंट में 3 मूड कैप्सूल इंतज़ार में रखे जा सकते हैं। Aura Plus में जितने चाहें, उतने। तारीख वाले कैप्सूल हमेशा अनलिमिटेड हैं।';

  @override
  String get plus_explainerVoice =>
      'मुफ़्त Aura में कैप्सूल की वॉइस 2 मिनट पर रुक जाती है, Aura Plus के साथ 10 मिनट पर।';

  @override
  String get plus_explainerSounds =>
      'यह आवाज़ Aura Plus के साथ मिलती है। हर बेसिक आवाज़ और रात का सोने से पहले का सुकून मुफ़्त रहते हैं।';

  @override
  String get plus_explainerInsights =>
      'Aura Plus में कोई भी अवधि, आदत × मूड और महीने की गहरी झलक मिलती है। आपका आसमान और हिस्ट्री मुफ़्त रहते हैं।';

  @override
  String get plus_explainerSky => 'यह आसमान Aura Plus के साथ मिलता है।';

  @override
  String get plus_statusFree => 'अभी आपके पास मुफ़्त Aura है।';

  @override
  String plus_statusTrial(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन बाकी',
      one: '1 दिन बाकी',
      zero: 'आज खत्म',
    );
    return 'मुफ़्त महीना: $_temp0। पहला चार्ज $date को।';
  }

  @override
  String plus_statusTrialCancelled(String date) {
    return 'आपका मुफ़्त महीना $date तक चालू रहेगा। उसके बाद मुफ़्त Aura रहेगा, और आपका बनाया सब कुछ आपका ही रहेगा।';
  }

  @override
  String plus_statusActive(String date) {
    return 'Aura Plus $date को रिन्यू होगा।';
  }

  @override
  String plus_statusCancelled(String date) {
    return 'Aura Plus $date तक चालू रहेगा। आपसे दोबारा चार्ज नहीं लिया जाएगा।';
  }

  @override
  String get plus_statusGrace =>
      'स्टोर Aura Plus को रिन्यू नहीं कर पाया। जब तक स्टोर फिर से कोशिश कर रहा है, Plus चालू रहेगा।';

  @override
  String get plus_statusBillingRetry =>
      'स्टोर के रिन्यू कर पाने तक Aura Plus रुका हुआ है। आपका बनाया सब कुछ आपका ही रहेगा।';

  @override
  String get plus_statusExpired =>
      'Aura Plus खत्म हो गया है। आपका बनाया सब कुछ आपका ही रहेगा।';

  @override
  String get plus_statusRefunded =>
      'आपका रिफ़ंड हो गया है, इसलिए Aura Plus खत्म हो गया है। आपका बनाया सब कुछ आपका ही रहेगा।';

  @override
  String get plus_statusPending =>
      'स्टोर की पुष्टि का इंतज़ार है। यह पूरा होने तक आपसे कोई चार्ज नहीं लिया जाएगा।';

  @override
  String get plus_updatePayment => 'स्टोर में पेमेंट अपडेट करें';

  @override
  String get plus_turnBackOn => 'Plus फिर से चालू करें';

  @override
  String plus_managedElsewhere(String store) {
    return '$store पर खरीदा गया। इसे वहीं मैनेज करें।';
  }

  @override
  String get plus_notYet =>
      'Aura Plus जुड़ने के एक दिन बाद खुलता है। आपकी ज़रूरत की हर चीज़ पहले से मुफ़्त है।';

  @override
  String plus_cardTrialEnding(String date, String price) {
    return 'आपका मुफ़्त महीना $date को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus $price/महीना पर जारी रहेगा।';
  }

  @override
  String plus_cardTrialEndingYear(String date, String price) {
    return 'आपका मुफ़्त महीना $date को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus $price/साल पर जारी रहेगा।';
  }

  @override
  String plus_cardTrialEndingNoPrice(String date) {
    return 'आपका मुफ़्त महीना $date को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus जारी रहेगा।';
  }

  @override
  String get plus_cardKeep => 'Plus जारी रखें';

  @override
  String plus_cardTrialCancelled(String date) {
    return 'Plus $date तक चालू रहेगा। आपसे कोई चार्ज नहीं लिया जाएगा।';
  }

  @override
  String get plus_cardBillingIssue =>
      'आपका Aura Plus पेमेंट नहीं हो पाया। आपका बनाया सब कुछ सुरक्षित है।';

  @override
  String get plus_cardContinues => 'Aura Plus जारी है। शुक्रिया।';

  @override
  String get plus_dismiss => 'हटाएँ';

  @override
  String get plus_giftWarmTea => 'एक कप चाय';

  @override
  String get plus_giftComfortLantern => 'सुकून की लालटेन';

  @override
  String get plus_giftBouquet => 'हौसले का गुलदस्ता';

  @override
  String plus_giftReceived(String gift) {
    return 'यहाँ किसी की ओर से आपके लिए $gift।';
  }

  @override
  String plus_giftStardust(int count) {
    return '+$count Stardust';
  }

  @override
  String get plus_giftTitle => 'तोहफ़ा भेजें';

  @override
  String get plus_giftBody =>
      'उन्हें “यहाँ किसी की ओर से आपके लिए एक तोहफ़ा” दिखेगा और आसमान के लिए Stardust मिलेगा। न कोई मैसेज, न कोई नाम।';

  @override
  String plus_giftSend(String price) {
    return '$price में भेजें';
  }

  @override
  String get plus_giftSent =>
      'भेज दिया गया। अगली बार Aura खोलने पर उन्हें दिखेगा।';

  @override
  String get plus_giftUnavailable =>
      'यह तोहफ़ा अभी नहीं भेजा जा सकता। कोई चार्ज नहीं लिया गया।';

  @override
  String get plus_giftDailyLimit =>
      'आज के 5 तोहफ़े हो गए। कल और भेजे जा सकते हैं।';

  @override
  String get plus_giftPaused => 'इस अकाउंट पर अभी तोहफ़े उपलब्ध नहीं हैं।';

  @override
  String get plus_giftsOff =>
      'तोहफ़े थोड़ी देर के लिए आराम कर रहे हैं। कोई चार्ज नहीं लिया गया।';

  @override
  String plus_stardustBalance(int count) {
    return '$count Stardust';
  }

  @override
  String get plus_stardustNote =>
      'Stardust सिर्फ़ उन तोहफ़ों से मिलता है जो लोग आपको भेजते हैं। इसे न खरीदा जा सकता है, न कैश किया जा सकता है, न कहीं भेजा जा सकता है।';

  @override
  String get plus_skiesTitle => 'आपका आसमान';

  @override
  String get plus_skiesIntro =>
      'आपके अपने होम, सुकून और समझ के लिए एक आसमान। यह सिर्फ़ आपको दिखता है।';

  @override
  String get plus_skyNight => 'रात का आसमान';

  @override
  String get plus_skyAurora => 'ऑरोरा';

  @override
  String get plus_skyMonsoonDusk => 'मानसून की शाम';

  @override
  String get plus_skyFirstLight => 'पहली रोशनी';

  @override
  String get plus_skyLanternFestival => 'लालटेन उत्सव';

  @override
  String get plus_skyDeepOcean => 'गहरा समंदर';

  @override
  String get plus_skyMeteorShower => 'टूटते तारे';

  @override
  String get plus_skyFree => 'मुफ़्त';

  @override
  String get plus_skyWithPlus => 'Aura Plus के साथ';

  @override
  String get plus_skyOwned => 'आपका';

  @override
  String get plus_skyInUse => 'इस्तेमाल में';

  @override
  String get plus_skyUse => 'यह आसमान लगाएँ';

  @override
  String plus_skyBuy(String price) {
    return '$price में खरीदें';
  }

  @override
  String plus_skyStardust(int count) {
    return '$count Stardust इस्तेमाल करें';
  }

  @override
  String get plus_skyNotEnough => 'इस आसमान के लिए अभी Stardust काफ़ी नहीं है।';

  @override
  String get plus_soundscapeTitle => 'साथ में एक साउंडस्केप जोड़ें';

  @override
  String get plus_soundscapeNone => 'कोई आवाज़ नहीं';

  @override
  String get plus_soundscapeNightAir => 'रात की हवा';

  @override
  String get plus_soundscapeHighWind => 'तेज़ हवा';

  @override
  String get plus_soundscapeMonsoon => 'मानसून';

  @override
  String get plus_soundscapeBells => 'घंटियाँ';

  @override
  String get plus_soundscapeShore => 'समंदर किनारा';

  @override
  String get plus_soundscapePlay => 'ये आवाज़ें चलाएँ';

  @override
  String get plus_settingsSky => 'आपका आसमान और Stardust';

  @override
  String get plus_channelAccount => 'अकाउंट';

  @override
  String get plus_channelAccountDescription =>
      'Aura Plus रिमाइंडर, जैसे आपका मुफ़्त महीना खत्म होना।';

  @override
  String polish_legalOpenFailed(String url) {
    return 'आपका ब्राउज़र नहीं खुला। यह पेज $url पर है।';
  }

  @override
  String get polish_legalCopyLink => 'लिंक कॉपी करें';

  @override
  String get polish_legalLinkCopied => 'लिंक कॉपी हो गया';

  @override
  String polish_helpCallFailed(String number) {
    return 'इस फ़ोन से कॉल करना मुमकिन नहीं है। नंबर है $number।';
  }

  @override
  String get polish_helpCopyNumber => 'नंबर कॉपी करें';

  @override
  String get polish_helpNumberCopied => 'नंबर कॉपी हो गया';

  @override
  String get quiet_title => 'साथ में शांति';

  @override
  String get quiet_cardBody =>
      'दूसरों के साथ पढ़ाई करें, किताब पढ़ें या आराम करें। बस एक गिनती, एक साझा आवाज़ और भाव।';

  @override
  String get quiet_modeStudy => 'पढ़ाई';

  @override
  String get quiet_modeRead => 'पढ़ना';

  @override
  String get quiet_modeRest => 'आराम';

  @override
  String get quiet_titleStudy => 'साथ में पढ़ाई';

  @override
  String get quiet_titleRead => 'साथ में पढ़ना';

  @override
  String get quiet_titleRest => 'साथ में आराम';

  @override
  String quiet_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'यहाँ $count',
      one: 'यहाँ 1',
    );
    return '$_temp0';
  }

  @override
  String get quiet_justYou =>
      'अभी सिर्फ़ आप हैं। घंटे भर में और लोग आते रहते हैं।';

  @override
  String get quiet_joining => 'आपकी शांत जगह ढूँढी जा रही है…';

  @override
  String get quiet_reconnecting => 'फिर से जुड़ रहा है…';

  @override
  String get quiet_offline =>
      'साथ में शांति के लिए कनेक्शन चाहिए। Sanctuary ऑफ़लाइन भी चलता है।';

  @override
  String get quiet_openSanctuary => 'Sanctuary खोलें';

  @override
  String get quiet_paused =>
      'साथ में शांति थोड़ी देर आराम कर रहा है। Sanctuary हमेशा खुला है।';

  @override
  String get quiet_failed =>
      'साथ में शांति अभी खुल नहीं पाया। कृपया फिर से कोशिश करें।';

  @override
  String get quiet_tryAgain => 'फिर से कोशिश करें';

  @override
  String quiet_nextBlock(String time) {
    return 'अगला सेशन $time बजे शुरू होगा।';
  }

  @override
  String get quiet_leave => 'निकलें';

  @override
  String get quiet_leaveNote => 'जब चाहें निकल सकते हैं। कुछ नहीं खोता।';

  @override
  String get quiet_soundTitle => 'साझा आवाज़';

  @override
  String get quiet_soundBody =>
      'सब एक ही पल सुनते हैं, आपके अपने फ़ोन पर। कोई माइक्रोफ़ोन नहीं, कुछ रिकॉर्ड नहीं होता।';

  @override
  String get quiet_soundPlay => 'साझा आवाज़ चलाएँ';

  @override
  String get quiet_soundStop => 'आवाज़ रोकें';

  @override
  String get quiet_soundVolume => 'आवाज़ का स्तर';

  @override
  String get quiet_soundDownload => 'साझा आवाज़ के लिए एक बार डाउनलोड चाहिए।';

  @override
  String get quiet_soundDownloadCta => 'डाउनलोड करें';

  @override
  String get quiet_soundUnavailable =>
      'इस फ़ोन पर अभी आवाज़ नहीं चल पा रही। यहाँ होना ही काफ़ी है।';

  @override
  String get quiet_rhythm => 'फ़ोकस रिदम (25 / 5)';

  @override
  String get quiet_rhythmBody => 'अपनी मर्ज़ी से। सबके ब्रेक एक साथ आते हैं।';

  @override
  String quiet_rhythmFocus(String time) {
    return 'फ़ोकस · $time बजे ब्रेक';
  }

  @override
  String quiet_rhythmBreak(String time) {
    return 'ब्रेक · $time बजे फिर फ़ोकस';
  }

  @override
  String get quiet_rhythmToBreak => 'ब्रेक का समय।';

  @override
  String get quiet_rhythmToFocus => 'फ़ोकस का समय।';

  @override
  String get quiet_gesturesTitle => 'यहाँ सबको एक भाव भेजें';

  @override
  String quiet_gestureSent(String gesture) {
    return 'आपने $gesture भेजा';
  }

  @override
  String get quiet_moment_warm_tea => 'किसी ने गरम चाय बाँटी';

  @override
  String get quiet_moment_light_a_candle => 'किसी ने एक दीया जलाया';

  @override
  String get quiet_moment_hug => 'किसी ने एक झप्पी भेजी';

  @override
  String get quiet_moment_me_too => 'किसी ने कहा: मैं भी';

  @override
  String get quiet_moment_soft_rain => 'किसी ने हल्की बारिश भेजी';

  @override
  String get quiet_moment_stargaze => 'कोई आपके साथ तारे देख रहा है';

  @override
  String get quiet_moment_deep_breath => 'किसी ने एक गहरी साँस ली';

  @override
  String get quiet_moment_youre_not_alone => 'कोई कह रहा है: आप अकेले नहीं हैं';

  @override
  String get quiet_menu => 'सेशन मेनू';

  @override
  String get quiet_report => 'यहाँ की किसी समस्या की रिपोर्ट करें';

  @override
  String get quiet_hideGestures => 'भाव छिपाएँ';

  @override
  String get quiet_showGestures => 'भाव दिखाएँ';

  @override
  String get quiet_gesturesHidden => 'आपके लिए भाव छिपे हुए हैं।';

  @override
  String get quiet_reportBody =>
      'यहाँ कोई दिखाई नहीं देता, तो बताएँ क्या हुआ। एक मॉडरेटर इस सेशन के हाल के भाव देखेगा।';

  @override
  String get quiet_reportNote => 'मॉडरेटर को और कुछ जानना चाहिए? (वैकल्पिक)';

  @override
  String get quiet_reportSend => 'रिपोर्ट भेजें';

  @override
  String get quiet_reportThanks => 'धन्यवाद। एक मॉडरेटर इसे देखेगा।';

  @override
  String get quiet_reportFailed => 'यह हो नहीं पाया। कृपया फिर से कोशिश करें।';

  @override
  String get rooms_windDownTitle => 'साथ में सुकून से';

  @override
  String get rooms_windDownBody =>
      'दिन खत्म करने के लिए बीस शांत मिनट: एक साझा आवाज़, धीमी साँसें और कुछ नरम शब्द।';

  @override
  String rooms_windDownCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सुकून में',
      one: '1 सुकून में',
      zero: 'अभी कोई नहीं',
    );
    return '$_temp0';
  }

  @override
  String get rooms_windDownBack => 'वापस सुकून में';

  @override
  String get rooms_windDownFailed =>
      'यह हो नहीं पाया। कृपया फिर से कोशिश करें।';

  @override
  String get rooms_windDownEnded =>
      'सुकून का समय पूरा हुआ। अच्छे से आराम करें।';

  @override
  String get rooms_windDownLeave => 'निकलें';

  @override
  String get rooms_windDownCue_arrive => 'आ जाइए। अभी कुछ करने को नहीं है।';

  @override
  String get rooms_windDownCue_day_quieter => 'दिन को धीरे-धीरे शांत होने दें।';

  @override
  String get rooms_windDownCue_shoulders => 'कंधों को ढीला होने दें।';

  @override
  String get rooms_windDownCue_nothing_to_do =>
      'अभी किसी चीज़ को आपकी ज़रूरत नहीं है।';

  @override
  String get rooms_windDownCue_slower => 'हर साँस को थोड़ा और धीमा होने दें।';

  @override
  String get rooms_windDownCue_rest_well =>
      'अच्छे से आराम करें। बाकी रात सँभाल लेगी।';

  @override
  String get rooms_presenceStale =>
      'यहाँ कौन है देखने के लिए फिर से कनेक्ट करें';

  @override
  String get keepsakes_refreshFailed =>
      'अभी यादगारें रीफ़्रेश नहीं हो सकीं। आपकी सहेजी हुई यादगारें यहीं हैं।';

  @override
  String get keepsakes_signedOut =>
      'यादगारें रीफ़्रेश करने के लिए फिर से साइन इन करें। आपकी सहेजी हुई यादगारें यहीं हैं।';

  @override
  String get keepsakes_accountUnavailable =>
      'अभी इस खाते के लिए यादगारें उपलब्ध नहीं हैं। खाते की सेटिंग देखें।';

  @override
  String get keepsakes_unavailable =>
      'इस बिल्ड में यादगारें रीफ़्रेश करना अभी तैयार नहीं है। आपकी सहेजी हुई यादगारें यहीं हैं।';

  @override
  String get keepsakes_accountAction => 'खाते की सेटिंग';

  @override
  String get universe_title => 'आपका संसार';

  @override
  String get universe_entry =>
      'आदतों, शांत पलों और भविष्य के आपके लिए एक छोटा संसार।';

  @override
  String get universe_intro => 'थोड़ी देखभाल, थोड़ी बढ़त। अपनी गति से खोजें।';

  @override
  String get universe_worldView => '3D संसार दिखाएँ';

  @override
  String get universe_listView => 'सूची में देखें';

  @override
  String get universe_grove => 'आदतों का उपवन';

  @override
  String get universe_pool => 'शांत जल';

  @override
  String get universe_reflection => 'मन का बगीचा';

  @override
  String get universe_observatory => 'तारों की वेधशाला';

  @override
  String get universe_groveBody =>
      'हर आदत एक पौधा है जो लॉग करने पर बढ़ता है। जिन पौधों का आपने संकल्प लिया है, वे दिन छूटने पर आराम करते हैं, और एक लॉग उन्हें जगा देता है।';

  @override
  String get universe_poolBody =>
      'पानी के पास शांति से साँस लें। जब तैयार हों, तभी शुरू करें।';

  @override
  String get universe_reflectionBody =>
      'एक निजी चेक-इन से अपनी भावनाएँ समझें। आपकी भावनाएँ आपकी देखभाल की जगह में रहती हैं।';

  @override
  String get universe_observatoryBody =>
      'भविष्य के अपने लिए एक प्यारा संदेश छोड़ें या अपने टाइम कैप्सूल देखें।';

  @override
  String get universe_habits => 'आदतें खोलें';

  @override
  String get universe_breathe => 'साँस लेना शुरू करें';

  @override
  String get universe_checkIn => 'चेक-इन करें';

  @override
  String get universe_capsules => 'टाइम कैप्सूल खोलें';

  @override
  String get universe_left => 'बाईं ओर घुमाएँ';

  @override
  String get universe_right => 'दाईं ओर घुमाएँ';

  @override
  String get universe_zoomIn => 'पास से देखें';

  @override
  String get universe_zoomOut => 'दूर से देखें';

  @override
  String get universe_reset => 'कैमरा रीसेट करें';

  @override
  String get universe_hint =>
      'चारों ओर देखने के लिए खींचें। रोशनी पर टैप करें या नीचे कोई जगह चुनें।';

  @override
  String get reflections_title => 'दिल की बातें';

  @override
  String get reflections_intro =>
      'यहाँ के लोगों के कुछ शब्द। इनका जवाब सिर्फ़ भावों से दिया जाता है।';

  @override
  String get reflections_share => 'दिल की बात शेयर करें';

  @override
  String get reflections_empty =>
      'यहाँ अभी कोई दिल की बात नहीं है। आप चाहें तो एक शेयर करें, या बस पढ़ें और भाव भेजें।';

  @override
  String get reflections_emptyMemory =>
      'इस रूम में कोई दिल की बात शेयर नहीं हुई।';

  @override
  String get reflections_loadFailed => 'दिल की बातें अभी लोड नहीं हो पाईं।';

  @override
  String get reflections_offline =>
      'दिल की बातों के लिए कनेक्शन चाहिए। आप जो भी लिखें, वह इसी फ़ोन पर रहेगा।';

  @override
  String get reflections_memory =>
      'यह रूम अब एक याद है: इसकी दिल की बातें सिर्फ़ पढ़ने के लिए हैं, इनमें कुछ नया नहीं जुड़ेगा।';

  @override
  String get reflections_paused =>
      'दिल की बातें थोड़ी देर के लिए आराम पर हैं। भाव अब भी भेजे जा सकते हैं।';

  @override
  String reflections_limit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'आज के लिए $count दिल की बातें हो गईं। भाव हमेशा भेजे जा सकते हैं।',
      one: 'आज के लिए 1 दिल की बात हो गई। भाव हमेशा भेजे जा सकते हैं।',
    );
    return '$_temp0';
  }

  @override
  String get reflections_slow => 'दिल की बातें अभी थोड़ी धीमी चल रही हैं';

  @override
  String reflections_left(int remaining, int total) {
    return 'आज $total में से $remaining बाकी';
  }

  @override
  String reflections_cardLabel(String pseudonym) {
    return '$pseudonym की दिल की बात';
  }

  @override
  String get reflections_mine => 'आपकी दिल की बात';

  @override
  String get reflections_onlyYou => 'यह सिर्फ़ आपको दिखता है';

  @override
  String get reflections_pending => 'अभी जाँच चल रही है। आप पढ़ना जारी रखें।';

  @override
  String get reflections_heldSoon => 'एक छोटी-सी जाँच का इंतज़ार';

  @override
  String get reflections_heldOvernight =>
      'एक छोटी-सी जाँच का इंतज़ार। इसमें सुबह तक का समय लग सकता है।';

  @override
  String get reflections_rejectedCard => 'यह यहाँ पोस्ट नहीं हो पाई।';

  @override
  String get reflections_removedCard => 'रिव्यू के बाद इसे हटा दिया गया।';

  @override
  String reflections_gestureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count भाव',
      one: '1 भाव',
      zero: 'अभी कोई भाव नहीं',
    );
    return '$_temp0';
  }

  @override
  String get reflections_countPrivate => 'यह गिनती सिर्फ़ आपको दिखती है';

  @override
  String get reflections_options => 'दिल की बात के विकल्प';

  @override
  String reflections_gestureHint(String pseudonym) {
    return 'इस दिल की बात पर $pseudonym को भेजा जाएगा';
  }

  @override
  String reflections_gestureSent(String gesture, String pseudonym) {
    return '$pseudonym को भेजा गया: $gesture';
  }

  @override
  String get reflections_delete => 'डिलीट करें';

  @override
  String get reflections_withdraw => 'वापस लें';

  @override
  String get reflections_deleteTitle => 'यह दिल की बात डिलीट करें?';

  @override
  String get reflections_deleteBody =>
      'यह यहाँ सबके लिए हट जाएगी। दिल की बात एडिट नहीं होती, पर आप चाहें तो नई शेयर करें।';

  @override
  String get reflections_withdrawTitle => 'यह दिल की बात वापस लें?';

  @override
  String get reflections_withdrawBody =>
      'यह पोस्ट नहीं होगी। आप चाहें तो कभी भी नई शेयर करें।';

  @override
  String get reflections_deleted => 'आपकी दिल की बात हटा दी गई।';

  @override
  String get reflections_reportTitle => 'इस दिल की बात को रिपोर्ट करें';

  @override
  String get reflections_reportHidden =>
      'हमें बताने के लिए शुक्रिया। वह दिल की बात अब आपको नहीं दिखेगी।';

  @override
  String get reflections_composeTitle => 'दिल की बात शेयर करें';

  @override
  String get reflections_composeLabel => 'मन में क्या है?';

  @override
  String get reflections_composeNote =>
      'इस रूम के लिए कुछ शब्द। लोग सिर्फ़ भावों से जवाब दे सकते हैं, रिप्लाई से कभी नहीं।';

  @override
  String reflections_counter(int count, int max) {
    return '$count/$max';
  }

  @override
  String reflections_counterSemantic(int count, int max) {
    return '$max में से $count अक्षर';
  }

  @override
  String reflections_tooLong(int max) {
    return 'थोड़ा छोटा करें: ज़्यादा से ज़्यादा $max अक्षर।';
  }

  @override
  String get reflections_send => 'भेजें';

  @override
  String get reflections_sending => 'आराम से भेजा जा रहा है…';

  @override
  String get reflections_contactBlocked =>
      'फ़ोन नंबर, लिंक और हैंडल यहाँ शेयर नहीं किए जा सकते। इससे सब ज़्यादा सुरक्षित रहते हैं।';

  @override
  String get reflections_draftKept =>
      'ड्राफ़्ट रख लिया गया है। ऑनलाइन वापस आने पर इसे भेजा जा सकता है।';

  @override
  String get reflections_sendFailed =>
      'अभी भेजा नहीं जा सका। आपके शब्द यहीं हैं: थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get reflections_rejectedContact =>
      'दिल की बात में कॉन्टैक्ट डिटेल्स नहीं हो सकते। इनके बिना फिर से कोशिश करें?';

  @override
  String get reflections_rejectedLink =>
      'दिल की बात में लिंक नहीं हो सकते। इसके बिना फिर से कोशिश करें?';

  @override
  String get reflections_rejectedPersonal =>
      'किसी की निजी जानकारी के बारे में सवाल यहाँ पोस्ट नहीं हो सकते। इनके बिना फिर से कोशिश करें?';

  @override
  String get reflections_rejectedGeneral =>
      'यह यहाँ पोस्ट नहीं होगी। इससे किसी को ठेस पहुँचना या निजी जानकारी शेयर होना मुमकिन है। आपके शब्द एडिट करने के लिए यहीं हैं।';

  @override
  String get reflections_supportSubtitle => 'यह बोझ आपको अकेले नहीं उठाना है।';

  @override
  String get reflections_backToRoom => 'रूम में वापस जाएँ';

  @override
  String get set_corpusTitle =>
      'सेफ़्टी फ़िल्टर बेहतर करने के लिए मेरी दिल की बातें इस्तेमाल करें';

  @override
  String get set_corpusNote =>
      'रूम में पोस्ट की गई आपकी दिल की बातें और उन पर लिए गए फ़ैसले, आपके नाम, रूम या छद्म नाम के बिना, Aura के अपने सेफ़्टी फ़िल्टर सिखाने के लिए रखे जा सकते हैं। इसे बंद करने पर अब से पोस्ट की गई कोई भी चीज़ नहीं रखी जाएगी।';

  @override
  String get set_corpusOffline =>
      'इस विकल्प के लिए कनेक्शन चाहिए। कुछ नहीं बदला।';

  @override
  String get device_bannedTitle =>
      'इस डिवाइस पर Aura इस्तेमाल नहीं किया जा सकता';

  @override
  String get device_bannedBody => 'इस फ़ोन पर Aura उपलब्ध नहीं है।';

  @override
  String get device_bannedReviewSubject => 'डिवाइस का रिव्यू';

  @override
  String get rooms_paused =>
      'रूम कुछ देर आराम कर रहे हैं। थोड़ी देर बाद फिर से कोशिश करें।';

  @override
  String get rooms_pausedJoin =>
      'रूम कुछ देर आराम कर रहे हैं। आपका चेक-इन सेव हो गया है।';

  @override
  String get ripples_title => 'Breath Ripples';

  @override
  String get ripples_homeCard => 'साथ में साँस लें';

  @override
  String get ripples_homeCardBody =>
      'कुछ और लोगों के साथ तीन शांत मिनट। न कोई बात, न कोई स्कोर।';

  @override
  String get ripples_breatheTogether => 'साथ में साँस लें';

  @override
  String ripples_invite(String name, int count, int capacity) {
    return '$name का साथ में साँस लेने का मन है · $count/$capacity';
  }

  @override
  String get ripples_inviteJoin => 'जुड़ें';

  @override
  String ripples_inviteMine(int count, int capacity) {
    return 'आपका इनवाइट खुला है · $count/$capacity';
  }

  @override
  String get ripples_lobby => 'साथ साँस लेने वाले लोग ढूँढे जा रहे हैं…';

  @override
  String get ripples_lobbyHint =>
      'इंतज़ार के दौरान साथ-साथ साँस लें। इसे कभी भी छोड़ा जा सकता है।';

  @override
  String get ripples_holdHint =>
      'साँस अंदर लेने के लिए दबाकर रखें, बाहर छोड़ने के लिए छोड़ दें';

  @override
  String get ripples_tapHint =>
      'साँस अंदर और बाहर के बीच बदलने के लिए टैप करें';

  @override
  String get ripples_breathArea => 'साँस लेने की जगह';

  @override
  String get ripples_offline =>
      'साथ में साँस लेने के लिए कनेक्शन चाहिए। अकेले साँस लें?';

  @override
  String get ripples_paused =>
      'Breath Ripples अभी थोड़ी देर आराम कर रहा है। अकेले साँस लें?';

  @override
  String get ripples_suspended =>
      'इस अकाउंट के लिए साथ में साँस लेना अभी रुका हुआ है। अकेले साँस लेना अब भी मुमकिन है।';

  @override
  String get ripples_closed =>
      'इस अकाउंट से दूसरों के साथ साँस लेना मुमकिन नहीं है। अकेले साँस लेना अब भी मुमकिन है।';

  @override
  String get ripples_guidelines =>
      'पहले कम्युनिटी गाइडलाइंस। उन्हें पढ़ने के लिए रूम खोलें, या अभी अकेले साँस लें।';

  @override
  String get ripples_breatheSolo => 'अकेले साँस लें';

  @override
  String get ripples_settle => 'सहज हो जाएँ';

  @override
  String get ripples_fade => 'धीरे-धीरे थमने दें';

  @override
  String ripples_together(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोग साथ साँस ले रहे हैं',
      one: 'बस आप और समंदर',
    );
    return '$_temp0';
  }

  @override
  String ripples_echoesJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count गूँजें जुड़ीं। ये उन असली लोगों की रिकॉर्डिंग हैं, जिन्होंने पहले यहाँ साँस ली थी।',
      one: '1 गूँज जुड़ी। यह किसी असली इंसान की रिकॉर्डिंग है, जिसने पहले यहाँ साँस ली थी।',
    );
    return '$_temp0';
  }

  @override
  String ripples_guides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count गाइड लाइट आपके साथ साँस लेती हैं।',
      one: 'एक गाइड लाइट आपके साथ साँस लेती है।',
    );
    return '$_temp0';
  }

  @override
  String get ripples_solo =>
      'इस बार अकेले साँस चल रही है। समंदर अब भी सुन रहा है।';

  @override
  String get ripples_linkLost => 'कुछ पल के लिए अकेले साँस चल रही है।';

  @override
  String get ripples_alone => 'साँस लेते रहें। समंदर अब भी यहीं है।';

  @override
  String get ripples_leave => 'निकलें';

  @override
  String get ripples_accessibleMode => 'एक्सेसिबल मोड';

  @override
  String get ripples_accessibleModeHint =>
      'अंदर और बाहर के बीच बदलने के लिए टैप करें। जब आप दूसरों के साथ ताल में हों, तो टोन और ज़्यादा मज़बूत वाइब्रेशन यह बताते हैं।';

  @override
  String ripples_oceanSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रोशनियों के साथ रात का समंदर',
      one: 'आपकी रोशनी के साथ रात का समंदर',
    );
    return '$_temp0';
  }

  @override
  String get ripples_lightMe => 'आपकी रोशनी';

  @override
  String ripples_lightHuman(String name) {
    return '$name की रोशनी';
  }

  @override
  String get ripples_lightEcho => 'किसी की गूँज, जिसने पहले यहाँ साँस ली थी';

  @override
  String get ripples_lightGuide => 'एक गाइड लाइट, पेसर के साथ साँस लेती हुई';

  @override
  String get ripples_echo => 'गूँज';

  @override
  String get ripples_guide => 'गाइड';

  @override
  String get ripples_you => 'आप';

  @override
  String get ripples_pulse => 'पल्स भेजें';

  @override
  String get ripples_gestureHug => 'झप्पी';

  @override
  String get ripples_gestureDeepBreath => 'गहरी साँस';

  @override
  String get ripples_gestureNotAlone => 'कोई साथ है';

  @override
  String ripples_pulseFrom(String name) {
    return '$name ने पल्स भेजी';
  }

  @override
  String ripples_gestureFrom(String name, String gesture) {
    return '$name · $gesture';
  }

  @override
  String get ripples_contactTray => 'कुछ अपनापन भेजें';

  @override
  String get ripples_mute => 'म्यूट';

  @override
  String get ripples_unmute => 'अनम्यूट';

  @override
  String get ripples_block => 'ब्लॉक';

  @override
  String get ripples_report => 'रिपोर्ट';

  @override
  String get ripples_blocked =>
      'ब्लॉक कर दिया गया। आप दोनों का फिर से मैच नहीं होगा।';

  @override
  String get ripples_reported => 'शुक्रिया। Aura की टीम से कोई इसे देखेगा।';

  @override
  String get ripples_actionFailed =>
      'यह नहीं हो पाया। कृपया फिर से कोशिश करें।';

  @override
  String get ripples_endTitle => 'ये कुछ मिनट साथ में बीते।';

  @override
  String get ripples_again => 'फिर से साँस लें';

  @override
  String get ripples_backToRoom => 'रूम पर वापस';

  @override
  String get ripples_feelNow => 'अब कैसा लग रहा है?';

  @override
  String get ripples_echoToggle => 'मेरी साँसों को गूँज बनने दें';

  @override
  String get ripples_echoToggleHint =>
      'गूँज में सिर्फ़ आपकी साँसों की टाइमिंग रहती है, आप कौन हैं यह कभी नहीं, इसलिए इसे आप तक वापस नहीं जोड़ा जा सकता। इसे बंद करने पर आगे से कोई नई गूँज नहीं बनेगी।';

  @override
  String get rooms_title => 'रूम';

  @override
  String get rooms_yourRooms => 'आपके रूम';

  @override
  String get rooms_memories => 'यादें';

  @override
  String get rooms_whatTitle => 'रूम क्या हैं';

  @override
  String get rooms_whatBody =>
      'अभी आप जैसा महसूस करने वाले कुछ लोगों का एक छोटा रूम, एक दिन के लिए।';

  @override
  String get rooms_pointName =>
      'हर रूम में एक नया नाम। आपका अकाउंट किसी को नहीं दिखता।';

  @override
  String get rooms_pointGestures =>
      'कोई मैसेज या DM नहीं: सिर्फ़ आठ अपनेपन भरे भाव।';

  @override
  String get rooms_pointTime =>
      'रूम एक दिन चलते हैं, फिर 7 दिन याद बनकर रहते हैं।';

  @override
  String get rooms_lanternNote =>
      'Lantern Hour: हर रात आपके इलाके के समय से 9 से 11 बजे तक, रूम मिलकर एक लालटेन जलाते हैं और ज़्यादा लोग आते हैं।';

  @override
  String get rooms_lanternNow => 'अभी Lantern Hour चल रहा है';

  @override
  String get rooms_checkInCta => 'रूम ढूँढने के लिए चेक-इन करें';

  @override
  String get rooms_empty =>
      'आप अभी किसी रूम में नहीं हैं। चेक-इन के बाद अपने जैसा महसूस करने वालों से जुड़ना मुमकिन है।';

  @override
  String get rooms_offline =>
      'रूम के लिए कनेक्शन चाहिए। आपके अपने चेक-इन इस फ़ोन पर सेव होते रहेंगे।';

  @override
  String get rooms_loadFailed => 'अभी रूम तक पहुँचना नहीं हो पाया।';

  @override
  String get rooms_tryAgain => 'फिर से कोशिश करें';

  @override
  String get rooms_signedOut => 'साइन इन करने के बाद रूम खुलते हैं।';

  @override
  String get rooms_signIn => 'साइन इन करें';

  @override
  String get rooms_suspended =>
      'अभी आपके अकाउंट के लिए रूम रुके हुए हैं। मदद हमेशा यहाँ है।';

  @override
  String rooms_suspendedUntil(String date) {
    return '$date तक आपके अकाउंट के लिए रूम रुके हुए हैं। मदद हमेशा यहाँ है।';
  }

  @override
  String get rooms_accountClosed =>
      'Aura के नियम तोड़ने की वजह से यह अकाउंट बंद कर दिया गया।';

  @override
  String get rooms_profilePending =>
      'आपके अकाउंट का सेटअप पूरा होते ही रूम खुलेंगे। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get rooms_openHint => 'रूम खोलता है';

  @override
  String rooms_memoryUntil(String date) {
    return '$date तक एक याद';
  }

  @override
  String get rooms_theme_lighthouse => 'प्रकाश स्तंभ';

  @override
  String get rooms_theme_rain_sanctuary => 'बारिश का ठिकाना';

  @override
  String get rooms_theme_midnight_observatory => 'आधी रात की वेधशाला';

  @override
  String get rooms_theme_sunrise_deck => 'सूर्योदय की छत';

  @override
  String get rooms_gesture_warm_tea => 'एक कप चाय';

  @override
  String get rooms_gesture_light_a_candle => 'एक दीया';

  @override
  String get rooms_gesture_hug => 'झप्पी';

  @override
  String get rooms_gesture_me_too => 'मैं भी';

  @override
  String get rooms_gesture_soft_rain => 'हल्की फुहार';

  @override
  String get rooms_gesture_stargaze => 'तारे देखें';

  @override
  String get rooms_gesture_deep_breath => 'गहरी साँस';

  @override
  String get rooms_gesture_youre_not_alone => 'कोई साथ है';

  @override
  String rooms_hereNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अभी यहाँ $count हैं',
      one: 'अभी यहाँ 1 है',
      zero: 'अभी यहाँ कोई नहीं है',
    );
    return '$_temp0';
  }

  @override
  String rooms_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count लोग यहाँ आ चुके हैं',
      one: 'आज 1 व्यक्ति यहाँ आ चुका है',
    );
    return '$_temp0';
  }

  @override
  String rooms_countsSemantic(int now, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      now,
      locale: localeName,
      other: 'अभी यहाँ $now लोग',
      one: 'अभी यहाँ 1 व्यक्ति',
    );
    String _temp1 = intl.Intl.pluralLogic(
      today,
      locale: localeName,
      other: 'आज $today',
      one: 'आज 1',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String rooms_stripSemantic(String theme, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अभी यहाँ $count लोग',
      one: 'अभी यहाँ 1 व्यक्ति',
    );
    return '$theme, $_temp0';
  }

  @override
  String get rooms_opening => 'रूम खुल रहा है…';

  @override
  String rooms_youAre(String pseudonym) {
    return 'यहाँ आप $pseudonym हैं';
  }

  @override
  String rooms_coldStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'आज $count लोग यहाँ आ चुके हैं। अगले आने वाले के लिए एक रोशनी छोड़ जाएँ।',
      one: 'आज यहाँ सबसे पहले आप हैं। अगले आने वाले के लिए एक रोशनी छोड़ जाएँ।',
    );
    return '$_temp0';
  }

  @override
  String rooms_lanternOn(String time) {
    return 'Lantern Hour · $time तक';
  }

  @override
  String rooms_closing(String time) {
    return 'यह रूम $time पर याद बन जाएगा।';
  }

  @override
  String get rooms_memory =>
      'यह रूम अब एक याद बन गया है। 7 दिन तक इसे फिर से देखा जा सकता है।';

  @override
  String get rooms_findNew => 'नया रूम ढूँढें';

  @override
  String get rooms_reconnecting => 'फिर से जुड़ रहा है…';

  @override
  String get rooms_membersTitle => 'यहाँ आपके साथ';

  @override
  String get rooms_you => 'आप';

  @override
  String get rooms_memberHereNow => 'अभी यहाँ';

  @override
  String get rooms_memberAway => 'अभी दूर';

  @override
  String get rooms_memberMuted => 'आपके लिए म्यूट';

  @override
  String rooms_memberLabel(String pseudonym, String mood, String status) {
    return '$pseudonym, $mood, $status';
  }

  @override
  String rooms_youLabel(String pseudonym, String mood) {
    return 'आप, $pseudonym, $mood';
  }

  @override
  String get rooms_memberHint => 'विकल्प खोलता है';

  @override
  String get rooms_recentTitle => 'इस रूम में अपनापन';

  @override
  String rooms_receivedLine(String pseudonym, String gesture) {
    return '$pseudonym ने आपको $gesture भेजा';
  }

  @override
  String rooms_sentToMember(String gesture, String pseudonym) {
    return '$gesture $pseudonym को भेजा गया';
  }

  @override
  String rooms_sentToRoom(String gesture) {
    return '$gesture यहाँ सबको भेजा गया';
  }

  @override
  String rooms_someoneSent(String gesture) {
    return 'किसी ने $gesture भेजा';
  }

  @override
  String rooms_someoneSentRoom(String gesture) {
    return 'किसी ने यहाँ सबको $gesture भेजा';
  }

  @override
  String rooms_youSentMember(String gesture, String pseudonym) {
    return 'आपने $pseudonym को $gesture भेजा';
  }

  @override
  String rooms_youSentRoom(String gesture) {
    return 'आपने यहाँ सबको $gesture भेजा';
  }

  @override
  String get rooms_trayTitle => 'यहाँ सबको अपनापन भेजें';

  @override
  String get rooms_trayHint => 'यहाँ सबको भेजता है';

  @override
  String get rooms_trayResting =>
      'याद में भाव आराम करते हैं। रिपोर्ट, ब्लॉक या म्यूट अब भी किया जा सकता है।';

  @override
  String get rooms_roomOptions => 'रूम के विकल्प';

  @override
  String get rooms_reportRoom => 'यहाँ की कोई समस्या रिपोर्ट करें';

  @override
  String get rooms_leave => 'यह रूम छोड़ें';

  @override
  String get rooms_removeMemory => 'मेरे रूम से हटाएँ';

  @override
  String get rooms_leaveTitle => 'यह रूम छोड़ना है?';

  @override
  String get rooms_leaveBody =>
      'इस रूम में वापस आना मुमकिन नहीं होगा, और आपकी जगह किसी और के लिए खुल जाएगी। आपका अगला चेक-इन आपके लिए नया रूम ढूँढ सकता है।';

  @override
  String get rooms_leaveConfirm => 'रूम छोड़ें';

  @override
  String get rooms_stay => 'यहीं रहें';

  @override
  String get rooms_removeTitle => 'यह याद हटानी है?';

  @override
  String get rooms_removeBody =>
      'यह अभी आपके रूम से हट जाएगी। वैसे भी यादें 7 दिन बाद हमेशा के लिए बंद हो जाती हैं।';

  @override
  String get rooms_removeConfirm => 'हटाएँ';

  @override
  String get rooms_keep => 'रहने दें';

  @override
  String get rooms_leaveFailed => 'यह हो नहीं पाया। आप अभी भी रूम में हैं।';

  @override
  String get rooms_gone =>
      'यह रूम बंद हो गया है। रूम 7 दिन याद बनकर रहते हैं, फिर चले जाते हैं।';

  @override
  String get rooms_backToRooms => 'अपने रूम पर वापस';

  @override
  String get rooms_offlineRoom =>
      'रूम के लिए कनेक्शन चाहिए। ऑनलाइन वापस आते ही यह रूम फिर खुलेगा।';

  @override
  String get rooms_joinTitle => 'आपका रूम ढूँढा जा रहा है';

  @override
  String get rooms_finding =>
      'अभी ऐसा ही महसूस करने वाले लोग ढूँढे जा रहे हैं…';

  @override
  String get rooms_offlineJoin =>
      'रूम के लिए कनेक्शन चाहिए। आपका चेक-इन सेव हो गया है।';

  @override
  String get rooms_joinFailed =>
      'अभी रूम तक पहुँचना नहीं हो पाया। आपका चेक-इन सेव हो गया है।';

  @override
  String get rooms_joinLimit =>
      'आज इस एहसास के लिए 3 नए रूम हो चुके हैं। जिन रूम में आप हैं, वे अभी भी आपके लिए खुले हैं।';

  @override
  String get rooms_seeYourRooms => 'अपने रूम देखें';

  @override
  String get rooms_poolUnavailable =>
      'हिंदी और हिंग्लिश रूम जल्द खुलेंगे। अभी के लिए अंग्रेज़ी रूम में जुड़ें?';

  @override
  String get rooms_poolJoinEnglish => 'अंग्रेज़ी रूम में जुड़ें';

  @override
  String get rooms_poolNotify => 'खुलने पर मुझे बताएँ';

  @override
  String get rooms_poolNotifyDone =>
      'हिंदी और हिंग्लिश रूम खुलने पर हम आपको यहीं बताएँगे।';

  @override
  String get rooms_noRequest => 'रूम चेक-इन से खुलते हैं।';

  @override
  String get rooms_offer => 'ऐसा ही महसूस करने वालों के रूम में जुड़ें';

  @override
  String get rooms_offerHint =>
      'एक रूम खोलता है, सिर्फ़ उसी के लिए नए नाम के साथ';

  @override
  String get rooms_offerOffline => 'ऑनलाइन वापस आने पर रूम खुलेंगे';

  @override
  String get rooms_offerLater =>
      'जब भी किसी के साथ का मन हो, रूम टैब में रूम मिलेंगे।';

  @override
  String get rooms_guidelinesTitle => 'आपके पहले रूम से पहले';

  @override
  String get rooms_guidelinesIntro =>
      'रूम सुकून भरे रहते हैं, क्योंकि हर कोई कुछ आसान बातों का ध्यान रखता है:';

  @override
  String get rooms_rule1 =>
      'अच्छे से पेश आएँ। यहाँ हर कोई सच में अपना दिन जी रहा है।';

  @override
  String get rooms_rule2 =>
      'जाति, धर्म, जेंडर, सेक्शुअलिटी या किसी भी और चीज़ को लेकर कोई नफ़रत नहीं।';

  @override
  String get rooms_rule3 => 'कोई सेक्शुअल कंटेंट नहीं।';

  @override
  String get rooms_rule4 =>
      'कॉन्टैक्ट डिटेल्स, मिलने की बात, या किसी की उम्र, स्कूल, शहर या फ़ोटो कभी न शेयर करें, न माँगें।';

  @override
  String get rooms_rule5 => 'कोई बिक्री या स्पैम नहीं।';

  @override
  String get rooms_rule6 =>
      'किसी को भी खुद को चोट पहुँचाने के लिए कभी न उकसाएँ। अपने मन की बात कहना हमेशा ठीक है।';

  @override
  String get rooms_guidelinesSafety =>
      'किसी को भी रिपोर्ट, ब्लॉक या म्यूट किया जा सकता है, और मदद हमेशा बस एक टैप दूर है।';

  @override
  String get rooms_guidelinesAgree => 'मंज़ूर है, इनका ध्यान रहेगा';

  @override
  String get rooms_guidelinesUpdate =>
      'रूम की कम्युनिटी गाइडलाइंस नई हैं। अगले रूम से पहले इन्हें पढ़ने के लिए Aura अपडेट करें।';

  @override
  String rooms_sendTo(String pseudonym) {
    return '$pseudonym को थोड़ा अपनापन भेजें';
  }

  @override
  String rooms_gestureHintMember(String pseudonym) {
    return '$pseudonym को भेजता है';
  }

  @override
  String get rooms_report => 'रिपोर्ट करें';

  @override
  String get rooms_block => 'ब्लॉक करें';

  @override
  String get rooms_mute => 'म्यूट करें';

  @override
  String get rooms_unmute => 'अनम्यूट करें';

  @override
  String get rooms_safetyNote =>
      'उन्हें कभी नहीं बताया जाता कि किसने उन्हें रिपोर्ट, ब्लॉक या म्यूट किया।';

  @override
  String rooms_blockTitle(String pseudonym) {
    return '$pseudonym को ब्लॉक करें?';
  }

  @override
  String get rooms_blockBody =>
      'आप दोनों को फिर कभी एक रूम में नहीं रखा जाएगा, और आपके बीच भावों का आना-जाना बंद हो जाएगा। उन्हें इस बारे में नहीं बताया जाएगा।';

  @override
  String rooms_blocked(String pseudonym) {
    return '$pseudonym को ब्लॉक कर दिया गया। अब आप दोनों को एक रूम में नहीं रखा जाएगा।';
  }

  @override
  String rooms_muted(String pseudonym) {
    return '$pseudonym को आपके लिए म्यूट कर दिया गया। यहाँ उनके भाव आप तक नहीं पहुँचेंगे।';
  }

  @override
  String rooms_unmuted(String pseudonym) {
    return '$pseudonym को अनम्यूट कर दिया गया।';
  }

  @override
  String get rooms_undo => 'वापस लें';

  @override
  String get rooms_actionFailed =>
      'यह हो नहीं पाया। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String rooms_reportMember(String pseudonym) {
    return '$pseudonym को रिपोर्ट करें';
  }

  @override
  String get rooms_reportGesture => 'इस भाव को रिपोर्ट करें';

  @override
  String get rooms_reportWhy => 'क्या हो रहा है?';

  @override
  String get rooms_reason1 =>
      'शायद कोई खतरे में है या खुद को चोट पहुँचा रहा है';

  @override
  String get rooms_reason2 => 'तंग करना या बुलिंग';

  @override
  String get rooms_reason3 => 'सेक्शुअल कंटेंट या छेड़खानी';

  @override
  String get rooms_reason4 => 'नफ़रत या अपमानजनक शब्द';

  @override
  String get rooms_reason5 => 'कॉन्टैक्ट डिटेल्स या निजी जानकारी';

  @override
  String get rooms_reason6 => 'स्पैम या बिक्री';

  @override
  String get rooms_reason7 => 'शायद किसी की उम्र 13 से कम है';

  @override
  String get rooms_reason8 => 'कुछ और';

  @override
  String get rooms_reason9 =>
      'लगता है किसी कम उम्र के इंसान को निशाना बनाया जा रहा है';

  @override
  String get rooms_reportNoteLabel => 'मॉडरेटर को कुछ बताना है? (ज़रूरी नहीं)';

  @override
  String get rooms_reportNoteHelp =>
      'इसे सिर्फ़ Aura के मॉडरेटर पढ़ते हैं। कृपया फ़ोन नंबर, लिंक और हैंडल न लिखें।';

  @override
  String get rooms_reportNoteContact =>
      'फ़ोन नंबर, लिंक और हैंडल यहाँ शेयर नहीं किए जा सकते। इससे सब ज़्यादा सुरक्षित रहते हैं।';

  @override
  String get rooms_reportSend => 'रिपोर्ट भेजें';

  @override
  String get rooms_reportThanks =>
      'बताने के लिए शुक्रिया। आमतौर पर एक दिन के अंदर एक मॉडरेटर इसे देखेंगे।';

  @override
  String get rooms_reportHidden =>
      'बताने के लिए शुक्रिया। जब तक मॉडरेटर इसे देखते हैं, इस रूम में उनके भाव आप तक नहीं आएँगे।';

  @override
  String get rooms_reportGestureHidden =>
      'बताने के लिए शुक्रिया। वह भाव अब आपके लिए छिपा दिया गया है।';

  @override
  String get rooms_reportCrisis =>
      'बताने के लिए शुक्रिया। एक मॉडरेटर जल्द ही देखेंगे, और मदद हमेशा बस एक टैप दूर है।';

  @override
  String get rooms_reportLimit =>
      'आज काफ़ी रिपोर्ट भेजी जा चुकी हैं। अगर कोई खतरे में है, तो मदद का बटन हमेशा यहाँ है।';

  @override
  String get rooms_reportFailed =>
      'यह हो नहीं पाया, इसलिए कुछ नहीं भेजा गया। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get rooms_reportOffline =>
      'रिपोर्ट के लिए कनेक्शन चाहिए। अभी तक कुछ नहीं भेजा गया।';

  @override
  String get rooms_surveyTitle => 'क्या अकेलापन थोड़ा कम लगा?';

  @override
  String get rooms_surveyYes => 'हाँ';

  @override
  String get rooms_surveyNo => 'कुछ खास नहीं';

  @override
  String get rooms_surveySkip => 'छोड़ें';

  @override
  String get settings_poolNoticeEn =>
      'नए रूम आपको English बोलने वालों के साथ जोड़ेंगे। आप अभी जिस रूम में हैं, उसकी भाषा नहीं बदलेगी।';

  @override
  String get settings_poolNoticeTe =>
      'नए रूम आपको तेलुगु और Tenglish बोलने वालों के साथ जोड़ेंगे। आप अभी जिस रूम में हैं, उसकी भाषा नहीं बदलेगी।';

  @override
  String get settings_poolNoticeHi =>
      'नए रूम आपको हिंदी और Hinglish बोलने वालों के साथ जोड़ेंगे। आप अभी जिस रूम में हैं, उसकी भाषा नहीं बदलेगी।';

  @override
  String get settings_poolNoticeHiSoon =>
      'हिंदी और Hinglish रूम जल्द खुलेंगे, इसलिए अभी नए रूम आपको English बोलने वालों के साथ जोड़ेंगे।';

  @override
  String get sanctuary_title => 'सुकून';

  @override
  String get sanctuary_intro =>
      'सिर्फ़ आपके लिए एक शांत जगह। अपनी रफ़्तार से चलें। यहाँ किसी चीज़ का स्कोर नहीं होता।';

  @override
  String get sanctuary_todayTitle => 'आज का एक मिनट';

  @override
  String get sanctuary_breatheSection => 'साँस लें';

  @override
  String get sanctuary_breatheCard => 'अपने Aura के साथ साँस लें';

  @override
  String get sanctuary_breatheCardBody =>
      'शांत, बॉक्स या 4-7-8 ब्रीदिंग, जितनी देर मन हो।';

  @override
  String get sanctuary_groundingSection => 'ग्राउंडिंग';

  @override
  String get sanctuary_begin => 'शुरू करें';

  @override
  String get sanctuary_start => 'शुरू करें';

  @override
  String get sanctuary_pause => 'रोकें';

  @override
  String get sanctuary_resume => 'फिर से शुरू करें';

  @override
  String get sanctuary_finish => 'ख़त्म करें';

  @override
  String get sanctuary_next => 'आगे';

  @override
  String get sanctuary_progress => 'इस सेशन की प्रगति';

  @override
  String get sanctuary_progressBegun => 'अभी शुरू हुआ';

  @override
  String get sanctuary_progressHalf => 'लगभग आधा';

  @override
  String get sanctuary_progressNearly => 'लगभग पूरा';

  @override
  String get sanctuary_progressDone => 'पूरा हुआ';

  @override
  String habits_autoLogged(String habit) {
    return 'आज के लिए $habit को पूरा मार्क किया गया।';
  }

  @override
  String get breathe_rhythm => 'लय';

  @override
  String get breathe_calm => 'शांत';

  @override
  String get breathe_calmBody => '4 तक साँस अंदर, 6 तक बाहर। हल्की और एक-सी।';

  @override
  String get breathe_box => 'बॉक्स';

  @override
  String get breathe_boxBody => 'अंदर, रोकें, बाहर, रोकें। हर बार चार गिनती।';

  @override
  String get breathe_478 => '4-7-8';

  @override
  String get breathe_478Body => '4 तक अंदर, 7 तक रोकें, 8 तक बाहर।';

  @override
  String get breathe_lightHeaded =>
      'अगर चक्कर-सा लगे, तो रुकें और आम तरह से साँस लें।';

  @override
  String get breathe_length => 'कितनी देर';

  @override
  String breathe_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String get breathe_openEnded => 'जब तक मैं न रोकूँ';

  @override
  String get breathe_in => 'साँस अंदर लें';

  @override
  String get breathe_hold => 'रोकें';

  @override
  String get breathe_out => 'साँस बाहर छोड़ें';

  @override
  String get breathe_paused => 'रुका हुआ है। आराम से।';

  @override
  String get breathe_done => 'यह वक़्त सिर्फ़ आपके लिए था।';

  @override
  String get breathe_again => 'फिर से';

  @override
  String get breathe_land1 => 'अपने पैरों को ज़मीन पर महसूस करें।';

  @override
  String get breathe_land2 => 'आसपास की तीन आवाज़ों पर ध्यान दें।';

  @override
  String get breathe_keepGoing => 'जारी रखें';

  @override
  String get breathe_land3 => 'कंधों को ढीला छोड़ दें।';

  @override
  String get senses_title => 'पाँच इंद्रियाँ';

  @override
  String get senses_card => 'आसपास जो है, उसे एक-एक इंद्रिय से महसूस करें।';

  @override
  String get senses_intro =>
      'चलिए, आसपास जो है उसे एक-एक इंद्रिय से महसूस करें। अपनी रफ़्तार से चलें।';

  @override
  String get senses_see => 'पाँच चीज़ें जो आपको दिख रही हैं';

  @override
  String get senses_seeBody =>
      'धीरे-धीरे आसपास देखें। मन में या बोलकर उनके नाम लें।';

  @override
  String get senses_touch => 'चार चीज़ें जिन्हें आप छू सकें';

  @override
  String get senses_touchBody =>
      'नीचे की कुर्सी, आपके कपड़े, त्वचा को छूती हवा।';

  @override
  String get senses_hear => 'तीन आवाज़ें जो आपको सुनाई दे रही हैं';

  @override
  String get senses_hearBody => 'पास की या दूर की, तेज़ या धीमी।';

  @override
  String get senses_smell => 'दो चीज़ें जिनकी महक आ रही हो';

  @override
  String get senses_smellBody => 'या अगर पास कुछ न हो, तो दो पसंदीदा ख़ुशबुएँ।';

  @override
  String get senses_taste => 'एक चीज़ जिसका स्वाद महसूस हो';

  @override
  String get senses_tasteBody => 'या पानी का एक घूँट लें और उसे महसूस करें।';

  @override
  String senses_step(int step, int total) {
    return '$total में से स्टेप $step';
  }

  @override
  String get senses_done => 'आप यहाँ हैं, इसी पल में। बहुत अच्छा।';

  @override
  String get heart_title => 'दिल पर हाथ';

  @override
  String get heart_card => 'सिर्फ़ आपके लिए, एक मिनट की गर्माहट।';

  @override
  String get heart_intro => 'एक हाथ अपने दिल पर रखें, या जहाँ भी सुकून लगे।';

  @override
  String get heart_1 => 'अपने हाथ की गर्माहट महसूस करें।';

  @override
  String get heart_2 => 'धीरे से साँस लें। कोई जल्दी नहीं है।';

  @override
  String get heart_3 => 'यहाँ जो भी महसूस हो, उसकी जगह है।';

  @override
  String get heart_4 =>
      'ख़ुद के साथ उतनी ही नरमी रखें, जितनी किसी दोस्त के साथ।';

  @override
  String get heart_done => 'ख़ुद के साथ नरमी रखने के लिए शुक्रिया।';

  @override
  String get gratitude_title => 'तीन छोटी बातें';

  @override
  String get gratitude_card => 'आज की तीन छोटी बातें जो ठीक-ठाक रहीं।';

  @override
  String get gratitude_intro =>
      'आज की तीन छोटी बातें, एक-एक करके याद करें। कुछ लिखना नहीं है।';

  @override
  String get gratitude_1 => 'एक छोटी बात जो ठीक रही';

  @override
  String get gratitude_1Body =>
      'बहुत छोटी बात भी चलेगी, जैसे कुछ गरम पीना या किसी के मीठे बोल।';

  @override
  String get gratitude_2 => 'एक और छोटी बात';

  @override
  String get gratitude_2Body => 'कुछ जो आपने देखा, सुना या किया।';

  @override
  String get gratitude_3 => 'बस एक और छोटी बात';

  @override
  String get gratitude_3Body => 'शायद आपके अपने बारे में कुछ।';

  @override
  String get gratitude_done =>
      'इन्हें एक पल के लिए अपने पास रखें। ये आपकी हैं।';

  @override
  String get savour_intro =>
      'चलिए, आज के एक अच्छे पल को धीरे-धीरे फिर से जिएँ।';

  @override
  String get savour_1 => 'आज का एक अच्छा पल याद करें, चाहे कितना भी छोटा हो।';

  @override
  String get savour_2 => 'वह पल कहाँ का था? आसपास क्या दिख और सुनाई दे रहा था?';

  @override
  String get savour_3 => 'अब उसे याद करके कैसा लग रहा है, इस पर ध्यान दें।';

  @override
  String get savour_done => 'उसे थोड़ी देर और अपने साथ रहने दें।';

  @override
  String get minute_forYou => 'आपके लिए एक मिनट';

  @override
  String get minute_calmTitle => 'एक शांत मिनट';

  @override
  String get minute_boxTitle => 'बॉक्स ब्रीदिंग';

  @override
  String get minute_478Title => '4-7-8 ब्रीदिंग';

  @override
  String get minute_stillnessTitle => 'एक मिनट का ठहराव';

  @override
  String get minute_stillnessBody => 'ऑर्ब के साथ एक शांत मिनट।';

  @override
  String get minute_landTitle => 'ठहरने के लिए तीस सेकंड';

  @override
  String get minute_landBody => 'ऑर्ब के साथ तीन धीमी साँसें।';

  @override
  String get minute_comfortTitle => 'थोड़ा सुकून';

  @override
  String get minute_comfortBody => 'दिल पर एक हाथ, और एक मिनट की गर्माहट।';

  @override
  String get minute_savourTitle => 'इस पल को जिएँ';

  @override
  String get minute_savourBody => 'आज का एक अच्छा पल फिर से जिएँ।';

  @override
  String get companion_storm1 =>
      'एक साथ बहुत कुछ है। आपकी रोशनी अब भी यहीं है।';

  @override
  String get companion_storm2 =>
      'तूफ़ान को नाम देना हिम्मत की बात है। आपने अपना साथ दिया।';

  @override
  String get companion_storm3 =>
      'बड़ी, तेज़ भावनाओं के लिए यहाँ जगह है। आपके लिए भी।';

  @override
  String get companion_storm4 =>
      'तूफ़ानी दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया।';

  @override
  String get companion_storm5 =>
      'आपने इसे ईमानदारी से नाम दिया। यह मायने रखता है।';

  @override
  String get companion_storm6 => 'तूफ़ान भी आपके आसमान का हिस्सा है।';

  @override
  String get companion_storm7 =>
      'अंदर जो भी उमड़ रहा हो, आपने उसे पहचाना। इसकी अहमियत है।';

  @override
  String get companion_storm8 => 'तूफ़ान में भी, आपकी चमक आपकी अपनी है।';

  @override
  String get companion_rain1 =>
      'यह भारी लग रहा है। आपकी रोशनी अब भी आपके साथ है।';

  @override
  String get companion_rain2 =>
      'बुझे-से दिन के बारे में सच कहना हिम्मत की बात है। आपने अपना साथ दिया।';

  @override
  String get companion_rain3 =>
      'धीमी, भारी भावनाओं के लिए यहाँ जगह है। आपके लिए भी।';

  @override
  String get companion_rain4 =>
      'बारिश वाले दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया।';

  @override
  String get companion_rain5 => 'आज आपने ख़ुद से सच कहा। यह मायने रखता है।';

  @override
  String get companion_rain6 => 'बारिश भी आपके आसमान का हिस्सा है।';

  @override
  String get companion_rain7 =>
      'यह जितना भी भारी हो, आपने इसे पहचाना। इसकी अहमियत है।';

  @override
  String get companion_rain8 =>
      'बादलों वाले दिनों में भी, आपकी चमक आपकी अपनी है।';

  @override
  String get companion_moonlight1 =>
      'एक शांत, ठहरा हुआ पल। आपकी रोशनी आराम से है।';

  @override
  String get companion_moonlight2 =>
      'एक शांत पल को पहचानना भी मायने रखता है। आपने अपना साथ दिया।';

  @override
  String get companion_moonlight3 =>
      'नरम, हल्की भावनाओं के लिए यहाँ जगह है। आपके लिए भी।';

  @override
  String get companion_moonlight4 =>
      'सुकून भरे दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया।';

  @override
  String get companion_moonlight5 =>
      'आपने इसे महसूस करने के लिए एक पल लिया। यह मायने रखता है।';

  @override
  String get companion_moonlight6 => 'चाँदनी भी आपके आसमान का हिस्सा है।';

  @override
  String get companion_moonlight7 =>
      'यह सुकून जितना भी छोटा हो, आपने इसे पहचाना। इसकी अहमियत है।';

  @override
  String get companion_moonlight8 => 'इस ख़ामोशी में, आपकी चमक आपकी अपनी है।';

  @override
  String get companion_sunrise1 => 'एक रोशन पल। आपकी रोशनी चमक रही है।';

  @override
  String get companion_sunrise2 =>
      'एक अच्छे पल को पहचानना भी मायने रखता है। आपने अपना साथ दिया।';

  @override
  String get companion_sunrise3 =>
      'बड़ी, चमकती भावनाओं के लिए यहाँ जगह है। आपके लिए भी।';

  @override
  String get companion_sunrise4 =>
      'रोशन दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया।';

  @override
  String get companion_sunrise5 =>
      'आपने ख़ुद को यह महसूस करने दिया। यह मायने रखता है।';

  @override
  String get companion_sunrise6 => 'सूर्योदय भी आपके आसमान का हिस्सा है।';

  @override
  String get companion_sunrise7 =>
      'यह बड़ा हो या छोटा, आपने इसे पहचाना। इसकी अहमियत है।';

  @override
  String get companion_sunrise8 => 'इस उजाले में, आपकी चमक आपकी अपनी है।';

  @override
  String get companion_neutral1 => 'चेक-इन करने के लिए शुक्रिया।';

  @override
  String get companion_neutral2 => 'आपने अपना साथ दिया।';

  @override
  String get companion_neutral3 => 'आपकी रोशनी अब भी यहीं है।';

  @override
  String get companion_neutral4 => 'यहाँ कोई जल्दी नहीं है।';

  @override
  String get prompt_note1 => 'आज किस छोटी चीज़ से थोड़ी मदद मिली?';

  @override
  String get prompt_note2 => 'अभी मन में क्या चल रहा है?';

  @override
  String get prompt_note3 => 'आज की कौन-सी बात याद रखने का मन है?';

  @override
  String get prompt_storm1 =>
      'अभी मन में सबसे ज़्यादा जगह किस चीज़ ने घेरी है?';

  @override
  String get prompt_storm2 => 'अगर यह एहसास बोल पाता, तो क्या कहता?';

  @override
  String get prompt_storm3 =>
      'ऐसी कौन-सी एक चीज़ है जिसे एक मिनट के लिए ही सही, किनारे रखा जा सके?';

  @override
  String get prompt_rain1 => 'अभी क्या सुकून भरा लगेगा?';

  @override
  String get prompt_rain2 => 'आज मन पर क्या भारी है?';

  @override
  String get prompt_rain3 => 'हाल में किसकी या किस चीज़ की नरमी महसूस हुई?';

  @override
  String get prompt_moonlight1 => 'किस चीज़ से मन ठहरा हुआ लग रहा है?';

  @override
  String get prompt_moonlight2 => 'आज किस चीज़ ने दिन को थोड़ा नरम बनाया?';

  @override
  String get prompt_moonlight3 => 'इस पल से क्या अपने साथ रखने का मन है?';

  @override
  String get prompt_sunrise1 => 'आज किस चीज़ से मन खिल रहा है?';

  @override
  String get prompt_sunrise2 => 'क्या अच्छा रहा, जिसे याद रखने का मन है?';

  @override
  String get prompt_sunrise3 => 'यह किसके साथ बाँटने का मन है?';

  @override
  String get prompt_capsule1 => 'भविष्य के आप तक कौन-सी बात पहुँचानी है?';

  @override
  String get prompt_capsule2 =>
      'अभी किस चीज़ से मदद मिल रही है, जो शायद बाद में याद न रहे?';

  @override
  String get prompt_capsule3 => 'मुश्किल दिन पर ख़ुद से क्या कहना है?';

  @override
  String get prompt_capsuleStorm =>
      'जब सब कुछ बहुत ज़्यादा लगे, तब किस चीज़ से मदद मिलती है?';

  @override
  String get prompt_capsuleRain => 'भारी दिन पर क्या सुनने का मन होगा?';

  @override
  String get prompt_capsuleMoonlight =>
      'यह सुकून फिर से पाने में किस चीज़ से मदद मिलती है?';

  @override
  String get prompt_capsuleSunrise =>
      'भविष्य के आप के साथ किस बात का जश्न मनाने का मन है?';

  @override
  String get prompt_another => 'कोई और सवाल';

  @override
  String get prompt_settingsTitle => 'लिखने के लिए सवाल';

  @override
  String get prompt_settingsBody =>
      'खाली नोट में एक हल्का-सा सवाल। कभी सेव नहीं होता।';

  @override
  String get backfill_add => 'पिछला चेक-इन जोड़ें';

  @override
  String get backfill_pickTitle => 'कौन-सा दिन?';

  @override
  String backfill_pickBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'पिछले $count दिनों में से किसी भी दिन का चेक-इन जोड़ा जा सकता है।',
      one: 'कल के लिए चेक-इन जोड़ा जा सकता है।',
    );
    return '$_temp0';
  }

  @override
  String get backfill_title => 'उस दिन कैसा लग रहा था?';

  @override
  String backfill_forDay(String day) {
    return '$day का चेक-इन';
  }

  @override
  String get backfill_changeDay => 'दिन बदलें';

  @override
  String get backfill_outOfRange =>
      'पिछले चेक-इन सिर्फ़ एक हफ़्ते पीछे तक जोड़े जा सकते हैं। कोई और दिन चुनें?';

  @override
  String get backfill_savedTitle => 'आपके आसमान में जुड़ गया';

  @override
  String backfill_savedDay(String day) {
    return '$day के लिए सेव हो गया।';
  }

  @override
  String get backfill_savedBody =>
      'Starlight उसी दिन किए गए चेक-इन से मिलता है।';

  @override
  String get history_addedLater => 'बाद में जोड़ा गया';

  @override
  String history_whenAddedLater(String day) {
    return '$day · बाद में जोड़ा गया';
  }

  @override
  String get shell_tabHome => 'होम';

  @override
  String get shell_tabSanctuary => 'सुकून';

  @override
  String get shell_tabRooms => 'रूम';

  @override
  String get shell_tabInsights => 'समझ';

  @override
  String get shell_checkIn => 'चेक-इन';

  @override
  String get shell_checkInHint => 'नया चेक-इन शुरू करता है';

  @override
  String get safety_emergencyWhen =>
      'अगर आपको या आपके आसपास किसी को तुरंत खतरा है, गंभीर चोट लगी है, या सुरक्षित रह पाना मुश्किल है, तो तुरंत इमरजेंसी सेवाओं को कॉल करें।';

  @override
  String get safety_settingsLink => 'सेटिंग्स में मदद और सुरक्षा';

  @override
  String get safety_settingsHint => 'सपोर्ट संपर्क, शिकायत अधिकारी और नीतियाँ';

  @override
  String get sounds_title => 'आवाज़ें';

  @override
  String get sounds_cardBody =>
      'बारिश, समुद्र, हवा और भी बहुत कुछ। जब तक आप न चुनें, कुछ नहीं बजता।';

  @override
  String get sounds_cardPlaying => 'अभी बज रहा है';

  @override
  String get sounds_intro =>
      'शुरू करने के लिए एक आवाज़ चुनें, या चार तक मिलाएँ। जब तक आप टैप न करें, कुछ नहीं बजता।';

  @override
  String get sounds_nothingPlaying => 'कुछ नहीं बज रहा';

  @override
  String get sounds_statePlaying => 'बज रहा है';

  @override
  String get sounds_statePaused => 'रुका हुआ';

  @override
  String get sounds_backgroundNote =>
      'स्क्रीन बंद होने पर भी आवाज़ें बजती रहती हैं। हेडफ़ोन डिसकनेक्ट होने या कॉल आने पर ये रुक जाती हैं।';

  @override
  String get sounds_notificationChannel => 'आवाज़ों का प्लेबैक';

  @override
  String get sounds_windDownTitle => 'रात का सुकून';

  @override
  String get sounds_windDownBody =>
      'लगभग 20 मिनट की आवाज़ें, जो धीरे-धीरे कम होकर ख़ामोशी में बदल जाती हैं। हर रात इनका क्रम बदलता है।';

  @override
  String get sounds_windDownBegin => 'रात का सुकून शुरू करें';

  @override
  String sounds_windDownLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'लगभग $minutes मिनट बाक़ी',
      one: 'लगभग 1 मिनट बाक़ी',
    );
    return '$_temp0';
  }

  @override
  String get sounds_windDownBusy =>
      'रात का सुकून चल रहा है। अपना मिक्स बनाने के लिए पहले इसे रोकें।';

  @override
  String get sounds_mixSection => 'अपना मिक्स बनाएँ';

  @override
  String get sounds_mixHint => 'एक साथ चार तक, हर एक का अपना वॉल्यूम।';

  @override
  String get sounds_stemRain => 'बारिश';

  @override
  String get sounds_stemOcean => 'समुद्र';

  @override
  String get sounds_stemWind => 'हवा';

  @override
  String get sounds_stemNightInsects => 'रात के झींगुर';

  @override
  String get sounds_stemSingingBowl => 'सिंगिंग बाउल';

  @override
  String get sounds_stemChimes => 'घंटियाँ';

  @override
  String get sounds_stemBrownNoise => 'ब्राउन नॉइज़';

  @override
  String get sounds_stemPinkNoise => 'पिंक नॉइज़';

  @override
  String get sounds_stemDeepBell => 'दूर की घंटी';

  @override
  String get sounds_stemMonsoonRoof => 'छत पर बरसात';

  @override
  String get sounds_stemStream => 'बहती धारा';

  @override
  String get sounds_stemFireplace => 'अलाव';

  @override
  String get sounds_stemDistantThunder => 'दूर की गरज';

  @override
  String sounds_stemOn(String name, int percent) {
    return '$name, बज रहा है, वॉल्यूम $percent%';
  }

  @override
  String sounds_stemPaused(String name, int percent) {
    return '$name, रुका हुआ, वॉल्यूम $percent%';
  }

  @override
  String sounds_stemOff(String name) {
    return '$name, बंद';
  }

  @override
  String sounds_stemLocked(String name) {
    return '$name, Aura Plus का हिस्सा';
  }

  @override
  String sounds_stemNeedsDownload(String name, String size) {
    return '$name, एक बार $size डाउनलोड करना है';
  }

  @override
  String sounds_stemDownloading(String name) {
    return '$name, डाउनलोड हो रहा है';
  }

  @override
  String sounds_volume(String name) {
    return '$name का वॉल्यूम';
  }

  @override
  String get sounds_plusBadge => 'Aura Plus';

  @override
  String get sounds_plusNote => 'Aura Plus के साथ मिलता है।';

  @override
  String get sounds_full =>
      'चार आवाज़ें बज रही हैं। नई जोड़ने के लिए एक बंद करें।';

  @override
  String get sounds_play => 'चलाएँ';

  @override
  String get sounds_pause => 'रोकें';

  @override
  String get sounds_stop => 'बंद करें';

  @override
  String get sounds_timer => 'टाइमर';

  @override
  String get sounds_timerTitle => 'कितनी देर बाद धीरे-धीरे बंद हो';

  @override
  String get sounds_timerOff => 'बंद';

  @override
  String sounds_timerValue(String value) {
    return 'टाइमर · $value';
  }

  @override
  String sounds_timerLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'लगभग $minutes मिनट में धीरे-धीरे बंद होगा',
      one: 'लगभग 1 मिनट में धीरे-धीरे बंद होगा',
    );
    return '$_temp0';
  }

  @override
  String get sounds_fadingOut => 'धीरे-धीरे बंद हो रहा है';

  @override
  String get sounds_saveMix => 'यह मिक्स सेव करें';

  @override
  String get sounds_savedMixes => 'सेव किए गए मिक्स';

  @override
  String get sounds_mixSaved => 'इस फ़ोन पर सेव हो गया।';

  @override
  String get sounds_mixAlreadySaved => 'यह मिक्स पहले से सेव है।';

  @override
  String sounds_playMix(String mix) {
    return '$mix चलाएँ';
  }

  @override
  String sounds_removeMix(String mix) {
    return '$mix हटाएँ';
  }

  @override
  String get sounds_mixUnavailable => 'यह मिक्स अभी नहीं चल सकता।';

  @override
  String get sounds_downloadTitle => 'रिकॉर्ड की गई आवाज़ें';

  @override
  String sounds_downloadBody(String size) {
    return 'एक बार $size डाउनलोड करना है। उसके बाद ये बिना इंटरनेट के बजती हैं। तब तक आपके फ़ोन पर बनी आवाज़ें बजती हैं।';
  }

  @override
  String get sounds_download => 'डाउनलोड करें';

  @override
  String get sounds_downloading => 'डाउनलोड हो रहा है…';

  @override
  String get sounds_downloadOffline =>
      'आप ऑफ़लाइन हैं। ब्राउन नॉइज़ और आपके फ़ोन पर बनी आवाज़ें अभी बजती हैं; रिकॉर्डिंग बाद में डाउनलोड करना मुमकिन है।';

  @override
  String get sounds_downloadFailed =>
      'डाउनलोड पूरा नहीं हुआ। कुछ नहीं खोया; बाद में फिर से डाउनलोड करना मुमकिन है।';

  @override
  String sounds_noSpace(String size) {
    return 'आवाज़ों के लिए लगभग $size जगह चाहिए। थोड़ी जगह ख़ाली करें, या ब्राउन नॉइज़ चलाएँ, जिसे जगह की ज़रूरत नहीं।';
  }

  @override
  String sounds_megabytes(String size) {
    return '$size MB';
  }

  @override
  String get sounds_removeDownloads => 'डाउनलोड की गई आवाज़ें हटाएँ';

  @override
  String get sounds_downloadsRemoved =>
      'डाउनलोड की गई आवाज़ें हटा दी गईं। आपके फ़ोन पर बनी आवाज़ें अब भी बजती हैं।';

  @override
  String get update_title => 'कृपया Aura अपडेट करें';

  @override
  String get update_body =>
      'Aura को आगे चलाने के लिए इसे अपडेट करना ज़रूरी है। बस एक पल लगेगा।';

  @override
  String get update_safe =>
      'इस फ़ोन पर सब कुछ सुरक्षित रहेगा। अपडेट होते ही आपके चेक-इन सिंक हो जाएँगे।';

  @override
  String get update_openAppStore => 'App Store में अपडेट करें';

  @override
  String get update_openPlayStore => 'Google Play पर अपडेट करें';

  @override
  String get update_storeFailed =>
      'स्टोर नहीं खुला। कृपया खुद खोलकर Aura खोजें।';

  @override
  String get voice_record => 'वॉइस नोट रिकॉर्ड करें';

  @override
  String get voice_recordHint => 'एक मिनट तक। यह सिर्फ़ आपको सुनाई देगा।';

  @override
  String get voice_rationaleTitle => 'अपनी आवाज़ जोड़ें?';

  @override
  String get voice_rationaleBody =>
      'वॉइस नोट रिकॉर्ड करने के लिए Aura को आपका माइक्रोफ़ोन चाहिए। रिकॉर्डिंग सिर्फ़ आपके पास रहती हैं और रूम में कभी शेयर नहीं होतीं।';

  @override
  String get voice_rationaleAllow => 'अनुमति दें';

  @override
  String get voice_denied =>
      'आवाज़ बंद है। इसकी जगह टाइप करें, या सेटिंग्स में इसे चालू करें।';

  @override
  String get voice_openSettings => 'सेटिंग्स';

  @override
  String get voice_recording => 'रिकॉर्ड हो रहा है';

  @override
  String voice_elapsed(String time, String limit) {
    return '$time · $limit तक';
  }

  @override
  String voice_recordingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'रिकॉर्ड हो रहा है, $seconds सेकंड',
      one: 'रिकॉर्ड हो रहा है, 1 सेकंड',
    );
    return '$_temp0';
  }

  @override
  String get voice_stop => 'रिकॉर्डिंग रोकें';

  @override
  String get voice_started => 'रिकॉर्डिंग शुरू हुई';

  @override
  String voice_recorded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'वॉइस नोट रिकॉर्ड हुआ, $seconds सेकंड',
      one: 'वॉइस नोट रिकॉर्ड हुआ, 1 सेकंड',
    );
    return '$_temp0';
  }

  @override
  String get voice_limitReached =>
      'पूरा एक मिनट हो गया, इसलिए रिकॉर्डिंग रुक गई। आपका वॉइस नोट तैयार है।';

  @override
  String get voice_recordFailed =>
      'अभी आवाज़ रिकॉर्ड नहीं हो पाई। आपका लिखा हुआ फिर भी सेव होगा।';

  @override
  String get voice_note => 'वॉइस नोट';

  @override
  String voice_length(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds सेकंड',
      one: '1 सेकंड',
    );
    return '$_temp0';
  }

  @override
  String get voice_play => 'वॉइस नोट चलाएँ';

  @override
  String get voice_pause => 'वॉइस नोट रोकें';

  @override
  String get voice_reRecord => 'फिर से रिकॉर्ड करें';

  @override
  String get voice_remove => 'हटाएँ';

  @override
  String get voice_removeSemantic => 'वॉइस नोट हटाएँ';

  @override
  String get voice_dropped =>
      'आपका चेक-इन सेव हो गया है। वॉइस नोट नहीं रखा जा सका, शायद फ़ोन में जगह कम है।';

  @override
  String get voice_loading => 'आपका वॉइस नोट लाया जा रहा है…';

  @override
  String get voice_offline => 'फिर से ऑनलाइन होने पर वॉइस नोट चलेगा।';

  @override
  String get voice_failed =>
      'यह वॉइस नोट अभी चल नहीं पाया। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get voice_section => 'आपकी आवाज़';

  @override
  String get voice_hasVoice => 'इसमें वॉइस नोट है';

  @override
  String get widget_prompt => 'अभी कैसा लग रहा है?';

  @override
  String get widget_checkIn => 'चेक-इन';

  @override
  String get widget_doneToday => 'आज चेक-इन हो गया';

  @override
  String get widget_saved => 'सेव हो गया';

  @override
  String widget_savedStarlight(int amount) {
    return 'सेव हो गया · +$amount Starlight';
  }

  @override
  String get widget_needHelp => 'मदद चाहिए';

  @override
  String get widget_openApp => 'आगे बढ़ने के लिए Aura खोलें';

  @override
  String get widget_openAppDiscreet => 'आगे बढ़ने के लिए ऐप खोलें';

  @override
  String get widget_capsuleWaiting => 'बीते समय के आप से कुछ इंतज़ार में है';

  @override
  String get widget_back => 'वापस';

  @override
  String widget_lastMood(String mood) {
    return 'पिछला: $mood';
  }

  @override
  String get widget_galleryName => 'Aura चेक-इन';

  @override
  String get widget_galleryDescription =>
      'होम स्क्रीन से ही दो टैप में चेक-इन करें।';

  @override
  String get widget_lockGalleryName => 'झटपट चेक-इन';

  @override
  String get widget_lockGalleryDescription =>
      'एक तारा जो आपका चेक-इन खोलता है। यह कभी नहीं दिखाता कि आपका मन कैसा है।';

  @override
  String get widget_settingsTitle => 'होम स्क्रीन विजेट';

  @override
  String get widget_showLastMood => 'मेरा पिछला मूड दिखाएँ';

  @override
  String get widget_showLastMoodNote =>
      'सिर्फ़ आपकी होम स्क्रीन पर। लॉक स्क्रीन पर यह कभी नहीं दिखता।';

  @override
  String get widget_discreet => 'सादा विजेट';

  @override
  String get widget_discreetNote =>
      'बिना ऐप के नाम और बिना मूड वाले शब्दों का एक सादा तारा। इसे टैप करने पर ऐप खुलता है।';

  @override
  String get habits_commitmentsTitle => 'संकल्प';

  @override
  String get habits_commitmentsBody =>
      'जिन आदतों को आप अपने पास रखना चाहते हैं, उन्हें चुनें। कुछ दिन छूट जाएँ तो आपकी दुनिया में उस आदत का पौधा आराम करता है। एक लॉग उसे जगा देता है। आपकी Starlight और glow days को कभी कुछ नहीं होता।';

  @override
  String get habits_commitmentSwitch => 'संकल्प की तरह लें';

  @override
  String habits_pauseSemantic(String name) {
    return '$name को विराम दें';
  }

  @override
  String habits_pausedUntil(String date) {
    return '$date तक विराम';
  }

  @override
  String habits_pauseDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '$count दिन',
    );
    return '$_temp0';
  }

  @override
  String get habits_pauseEnd => 'विराम खत्म करें';

  @override
  String get universe_yourPlants => 'आपके पौधे';

  @override
  String universe_plantsResting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पौधे आराम कर रहे हैं। हर एक को एक लॉग जगा देता है।',
      one: 'एक पौधा आराम कर रहा है। एक लॉग उसे जगा देता है।',
    );
    return '$_temp0';
  }

  @override
  String get universe_stage_seed => 'बीज';

  @override
  String get universe_stage_sprout => 'अंकुर';

  @override
  String get universe_stage_young => 'बढ़ता हुआ';

  @override
  String get universe_stage_grown => 'पूरा बढ़ा';

  @override
  String get universe_stage_flourishing => 'हरा-भरा';

  @override
  String get universe_stage_ancient => 'प्राचीन';

  @override
  String get universe_vitality_dimmed => 'आराम में';

  @override
  String get universe_vitality_wilting => 'थोड़ा झुका हुआ';

  @override
  String get universe_vitality_dormant => 'सो रहा है, आपका इंतज़ार कर रहा है';

  @override
  String universe_plantRow(String name, String stage) {
    return '$name, $stage';
  }

  @override
  String universe_plantRowResting(String name, String stage, String state) {
    return '$name, $stage, $state';
  }
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class AppLocalizationsHiLatn extends AppLocalizationsHi {
  AppLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get appTitle => 'Aura';

  @override
  String get common_continue => 'Aage badhein';

  @override
  String get common_back => 'Wapas';

  @override
  String get common_done => 'Ho gaya';

  @override
  String get common_notNow => 'Abhi nahi';

  @override
  String get common_cancel => 'Cancel karein';

  @override
  String get common_close => 'Band karein';

  @override
  String get common_comingSoon => 'Jald aa raha hai';

  @override
  String get help_button => 'Mujhe abhi madad chahiye';

  @override
  String get help_title => 'Madad yahan hai';

  @override
  String get help_subtitle =>
      'Aapko ise akele nahi sehna hai. Abhi kisi se contact karein, ya ek minute ruk kar saans lein.';

  @override
  String get help_crisisTitle => 'Lagta hai abhi bahut kuch chal raha hai.';

  @override
  String get help_crisisSubtitle =>
      'Aapko ise akele nahi sehna hai. Aapka check-in save ho gaya hai.';

  @override
  String get help_teleManas => 'Tele-MANAS · free, 24×7';

  @override
  String get help_teleManasTollFree => 'Tele-MANAS toll-free';

  @override
  String get help_emergency112 => 'Emergency';

  @override
  String get help_childline => 'Childline · 18 se kam umar walon ke liye';

  @override
  String get help_us988 => 'Suicide & Crisis Lifeline · call ya text karein';

  @override
  String get help_otherEmergency =>
      'Agar aap abhi khatre mein hain, to please apne local emergency number par call karein.';

  @override
  String help_callSemantic(String name, String number) {
    return '$name ko call karein, $number';
  }

  @override
  String get help_groundingTitle => 'Thehrne ke liye sixty seconds';

  @override
  String get help_groundingBody =>
      'Circle ke saath saans lein. Baaki sab ek minute ruk sakta hai.';

  @override
  String get help_groundingStart => 'Shuru karein';

  @override
  String get help_groundingPause => 'Rokein';

  @override
  String get help_groundingResume => 'Phir se shuru karein';

  @override
  String get help_breatheIn => 'Saans andar lein';

  @override
  String get help_breatheOut => 'Saans bahar chhodein';

  @override
  String get help_ground1 => 'Zameen par apne pairon ko mehsoos karein.';

  @override
  String get help_ground2 =>
      'Aas-paas dikhne wali paanch cheezon par dhyaan dein.';

  @override
  String get help_ground3 => 'Aas-paas ki teen awaazon par dhyaan dein.';

  @override
  String get help_ground4 => 'Apne kandhon ko dheela chhod dein.';

  @override
  String get help_ground5 => 'Aap yahan hain. Abhi ke liye itna kaafi hai.';

  @override
  String get help_groundingDone =>
      'Bahut accha. Jitni der zaroorat ho, yahin rahein.';

  @override
  String help_secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds baaki',
      one: '1 second baaki',
    );
    return '$_temp0';
  }

  @override
  String get help_disclaimer =>
      'Aura koi medical device ya emergency service nahi hai.';

  @override
  String get help_backToCheckin => 'Mere check-in par wapas';

  @override
  String get welcome_title => 'Aura mein aapka swagat hai';

  @override
  String get welcome_body =>
      'Apne mann ka haal dekhne ki ek shaant jagah. Aapke check-ins private rehte hain, aur har baar aapke aane par aapka Aura thoda badhta hai.';

  @override
  String get welcome_begin => 'Shuru karein';

  @override
  String get dob_title => 'Aapka birthday kab hai?';

  @override
  String get dob_body =>
      'Yeh hum sabse poochhte hain. Yeh private rehta hai aur kisi ko kabhi nahi dikhaya jaata.';

  @override
  String get dob_day => 'Din';

  @override
  String get dob_month => 'Mahina';

  @override
  String get dob_year => 'Saal';

  @override
  String get dob_invalid => 'Aisi koi date nahi hoti. Ek baar check kar lein?';

  @override
  String get dob_future =>
      'Yeh date abhi aayi nahi hai. Ek baar check kar lein?';

  @override
  String get blocked_title =>
      'Aura 13 saal aur usse zyada umar ke logon ke liye bana hai.';

  @override
  String get blocked_body => 'Tab aapse milkar humein bahut khushi hogi.';

  @override
  String get blocked_helpIndia =>
      'Agar abhi kisi se baat karne ka mann hai, to Childline 1098 par free hai. Emergency mein 112 par call karein.';

  @override
  String get blocked_helpOther =>
      'Agar abhi kisi se baat karne ka mann hai, to please kisi aise bade se baat karein jis par aapko bharosa ho.';

  @override
  String get language_title => 'Kaun si bhasha apni si lagti hai?';

  @override
  String get language_body => 'Ise Settings mein kabhi bhi badla ja sakta hai.';

  @override
  String get language_teLatnHint => 'Telugu, English letters mein';

  @override
  String get language_hiLatnHint => 'Hindi, English letters mein';

  @override
  String get language_beta => 'Beta';

  @override
  String get signin_title => 'Apne Aura ko safe rakhein';

  @override
  String get signin_body =>
      'Apne email se sign in karein, taaki naye phone mein bhi aapka Aura aapke saath rahe. Na naam, na phone number, na password.';

  @override
  String get signin_emailLabel => 'Email';

  @override
  String get signin_sendCode => 'Mujhe email par code bhejein';

  @override
  String signin_codeSent(String email) {
    return 'Humne $email par 6-digit code bheja hai. Chahein to us email ke link par bhi tap karein.';
  }

  @override
  String get signin_codeLabel => '6-digit code';

  @override
  String get signin_verify => 'Aage badhein';

  @override
  String get signin_resend => 'Naya code bhejein';

  @override
  String get signin_changeEmail => 'Doosra email use karein';

  @override
  String get signin_error =>
      'Yeh ho nahi paaya. Phir se try karein, ya kisi aur tareeke se sign in karein.';

  @override
  String get signin_codeExpired =>
      'Is code ka time khatam ho gaya hai. Hum naya code bhej denge.';

  @override
  String get signin_invalidCode =>
      'Yeh code match nahi ho raha. Ek baar check kar lein?';

  @override
  String get signin_invalidEmail => 'Yeh email kuch sahi nahi lag raha.';

  @override
  String get signin_apple => 'Apple ke saath continue karein';

  @override
  String get signin_google => 'Google ke saath continue karein';

  @override
  String get signin_offline =>
      'Aap offline hain. Abhi apna pehla mood chunein. Connect hone par hum setup poora kar denge.';

  @override
  String get signin_offlineContinue => 'Abhi check-in karein';

  @override
  String get signin_unavailable =>
      'Is build mein sign-in abhi set nahi hua hai. Filhaal aapke check-ins isi phone par rahenge.';

  @override
  String get signin_continueLocal => 'Isi phone par aage badhein';

  @override
  String get checkin_title => 'Abhi kaisa lag raha hai?';

  @override
  String get checkin_subtitle =>
      'Jo sabse kareeb lage, use chunein. Koi jawaab galat nahi hai.';

  @override
  String get checkin_moreEnergy => 'Zyada energy';

  @override
  String get checkin_lessEnergy => 'Kam energy';

  @override
  String get checkin_pleasant => 'Pleasant';

  @override
  String get checkin_unpleasant => 'Unpleasant';

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
  String get semantic_highEnergy => 'zyada energy';

  @override
  String get semantic_lowEnergy => 'kam energy';

  @override
  String get semantic_pleasant => 'pleasant';

  @override
  String get semantic_unpleasant => 'unpleasant';

  @override
  String get checkin_addDetails => 'Koi tag ya kuch shabd jodein';

  @override
  String get checkin_tagsTitle => 'Yeh kis baare mein hai?';

  @override
  String get tag_study => 'Padhai';

  @override
  String get tag_work => 'Kaam';

  @override
  String get tag_family => 'Family';

  @override
  String get tag_friends => 'Dost';

  @override
  String get tag_sleep => 'Neend';

  @override
  String get tag_health => 'Health';

  @override
  String get tag_money => 'Paisa';

  @override
  String get tag_love => 'Pyaar';

  @override
  String get tag_alone => 'Akele';

  @override
  String get tag_commute => 'Aana-jaana';

  @override
  String get checkin_customTag => 'Apna tag';

  @override
  String get checkin_customTagAdd => 'Tag jodein';

  @override
  String get checkin_noteLabel => 'Chahein to kuch shabd';

  @override
  String get checkin_noteHint => 'Yeh sirf aapko dikhega.';

  @override
  String get checkin_save => 'Save karein';

  @override
  String get checkin_saveFailed =>
      'Yeh save nahi ho paaya. Shayad aapke phone mein jagah kam hai.';

  @override
  String checkin_savedStarlight(int amount) {
    return '+$amount Starlight';
  }

  @override
  String get checkin_saved => 'Save ho gaya';

  @override
  String get checkin_savedOffline => 'Is phone par save ho gaya';

  @override
  String get checkin_savedThanks => 'Check-in karne ke liye shukriya.';

  @override
  String get checkin_savedFull =>
      'Aaj ki saari Starlight mil chuki hai. Aapka check-in phir bhi count hota hai.';

  @override
  String get checkin_roomButton =>
      'Aisa hi mehsoos karne walon ke room mein judein';

  @override
  String get home_checkIn => 'Check-in karein';

  @override
  String home_todayStarlight(int count) {
    return 'Aaj $count Starlight';
  }

  @override
  String home_totalStarlight(int count) {
    return 'Kul $count';
  }

  @override
  String get home_empty =>
      'Yeh aapka Aura hai. Ise roshni dene ke liye check-in karein.';

  @override
  String get home_resting =>
      'Aapka Aura kuch time se aaram kar raha hai. Jab mann ho, hi keh dein.';

  @override
  String home_glowStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Glow streak · $count din',
      one: 'Glow streak · 1 din',
    );
    return '$_temp0';
  }

  @override
  String home_restDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rest days jama hain',
      one: '1 rest day jama hai',
      zero: 'Abhi koi rest day jama nahi hai',
    );
    return '$_temp0';
  }

  @override
  String get home_restingSafe => 'Aaram · aapka glow safe hai';

  @override
  String get home_glowCarriesOn => 'Aapka glow jaari hai';

  @override
  String home_lifetimeGlow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kul $count glow days',
      one: 'Kul 1 glow day',
    );
    return '$_temp0';
  }

  @override
  String get home_habitsTitle => 'Aaj ki chhoti-chhoti cheezein';

  @override
  String home_habitDone(String habit) {
    return '$habit, aaj ho gaya';
  }

  @override
  String home_habitNotYet(String habit) {
    return '$habit, aaj abhi nahi';
  }

  @override
  String get home_offline =>
      'Aap offline hain. Aapki apni cheezein phir bhi yahan save hoti rahengi.';

  @override
  String get home_finishSetup =>
      'Setup poora karein, taaki aapka Aura safe rahe.';

  @override
  String get home_signIn => 'Sign in karein';

  @override
  String get home_syncIdle => 'Sab save ho gaya';

  @override
  String home_syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cheezein sync honi baaki hain',
      one: '1 cheez sync honi baaki hai',
    );
    return '$_temp0';
  }

  @override
  String get home_syncLocal => 'Is phone par save ho gaya';

  @override
  String get home_settings => 'Settings';

  @override
  String get home_welcomeBack =>
      'Phir se swagat hai. Aaj ek chhoti si cheez hi kaafi hai.';

  @override
  String home_evolved(String stage) {
    return 'Aapka Aura badhkar $stage ban gaya.';
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
  String get habit_hydrate => 'Paani peena';

  @override
  String get habit_sleep_on_time => 'Time par sona';

  @override
  String get habit_move => 'Chalna-phirna';

  @override
  String get habit_breathe => 'Saans lena';

  @override
  String get habit_journal => 'Diary likhna';

  @override
  String get habit_go_outside => 'Bahar jaana';

  @override
  String avatar_semantic(String stage, String hue) {
    return 'Aapka Aura, $stage stage, $hue glow';
  }

  @override
  String get avatar_semanticResting => 'naram nebula mein aaram karta hua';

  @override
  String avatar_semanticRings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'chaaron taraf ghoomti $count roshniyan',
      one: 'chaaron taraf ghoomti ek roshni',
    );
    return '$_temp0';
  }

  @override
  String avatar_semanticStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'iske constellation mein $count taare',
      one: 'iske constellation mein ek taara',
    );
    return '$_temp0';
  }

  @override
  String get hue_gold => 'sunehra';

  @override
  String get hue_green => 'hara';

  @override
  String get hue_teal => 'teal';

  @override
  String get hue_silverBlue => 'silver-blue';

  @override
  String get hue_violet => 'baingani';

  @override
  String get hue_rose => 'gulaabi';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_language => 'Bhasha';

  @override
  String get settings_account => 'Account';

  @override
  String settings_signedInAs(String email) {
    return '$email se sign in hai';
  }

  @override
  String get settings_signOut => 'Sign out karein';

  @override
  String settings_signOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cheezein abhi sync nahi hui hain. Unke sync hone tak sign in rahein?',
      one: '1 cheez abhi sync nahi hui hai. Uske sync hone tak sign in rahein?',
    );
    return '$_temp0';
  }

  @override
  String get settings_stay => 'Sign in rahein';

  @override
  String get settings_signOutAnyway => 'Phir bhi sign out karein';

  @override
  String get settings_signIn => 'Apna Aura safe rakhne ke liye sign in karein';

  @override
  String get settings_avatarLab => 'Avatar lab';

  @override
  String get settings_about => 'About';

  @override
  String settings_version(String version) {
    return 'Version $version';
  }

  @override
  String get push_title => 'Har shaam ek halka sa reminder chahiye?';

  @override
  String get push_body =>
      'Din mein zyada se zyada ek, aur streaks ke baare mein kabhi nahi. Aapki lock screen par kabhi nahi dikhega ki aapka mann kaisa hai.';

  @override
  String get push_allow => 'Allow karein';

  @override
  String get signin_busy => 'Ek pal';

  @override
  String signin_resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds second mein naya code maanga ja sakta hai',
      one: '1 second mein naya code maanga ja sakta hai',
    );
    return '$_temp0';
  }

  @override
  String get signin_freshSent => 'Naya code aa raha hai.';

  @override
  String get acct_pendingTitle => 'Apna account rakhna hai?';

  @override
  String acct_pendingBody(String date) {
    return 'Aapka account $date ko delete hona tay hai. Kya ise rakhna hai?';
  }

  @override
  String get acct_pendingBodySoon =>
      'Aapka account jald hi delete hona tay hai. Kya ise rakhna hai?';

  @override
  String get acct_keep => 'Mera account rakhein';

  @override
  String get acct_letGo => 'Jaane dein';

  @override
  String get acct_keepFailed =>
      'Yeh nahi ho paaya, isliye abhi kuch nahi badla hai. Connect hone par phir se try karein.';

  @override
  String get acct_deleteTitle => 'Mera account delete karein';

  @override
  String get acct_deleteIntro => 'Account delete karne par yeh sab hat jayega:';

  @override
  String get acct_itemCheckIns => 'Aapke check-ins aur notes';

  @override
  String get acct_itemHabits => 'Aapki habits';

  @override
  String get acct_itemProgress => 'Aapka Starlight aur aapke Aura ki growth';

  @override
  String get acct_itemAccount => 'Aapka account aur sign in wala email';

  @override
  String get acct_grace =>
      'Mann badalne ke liye aapke paas 7 din hain. Usse pehle phir se sign in karein, to sab kuch bana rahega. Uske baad yeh hamesha ke liye delete ho jayega aur wapas nahi laaya ja sakega.';

  @override
  String get acct_store =>
      'Agar kisi subscription ka payment App Store ya Google Play se hota hai, to account delete karne se woh cancel nahi hota. Use apne store ki subscription settings mein manage ya cancel karein.';

  @override
  String get acct_phone =>
      'Yeh phone turant clear ho jayega aur isse sign out ho jayega.';

  @override
  String get acct_needsConnection =>
      'Account delete karne ke liye connection chahiye. Internet se connect karke phir se try karein.';

  @override
  String get acct_confirmTitle => 'Apna account delete karein?';

  @override
  String get acct_confirmBody =>
      'Aapka account aur usmein maujood sab kuch 7 din mein delete ho jayega. Ise rakhna ho to usse pehle phir se sign in karein. Yeh phone abhi clear ho jayega.';

  @override
  String get acct_failed =>
      'Yeh nahi ho paaya, aur kuch bhi delete nahi hua hai. Thodi der mein phir se try karein.';

  @override
  String get acct_failedOffline =>
      'Aura tak pahuncha nahi ja saka, aur kuch bhi delete nahi hua hai. Apna connection check karein aur phir se try karein.';

  @override
  String get acct_retry => 'Phir se try karein';

  @override
  String get acct_scheduledTitle => 'Aapka account delete hona tay ho gaya hai';

  @override
  String acct_scheduledBody(String date) {
    return 'Yeh $date ko delete ho jayega. Ise rakhna ho to usse pehle phir se sign in karein.';
  }

  @override
  String get acct_phoneCleared =>
      'Yeh phone clear kar diya gaya hai aur isse sign out ho gaya hai.';

  @override
  String get acct_signedOut =>
      'Abhi sign in nahi hai, isliye delete karne ke liye koi account nahi hai. Aapka save kiya hua sab kuch sirf isi phone par hai.';

  @override
  String get acct_unavailable =>
      'Is build mein account delete karne ki suvidha set nahi hai.';

  @override
  String get set_comfort => 'Comfort';

  @override
  String get set_reduceMotion => 'Motion kam karein';

  @override
  String get set_reduceMotionNote =>
      'Aapke phone ki setting ko bhi follow karta hai';

  @override
  String get set_haptics => 'Haptics';

  @override
  String get set_hapticsNote => 'Kuch chunne par halka vibration';

  @override
  String get set_hideStreak => 'Streak number chhupayein';

  @override
  String get set_hideStreakNote =>
      'Aapka glow badhta rahega. Bas Home par din nahi gine jayenge.';

  @override
  String get set_signOutTitle => 'Aura se sign out karein?';

  @override
  String get set_helpSafety => 'Help & Safety';

  @override
  String get set_grievanceOfficer => 'Grievance Officer';

  @override
  String get set_grievanceSubject => 'Aura ke baare mein shikayat';

  @override
  String get set_contactSupport => 'Support se contact karein';

  @override
  String get set_supportSubject => 'Aura support';

  @override
  String get set_opensEmail => 'Aapka email app khulega';

  @override
  String set_emailFailed(String email) {
    return 'Koi email app nahi khul paaya. $email par likhein.';
  }

  @override
  String get acct_inProgress =>
      'Is account ko delete karne ka kaam shuru ho chuka hai, isliye ab ise rakha nahi ja sakta. Yeh phone clear ho jayega aur isse sign out ho jayega.';

  @override
  String get signin_or => 'ya';

  @override
  String get signin_socialNotReady =>
      'Sign-in ka yeh option abhi ready nahi hai. Filhaal apna email use karein.';

  @override
  String get signin_socialOffline =>
      'Lagta hai aap offline hain. Connect hone par phir se try karein.';

  @override
  String get capsules_title => 'Future you';

  @override
  String get capsules_emptyBody =>
      'Future you ke liye kuch likhein. Ise kisi date ke liye seal karein, ya kisi feeling ke liye.';

  @override
  String get capsules_emptyCta => 'Apna pehla capsule seal karein';

  @override
  String get capsules_new => 'Capsule likhein';

  @override
  String capsules_entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules seal hain',
      one: '1 capsule seal hai',
      zero: 'Abhi kuch seal nahi hua',
    );
    return '$_temp0';
  }

  @override
  String capsules_entryReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khulne ke liye taiyaar hain',
      one: '1 khulne ke liye taiyaar hai',
    );
    return '$_temp0';
  }

  @override
  String get capsules_sectionReady => 'Khulne ke liye taiyaar';

  @override
  String get capsules_sectionSealed => 'Sealed';

  @override
  String get capsules_sectionOpened => 'Khule hue';

  @override
  String capsules_sealedUntil(String date) {
    return '$date tak seal hai. Yeh safe rahega.';
  }

  @override
  String get capsules_waitingFeeling => 'Kisi feeling ka intezaar';

  @override
  String get capsules_readyRow => 'Jab aap taiyaar hon';

  @override
  String capsules_untitled(String date) {
    return '$date ka ek capsule';
  }

  @override
  String get capsules_lockedTitle => 'Ek sealed capsule';

  @override
  String capsules_sealedOn(String date) {
    return '$date ko seal kiya';
  }

  @override
  String capsules_openedOn(String date) {
    return '$date ko khola';
  }

  @override
  String get capsules_draftTitle => 'Aapka draft yahan hai';

  @override
  String get capsules_draftBody => 'Jahan chhoda tha, wahin se aage likhein.';

  @override
  String get capsules_composeTitle => 'Future you ke liye likhein';

  @override
  String get capsules_titleLabel => 'Title';

  @override
  String get capsules_titleHelper => 'Seal rehne tak capsule par yahi dikhega.';

  @override
  String get capsules_textLabel => 'Aapka note';

  @override
  String get capsules_textHelper => 'Khulne par yeh sirf aapke liye hoga.';

  @override
  String get capsules_photosTitle => 'Photos';

  @override
  String get capsules_addPhoto => 'Photo add karein';

  @override
  String get capsules_photoHint =>
      'Zyada se zyada 3. Location aur camera details hata di jaati hain.';

  @override
  String get capsules_photoAdding => 'Aapki photo add ho rahi hai…';

  @override
  String get capsules_photoFailed =>
      'Yeh photo add nahi ho payi. Koi doosri try karein.';

  @override
  String capsules_photoRemove(int index) {
    return 'Photo $index hatayein';
  }

  @override
  String capsules_photoSemantic(int index, int count) {
    return '$count mein se photo $index';
  }

  @override
  String get capsules_voiceHint =>
      'Zyada se zyada 2 minute. Yeh sirf aapke liye hai.';

  @override
  String get capsules_voiceLimit =>
      'Poore do minute ho gaye, isliye recording ruk gayi. Aapka voice note taiyaar hai.';

  @override
  String get capsules_unlockTitle => 'Yeh kab khule?';

  @override
  String get capsules_unlockDate => 'Kisi date par';

  @override
  String get capsules_unlockFeeling => 'Kisi feeling ke liye';

  @override
  String get capsules_pickDate => 'Date chunein';

  @override
  String get capsules_changeDate => 'Date badlein';

  @override
  String capsules_dateChosen(String date, String time) {
    return '$date ko $time par khulega';
  }

  @override
  String get capsules_dateHelp =>
      'Aaj se ek hafte se lekar paanch saal tak ka koi bhi din.';

  @override
  String get capsules_datePickerHelp => 'Us din 10:00 baje khulega';

  @override
  String get capsules_feelingHelp =>
      'Seal karne ke 24 ghante baad se, agli baar yahi feeling hone par check-in karte hi yeh khul sakta hai.';

  @override
  String capsules_anyQuadrant(String quadrant) {
    return 'Koi bhi $quadrant feeling';
  }

  @override
  String capsules_feelingChosen(String feeling) {
    return 'Iska intezaar: $feeling';
  }

  @override
  String get capsules_seal => 'Seal karein';

  @override
  String get capsules_needContent =>
      'Pehle kuch shabd, ek voice note ya ek photo add karein.';

  @override
  String get capsules_needUnlock => 'Chunein ki yeh kab khule.';

  @override
  String get capsules_sealFailed =>
      'Abhi seal nahi ho paya. Aapka capsule yahin hai. Phir se try karein.';

  @override
  String get capsules_sealedTitle => 'Seal ho gaya';

  @override
  String get capsules_sealedFeeling =>
      'Seal ho gaya. Yeh usi feeling ka intezaar karega.';

  @override
  String get capsules_mediaLater =>
      'Is phone par sealed aur safe hai. Online hone par photos aur voice ka backup ho jayega.';

  @override
  String get capsules_limitBody =>
      'Free account mein 3 mood capsules intezaar mein rakhe ja sakte hain. Date capsules ki koi limit nahi hai.';

  @override
  String get capsules_limitPickDate => 'Iske badle date chunein';

  @override
  String get capsules_makeDate => 'Ise date capsule banayein';

  @override
  String get capsules_leaveTitle => 'Yeh draft rakhein?';

  @override
  String get capsules_leaveBody =>
      'Jab tak aap ise seal na karein ya hata na dein, yeh isi phone par rahega.';

  @override
  String get capsules_leaveEditing => 'Likhte rahein';

  @override
  String get capsules_leaveKeep => 'Draft rakhein';

  @override
  String get capsules_leaveDiscard => 'Hata dein';

  @override
  String capsules_detailFeeling(String feeling) {
    return 'Kisi feeling ka intezaar: $feeling.';
  }

  @override
  String capsules_detailArming(String date) {
    return 'Yeh $date se khul sakta hai.';
  }

  @override
  String get capsules_detailNoEarly =>
      'Seal matlab seal: ise na pehle khola ja sakta hai, na badla ja sakta hai.';

  @override
  String get capsules_delete => 'Capsule delete karein';

  @override
  String get capsules_deleteTitle => 'Yeh capsule delete karein?';

  @override
  String get capsules_deleteBody =>
      'Yeh bina khule hamesha ke liye hat jayega.';

  @override
  String get capsules_deleteBodyOpened => 'Yeh hamesha ke liye hat jayega.';

  @override
  String get capsules_deleteConfirm => 'Delete karein';

  @override
  String get capsules_deleteKeep => 'Rehne dein';

  @override
  String get capsules_deleted => 'Capsule delete ho gaya.';

  @override
  String get capsules_triggerTitle =>
      'Aise pal ke liye aapne ek note chhoda tha. Abhi kholein ya baad mein?';

  @override
  String get capsules_holdTitle =>
      'Pehle likha aapka ek note intezaar mein hai. Abhi kholein, ya baad mein?';

  @override
  String get capsules_now => 'Abhi';

  @override
  String get capsules_later => 'Baad mein';

  @override
  String get capsules_readyTitle =>
      'Aapne jo seal kiya tha, woh ab khul sakta hai.';

  @override
  String capsules_readyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules taiyaar hain.',
      one: '1 capsule taiyaar hai.',
    );
    return '$_temp0';
  }

  @override
  String get capsules_readyOpen => 'Kholein';

  @override
  String get capsules_channelName => 'Capsules';

  @override
  String get capsules_notifyAskTitle => 'Khulne par aapko bataya jaye?';

  @override
  String get capsules_notifyAskBody =>
      'Khulne wale din bas ek halka sa note. Lock screen par yeh nahi dikhega ki andar kya hai.';

  @override
  String get capsules_channelDescription =>
      'Jab aapka seal kiya hua kuch khulne ke liye taiyaar ho.';

  @override
  String get capsules_hardMoment =>
      'Yeh aapne ek mushkil waqt mein likha tha. Jab aap taiyaar hon, tab kholein.';

  @override
  String get capsules_skip => 'Skip karein';

  @override
  String get capsules_opening => 'Aapka capsule khul raha hai';

  @override
  String get capsules_openedTitle => 'Past you se';

  @override
  String get capsules_keepNextTime => 'Agli baar ke liye rakhein';

  @override
  String get capsules_keptNextTime =>
      'Yeh phir se usi feeling ka intezaar karega.';

  @override
  String get capsules_voiceOffline =>
      'Aapka capsule khul gaya hai. Online wapas aane par voice note aa jayega.';

  @override
  String get capsules_photosOffline =>
      'Online wapas aane par photos aa jayengi.';

  @override
  String get capsules_mediaFailed =>
      'Yeh abhi load nahi ho paya. Thodi der mein phir se try karein.';

  @override
  String get capsules_retry => 'Phir se try karein';

  @override
  String get capsules_cantRead =>
      'Yeh capsule abhi is phone par padha nahi ja sakta. Online wapas aane par yeh khul jayega.';

  @override
  String capsules_accountDeletionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seal kiye hue $count capsules hamesha ke liye mit jayenge.',
      one: 'Seal kiya hua 1 capsule hamesha ke liye mit jayega.',
    );
    return '$_temp0';
  }

  @override
  String get checkin_discardTitle => 'Bina save kiye bahar niklein?';

  @override
  String get checkin_discardKeep => 'Edit karte rahein';

  @override
  String get checkin_discardConfirm => 'Hata dein';

  @override
  String checkin_tagLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zyada se zyada $count tags',
      one: 'Zyada se zyada 1 tag',
    );
    return '$_temp0';
  }

  @override
  String checkin_quadrantAxes(String energy, String feel) {
    return '$energy · $feel';
  }

  @override
  String get history_title => 'Aapke check-ins';

  @override
  String get history_private => 'Yeh sirf aapko dikhte hain.';

  @override
  String get history_empty =>
      'Yahan abhi kuch nahi hai. Aapke check-ins yahan jama honge, aur yeh sirf aapko dikhenge.';

  @override
  String get history_today => 'Aaj';

  @override
  String get history_yesterday => 'Kal';

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
  String get history_hasNote => 'Note hai';

  @override
  String get history_entryTitle => 'Aapka check-in';

  @override
  String history_when(String day, String time) {
    return '$day, $time';
  }

  @override
  String get history_tags => 'Tags';

  @override
  String get history_note => 'Aapke shabd';

  @override
  String get history_synced => 'Sync ho gaya';

  @override
  String get history_edit => 'Edit karein';

  @override
  String get history_editWindowOver =>
      'Check-in karne ke baad ek din tak use edit kiya ja sakta hai.';

  @override
  String get history_delete => 'Delete karein';

  @override
  String get history_deleteTitle => 'Yeh check-in delete karein?';

  @override
  String get history_deleteBody =>
      'Isse aapki Starlight ya glow days par koi asar nahi padta.';

  @override
  String get history_missing => 'Yeh check-in ab yahan nahi hai.';

  @override
  String get history_editNoteLocked =>
      'Is check-in ka note abhi is phone tak nahi pahuncha hai. Pahunchne ke baad ise edit kiya ja sakta hai.';

  @override
  String get legal_privacy => 'Privacy policy';

  @override
  String get legal_terms => 'Terms of use';

  @override
  String get legal_opensInBrowser => 'Aapke browser mein khulega';

  @override
  String get help_crisisSubtitleCapsule =>
      'Aapko ise akele nahi sehna hai. Aapka capsule seal ho gaya hai.';

  @override
  String get help_backToCapsule => 'Mere capsule par wapas';

  @override
  String get rooms_trayOpen => 'Warmth bhejein';

  @override
  String get rooms_howRoomsWork => 'Rooms kaise kaam karte hain';

  @override
  String get rooms_reportPickReason => 'Chunein ki kya ho raha hai';

  @override
  String plus_skyStardustNeeds(int count, int have) {
    return '$count Stardust chahiye (aapke paas $have hain)';
  }

  @override
  String get export_settingsRow => 'Mere data ki copy download karein';

  @override
  String get export_title => 'Aapke data ki copy';

  @override
  String get export_body =>
      'Aapke Aura mein jo kuch hai, uski copy: check-ins aur notes, habits, aapke khole hue capsules, aapke account ki details, purchases, Stardust aur keepsakes. Seal kiye gaye capsules seal hi rehte hain: sirf unke titles aur dates hote hain.';

  @override
  String get export_where =>
      'Yeh isi phone par banti hai aur sirf wahin jaati hai jahan aap ise save karna ya bhejna chunte hain.';

  @override
  String get export_media =>
      'Voice notes aur photos app mein hi rehte hain; copy mein likha hota hai ki woh kab banaye gaye.';

  @override
  String get export_private =>
      'Yeh files encrypted nahi hoti. Inhein kisi private jagah par rakhein.';

  @override
  String get export_make => 'Meri copy banayein';

  @override
  String get export_busy => 'Aapka data taiyaar ho raha hai…';

  @override
  String get export_done => 'Aapki copy taiyaar hai.';

  @override
  String get export_failed =>
      'Export poora nahi hua. Aapke account ki details jodne ke liye connection chahiye. Connect hone par phir se try karein.';

  @override
  String get export_shareText => 'Mera Aura data';

  @override
  String get export_hTitle => 'Aapka Aura data';

  @override
  String export_hExported(String date) {
    return '$date ko banayi gayi';
  }

  @override
  String get export_hCheckIns => 'Check-ins';

  @override
  String get export_hHabits => 'Habits';

  @override
  String get export_hCapsules => 'Capsules';

  @override
  String get export_hAccount => 'Account';

  @override
  String get export_hReflections => 'Aapki reflections';

  @override
  String get export_hSanctuary => 'Sanctuary';

  @override
  String get export_sealed => 'Seal hai';

  @override
  String get export_voiceNote => 'voice note';

  @override
  String get export_nothing => 'Yahan abhi kuch nahi hai.';

  @override
  String get flows_startOverTitle => 'Phir se shuru karein?';

  @override
  String get flows_startOverBody =>
      'Ab tak jo chuna aur likha hai, woh hat jayega.';

  @override
  String get flows_startOver => 'Phir se shuru karein';

  @override
  String get closed_title => 'Yeh account band hai';

  @override
  String get closed_body =>
      'Aura ke rules todne ki wajah se yeh account band kiya gaya.';

  @override
  String get closed_review =>
      'Agar aapko lagta hai ki yeh galti hai, to review maanga ja sakta hai. Hum 7 din ke andar jawaab dete hain.';

  @override
  String get closed_askReview => 'Review maangein';

  @override
  String get closed_reviewSubject => 'Band account ka review';

  @override
  String get closed_deleteNote =>
      'Apna account aur usmein maujood sab kuch ab bhi delete kiya ja sakta hai.';

  @override
  String get closed_signOutNote =>
      'Sign out karne se yeh account is phone se hat jayega.';

  @override
  String get notif_roomsPoolBanner =>
      'Hindi aur Hinglish rooms ab khul gaye hain.';

  @override
  String get notif_roomsPoolAction => 'Rooms dekhein';

  @override
  String get notif_channelRooms => 'Rooms & Lantern Hour';

  @override
  String get notif_channelRoomsDescription =>
      'Lantern Hour, aapke room se warmth, aur woh rooms jinke baare mein aapne poochha.';

  @override
  String get grievance_title => 'Grievance Officer se contact karein';

  @override
  String get grievance_intro =>
      'Kisi shikayat, pareshan karne wale content, aapke data, ya aapke account par liye gaye kisi faisle ke baare mein humein batayein. Aapko turant ek ticket number milega.';

  @override
  String grievance_introNamed(String name) {
    return '$name Aura ke Grievance Officer hain. Kisi shikayat, pareshan karne wale content, aapke data, ya aapke account par liye gaye kisi faisle ke baare mein humein batayein. Aapko turant ek ticket number milega.';
  }

  @override
  String get grievance_categoryTitle => 'Yeh kis baare mein hai?';

  @override
  String get grievance_catGeneral => 'Kisi ki post ya bartaav';

  @override
  String get grievance_catUnlawful => 'Aisa content jo illegal ho sakta hai';

  @override
  String get grievance_catNudity =>
      'Nudity, sexual content ya bachchon ke sexual abuse se juda content';

  @override
  String get grievance_catNcii =>
      'Bina consent ke share ki gayi private photos';

  @override
  String get grievance_catData => 'Mera data ya mera account';

  @override
  String get grievance_catAppeal => 'Kisi faisle ka review maangna';

  @override
  String get grievance_descriptionLabel => 'Kya hua';

  @override
  String get grievance_descriptionHint => 'Kuch sentences kaafi hain.';

  @override
  String get grievance_appealHint =>
      'Kaunsa faisla, aur use dobara kyun dekha jaye.';

  @override
  String get grievance_whereLabel => 'Kahan? (optional)';

  @override
  String get grievance_whereHint =>
      'Jaise: koi room, koi reflection, ya lagbhag kab';

  @override
  String get grievance_emailLabel => 'Aapka email';

  @override
  String get grievance_emailHelp =>
      'Acknowledgement aur hamara jawaab yahin bheja jayega. Ise koi aur nahi dekhta.';

  @override
  String get grievance_nameLabel => 'Aapka naam (optional)';

  @override
  String get grievance_send => 'Bhejein';

  @override
  String get grievance_timelines =>
      'Hum 24 ghante ke andar acknowledge karte hain aur 7 din ke andar resolve karte hain. Nudity, bachchon se jude sexual content aur bina consent share ki gayi private photos par 2 ghante ke andar action hota hai.';

  @override
  String get grievance_offline =>
      'Iske liye connection chahiye. Aapne jo likha hai, woh yahin hai.';

  @override
  String get grievance_rateLimited =>
      'Pichhle ek ghante mein yahan se bahut saare messages aaye hain. Aapne jo likha hai, woh yahin hai; please thodi der baad phir try karein.';

  @override
  String get grievance_checkFields =>
      'Please email address check karein aur thoda aur detail likhein (kam se kam 10 characters).';

  @override
  String get grievance_failed =>
      'Yeh nahi ja paaya. Aapne jo likha hai, woh yahin hai. Phir se try karein?';

  @override
  String get grievance_noApi =>
      'Is version mein yeh form available nahi hai. Grievance Officer ko email se likha ja sakta hai.';

  @override
  String get grievance_sentTitle => 'Mil gaya';

  @override
  String grievance_ticket(String ticket) {
    return 'Aapka ticket: $ticket';
  }

  @override
  String grievance_sentBody(String date, String email) {
    return 'Hum $date tak jawaab denge. Is acknowledgement ki ek copy $email par bheji ja rahi hai.';
  }

  @override
  String get grievance_gac =>
      'Agar jawaab se santushti na ho, to 30 din ke andar gac.gov.in par Grievance Appellate Committee mein appeal ki ja sakti hai.';

  @override
  String get set_grievanceForm => 'Grievance Officer ko likhein';

  @override
  String get set_grievanceFormNote =>
      'App mein hi, turant ticket number ke saath';

  @override
  String get closed_askReviewInApp => 'App mein hi review maangein';

  @override
  String get closed_askReviewInAppNote =>
      'Aapko turant ek ticket number milega.';

  @override
  String home_stageProgress(String stage, String next, int count, int target) {
    return '$stage, $next ki taraf $target mein se $count Starlight';
  }

  @override
  String home_constellationProgress(String stage, int count, int max) {
    return '$stage, aapke constellation mein $max mein se $count stars';
  }

  @override
  String get home_glowTitle => 'Aapka glow';

  @override
  String get home_restDaysHint => 'Jaanein ki rest days kaise kaam karte hain';

  @override
  String get home_restInfoTitle => 'Rest days';

  @override
  String home_restInfoEarn(int days, int max) {
    return 'Har $days glow days par ek rest day milta hai. $max tak jama rakhe ja sakte hain.';
  }

  @override
  String get home_restInfoUse =>
      'Chhote break ke dauraan ye un dinon ko apne aap bhar dete hain. Aapko kuch nahi karna hai.';

  @override
  String get home_restInfoKeep => 'Aapka har glow day aapke saath rehta hai.';

  @override
  String home_checkInsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aaj $count check-ins',
      one: 'Aaj 1 check-in',
    );
    return '$_temp0';
  }

  @override
  String get home_seeAll => 'Sab dekhein';

  @override
  String get home_yourCheckIns => 'Aapke check-ins';

  @override
  String get home_syncExplainIdle =>
      'Sab kuch is phone par aur aapke account mein save hai.';

  @override
  String get home_syncExplainPending =>
      'Ye is phone par safe hain aur apne aap sync ho jayenge.';

  @override
  String get home_syncExplainOffline =>
      'Aap offline hain. Sab kuch is phone par safe hai aur phir se online hone par sync ho jayega.';

  @override
  String get home_syncExplainSignedOut =>
      'Aapne sign in nahi kiya hai, isliye abhi sab kuch isi phone par rahega.';

  @override
  String get home_syncExplainUnavailable =>
      'Ye version sab kuch isi phone par rakhta hai.';

  @override
  String get home_syncNow => 'Abhi sync karein';

  @override
  String get home_syncing => 'Sync ho raha hai…';

  @override
  String get home_syncHint => 'Sync details dekhein';

  @override
  String get habits_edit => 'Edit karein';

  @override
  String get habits_editSemantic => 'Chhote kaam edit karein';

  @override
  String get habits_sheetTitle => 'Aapke chhote kaam';

  @override
  String get habits_sheetBody =>
      'Chunein ki Home par kya dikhe. Check-ins se aapka Aura har haal mein badhta hai.';

  @override
  String get habits_presetsTitle => 'Suggestions';

  @override
  String get habits_customTitle => 'Aapke apne';

  @override
  String get habits_addLabel => 'Apna add karein';

  @override
  String get habits_addHint => 'Jaise, paudhon ko paani dena';

  @override
  String get habits_add => 'Add karein';

  @override
  String habits_limit(int count) {
    return 'Aapke paas $count custom habits hain. Nayi add karne ke liye kisi ek ko swap karein.';
  }

  @override
  String get habits_saveFailed => 'Ye save nahi hua. Phir se try karein?';

  @override
  String habits_remove(String name) {
    return '$name hatayein';
  }

  @override
  String habits_removeTitle(String name) {
    return '$name hatayein?';
  }

  @override
  String get habits_removeBody =>
      'Ye aapki list se hat jayega. Isse mile Starlight aur glow days bane rahenge.';

  @override
  String get habits_removeConfirm => 'Hatayein';

  @override
  String get habits_empty => 'Shuru karne ke liye ek chhota kaam chunein.';

  @override
  String get help_groundingProgress => 'Is ek minute mein ab tak';

  @override
  String get help_progressBegun => 'Abhi shuru hua';

  @override
  String get help_progressHalf => 'Lagbhag aadha';

  @override
  String get help_progressNearly => 'Lagbhag poora';

  @override
  String get help_progressDone => 'Poora hua';

  @override
  String help_breatheLogged(String habit) {
    return '$habit aaj ke liye done mark kar diya gaya hai.';
  }

  @override
  String get insights_title => 'Aura Sky';

  @override
  String get insights_private =>
      'Aapka aasmaan sirf aapko dikhta hai. Ye isi phone par banta hai.';

  @override
  String get insights_empty =>
      'Har check-in ke saath aapka aasmaan bharta jayega.';

  @override
  String get insights_allCheckIns => 'Saare check-in';

  @override
  String get insights_viewMonth => 'Mahina';

  @override
  String get insights_viewYear => 'Saal';

  @override
  String get insights_prevMonth => 'Pichhla mahina';

  @override
  String get insights_nextMonth => 'Agla mahina';

  @override
  String get insights_prevYear => 'Pichhla saal';

  @override
  String get insights_nextYear => 'Agla saal';

  @override
  String insights_dayEmpty(String date) {
    return '$date, shaant aasmaan';
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
    return '$date, $first aur $second barabar, $_temp0';
  }

  @override
  String insights_dayMixed(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$date, barabar ka mix, $_temp0';
  }

  @override
  String get insights_dayHint => 'Is din ke check-in dikhata hai';

  @override
  String get insights_dayNone =>
      'Is din kuch note nahi hua. Aasmaan bas shaant tha.';

  @override
  String insights_monthSemantic(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count din check-in kiya',
      one: '1 din check-in kiya',
      zero: 'shaant aasmaan',
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
  String get insights_patternsLast30 => 'Aapke pichhle 30 din se';

  @override
  String insights_patternsNeedCheckIns(int count) {
    return '7 check-ins ke baad patterns dikhenge ($count/7)';
  }

  @override
  String insights_patternsNeedDays(int count) {
    return '5 alag-alag dinon par check-in ke baad patterns dikhenge ($count/5)';
  }

  @override
  String get insights_patternsNone =>
      'Abhi koi clear pattern nahi hai. Aapka aasmaan yahin hai.';

  @override
  String insights_patternTag(String tag, String quadrant) {
    return 'Jab aapne $tag tag kiya, tab $quadrant zyada dikha.';
  }

  @override
  String insights_patternHabit(String habit, String quadrant) {
    return '$habit wale dinon mein $quadrant wale check-in zyada rahe.';
  }

  @override
  String insights_patternMorning(String quadrant) {
    return 'Subah ke waqt $quadrant wale check-in zyada rahe.';
  }

  @override
  String insights_patternAfternoon(String quadrant) {
    return 'Dopahar mein $quadrant wale check-in zyada rahe.';
  }

  @override
  String insights_patternEvening(String quadrant) {
    return 'Shaam ko $quadrant wale check-in zyada rahe.';
  }

  @override
  String insights_patternNight(String quadrant) {
    return 'Raat mein $quadrant wale check-in zyada rahe.';
  }

  @override
  String insights_patternMix(String quadrant) {
    return 'Aapke aasmaan mein $quadrant wale check-in sabse zyada rahe.';
  }

  @override
  String get insights_plusBadge => 'Aura Plus';

  @override
  String get insights_rangeLocked =>
      'Koi bhi range aur moods ke saath habits Aura Plus mein milti hain. Aapka aasmaan aur 30 din ke patterns hamesha free hain.';

  @override
  String get insights_rangeLabel => 'Patterns kab se';

  @override
  String get insights_range7 => '7 din';

  @override
  String get insights_range30 => '30 din';

  @override
  String get insights_range90 => '90 din';

  @override
  String get insights_range365 => '1 saal';

  @override
  String get insights_rangeAll => 'Shuru se ab tak';

  @override
  String get insights_weeklyTitle => 'Aapke pichhle hafte se';

  @override
  String get insights_weeklyHide => 'Is hafte ke liye chhupayein';

  @override
  String get insights_careTitle => 'Pichhle do hafte bhaari rahe hain';

  @override
  String get insights_careBody =>
      'Ye bojh akele uthana zaroori nahi. Jab bhi mann ho, support aur ek room yahin hain.';

  @override
  String get insights_careSupport => 'Support dekhein';

  @override
  String get insights_careRoom => 'Ek room dhoondhein';

  @override
  String get insights_monthTitle => 'Taaron mein aapka mahina';

  @override
  String insights_monthCardBody(String month) {
    return 'Aapke aasmaan mein $month';
  }

  @override
  String get insights_monthOpen => 'Kholein';

  @override
  String get insights_monthHide => 'Chhupayein';

  @override
  String insights_monthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count din check-in kiya',
      one: '1 din check-in kiya',
    );
    return '$_temp0';
  }

  @override
  String get insights_monthMixTitle => 'Is mahine aapka aasmaan';

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
      other: '$count taaron ka aasmaan',
      one: '1 taare ka aasmaan',
    );
    return '$_temp0, $month ke har check-in ke liye ek taara';
  }

  @override
  String get insights_deeperTitle => 'Mahine ka deeper review';

  @override
  String get insights_deeperLocked =>
      'Poore mahine ke patterns, moods ke saath habits, Aura Plus mein milte hain.';

  @override
  String get insights_deeperNone => 'Is mahine koi clear pattern nahi.';

  @override
  String get insights_statsTitle => 'Shuru se ab tak';

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
      other: 'Aapke aasmaan mein $count din',
      one: 'Aapke aasmaan mein 1 din',
    );
    return '$_temp0';
  }

  @override
  String get insights_lookBackTitle => 'Peeche dekhein';

  @override
  String get insights_lookBackTileBody =>
      'Kuch samay pehle ke isi hafte ka aapka aasmaan. Jab mann ho, tab kholein.';

  @override
  String get insights_lookBackIntro =>
      'Ek mahine, chhah mahine aur ek saal pehle ka yahi hafta. Ise sirf aap dekh sakte hain. Ye isi phone par rehta hai.';

  @override
  String get insights_lookBackMonth => 'Ek mahine pehle';

  @override
  String get insights_lookBackSixMonths => 'Chhah mahine pehle';

  @override
  String get insights_lookBackYear => 'Ek saal pehle';

  @override
  String insights_lookBackWeekOf(String date) {
    return '$date wala hafta';
  }

  @override
  String get insights_lookBackEmpty =>
      'Abhi peeche dekhne ko kuch nahi hai. Jin hafton mein aapne check-in kiya, wo yahan dikhenge.';

  @override
  String get insights_lookBackClosed => 'Peeche dekhein abhi ke liye band hai.';

  @override
  String get insights_lookBackShowNote => 'Note dikhayein';

  @override
  String get insights_lookBackShowVoice => 'Voice note dikhayein';

  @override
  String get insights_lookBackHideNote => 'Chhupayein';

  @override
  String get insights_lookBackSettingsHint =>
      'Settings mein \'Peeche dekhein\' band kar sakte hain.';

  @override
  String get insights_lookBackSetting => 'Aura Sky mein peeche dekhein';

  @override
  String get insights_lookBackSettingNote =>
      'Aapke aasmaan ke pichhle hafte, sirf jab aap kholein. Kabhi notification bankar nahi aate.';

  @override
  String insights_statsLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sabse lamba glow streak · $count din',
      one: 'Sabse lamba glow streak · 1 din',
    );
    return '$_temp0';
  }

  @override
  String get keepsakes_title => 'Yaadgaarein';

  @override
  String get keepsakes_intro =>
      'Chhote pal, saheje hue. Ye sirf aapko dikhte hain.';

  @override
  String get keepsakes_empty =>
      'Yahan abhi kuch nahi hai. Chhote-chhote palon se yaadgaarein apne aap aati hain.';

  @override
  String get keepsakes_privateNote =>
      'Yaadgaarein kisi aur ko kabhi nahi dikhtin. Koi yaadgaar aapke phone se bahar tabhi jaati hai jab aap uska card share karein.';

  @override
  String keepsakes_keptOn(String date) {
    return '$date ko saheja';
  }

  @override
  String keepsakes_sealSemantic(String line, String date) {
    return '$line, $date ko saheja';
  }

  @override
  String get keepsakes_shareThis => 'Yeh card share karein';

  @override
  String get keepsakes_shareAura => 'Apna Aura share karein';

  @override
  String get keepsakes_offline =>
      'Aapke phir se online aane par nayi yaadgaarein aayengi.';

  @override
  String get keepsakes_entry => 'Aapki yaadgaarein';

  @override
  String get keepsakes_entryNote => 'Chhote palon ki muhrein, sirf aapke liye.';

  @override
  String get keepsakes_newTitle => 'Ek nayi yaadgaar';

  @override
  String get keepsakes_newSeveral => 'Nayi yaadgaarein aapke box mein hain.';

  @override
  String get keepsakes_newOpen => 'Apni yaadgaarein dekhein';

  @override
  String get keepsakes_hideCard => 'Yeh card chhupaayein';

  @override
  String get keepsake_capsuleSealedFirst =>
      'Maine aage ke apne liye ek note seal kiya';

  @override
  String get keepsake_capsuleOpenedFirst =>
      'Maine beete kal ke apne se aaya capsule khola';

  @override
  String keepsake_glowDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days din ka glow',
      one: '1 din ka glow',
    );
    return '$_temp0';
  }

  @override
  String get keepsake_ripplesFirst => 'Pehli baar sabke saath milkar saans li';

  @override
  String get keepsake_lanternFirst => 'Mera pehla Lantern Hour';

  @override
  String keepsake_lanternHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lantern Hour ki $count shaamein',
      one: 'Lantern Hour ki 1 shaam',
    );
    return '$_temp0';
  }

  @override
  String keepsake_sanctuaryMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Sanctuary mein $minutes shaant minute',
      one: 'Sanctuary mein 1 shaant minute',
    );
    return '$_temp0';
  }

  @override
  String share_evolutionLine(String stage) {
    return 'Mera Aura $stage tak pahuncha';
  }

  @override
  String share_anniversaryLine(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years saal pehle ek capsule seal kiya',
      one: '1 saal pehle ek capsule seal kiya',
    );
    return '$_temp0';
  }

  @override
  String get share_storeLine => 'Aura · App Store aur Google Play par';

  @override
  String share_text(String link) {
    return 'Aura, apne mann ka haal dekhne ki ek shaant jagah: $link';
  }

  @override
  String get share_sheetTitle => 'Ek card share karein';

  @override
  String get share_sheetNote =>
      'Card par aapka Aura aur yeh pal hi dikhta hai. Aapke mood, notes ya naam kabhi nahi.';

  @override
  String get share_button => 'Share karein';

  @override
  String get share_failed =>
      'Abhi card nahi ban paaya. Please phir se try karein.';

  @override
  String share_cardSemantic(String line, String stage) {
    return 'Share karne ka card: $line. $stage stage mein aapka Aura.';
  }

  @override
  String share_promptEvolution(String stage) {
    return 'Aapka Aura $stage tak pahuncha. Iska card share karein?';
  }

  @override
  String share_promptGlow(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days din ka glow.',
      one: '1 din ka glow.',
    );
    return '$_temp0 Iska card share karein?';
  }

  @override
  String share_promptAnniversary(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: 'Aapne apna pehla capsule $years saal pehle seal kiya tha.',
      one: 'Aapne apna pehla capsule ek saal pehle seal kiya tha.',
    );
    return '$_temp0 Iska card share karein?';
  }

  @override
  String get rooms_lanternTitle => 'Aaj raat ki lantern';

  @override
  String get rooms_lanternStart => 'Yahan har gesture thodi roshni jodta hai.';

  @override
  String get rooms_lanternGlowing =>
      'Yahan har gesture ke saath yeh aur roshan hoti hai.';

  @override
  String get rooms_lanternFull => 'Sabne milkar, poori roshan ki.';

  @override
  String get rooms_lanternKept => 'Aaj raat ki lantern itni roshan hui.';

  @override
  String rooms_lanternSemantic(int level, int max) {
    return 'Aaj raat ki lantern, $max mein se $level roshniyan jali';
  }

  @override
  String get rooms_lanternRise =>
      'Lantern poori roshan ho gayi. Lanterns saath milkar upar uthti hain.';

  @override
  String get rooms_intentionTitle => 'Aaj raat ka irada';

  @override
  String get rooms_intentionHold => 'Aaj raat ise thaamein';

  @override
  String get rooms_intentionHolding => 'Aaj raat yeh irada aapke saath hai';

  @override
  String rooms_intentionHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aaj raat $count ne ise thaama hai',
      one: 'Aaj raat 1 ne ise thaama hai',
      zero: 'Ek tap se thaamein',
    );
    return '$_temp0';
  }

  @override
  String rooms_intentionHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aaj raat $count ne ise thaama',
      one: 'Aaj raat 1 ne ise thaama',
      zero: 'Agle Lantern Hour tak aaram',
    );
    return '$_temp0';
  }

  @override
  String get rooms_intentionPrivate =>
      'Ise kisne thaama, yeh kisi ko nahi dikhta, aur kal iske baare mein koi nahi poochhega.';

  @override
  String get rooms_intentionFailed =>
      'Yeh ho nahi paaya. Please phir se try karein.';

  @override
  String get rooms_intention_sleep_before_midnight =>
      'Aadhi raat se pehle sona';

  @override
  String get rooms_intention_gentle_with_myself => 'Aaj raat khud se narmi';

  @override
  String get rooms_intention_phone_down_10 => '10 minute phone se doori';

  @override
  String get rooms_intention_water_before_bed => 'Sone se pehle ek glass paani';

  @override
  String get rooms_intention_one_kind_thought =>
      'Aaj ke baare mein ek achha khayal';

  @override
  String get rooms_intention_slow_breaths =>
      'Sone se pehle teen dheemi saansein';

  @override
  String get notif_reminderBanner =>
      'Aapke liye sukoon ka ek minute. Aaj kaisa lag raha hai?';

  @override
  String get notif_reminderAction => 'Check-in karein';

  @override
  String get notif_capsuleBanner =>
      'Aapne jo seal kiya tha, woh ab khul sakta hai.';

  @override
  String get notif_capsuleAction => 'Kholein';

  @override
  String get notif_channelReminders => 'Reminders';

  @override
  String get notif_channelRemindersDescription =>
      'Aapke check-in, wind-down aur habit reminders.';

  @override
  String get set_notifications => 'Notifications';

  @override
  String get set_notifMaster => 'Aura ke notifications';

  @override
  String get set_notifMasterNote =>
      'Din mein zyada se zyada do. Aapki lock screen par kabhi nahi dikhega ki aapko kaisa lag raha hai.';

  @override
  String get set_notifReminder => 'Daily check-in reminder';

  @override
  String set_notifReminderNote(String time) {
    return 'Din mein ek halki si yaad, $time par. Check-in ho jaane par nahi aati.';
  }

  @override
  String get set_notifReminderOffNote =>
      'Off hai. Din mein ek halki si yaad ke liye ise on karein.';

  @override
  String get set_notifReminderTime => 'Reminder time';

  @override
  String get set_notifCapsule => 'Koi capsule khulne ke liye taiyaar hai';

  @override
  String get set_notifCapsuleNote =>
      'Us din, jo aapne apni seal ki hui cheez ke liye chuna tha.';

  @override
  String set_notifQuietNote(String start, String end) {
    return 'Quiet hours: $start–$end ke beech kuch nahi bheja jata.';
  }

  @override
  String get set_notifQuietFrom => 'Quiet hours shuru';

  @override
  String get set_notifQuietUntil => 'Quiet hours khatam';

  @override
  String get set_notifDiscreet => 'Discreet mode';

  @override
  String get set_notifDiscreetNote =>
      'Har notification mein bas “Aura · Aapke liye ek gentle update hai” likha hota hai.';

  @override
  String get set_notifOffNote =>
      'Is phone par Aura ke notifications off hain. On hone par yahan ki aapki choices laagu rahengi.';

  @override
  String get set_notifTurnOn => 'On karein';

  @override
  String get set_notifOpenSettings => 'Phone settings kholein';

  @override
  String get set_notifQuietConfirmTitle =>
      'Ye time aapke quiet hours mein aata hai';

  @override
  String set_notifQuietConfirmBody(String start, String end, String time) {
    return 'Aura $start–$end tak chup rehta hai. Phir bhi $time par reminder bhejein?';
  }

  @override
  String get set_notifQuietConfirmYes => 'Phir bhi bhejein';

  @override
  String get set_notifQuietConfirmNo => 'Quiet hi rakhein';

  @override
  String push_timeRow(String time) {
    return 'Har shaam $time par';
  }

  @override
  String get push_changeTime => 'Time badlein';

  @override
  String get push_discreet => 'Inhe discreet rakhein';

  @override
  String get notif_gesturesBanner =>
      'Aapke room ke logon ne aapko warmth bheji.';

  @override
  String get notif_gesturesAction => 'Room mein jaayein';

  @override
  String get notif_lanternBanner =>
      'Lantern Hour shuru ho gaya hai. Aaj raat aur log bhi yahan hain.';

  @override
  String get notif_lanternAction => 'Rooms dekhein';

  @override
  String get notif_windDownBanner =>
      'Sone se pehle sukoon ke kuch pal, jab bhi mann ho.';

  @override
  String get notif_windDownAction => 'Sounds kholein';

  @override
  String get notif_habitBanner =>
      'Ek-do chhoti habits, jab bhi aap taiyaar hon.';

  @override
  String get notif_habitAction => 'Habits dekhein';

  @override
  String get notif_crisisFollowUp =>
      'Bas haal-chaal pooch rahe hain. Aaj jaisa bhi lag raha ho, madad bas ek tap door hai.';

  @override
  String get notif_crisisFollowUpDismiss => 'Band karein';

  @override
  String get set_notifGestures => 'Aapke room se warmth';

  @override
  String get set_notifGesturesNote =>
      'Jab aapke room ke log aapko koi gesture bhejein. Din mein zyada se zyada ek.';

  @override
  String get set_notifLantern => 'Lantern Hour';

  @override
  String get set_notifLanternNote =>
      'Jab aapki shaam mein Lantern Hour shuru ho. Agar us din koi room pehle hi dekha ja chuka hai, to nahi.';

  @override
  String get set_notifWindDown => 'Wind-down reminder';

  @override
  String set_notifWindDownNote(String time) {
    return '$time par sukoon ke kuch minute. Agar us shaam Sanctuary use ho chuka hai, to nahi bheja jata.';
  }

  @override
  String get set_notifWindDownOffNote =>
      'Off hai. Sone se pehle ek halki si yaad ke liye time chunein.';

  @override
  String get set_notifWindDownTime => 'Wind-down time';

  @override
  String get set_notifWelcomeBack => 'Kuch samay baad';

  @override
  String get set_notifWelcomeBackNote =>
      'Ek hafte ya usse zyada ki doori ke baad, ek halka sa hello. Zyada se zyada do baar.';

  @override
  String get set_notifHabits => 'Habit nudges';

  @override
  String get set_notifHabitsNote =>
      'Home par kisi bhi habit ke liye, aapke chune time par ek chhoti si yaad. Din mein zyada se zyada ek.';

  @override
  String get set_notifHabitsNone =>
      'Nudge ke liye Home par koi habit add karein.';

  @override
  String get set_notifHabitOff => 'Off';

  @override
  String get set_notifHabitQuiet =>
      'Ye aapke quiet hours mein hai, isliye nahi bheja jayega.';

  @override
  String get set_notifHabitChange => 'Time badlein';

  @override
  String get set_notifHabitTurnOff => 'Off karein';

  @override
  String sounds_windDownRemind(String time) {
    return '$time par yaad dilayein';
  }

  @override
  String sounds_windDownReminderOn(String time) {
    return '$time par ek halki si yaad aayegi.';
  }

  @override
  String get sounds_windDownReminderOff => 'Off karein';

  @override
  String get onb_trustTitle => 'Shuru karne se pehle';

  @override
  String get onb_trustBody =>
      'Aura aapka khayal kaise rakhta hai, iske baare mein kuch baatein.';

  @override
  String get onb_trustPrivateTitle => 'Shuru se hi private';

  @override
  String get onb_trustPrivateBody =>
      'Aapke check-ins aur notes sirf aapke hain. Notes encrypted rehte hain, aur jab tak aap share karna na chunein, aapka haal koi aur nahi dekh sakta.';

  @override
  String get onb_trustCareTitle => 'Wellness support, therapy nahi';

  @override
  String get onb_trustCareBody =>
      'Aura aapko ye dhyaan dene mein madad karta hai ki aapka mann kaisa hai. Ye na koi diagnosis karta hai, na ilaaj.';

  @override
  String get onb_trustHelpTitle => 'Madad hamesha bas ek tap door';

  @override
  String onb_trustHelpBody(String button) {
    return 'Helpline par call karne ya ek minute saans par dhyaan dene ke liye kabhi bhi “$button” tap karein.';
  }

  @override
  String get onb_dobYearType => 'Saal type karein';

  @override
  String get onb_dobYearNoMatch =>
      'List mein isse milta koi saal nahi hai. Ek baar check kar lein?';

  @override
  String get onb_blockedWrongDate => 'Galat date daal di?';

  @override
  String get onb_blockedWrongDateHint => 'Aapka email app khulega';

  @override
  String get onb_blockedMailSubject => 'Aura: maine galat date daal di';

  @override
  String onb_blockedMailFailed(String email) {
    return 'Email app nahi khul paya. Aap chahein to humein $email par likhein.';
  }

  @override
  String get plus_title => 'Aura Plus';

  @override
  String get plus_intro =>
      'Jo aapke paas pehle se hai, usi ka aur zyada. Jo kuch bhi aapko achha feel karne mein madad karta hai, woh free hi rahega.';

  @override
  String get plus_addsTitle => 'Plus ke saath milta hai';

  @override
  String get plus_addCapsules => 'Unlimited mood-trigger capsules';

  @override
  String get plus_addVoice => 'Capsule mein 10 minute tak voice';

  @override
  String get plus_addInsights =>
      'Deeper Insights: koi bhi range, habit × mood, sitaron mein mahine ki gehri jhalak';

  @override
  String get plus_addSounds => 'Extra sounds aur do Plus skies';

  @override
  String get plus_freeTitle => 'Hamesha free';

  @override
  String get plus_freeBody =>
      'Check-ins, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Breathe, grounding, Today\'s minute, har base sound aur raat ka wind-down.';

  @override
  String get plus_planMonthly => 'Monthly';

  @override
  String get plus_planAnnual => 'Yearly';

  @override
  String plus_trialLineMonthly(String price) {
    return '1 month free, phir $price/month';
  }

  @override
  String plus_trialLineAnnual(String price) {
    return '1 month free, phir $price/year';
  }

  @override
  String plus_priceMonthly(String price) {
    return '$price/month';
  }

  @override
  String plus_priceAnnual(String price) {
    return '$price/year';
  }

  @override
  String plus_trialEnds(String date) {
    return 'Aapka free month $date ko khatam hoga. Usse pehle cancel nahi kiya, to pehla charge $date ko lagega.';
  }

  @override
  String plus_renews(String store) {
    return 'Cancel karne tak yeh apne-aap renew hota rahega. Payment aapke $store account se hoga.';
  }

  @override
  String get plus_cancelApple =>
      'Cancel karne ke liye: iPhone Settings › aapka naam › Subscriptions › Aura. Kisi bhi charge se kam se kam ek din pehle cancel karein.';

  @override
  String get plus_cancelGoogle =>
      'Cancel karne ke liye: Play Store › aapki profile › Payments & subscriptions › Subscriptions › Aura.';

  @override
  String get plus_storeApple => 'App Store';

  @override
  String get plus_storeGoogle => 'Google Play';

  @override
  String get plus_startTrial => 'Free month shuru karein';

  @override
  String get plus_subscribe => 'Subscribe karein';

  @override
  String get plus_restore => 'Purchases restore karein';

  @override
  String get plus_manage => 'Store mein manage karein';

  @override
  String get plus_loadingPrices => 'Store se prices load ho rahi hain';

  @override
  String get plus_storeUnavailable =>
      'Abhi store tak nahi pahuncha ja pa raha. Koi charge nahi liya gaya.';

  @override
  String get plus_retry => 'Phir se try karein';

  @override
  String get plus_confirming => 'Store se confirm ho raha hai…';

  @override
  String get plus_confirmingLater =>
      'Aapki request store tak pahunch gayi hai. Confirm hote hi Plus unlock ho jayega. Ise band kiya ja sakta hai.';

  @override
  String get plus_validationFailed =>
      'Abhi iska confirmation nahi ho paaya. Agar aapse charge liya gaya hai, to woh safe hai. Hum check karte rahenge.';

  @override
  String get plus_pendingApproval =>
      'Approval ka intezaar hai. Yeh poora hone tak aapse koi charge nahi liya jayega.';

  @override
  String get plus_declined =>
      'Payment nahi ho paaya. Aapse koi charge nahi liya gaya.';

  @override
  String get plus_welcome => 'Aura Plus on ho gaya hai. Shukriya.';

  @override
  String get plus_ownedElsewhere =>
      'Yeh purchase is store account par kisi doosre Aura account ki hai, isliye yeh wahin rahegi.';

  @override
  String plus_restored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases restore hui.',
      one: '1 purchase restore hui.',
      zero: 'Is store account par restore karne ke liye kuch nahi hai.',
    );
    return '$_temp0';
  }

  @override
  String get plus_lockedOnly => 'Aura Plus ka hissa';

  @override
  String get plus_about => 'Aura Plus ke baare mein';

  @override
  String get plus_seePlus => 'Aura Plus dekhein';

  @override
  String get plus_freePath => 'Free raasta yahin maujood hai.';

  @override
  String get plus_explainerCapsules =>
      'Free account mein 3 mood capsules wait mein rakhe ja sakte hain. Aura Plus mein jitne chahein, utne. Date capsules hamesha unlimited hain.';

  @override
  String get plus_explainerVoice =>
      'Free Aura mein capsule ki voice 2 minute par ruk jaati hai, Aura Plus ke saath 10 minute par.';

  @override
  String get plus_explainerSounds =>
      'Yeh sound Aura Plus ke saath milta hai. Har base sound aur raat ka wind-down free rehte hain.';

  @override
  String get plus_explainerInsights =>
      'Aura Plus mein koi bhi range, habit × mood aur deeper month milta hai. Aapka sky aur history free rehte hain.';

  @override
  String get plus_explainerSky => 'Yeh sky Aura Plus ke saath milta hai.';

  @override
  String get plus_statusFree => 'Abhi aapke paas free Aura hai.';

  @override
  String plus_statusTrial(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days din baaki',
      one: '1 din baaki',
      zero: 'aaj khatam',
    );
    return 'Free month: $_temp0. Pehla charge $date ko.';
  }

  @override
  String plus_statusTrialCancelled(String date) {
    return 'Aapka free month $date tak on rahega. Uske baad free Aura rahega, aur aapka banaya sab kuch aapka hi rahega.';
  }

  @override
  String plus_statusActive(String date) {
    return 'Aura Plus $date ko renew hoga.';
  }

  @override
  String plus_statusCancelled(String date) {
    return 'Aura Plus $date tak on rahega. Aapse dobara charge nahi liya jayega.';
  }

  @override
  String get plus_statusGrace =>
      'Store Aura Plus ko renew nahi kar paaya. Jab tak store phir se try kar raha hai, Plus on rahega.';

  @override
  String get plus_statusBillingRetry =>
      'Store ke renew kar paane tak Aura Plus ruka hua hai. Aapka banaya sab kuch aapka hi rahega.';

  @override
  String get plus_statusExpired =>
      'Aura Plus khatam ho gaya hai. Aapka banaya sab kuch aapka hi rahega.';

  @override
  String get plus_statusRefunded =>
      'Aapka refund ho gaya hai, isliye Aura Plus khatam ho gaya hai. Aapka banaya sab kuch aapka hi rahega.';

  @override
  String get plus_statusPending =>
      'Store ke confirmation ka intezaar hai. Yeh poora hone tak aapse koi charge nahi liya jayega.';

  @override
  String get plus_updatePayment => 'Store mein payment update karein';

  @override
  String get plus_turnBackOn => 'Plus phir se on karein';

  @override
  String plus_managedElsewhere(String store) {
    return '$store par kharida gaya. Ise wahin manage karein.';
  }

  @override
  String get plus_notYet =>
      'Aura Plus join karne ke ek din baad khulta hai. Aapki zaroorat ki har cheez pehle se free hai.';

  @override
  String plus_cardTrialEnding(String date, String price) {
    return 'Aapka free month $date ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus $price/month par jaari rahega.';
  }

  @override
  String plus_cardTrialEndingYear(String date, String price) {
    return 'Aapka free month $date ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus $price/year par jaari rahega.';
  }

  @override
  String plus_cardTrialEndingNoPrice(String date) {
    return 'Aapka free month $date ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus jaari rahega.';
  }

  @override
  String get plus_cardKeep => 'Plus jaari rakhein';

  @override
  String plus_cardTrialCancelled(String date) {
    return 'Plus $date tak on rahega. Aapse koi charge nahi liya jayega.';
  }

  @override
  String get plus_cardBillingIssue =>
      'Aapka Aura Plus payment nahi ho paaya. Aapka banaya sab kuch safe hai.';

  @override
  String get plus_cardContinues => 'Aura Plus jaari hai. Shukriya.';

  @override
  String get plus_dismiss => 'Hatayein';

  @override
  String get plus_giftWarmTea => 'Ek cup chai';

  @override
  String get plus_giftComfortLantern => 'Sukoon ki lalten';

  @override
  String get plus_giftBouquet => 'Hausle ka guldasta';

  @override
  String plus_giftReceived(String gift) {
    return 'Yahan kisi ki taraf se aapke liye $gift.';
  }

  @override
  String plus_giftStardust(int count) {
    return '+$count Stardust';
  }

  @override
  String get plus_giftTitle => 'Gift bhejein';

  @override
  String get plus_giftBody =>
      'Unhe “Yahan kisi ki taraf se aapke liye ek gift” dikhega aur sky ke liye Stardust milega. Na koi message, na koi naam.';

  @override
  String plus_giftSend(String price) {
    return '$price mein bhejein';
  }

  @override
  String get plus_giftSent =>
      'Bhej diya gaya. Agli baar Aura kholne par unhe dikhega.';

  @override
  String get plus_giftUnavailable =>
      'Yeh gift abhi nahi bheja ja sakta. Koi charge nahi liya gaya.';

  @override
  String get plus_giftDailyLimit =>
      'Aaj ke 5 gifts ho gaye. Kal aur bheje ja sakte hain.';

  @override
  String get plus_giftPaused =>
      'Is account par abhi gifts available nahi hain.';

  @override
  String get plus_giftsOff =>
      'Gifts thodi der ke liye aaram kar rahe hain. Koi charge nahi liya gaya.';

  @override
  String plus_stardustBalance(int count) {
    return '$count Stardust';
  }

  @override
  String get plus_stardustNote =>
      'Stardust sirf un gifts se milta hai jo log aapko bhejte hain. Ise na khareeda ja sakta hai, na cash kiya ja sakta hai, na kahin bheja ja sakta hai.';

  @override
  String get plus_skiesTitle => 'Aapka sky';

  @override
  String get plus_skiesIntro =>
      'Aapke apne Home, Sanctuary aur Insights ke liye ek sky. Yeh sirf aapko dikhta hai.';

  @override
  String get plus_skyNight => 'Night sky';

  @override
  String get plus_skyAurora => 'Aurora';

  @override
  String get plus_skyMonsoonDusk => 'Monsoon dusk';

  @override
  String get plus_skyFirstLight => 'First light';

  @override
  String get plus_skyLanternFestival => 'Lantern festival';

  @override
  String get plus_skyDeepOcean => 'Deep ocean';

  @override
  String get plus_skyMeteorShower => 'Meteor shower';

  @override
  String get plus_skyFree => 'Free';

  @override
  String get plus_skyWithPlus => 'Aura Plus ke saath';

  @override
  String get plus_skyOwned => 'Aapka';

  @override
  String get plus_skyInUse => 'Use mein';

  @override
  String get plus_skyUse => 'Yeh sky lagayein';

  @override
  String plus_skyBuy(String price) {
    return '$price mein kharidein';
  }

  @override
  String plus_skyStardust(int count) {
    return '$count Stardust use karein';
  }

  @override
  String get plus_skyNotEnough =>
      'Is sky ke liye abhi Stardust kaafi nahi hai.';

  @override
  String get plus_soundscapeTitle => 'Saath mein ek soundscape jodein';

  @override
  String get plus_soundscapeNone => 'Koi sound nahi';

  @override
  String get plus_soundscapeNightAir => 'Night air';

  @override
  String get plus_soundscapeHighWind => 'High wind';

  @override
  String get plus_soundscapeMonsoon => 'Monsoon';

  @override
  String get plus_soundscapeBells => 'Bells';

  @override
  String get plus_soundscapeShore => 'Shore';

  @override
  String get plus_soundscapePlay => 'Yeh sounds chalayein';

  @override
  String get plus_settingsSky => 'Aapka sky aur Stardust';

  @override
  String get plus_channelAccount => 'Account';

  @override
  String get plus_channelAccountDescription =>
      'Aura Plus reminders, jaise aapka free month khatam hona.';

  @override
  String polish_legalOpenFailed(String url) {
    return 'Aapka browser nahi khula. Yeh page $url par hai.';
  }

  @override
  String get polish_legalCopyLink => 'Link copy karein';

  @override
  String get polish_legalLinkCopied => 'Link copy ho gaya';

  @override
  String polish_helpCallFailed(String number) {
    return 'Is phone se call karna mumkin nahi hai. Number hai $number.';
  }

  @override
  String get polish_helpCopyNumber => 'Number copy karein';

  @override
  String get polish_helpNumberCopied => 'Number copy ho gaya';

  @override
  String get quiet_title => 'Saath mein shaanti';

  @override
  String get quiet_cardBody =>
      'Doosron ke saath padhai karein, kitaab padhein ya aaram karein. Bas ek ginti, ek shared awaaz aur gestures.';

  @override
  String get quiet_modeStudy => 'Padhai';

  @override
  String get quiet_modeRead => 'Padhna';

  @override
  String get quiet_modeRest => 'Aaram';

  @override
  String get quiet_titleStudy => 'Saath mein padhai';

  @override
  String get quiet_titleRead => 'Saath mein padhna';

  @override
  String get quiet_titleRest => 'Saath mein aaram';

  @override
  String quiet_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yahan $count',
      one: 'Yahan 1',
    );
    return '$_temp0';
  }

  @override
  String get quiet_justYou =>
      'Abhi sirf aap hain. Ghante bhar mein aur log aate rehte hain.';

  @override
  String get quiet_joining => 'Aapki shaant jagah dhoondhi ja rahi hai…';

  @override
  String get quiet_reconnecting => 'Phir se jud raha hai…';

  @override
  String get quiet_offline =>
      'Saath mein shaanti ke liye connection chahiye. Sanctuary offline bhi chalta hai.';

  @override
  String get quiet_openSanctuary => 'Sanctuary kholein';

  @override
  String get quiet_paused =>
      'Saath mein shaanti thodi der aaram kar raha hai. Sanctuary hamesha khula hai.';

  @override
  String get quiet_failed =>
      'Saath mein shaanti abhi khul nahi paaya. Please phir se try karein.';

  @override
  String get quiet_tryAgain => 'Phir se try karein';

  @override
  String quiet_nextBlock(String time) {
    return 'Agla session $time baje shuru hoga.';
  }

  @override
  String get quiet_leave => 'Niklein';

  @override
  String get quiet_leaveNote =>
      'Jab chahein nikal sakte hain. Kuch nahi khota.';

  @override
  String get quiet_soundTitle => 'Shared awaaz';

  @override
  String get quiet_soundBody =>
      'Sab ek hi pal sunte hain, aapke apne phone par. Koi microphone nahi, kuch record nahi hota.';

  @override
  String get quiet_soundPlay => 'Shared awaaz chalayein';

  @override
  String get quiet_soundStop => 'Awaaz rokein';

  @override
  String get quiet_soundVolume => 'Volume';

  @override
  String get quiet_soundDownload =>
      'Shared awaaz ke liye ek baar download chahiye.';

  @override
  String get quiet_soundDownloadCta => 'Download karein';

  @override
  String get quiet_soundUnavailable =>
      'Is phone par abhi awaaz nahi chal pa rahi. Yahan hona hi kaafi hai.';

  @override
  String get quiet_rhythm => 'Focus rhythm (25 / 5)';

  @override
  String get quiet_rhythmBody =>
      'Apni marzi se. Sabke break ek saath aate hain.';

  @override
  String quiet_rhythmFocus(String time) {
    return 'Focus · $time baje break';
  }

  @override
  String quiet_rhythmBreak(String time) {
    return 'Break · $time baje phir focus';
  }

  @override
  String get quiet_rhythmToBreak => 'Break ka samay.';

  @override
  String get quiet_rhythmToFocus => 'Focus ka samay.';

  @override
  String get quiet_gesturesTitle => 'Yahan sabko ek gesture bhejein';

  @override
  String quiet_gestureSent(String gesture) {
    return 'Aapne $gesture bheja';
  }

  @override
  String get quiet_moment_warm_tea => 'Kisi ne garam chai baanti';

  @override
  String get quiet_moment_light_a_candle => 'Kisi ne ek diya jalaya';

  @override
  String get quiet_moment_hug => 'Kisi ne ek jhappi bheji';

  @override
  String get quiet_moment_me_too => 'Kisi ne kaha: main bhi';

  @override
  String get quiet_moment_soft_rain => 'Kisi ne halki baarish bheji';

  @override
  String get quiet_moment_stargaze => 'Koi aapke saath taare dekh raha hai';

  @override
  String get quiet_moment_deep_breath => 'Kisi ne ek gehri saans li';

  @override
  String get quiet_moment_youre_not_alone =>
      'Koi keh raha hai: aap akele nahi hain';

  @override
  String get quiet_menu => 'Session menu';

  @override
  String get quiet_report => 'Yahan ki kisi problem ki report karein';

  @override
  String get quiet_hideGestures => 'Gestures chhupayein';

  @override
  String get quiet_showGestures => 'Gestures dikhayein';

  @override
  String get quiet_gesturesHidden => 'Aapke liye gestures chhupe hue hain.';

  @override
  String get quiet_reportBody =>
      'Yahan koi dikhai nahi deta, to batayein kya hua. Ek moderator is session ke haal ke gestures dekhega.';

  @override
  String get quiet_reportNote =>
      'Moderator ko aur kuch jaanna chahiye? (optional)';

  @override
  String get quiet_reportSend => 'Report bhejein';

  @override
  String get quiet_reportThanks => 'Dhanyavaad. Ek moderator ise dekhega.';

  @override
  String get quiet_reportFailed =>
      'Yeh ho nahi paaya. Please phir se try karein.';

  @override
  String get rooms_windDownTitle => 'Saath mein sukoon se';

  @override
  String get rooms_windDownBody =>
      'Din khatam karne ke liye bees shaant minute: ek shared awaaz, dheemi saansein aur kuch narm shabd.';

  @override
  String rooms_windDownCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sukoon mein',
      one: '1 sukoon mein',
      zero: 'Abhi koi nahi',
    );
    return '$_temp0';
  }

  @override
  String get rooms_windDownBack => 'Wapas sukoon mein';

  @override
  String get rooms_windDownFailed =>
      'Yeh ho nahi paaya. Please phir se try karein.';

  @override
  String get rooms_windDownEnded =>
      'Sukoon ka samay poora hua. Acche se aaram karein.';

  @override
  String get rooms_windDownLeave => 'Niklein';

  @override
  String get rooms_windDownCue_arrive =>
      'Aa jaiye. Abhi kuch karne ko nahi hai.';

  @override
  String get rooms_windDownCue_day_quieter =>
      'Din ko dheere-dheere shaant hone dein.';

  @override
  String get rooms_windDownCue_shoulders => 'Kandhon ko dheela hone dein.';

  @override
  String get rooms_windDownCue_nothing_to_do =>
      'Abhi kisi cheez ko aapki zaroorat nahi hai.';

  @override
  String get rooms_windDownCue_slower =>
      'Har saans ko thoda aur dheema hone dein.';

  @override
  String get rooms_windDownCue_rest_well =>
      'Acche se aaram karein. Baaki raat sambhaal legi.';

  @override
  String get rooms_presenceStale =>
      'Yahan kaun hai dekhne ke liye phir se connect karein';

  @override
  String get keepsakes_refreshFailed =>
      'Abhi yaadgaarein refresh nahi ho sakin. Aapki save ki hui yaadgaarein yahin hain.';

  @override
  String get keepsakes_signedOut =>
      'Yaadgaarein refresh karne ke liye phir se sign in karein. Aapki save ki hui yaadgaarein yahin hain.';

  @override
  String get keepsakes_accountUnavailable =>
      'Abhi is account ke liye yaadgaarein available nahi hain. Account settings dekhein.';

  @override
  String get keepsakes_unavailable =>
      'Is build mein yaadgaarein refresh karna abhi taiyaar nahi hai. Aapki save ki hui yaadgaarein yahin hain.';

  @override
  String get keepsakes_accountAction => 'Account settings';

  @override
  String get universe_title => 'Aapka sansaar';

  @override
  String get universe_entry =>
      'Aadaton, shaant palon aur future you ke liye ek chhota sansaar.';

  @override
  String get universe_intro =>
      'Thodi care, thodi growth. Apni raftaar se explore karein.';

  @override
  String get universe_worldView => '3D sansaar dikhayein';

  @override
  String get universe_listView => 'List mein dekhein';

  @override
  String get universe_grove => 'Aadaton ka upvan';

  @override
  String get universe_pool => 'Shaant paani';

  @override
  String get universe_reflection => 'Mann ka bageecha';

  @override
  String get universe_observatory => 'Taaron ki vedhshala';

  @override
  String get universe_groveBody =>
      'Har aadat ek paudha hai jo log karne par badhta hai. Jin paudhon ka aapne sankalp liya hai, ve din chhootne par aaraam karte hain, aur ek log unhein jaga deta hai.';

  @override
  String get universe_poolBody =>
      'Paani ke paas shaanti se saans lein. Jab taiyaar hon, tabhi shuru karein.';

  @override
  String get universe_reflectionBody =>
      'Ek private check-in se apni feelings samjhein. Aapki feelings aapki care space mein rehti hain.';

  @override
  String get universe_observatoryBody =>
      'Future you ke liye ek pyaara message chhodein ya apne time capsules dekhein.';

  @override
  String get universe_habits => 'Aadatein kholein';

  @override
  String get universe_breathe => 'Saans lena shuru karein';

  @override
  String get universe_checkIn => 'Check-in karein';

  @override
  String get universe_capsules => 'Time capsules kholein';

  @override
  String get universe_left => 'Baayein ghumayein';

  @override
  String get universe_right => 'Daayein ghumayein';

  @override
  String get universe_zoomIn => 'Paas se dekhein';

  @override
  String get universe_zoomOut => 'Door se dekhein';

  @override
  String get universe_reset => 'Camera reset karein';

  @override
  String get universe_hint =>
      'Aas-paas dekhne ke liye drag karein. Roshni par tap karein ya neeche koi jagah chunein.';

  @override
  String get reflections_title => 'Reflections';

  @override
  String get reflections_intro =>
      'Yahan ke logon ke kuch shabd. Inka jawab sirf gestures se diya jata hai.';

  @override
  String get reflections_share => 'Reflection share karein';

  @override
  String get reflections_empty =>
      'Yahan abhi koi reflection nahi hai. Aap chahein to ek share karein, ya bas padhein aur gestures bhejein.';

  @override
  String get reflections_emptyMemory =>
      'Is room mein koi reflection share nahi hui.';

  @override
  String get reflections_loadFailed => 'Reflections abhi load nahi ho payi.';

  @override
  String get reflections_offline =>
      'Reflections ke liye connection chahiye. Aap jo bhi likhein, woh isi phone par rahega.';

  @override
  String get reflections_memory =>
      'Yeh room ab ek yaad hai: iski reflections sirf padhne ke liye hain, ab koi nayi add nahi hogi.';

  @override
  String get reflections_paused =>
      'Reflections thodi der ke liye aaram par hain. Gestures ab bhi kaam karte hain.';

  @override
  String reflections_limit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Aaj ke liye $count reflections ho gayin. Gestures hamesha khule hain.',
      one: 'Aaj ke liye 1 reflection ho gayi. Gestures hamesha khule hain.',
    );
    return '$_temp0';
  }

  @override
  String get reflections_slow => 'Reflections abhi thodi dheemi chal rahi hain';

  @override
  String reflections_left(int remaining, int total) {
    return 'Aaj $total mein se $remaining baaki';
  }

  @override
  String reflections_cardLabel(String pseudonym) {
    return '$pseudonym ki reflection';
  }

  @override
  String get reflections_mine => 'Aapki reflection';

  @override
  String get reflections_onlyYou => 'Yeh sirf aapko dikhta hai';

  @override
  String get reflections_pending =>
      'Abhi check ho raha hai. Aap padhna jaari rakhein.';

  @override
  String get reflections_heldSoon => 'Ek chhote se check ka intezaar';

  @override
  String get reflections_heldOvernight =>
      'Ek chhote se check ka intezaar. Ismein subah tak ka time lag sakta hai.';

  @override
  String get reflections_rejectedCard => 'Yeh yahan post nahi ho payi.';

  @override
  String get reflections_removedCard => 'Review ke baad ise hata diya gaya.';

  @override
  String reflections_gestureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gestures',
      one: '1 gesture',
      zero: 'Abhi koi gesture nahi',
    );
    return '$_temp0';
  }

  @override
  String get reflections_countPrivate => 'Yeh count sirf aapko dikhta hai';

  @override
  String get reflections_options => 'Reflection options';

  @override
  String reflections_gestureHint(String pseudonym) {
    return 'Is reflection par $pseudonym ko bheja jayega';
  }

  @override
  String reflections_gestureSent(String gesture, String pseudonym) {
    return '$pseudonym ko bheja gaya: $gesture';
  }

  @override
  String get reflections_delete => 'Delete karein';

  @override
  String get reflections_withdraw => 'Wapas lein';

  @override
  String get reflections_deleteTitle => 'Yeh reflection delete karein?';

  @override
  String get reflections_deleteBody =>
      'Yeh yahan sabke liye hat jayegi. Reflection edit nahi hoti, par aap chahein to nayi share karein.';

  @override
  String get reflections_withdrawTitle => 'Yeh reflection wapas lein?';

  @override
  String get reflections_withdrawBody =>
      'Yeh post nahi hogi. Aap chahein to kabhi bhi nayi share karein.';

  @override
  String get reflections_deleted => 'Aapki reflection hata di gayi.';

  @override
  String get reflections_reportTitle => 'Is reflection ko report karein';

  @override
  String get reflections_reportHidden =>
      'Humein batane ke liye shukriya. Woh reflection ab aapko nahi dikhegi.';

  @override
  String get reflections_composeTitle => 'Reflection share karein';

  @override
  String get reflections_composeLabel => 'Mann mein kya hai?';

  @override
  String get reflections_composeNote =>
      'Is room ke liye kuch shabd. Log sirf gestures se jawab de sakte hain, replies se kabhi nahi.';

  @override
  String reflections_counter(int count, int max) {
    return '$count/$max';
  }

  @override
  String reflections_counterSemantic(int count, int max) {
    return '$max mein se $count characters';
  }

  @override
  String reflections_tooLong(int max) {
    return 'Thoda chhota karein: zyada se zyada $max characters.';
  }

  @override
  String get reflections_send => 'Bhejein';

  @override
  String get reflections_sending => 'Aaram se bheja ja raha hai…';

  @override
  String get reflections_contactBlocked =>
      'Phone numbers, links aur handles yahan share nahi kiye ja sakte. Isse sab zyada safe rehte hain.';

  @override
  String get reflections_draftKept =>
      'Draft rakh liya gaya hai. Online wapas aane par ise bheja ja sakta hai.';

  @override
  String get reflections_sendFailed =>
      'Abhi bheja nahi ja saka. Aapke shabd yahin hain: thodi der mein phir se try karein.';

  @override
  String get reflections_rejectedContact =>
      'Reflection mein contact details nahi ho sakti. Inke bina phir se try karein?';

  @override
  String get reflections_rejectedLink =>
      'Reflection mein links nahi ho sakte. Iske bina phir se try karein?';

  @override
  String get reflections_rejectedPersonal =>
      'Kisi ki personal details ke baare mein sawaal yahan post nahi ho sakte. Inke bina phir se try karein?';

  @override
  String get reflections_rejectedGeneral =>
      'Yeh yahan post nahi hogi. Isse kisi ko thes pahunchna ya personal details share hona mumkin hai. Aapke shabd edit karne ke liye yahin hain.';

  @override
  String get reflections_supportSubtitle =>
      'Yeh bojh aapko akele nahi uthana hai.';

  @override
  String get reflections_backToRoom => 'Room mein wapas jayein';

  @override
  String get set_corpusTitle =>
      'Safety filters behtar karne ke liye meri reflections use karein';

  @override
  String get set_corpusNote =>
      'Rooms mein post ki gayi aapki reflections aur un par liye gaye faisle, aapke naam, room ya pseudonym ke bina, Aura ke apne safety filters sikhane ke liye rakhe ja sakte hain. Ise band karne par ab se post ki gayi koi bhi cheez nahi rakhi jayegi.';

  @override
  String get set_corpusOffline =>
      'Is choice ke liye connection chahiye. Kuch nahi badla.';

  @override
  String get device_bannedTitle => 'Is device par Aura use nahi kiya ja sakta';

  @override
  String get device_bannedBody => 'Is phone par Aura available nahi hai.';

  @override
  String get device_bannedReviewSubject => 'Device ka review';

  @override
  String get rooms_paused =>
      'Rooms kuch der aaram kar rahe hain. Thodi der baad phir se try karein.';

  @override
  String get rooms_pausedJoin =>
      'Rooms kuch der aaram kar rahe hain. Aapka check-in save ho gaya hai.';

  @override
  String get ripples_title => 'Breath Ripples';

  @override
  String get ripples_homeCard => 'Saath mein saans lein';

  @override
  String get ripples_homeCardBody =>
      'Kuch aur logon ke saath teen shaant minute. Na koi baat, na koi score.';

  @override
  String get ripples_breatheTogether => 'Saath mein saans lein';

  @override
  String ripples_invite(String name, int count, int capacity) {
    return '$name ka saath mein saans lene ka mann hai · $count/$capacity';
  }

  @override
  String get ripples_inviteJoin => 'Join karein';

  @override
  String ripples_inviteMine(int count, int capacity) {
    return 'Aapka invite open hai · $count/$capacity';
  }

  @override
  String get ripples_lobby =>
      'Saath saans lene wale log dhoondhe ja rahe hain…';

  @override
  String get ripples_lobbyHint =>
      'Intezaar ke dauraan saath-saath saans lein. Ise kabhi bhi chhoda ja sakta hai.';

  @override
  String get ripples_holdHint =>
      'Saans andar lene ke liye daba ke rakhein, bahar chhodne ke liye chhod dein';

  @override
  String get ripples_tapHint =>
      'Saans andar aur bahar ke beech badalne ke liye tap karein';

  @override
  String get ripples_breathArea => 'Saans lene ki jagah';

  @override
  String get ripples_offline =>
      'Saath mein saans lene ke liye connection chahiye. Akele saans lein?';

  @override
  String get ripples_paused =>
      'Breath Ripples abhi thodi der aaram kar raha hai. Akele saans lein?';

  @override
  String get ripples_suspended =>
      'Is account ke liye saath mein saans lena abhi ruka hua hai. Akele saans lena ab bhi mumkin hai.';

  @override
  String get ripples_closed =>
      'Is account se doosron ke saath saans lena mumkin nahi hai. Akele saans lena ab bhi mumkin hai.';

  @override
  String get ripples_guidelines =>
      'Pehle community guidelines. Unhein padhne ke liye Rooms kholein, ya abhi ke liye akele saans lein.';

  @override
  String get ripples_breatheSolo => 'Akele saans lein';

  @override
  String get ripples_settle => 'Sahaj ho jayein';

  @override
  String get ripples_fade => 'Dheere-dheere thamne dein';

  @override
  String ripples_together(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count log saath saans le rahe hain',
      one: 'Bas aap aur samandar',
    );
    return '$_temp0';
  }

  @override
  String ripples_echoesJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count echoes judi. Ye un asli logon ki recordings hain, jinhone pehle yahan saans li thi.',
      one: '1 echo judi. Ye kisi asli insaan ki recording hai, jisne pehle yahan saans li thi.',
    );
    return '$_temp0';
  }

  @override
  String ripples_guides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guide lights aapke saath saans leti hain.',
      one: 'Ek guide light aapke saath saans leti hai.',
    );
    return '$_temp0';
  }

  @override
  String get ripples_solo =>
      'Is baar akele saans chal rahi hai. Samandar ab bhi sun raha hai.';

  @override
  String get ripples_linkLost => 'Kuch pal ke liye akele saans chal rahi hai.';

  @override
  String get ripples_alone => 'Saans lete rahein. Samandar ab bhi yahin hai.';

  @override
  String get ripples_leave => 'Nikalein';

  @override
  String get ripples_accessibleMode => 'Accessible mode';

  @override
  String get ripples_accessibleModeHint =>
      'Andar aur bahar ke beech badalne ke liye tap karein. Jab aap doosron ke saath step mein hon, to tones aur zyada firm haptics ye batate hain.';

  @override
  String ripples_oceanSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights ke saath raat ka samandar',
      one: 'Aapki light ke saath raat ka samandar',
    );
    return '$_temp0';
  }

  @override
  String get ripples_lightMe => 'Aapki light';

  @override
  String ripples_lightHuman(String name) {
    return '$name ki light';
  }

  @override
  String get ripples_lightEcho =>
      'Kisi ki echo, jisne pehle yahan saans li thi';

  @override
  String get ripples_lightGuide =>
      'Ek guide light, pacer ke saath saans leti hui';

  @override
  String get ripples_echo => 'echo';

  @override
  String get ripples_guide => 'guide';

  @override
  String get ripples_you => 'aap';

  @override
  String get ripples_pulse => 'Pulse bhejein';

  @override
  String get ripples_gestureHug => 'Jhappi';

  @override
  String get ripples_gestureDeepBreath => 'Gehri saans';

  @override
  String get ripples_gestureNotAlone => 'Koi saath hai';

  @override
  String ripples_pulseFrom(String name) {
    return '$name ne pulse bheji';
  }

  @override
  String ripples_gestureFrom(String name, String gesture) {
    return '$name · $gesture';
  }

  @override
  String get ripples_contactTray => 'Thoda apnapan bhejein';

  @override
  String get ripples_mute => 'Mute';

  @override
  String get ripples_unmute => 'Unmute';

  @override
  String get ripples_block => 'Block';

  @override
  String get ripples_report => 'Report';

  @override
  String get ripples_blocked =>
      'Block kar diya gaya. Aap dono ka phir se match nahi hoga.';

  @override
  String get ripples_reported => 'Shukriya. Aura ki team se koi ise dekhega.';

  @override
  String get ripples_actionFailed =>
      'Ye nahi ho paya. Please phir se try karein.';

  @override
  String get ripples_endTitle => 'Ye kuch minute saath mein beete.';

  @override
  String get ripples_again => 'Phir se saans lein';

  @override
  String get ripples_backToRoom => 'Room par wapas';

  @override
  String get ripples_feelNow => 'Ab kaisa lag raha hai?';

  @override
  String get ripples_echoToggle => 'Meri saanson ko echo banne dein';

  @override
  String get ripples_echoToggleHint =>
      'Echo mein sirf aapki saanson ki timing rehti hai, aap kaun hain ye kabhi nahi, isliye ise aap tak wapas nahi joda ja sakta. Ise band karne par aage se koi nayi echo nahi banegi.';

  @override
  String get rooms_title => 'Rooms';

  @override
  String get rooms_yourRooms => 'Aapke rooms';

  @override
  String get rooms_memories => 'Memories';

  @override
  String get rooms_whatTitle => 'Rooms kya hain';

  @override
  String get rooms_whatBody =>
      'Abhi aap jaisa feel karne wale kuch logon ka ek chhota room, ek din ke liye.';

  @override
  String get rooms_pointName =>
      'Har room mein ek naya naam. Aapka account kisi ko nahi dikhta.';

  @override
  String get rooms_pointGestures =>
      'Koi message ya DM nahi: sirf aath warm gestures.';

  @override
  String get rooms_pointTime =>
      'Rooms ek din chalte hain, phir 7 din memory bankar rehte hain.';

  @override
  String get rooms_lanternNote =>
      'Lantern Hour: har raat aapke region ke time se 9 se 11 baje tak, rooms milkar ek lantern jalaate hain aur zyada log aate hain.';

  @override
  String get rooms_lanternNow => 'Abhi Lantern Hour chal raha hai';

  @override
  String get rooms_checkInCta => 'Room dhoondhne ke liye check-in karein';

  @override
  String get rooms_empty =>
      'Aap abhi kisi room mein nahi hain. Check-in ke baad apne jaisa feel karne walon se judna mumkin hai.';

  @override
  String get rooms_offline =>
      'Rooms ke liye connection chahiye. Aapke apne check-in is phone par save hote rahenge.';

  @override
  String get rooms_loadFailed => 'Abhi rooms tak pahunchna nahi ho paaya.';

  @override
  String get rooms_tryAgain => 'Phir se try karein';

  @override
  String get rooms_signedOut => 'Sign in karne ke baad rooms khulte hain.';

  @override
  String get rooms_signIn => 'Sign in karein';

  @override
  String get rooms_suspended =>
      'Abhi aapke account ke liye rooms ruke hue hain. Madad hamesha yahan hai.';

  @override
  String rooms_suspendedUntil(String date) {
    return '$date tak aapke account ke liye rooms ruke hue hain. Madad hamesha yahan hai.';
  }

  @override
  String get rooms_accountClosed =>
      'Aura ke rules todne ki wajah se yeh account band kar diya gaya.';

  @override
  String get rooms_profilePending =>
      'Aapke account ka setup poora hote hi rooms khulenge. Thodi der mein phir se try karein.';

  @override
  String get rooms_openHint => 'Room kholta hai';

  @override
  String rooms_memoryUntil(String date) {
    return '$date tak ek memory';
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
  String get rooms_gesture_warm_tea => 'Ek cup chai';

  @override
  String get rooms_gesture_light_a_candle => 'Ek diya';

  @override
  String get rooms_gesture_hug => 'Jhappi';

  @override
  String get rooms_gesture_me_too => 'Main bhi';

  @override
  String get rooms_gesture_soft_rain => 'Halki phuhaar';

  @override
  String get rooms_gesture_stargaze => 'Taare dekhein';

  @override
  String get rooms_gesture_deep_breath => 'Gehri saans';

  @override
  String get rooms_gesture_youre_not_alone => 'Koi saath hai';

  @override
  String rooms_hereNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abhi yahan $count hain',
      one: 'Abhi yahan 1 hai',
      zero: 'Abhi yahan koi nahi hai',
    );
    return '$_temp0';
  }

  @override
  String rooms_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aaj $count log yahan aa chuke hain',
      one: 'Aaj 1 person yahan aa chuka hai',
    );
    return '$_temp0';
  }

  @override
  String rooms_countsSemantic(int now, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      now,
      locale: localeName,
      other: 'Abhi yahan $now log',
      one: 'Abhi yahan 1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      today,
      locale: localeName,
      other: 'aaj $today',
      one: 'aaj 1',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String rooms_stripSemantic(String theme, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'abhi yahan $count log',
      one: 'abhi yahan 1 person',
    );
    return '$theme, $_temp0';
  }

  @override
  String get rooms_opening => 'Room khul raha hai…';

  @override
  String rooms_youAre(String pseudonym) {
    return 'Yahan aap $pseudonym hain';
  }

  @override
  String rooms_coldStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Aaj $count log yahan aa chuke hain. Agle aane wale ke liye ek roshni chhod jaayein.',
      one: 'Aaj yahan sabse pehle aap hain. Agle aane wale ke liye ek roshni chhod jaayein.',
    );
    return '$_temp0';
  }

  @override
  String rooms_lanternOn(String time) {
    return 'Lantern Hour · $time tak';
  }

  @override
  String rooms_closing(String time) {
    return 'Yeh room $time par memory ban jayega.';
  }

  @override
  String get rooms_memory =>
      'Yeh room ab ek memory ban gaya hai. 7 din tak ise phir se dekha ja sakta hai.';

  @override
  String get rooms_findNew => 'Naya room dhoondhein';

  @override
  String get rooms_reconnecting => 'Phir se connect ho raha hai…';

  @override
  String get rooms_membersTitle => 'Yahan aapke saath';

  @override
  String get rooms_you => 'Aap';

  @override
  String get rooms_memberHereNow => 'abhi yahan';

  @override
  String get rooms_memberAway => 'abhi door';

  @override
  String get rooms_memberMuted => 'aapke liye mute';

  @override
  String rooms_memberLabel(String pseudonym, String mood, String status) {
    return '$pseudonym, $mood, $status';
  }

  @override
  String rooms_youLabel(String pseudonym, String mood) {
    return 'Aap, $pseudonym, $mood';
  }

  @override
  String get rooms_memberHint => 'Options kholta hai';

  @override
  String get rooms_recentTitle => 'Is room mein warmth';

  @override
  String rooms_receivedLine(String pseudonym, String gesture) {
    return '$pseudonym ne aapko $gesture bheja';
  }

  @override
  String rooms_sentToMember(String gesture, String pseudonym) {
    return '$gesture $pseudonym ko bheja gaya';
  }

  @override
  String rooms_sentToRoom(String gesture) {
    return '$gesture yahan sabko bheja gaya';
  }

  @override
  String rooms_someoneSent(String gesture) {
    return 'Kisi ne $gesture bheja';
  }

  @override
  String rooms_someoneSentRoom(String gesture) {
    return 'Kisi ne yahan sabko $gesture bheja';
  }

  @override
  String rooms_youSentMember(String gesture, String pseudonym) {
    return 'Aapne $pseudonym ko $gesture bheja';
  }

  @override
  String rooms_youSentRoom(String gesture) {
    return 'Aapne yahan sabko $gesture bheja';
  }

  @override
  String get rooms_trayTitle => 'Yahan sabko warmth bhejein';

  @override
  String get rooms_trayHint => 'Yahan sabko bhejta hai';

  @override
  String get rooms_trayResting =>
      'Memory mein gestures aaram karte hain. Report, block ya mute ab bhi kiya ja sakta hai.';

  @override
  String get rooms_roomOptions => 'Room options';

  @override
  String get rooms_reportRoom => 'Yahan ki koi problem report karein';

  @override
  String get rooms_leave => 'Yeh room chhodein';

  @override
  String get rooms_removeMemory => 'Mere rooms se hatayein';

  @override
  String get rooms_leaveTitle => 'Yeh room chhodna hai?';

  @override
  String get rooms_leaveBody =>
      'Is room mein wapas aana mumkin nahi hoga, aur aapki jagah kisi aur ke liye khul jayegi. Aapka agla check-in aapke liye naya room dhoondh sakta hai.';

  @override
  String get rooms_leaveConfirm => 'Room chhodein';

  @override
  String get rooms_stay => 'Yahin rahein';

  @override
  String get rooms_removeTitle => 'Yeh memory hatani hai?';

  @override
  String get rooms_removeBody =>
      'Yeh abhi aapke rooms se hat jayegi. Waise bhi memories 7 din baad hamesha ke liye band ho jaati hain.';

  @override
  String get rooms_removeConfirm => 'Hatayein';

  @override
  String get rooms_keep => 'Rehne dein';

  @override
  String get rooms_leaveFailed =>
      'Yeh ho nahi paaya. Aap abhi bhi room mein hain.';

  @override
  String get rooms_gone =>
      'Yeh room band ho gaya hai. Rooms 7 din memory bankar rehte hain, phir chale jaate hain.';

  @override
  String get rooms_backToRooms => 'Apne rooms par wapas';

  @override
  String get rooms_offlineRoom =>
      'Rooms ke liye connection chahiye. Online wapas aate hi yeh room phir khulega.';

  @override
  String get rooms_joinTitle => 'Aapka room dhoondha ja raha hai';

  @override
  String get rooms_finding =>
      'Abhi aisa hi feel karne wale log dhoondhe ja rahe hain…';

  @override
  String get rooms_offlineJoin =>
      'Rooms ke liye connection chahiye. Aapka check-in save ho gaya hai.';

  @override
  String get rooms_joinFailed =>
      'Abhi rooms tak pahunchna nahi ho paaya. Aapka check-in save ho gaya hai.';

  @override
  String get rooms_joinLimit =>
      'Aaj is feeling ke liye 3 naye rooms ho chuke hain. Jin rooms mein aap hain, woh abhi bhi aapke liye khule hain.';

  @override
  String get rooms_seeYourRooms => 'Apne rooms dekhein';

  @override
  String get rooms_poolUnavailable =>
      'Hindi aur Hinglish rooms jald khulenge. Abhi ke liye English room join karein?';

  @override
  String get rooms_poolJoinEnglish => 'English room join karein';

  @override
  String get rooms_poolNotify => 'Khulne par mujhe batayein';

  @override
  String get rooms_poolNotifyDone =>
      'Hindi aur Hinglish rooms khulne par hum aapko yahin batayenge.';

  @override
  String get rooms_noRequest => 'Rooms check-in se khulte hain.';

  @override
  String get rooms_offer => 'Aisa hi feel karne walon ke room mein judein';

  @override
  String get rooms_offerHint =>
      'Ek room kholta hai, sirf usi ke liye naye naam ke saath';

  @override
  String get rooms_offerOffline => 'Online wapas aane par rooms khulenge';

  @override
  String get rooms_offerLater =>
      'Jab bhi kisi ke saath ka mann ho, Rooms tab mein rooms milenge.';

  @override
  String get rooms_guidelinesTitle => 'Aapke pehle room se pehle';

  @override
  String get rooms_guidelinesIntro =>
      'Rooms sukoon bhare rehte hain, kyunki har koi kuch aasaan baaton ka dhyaan rakhta hai:';

  @override
  String get rooms_rule1 =>
      'Achhe se pesh aayein. Yahan har koi sach mein apna din jee raha hai.';

  @override
  String get rooms_rule2 =>
      'Jaati, dharm, gender, sexuality ya kisi bhi aur cheez ko lekar koi hate nahi.';

  @override
  String get rooms_rule3 => 'Koi sexual content nahi.';

  @override
  String get rooms_rule4 =>
      'Contact details, milne ki baat, ya kisi ki umar, school, sheher ya photos kabhi na share karein, na maangein.';

  @override
  String get rooms_rule5 => 'Koi selling ya spam nahi.';

  @override
  String get rooms_rule6 =>
      'Kisi ko bhi khud ko chot pahunchane ke liye kabhi na uksaayein. Apne mann ki baat kehna hamesha theek hai.';

  @override
  String get rooms_guidelinesSafety =>
      'Kisi ko bhi report, block ya mute kiya ja sakta hai, aur madad hamesha bas ek tap door hai.';

  @override
  String get rooms_guidelinesAgree => 'Manzoor hai, inka dhyaan rahega';

  @override
  String get rooms_guidelinesUpdate =>
      'Rooms ki community guidelines nayi hain. Agle room se pehle inhein padhne ke liye Aura update karein.';

  @override
  String rooms_sendTo(String pseudonym) {
    return '$pseudonym ko thodi warmth bhejein';
  }

  @override
  String rooms_gestureHintMember(String pseudonym) {
    return '$pseudonym ko bhejta hai';
  }

  @override
  String get rooms_report => 'Report karein';

  @override
  String get rooms_block => 'Block karein';

  @override
  String get rooms_mute => 'Mute karein';

  @override
  String get rooms_unmute => 'Unmute karein';

  @override
  String get rooms_safetyNote =>
      'Unhein kabhi nahi bataya jaata ki kisne unhein report, block ya mute kiya.';

  @override
  String rooms_blockTitle(String pseudonym) {
    return '$pseudonym ko block karein?';
  }

  @override
  String get rooms_blockBody =>
      'Aap dono ko phir kabhi ek room mein nahi rakha jayega, aur aapke beech gestures band ho jayenge. Unhein is baare mein nahi bataya jayega.';

  @override
  String rooms_blocked(String pseudonym) {
    return '$pseudonym ko block kar diya gaya. Ab aap dono ko ek room mein nahi rakha jayega.';
  }

  @override
  String rooms_muted(String pseudonym) {
    return '$pseudonym ko aapke liye mute kar diya gaya. Yahan unke gestures aap tak nahi pahunchenge.';
  }

  @override
  String rooms_unmuted(String pseudonym) {
    return '$pseudonym ko unmute kar diya gaya.';
  }

  @override
  String get rooms_undo => 'Undo';

  @override
  String get rooms_actionFailed =>
      'Yeh ho nahi paaya. Thodi der mein phir se try karein.';

  @override
  String rooms_reportMember(String pseudonym) {
    return '$pseudonym ko report karein';
  }

  @override
  String get rooms_reportGesture => 'Is gesture ko report karein';

  @override
  String get rooms_reportWhy => 'Kya ho raha hai?';

  @override
  String get rooms_reason1 =>
      'Shayad koi khatre mein hai ya khud ko chot pahuncha raha hai';

  @override
  String get rooms_reason2 => 'Harassment ya bullying';

  @override
  String get rooms_reason3 => 'Sexual content ya advances';

  @override
  String get rooms_reason4 => 'Hate ya slurs';

  @override
  String get rooms_reason5 => 'Contact details ya personal info';

  @override
  String get rooms_reason6 => 'Spam ya selling';

  @override
  String get rooms_reason7 => 'Shayad kisi ki umar 13 se kam hai';

  @override
  String get rooms_reason8 => 'Kuch aur';

  @override
  String get rooms_reason9 =>
      'Lagta hai kisi kam umar ke insaan ko target kiya ja raha hai';

  @override
  String get rooms_reportNoteLabel =>
      'Moderator ko kuch batana hai? (optional)';

  @override
  String get rooms_reportNoteHelp =>
      'Ise sirf Aura ke moderators padhte hain. Please phone number, links aur handles na likhein.';

  @override
  String get rooms_reportNoteContact =>
      'Phone number, links aur handles yahan share nahi kiye ja sakte. Isse sab zyada safe rehte hain.';

  @override
  String get rooms_reportSend => 'Report bhejein';

  @override
  String get rooms_reportThanks =>
      'Batane ke liye shukriya. Aamtaur par ek din ke andar ek moderator ise dekhenge.';

  @override
  String get rooms_reportHidden =>
      'Batane ke liye shukriya. Jab tak moderator ise dekhte hain, is room mein unke gestures aap tak nahi aayenge.';

  @override
  String get rooms_reportGestureHidden =>
      'Batane ke liye shukriya. Woh gesture ab aapke liye chhupa diya gaya hai.';

  @override
  String get rooms_reportCrisis =>
      'Batane ke liye shukriya. Ek moderator jald hi dekhenge, aur madad hamesha bas ek tap door hai.';

  @override
  String get rooms_reportLimit =>
      'Aaj kaafi reports bheji ja chuki hain. Agar koi khatre mein hai, to help button hamesha yahan hai.';

  @override
  String get rooms_reportFailed =>
      'Yeh ho nahi paaya, isliye kuch nahi bheja gaya. Thodi der mein phir se try karein.';

  @override
  String get rooms_reportOffline =>
      'Reports ke liye connection chahiye. Abhi tak kuch nahi bheja gaya.';

  @override
  String get rooms_surveyTitle => 'Kya akelapan thoda kam laga?';

  @override
  String get rooms_surveyYes => 'Haan';

  @override
  String get rooms_surveyNo => 'Kuch khaas nahi';

  @override
  String get rooms_surveySkip => 'Skip karein';

  @override
  String get settings_poolNoticeEn =>
      'Naye rooms aapko English bolne walon ke saath jodenge. Aap abhi jis room mein hain, uski bhasha nahi badlegi.';

  @override
  String get settings_poolNoticeTe =>
      'Naye rooms aapko Telugu aur Tenglish bolne walon ke saath jodenge. Aap abhi jis room mein hain, uski bhasha nahi badlegi.';

  @override
  String get settings_poolNoticeHi =>
      'Naye rooms aapko Hindi aur Hinglish bolne walon ke saath jodenge. Aap abhi jis room mein hain, uski bhasha nahi badlegi.';

  @override
  String get settings_poolNoticeHiSoon =>
      'Hindi aur Hinglish rooms jald khulenge, isliye abhi naye rooms aapko English bolne walon ke saath jodenge.';

  @override
  String get sanctuary_title => 'Sanctuary';

  @override
  String get sanctuary_intro =>
      'Sirf aapke liye ek shaant jagah. Apni raftaar se chalein. Yahan kisi cheez ka score nahi hota.';

  @override
  String get sanctuary_todayTitle => 'Aaj ka ek minute';

  @override
  String get sanctuary_breatheSection => 'Saans lein';

  @override
  String get sanctuary_breatheCard => 'Apne Aura ke saath saans lein';

  @override
  String get sanctuary_breatheCardBody =>
      'Calm, box ya 4-7-8 breathing, jitni der mann ho.';

  @override
  String get sanctuary_groundingSection => 'Grounding';

  @override
  String get sanctuary_begin => 'Shuru karein';

  @override
  String get sanctuary_start => 'Start karein';

  @override
  String get sanctuary_pause => 'Pause karein';

  @override
  String get sanctuary_resume => 'Phir se shuru karein';

  @override
  String get sanctuary_finish => 'Khatam karein';

  @override
  String get sanctuary_next => 'Aage';

  @override
  String get sanctuary_progress => 'Is session ki progress';

  @override
  String get sanctuary_progressBegun => 'Abhi shuru hua';

  @override
  String get sanctuary_progressHalf => 'Lagbhag aadha';

  @override
  String get sanctuary_progressNearly => 'Lagbhag poora';

  @override
  String get sanctuary_progressDone => 'Poora hua';

  @override
  String habits_autoLogged(String habit) {
    return 'Aaj ke liye $habit ko done mark kiya gaya.';
  }

  @override
  String get breathe_rhythm => 'Rhythm';

  @override
  String get breathe_calm => 'Calm';

  @override
  String get breathe_calmBody =>
      '4 tak saans andar, 6 tak baahar. Halki aur ek-si.';

  @override
  String get breathe_box => 'Box';

  @override
  String get breathe_boxBody =>
      'Andar, rokein, baahar, rokein. Har baar chaar ginti.';

  @override
  String get breathe_478 => '4-7-8';

  @override
  String get breathe_478Body => '4 tak andar, 7 tak rokein, 8 tak baahar.';

  @override
  String get breathe_lightHeaded =>
      'Agar chakkar-sa lage, to rukein aur normal tarah se saans lein.';

  @override
  String get breathe_length => 'Kitni der';

  @override
  String breathe_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minute',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get breathe_openEnded => 'Jab tak main na rokun';

  @override
  String get breathe_in => 'Saans andar lein';

  @override
  String get breathe_hold => 'Rokein';

  @override
  String get breathe_out => 'Saans baahar chhodein';

  @override
  String get breathe_paused => 'Ruka hua hai. Aaram se.';

  @override
  String get breathe_done => 'Yeh waqt sirf aapke liye tha.';

  @override
  String get breathe_again => 'Phir se';

  @override
  String get breathe_land1 => 'Apne pairon ko zameen par mehsoos karein.';

  @override
  String get breathe_land2 => 'Aas-paas ki teen aawazon par dhyaan dein.';

  @override
  String get breathe_keepGoing => 'Jaari rakhein';

  @override
  String get breathe_land3 => 'Kandhon ko dheela chhod dein.';

  @override
  String get senses_title => 'Paanch senses';

  @override
  String get senses_card =>
      'Aas-paas jo hai, use ek-ek sense se mehsoos karein.';

  @override
  String get senses_intro =>
      'Chaliye, aas-paas jo hai use ek-ek sense se mehsoos karein. Apni raftaar se chalein.';

  @override
  String get senses_see => 'Paanch cheezein jo aapko dikh rahi hain';

  @override
  String get senses_seeBody =>
      'Dheere-dheere aas-paas dekhein. Mann mein ya bolkar unke naam lein.';

  @override
  String get senses_touch => 'Chaar cheezein jinhein aap chhoo sakein';

  @override
  String get senses_touchBody =>
      'Neeche ki kursi, aapke kapde, skin ko chhooti hawa.';

  @override
  String get senses_hear => 'Teen aawazein jo aapko sunai de rahi hain';

  @override
  String get senses_hearBody => 'Paas ki ya door ki, tez ya dheemi.';

  @override
  String get senses_smell => 'Do cheezein jinki mehak aa rahi ho';

  @override
  String get senses_smellBody =>
      'Ya agar paas kuch na ho, to do pasandeeda khushbuein.';

  @override
  String get senses_taste => 'Ek cheez jiska swaad mehsoos ho';

  @override
  String get senses_tasteBody =>
      'Ya paani ka ek ghoont lein aur use mehsoos karein.';

  @override
  String senses_step(int step, int total) {
    return '$total mein se step $step';
  }

  @override
  String get senses_done => 'Aap yahan hain, isi pal mein. Bahut achha.';

  @override
  String get heart_title => 'Dil par haath';

  @override
  String get heart_card => 'Sirf aapke liye, ek minute ki garmahat.';

  @override
  String get heart_intro =>
      'Ek haath apne dil par rakhein, ya jahan bhi sukoon lage.';

  @override
  String get heart_1 => 'Apne haath ki garmahat mehsoos karein.';

  @override
  String get heart_2 => 'Dheere se saans lein. Koi jaldi nahi hai.';

  @override
  String get heart_3 => 'Yahan jo bhi mehsoos ho, uski jagah hai.';

  @override
  String get heart_4 =>
      'Khud ke saath utni hi narmi rakhein, jitni kisi dost ke saath.';

  @override
  String get heart_done => 'Khud ke saath narmi rakhne ke liye shukriya.';

  @override
  String get gratitude_title => 'Teen chhoti baatein';

  @override
  String get gratitude_card =>
      'Aaj ki teen chhoti baatein jo theek-thaak rahin.';

  @override
  String get gratitude_intro =>
      'Aaj ki teen chhoti baatein, ek-ek karke yaad karein. Kuch likhna nahi hai.';

  @override
  String get gratitude_1 => 'Ek chhoti baat jo theek rahi';

  @override
  String get gratitude_1Body =>
      'Bahut chhoti baat bhi chalegi, jaise kuch garam peena ya kisi ke meethe bol.';

  @override
  String get gratitude_2 => 'Ek aur chhoti baat';

  @override
  String get gratitude_2Body => 'Kuch jo aapne dekha, suna ya kiya.';

  @override
  String get gratitude_3 => 'Bas ek aur chhoti baat';

  @override
  String get gratitude_3Body => 'Shayad aapke apne baare mein kuch.';

  @override
  String get gratitude_done =>
      'Inhein ek pal ke liye apne paas rakhein. Ye aapki hain.';

  @override
  String get savour_intro =>
      'Chaliye, aaj ke ek achhe pal ko dheere-dheere phir se jiyein.';

  @override
  String get savour_1 =>
      'Aaj ka ek achha pal yaad karein, chahe kitna bhi chhota ho.';

  @override
  String get savour_2 =>
      'Woh pal kahan ka tha? Aas-paas kya dikh aur sunai de raha tha?';

  @override
  String get savour_3 =>
      'Ab use yaad karke kaisa lag raha hai, is par dhyaan dein.';

  @override
  String get savour_done => 'Use thodi der aur apne saath rehne dein.';

  @override
  String get minute_forYou => 'Aapke liye ek minute';

  @override
  String get minute_calmTitle => 'Ek shaant minute';

  @override
  String get minute_boxTitle => 'Box breathing';

  @override
  String get minute_478Title => '4-7-8 breathing';

  @override
  String get minute_stillnessTitle => 'Ek minute ka thehraav';

  @override
  String get minute_stillnessBody => 'Orb ke saath ek shaant minute.';

  @override
  String get minute_landTitle => 'Thehrne ke liye tees second';

  @override
  String get minute_landBody => 'Orb ke saath teen dheemi saansein.';

  @override
  String get minute_comfortTitle => 'Thoda sukoon';

  @override
  String get minute_comfortBody =>
      'Dil par ek haath, aur ek minute ki garmahat.';

  @override
  String get minute_savourTitle => 'Is pal ko jiyein';

  @override
  String get minute_savourBody => 'Aaj ka ek achha pal phir se jiyein.';

  @override
  String get companion_storm1 =>
      'Ek saath bahut kuch hai. Aapki roshni ab bhi yahin hai.';

  @override
  String get companion_storm2 =>
      'Storm ko naam dena himmat ki baat hai. Aapne apna saath diya.';

  @override
  String get companion_storm3 =>
      'Badi, tez feelings ke liye yahan jagah hai. Aapke liye bhi.';

  @override
  String get companion_storm4 =>
      'Storm wale din bhi maayne rakhte hain. Check-in karne ke liye shukriya.';

  @override
  String get companion_storm5 =>
      'Aapne ise imaandaari se naam diya. Yeh maayne rakhta hai.';

  @override
  String get companion_storm6 => 'Storm bhi aapke aasmaan ka hissa hai.';

  @override
  String get companion_storm7 =>
      'Andar jo bhi umad raha ho, aapne use pehchaana. Iski ahmiyat hai.';

  @override
  String get companion_storm8 => 'Storm mein bhi, aapki chamak aapki apni hai.';

  @override
  String get companion_rain1 =>
      'Yeh bhaari lag raha hai. Aapki roshni ab bhi aapke saath hai.';

  @override
  String get companion_rain2 =>
      'Low din ke baare mein sach kehna himmat ki baat hai. Aapne apna saath diya.';

  @override
  String get companion_rain3 =>
      'Dheemi, bhaari feelings ke liye yahan jagah hai. Aapke liye bhi.';

  @override
  String get companion_rain4 =>
      'Rain wale din bhi maayne rakhte hain. Check-in karne ke liye shukriya.';

  @override
  String get companion_rain5 =>
      'Aaj aapne khud se sach kaha. Yeh maayne rakhta hai.';

  @override
  String get companion_rain6 => 'Rain bhi aapke aasmaan ka hissa hai.';

  @override
  String get companion_rain7 =>
      'Yeh jitna bhi bhaari ho, aapne ise pehchaana. Iski ahmiyat hai.';

  @override
  String get companion_rain8 =>
      'Baadal wale dinon mein bhi, aapki chamak aapki apni hai.';

  @override
  String get companion_moonlight1 =>
      'Ek shaant, thehra hua pal. Aapki roshni aaraam se hai.';

  @override
  String get companion_moonlight2 =>
      'Ek shaant pal ko pehchaanna bhi maayne rakhta hai. Aapne apna saath diya.';

  @override
  String get companion_moonlight3 =>
      'Naram, halki feelings ke liye yahan jagah hai. Aapke liye bhi.';

  @override
  String get companion_moonlight4 =>
      'Sukoon bhare din bhi maayne rakhte hain. Check-in karne ke liye shukriya.';

  @override
  String get companion_moonlight5 =>
      'Aapne ise mehsoos karne ke liye ek pal liya. Yeh maayne rakhta hai.';

  @override
  String get companion_moonlight6 =>
      'Moonlight bhi aapke aasmaan ka hissa hai.';

  @override
  String get companion_moonlight7 =>
      'Yeh sukoon jitna bhi chhota ho, aapne ise pehchaana. Iski ahmiyat hai.';

  @override
  String get companion_moonlight8 =>
      'Is khamoshi mein, aapki chamak aapki apni hai.';

  @override
  String get companion_sunrise1 =>
      'Ek roshan pal. Aapki roshni chamak rahi hai.';

  @override
  String get companion_sunrise2 =>
      'Ek achhe pal ko pehchaanna bhi maayne rakhta hai. Aapne apna saath diya.';

  @override
  String get companion_sunrise3 =>
      'Badi, chamakti feelings ke liye yahan jagah hai. Aapke liye bhi.';

  @override
  String get companion_sunrise4 =>
      'Roshan din bhi maayne rakhte hain. Check-in karne ke liye shukriya.';

  @override
  String get companion_sunrise5 =>
      'Aapne khud ko yeh mehsoos karne diya. Yeh maayne rakhta hai.';

  @override
  String get companion_sunrise6 => 'Sunrise bhi aapke aasmaan ka hissa hai.';

  @override
  String get companion_sunrise7 =>
      'Yeh bada ho ya chhota, aapne ise pehchaana. Iski ahmiyat hai.';

  @override
  String get companion_sunrise8 =>
      'Is ujaale mein, aapki chamak aapki apni hai.';

  @override
  String get companion_neutral1 => 'Check-in karne ke liye shukriya.';

  @override
  String get companion_neutral2 => 'Aapne apna saath diya.';

  @override
  String get companion_neutral3 => 'Aapki roshni ab bhi yahin hai.';

  @override
  String get companion_neutral4 => 'Yahan koi jaldi nahi hai.';

  @override
  String get prompt_note1 => 'Aaj kis chhoti cheez se thodi madad mili?';

  @override
  String get prompt_note2 => 'Abhi mann mein kya chal raha hai?';

  @override
  String get prompt_note3 => 'Aaj ki kaun-si baat yaad rakhne ka mann hai?';

  @override
  String get prompt_storm1 =>
      'Abhi mann mein sabse zyada jagah kis cheez ne gheri hai?';

  @override
  String get prompt_storm2 => 'Agar yeh ehsaas bol paata, to kya kehta?';

  @override
  String get prompt_storm3 =>
      'Aisi kaun-si ek cheez hai jise ek minute ke liye hi sahi, kinaare rakha ja sake?';

  @override
  String get prompt_rain1 => 'Abhi kya sukoon bhara lagega?';

  @override
  String get prompt_rain2 => 'Aaj mann par kya bhaari hai?';

  @override
  String get prompt_rain3 =>
      'Haal mein kiski ya kis cheez ki narmi mehsoos hui?';

  @override
  String get prompt_moonlight1 => 'Kis cheez se mann thehra hua lag raha hai?';

  @override
  String get prompt_moonlight2 => 'Aaj kis cheez ne din ko thoda naram banaya?';

  @override
  String get prompt_moonlight3 =>
      'Is pal se kya apne saath rakhne ka mann hai?';

  @override
  String get prompt_sunrise1 => 'Aaj kis cheez se mann khil raha hai?';

  @override
  String get prompt_sunrise2 => 'Kya achha raha, jise yaad rakhne ka mann hai?';

  @override
  String get prompt_sunrise3 => 'Yeh kiske saath baantne ka mann hai?';

  @override
  String get prompt_capsule1 => 'Future you tak kaun-si baat pahunchaani hai?';

  @override
  String get prompt_capsule2 =>
      'Abhi kis cheez se madad mil rahi hai, jo shayad baad mein yaad na rahe?';

  @override
  String get prompt_capsule3 => 'Mushkil din par khud se kya kehna hai?';

  @override
  String get prompt_capsuleStorm =>
      'Jab sab kuch bahut zyada lage, tab kis cheez se madad milti hai?';

  @override
  String get prompt_capsuleRain => 'Bhaari din par kya sunne ka mann hoga?';

  @override
  String get prompt_capsuleMoonlight =>
      'Yeh sukoon phir se paane mein kis cheez se madad milti hai?';

  @override
  String get prompt_capsuleSunrise =>
      'Future you ke saath kis baat ka jashn manaane ka mann hai?';

  @override
  String get prompt_another => 'Koi aur sawaal';

  @override
  String get prompt_settingsTitle => 'Writing prompts';

  @override
  String get prompt_settingsBody =>
      'Khaali note mein ek halka-sa sawaal. Kabhi save nahi hota.';

  @override
  String get backfill_add => 'Pichhla check-in add karein';

  @override
  String get backfill_pickTitle => 'Kaun-sa din?';

  @override
  String backfill_pickBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Pichhle $count dinon mein se kisi bhi din ka check-in add kiya ja sakta hai.',
      one: 'Kal ke liye check-in add kiya ja sakta hai.',
    );
    return '$_temp0';
  }

  @override
  String get backfill_title => 'Us din kaisa lag raha tha?';

  @override
  String backfill_forDay(String day) {
    return '$day ka check-in';
  }

  @override
  String get backfill_changeDay => 'Din badlein';

  @override
  String get backfill_outOfRange =>
      'Pichhle check-in sirf ek hafte peeche tak add kiye ja sakte hain. Koi aur din chunein?';

  @override
  String get backfill_savedTitle => 'Aapke aasmaan mein jud gaya';

  @override
  String backfill_savedDay(String day) {
    return '$day ke liye save ho gaya.';
  }

  @override
  String get backfill_savedBody =>
      'Starlight usi din kiye gaye check-in se milta hai.';

  @override
  String get history_addedLater => 'Baad mein joda gaya';

  @override
  String history_whenAddedLater(String day) {
    return '$day · baad mein joda gaya';
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
  String get shell_checkIn => 'Check-in';

  @override
  String get shell_checkInHint => 'Naya check-in shuru karta hai';

  @override
  String get safety_emergencyWhen =>
      'Agar aapko ya aapke aas-paas kisi ko turant khatra hai, gambhir chot lagi hai, ya safe reh paana mushkil hai, to turant emergency services ko call karein.';

  @override
  String get safety_settingsLink => 'Settings mein Help & Safety';

  @override
  String get safety_settingsHint =>
      'Support contact, Grievance Officer aur policies';

  @override
  String get sounds_title => 'Sounds';

  @override
  String get sounds_cardBody =>
      'Baarish, samundar, hawa aur bhi bahut kuch. Jab tak aap na chunein, kuch nahi bajta.';

  @override
  String get sounds_cardPlaying => 'Abhi baj raha hai';

  @override
  String get sounds_intro =>
      'Shuru karne ke liye ek sound chunein, ya chaar tak mix karein. Jab tak aap tap na karein, kuch nahi bajta.';

  @override
  String get sounds_nothingPlaying => 'Kuch nahi baj raha';

  @override
  String get sounds_statePlaying => 'Baj raha hai';

  @override
  String get sounds_statePaused => 'Ruka hua';

  @override
  String get sounds_backgroundNote =>
      'Screen off hone par bhi sounds bajti rehti hain. Headphones disconnect hone ya call aane par ye ruk jaati hain.';

  @override
  String get sounds_notificationChannel => 'Sounds playback';

  @override
  String get sounds_windDownTitle => 'Night wind-down';

  @override
  String get sounds_windDownBody =>
      'Lagbhag 20 minute ki sounds, jo dheere-dheere kam hokar khamoshi mein badal jaati hain. Har raat inka order badalta hai.';

  @override
  String get sounds_windDownBegin => 'Wind-down shuru karein';

  @override
  String sounds_windDownLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Lagbhag $minutes minute baaki',
      one: 'Lagbhag 1 minute baaki',
    );
    return '$_temp0';
  }

  @override
  String get sounds_windDownBusy =>
      'Wind-down chal raha hai. Apna mix banane ke liye pehle ise rokein.';

  @override
  String get sounds_mixSection => 'Apna mix banayein';

  @override
  String get sounds_mixHint => 'Ek saath chaar tak, har ek ka apna volume.';

  @override
  String get sounds_stemRain => 'Baarish';

  @override
  String get sounds_stemOcean => 'Samundar';

  @override
  String get sounds_stemWind => 'Hawa';

  @override
  String get sounds_stemNightInsects => 'Raat ke jheengur';

  @override
  String get sounds_stemSingingBowl => 'Singing bowl';

  @override
  String get sounds_stemChimes => 'Chimes';

  @override
  String get sounds_stemBrownNoise => 'Brown noise';

  @override
  String get sounds_stemPinkNoise => 'Pink noise';

  @override
  String get sounds_stemDeepBell => 'Door ki ghanti';

  @override
  String get sounds_stemMonsoonRoof => 'Chhat par barsaat';

  @override
  String get sounds_stemStream => 'Behti dhaara';

  @override
  String get sounds_stemFireplace => 'Alaav';

  @override
  String get sounds_stemDistantThunder => 'Door ki garaj';

  @override
  String sounds_stemOn(String name, int percent) {
    return '$name, baj raha hai, volume $percent%';
  }

  @override
  String sounds_stemPaused(String name, int percent) {
    return '$name, ruka hua, volume $percent%';
  }

  @override
  String sounds_stemOff(String name) {
    return '$name, off';
  }

  @override
  String sounds_stemLocked(String name) {
    return '$name, Aura Plus ka hissa';
  }

  @override
  String sounds_stemNeedsDownload(String name, String size) {
    return '$name, ek baar $size download karna hai';
  }

  @override
  String sounds_stemDownloading(String name) {
    return '$name, download ho raha hai';
  }

  @override
  String sounds_volume(String name) {
    return '$name ka volume';
  }

  @override
  String get sounds_plusBadge => 'Aura Plus';

  @override
  String get sounds_plusNote => 'Aura Plus ke saath milta hai.';

  @override
  String get sounds_full =>
      'Chaar sounds baj rahi hain. Nayi add karne ke liye ek band karein.';

  @override
  String get sounds_play => 'Play';

  @override
  String get sounds_pause => 'Pause';

  @override
  String get sounds_stop => 'Stop';

  @override
  String get sounds_timer => 'Timer';

  @override
  String get sounds_timerTitle => 'Kitni der baad dheere-dheere band ho';

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
      other: 'Lagbhag $minutes minute mein dheere-dheere band hoga',
      one: 'Lagbhag 1 minute mein dheere-dheere band hoga',
    );
    return '$_temp0';
  }

  @override
  String get sounds_fadingOut => 'Dheere-dheere band ho raha hai';

  @override
  String get sounds_saveMix => 'Ye mix save karein';

  @override
  String get sounds_savedMixes => 'Save kiye gaye mix';

  @override
  String get sounds_mixSaved => 'Is phone par save ho gaya.';

  @override
  String get sounds_mixAlreadySaved => 'Ye mix pehle se save hai.';

  @override
  String sounds_playMix(String mix) {
    return '$mix play karein';
  }

  @override
  String sounds_removeMix(String mix) {
    return '$mix hatayein';
  }

  @override
  String get sounds_mixUnavailable => 'Ye mix abhi play nahi ho sakta.';

  @override
  String get sounds_downloadTitle => 'Recorded sounds';

  @override
  String sounds_downloadBody(String size) {
    return 'Ek baar $size download karna hai. Uske baad ye bina internet ke bajti hain. Tab tak aapke phone par bani sounds bajti hain.';
  }

  @override
  String get sounds_download => 'Download karein';

  @override
  String get sounds_downloading => 'Download ho raha hai…';

  @override
  String get sounds_downloadOffline =>
      'Aap offline hain. Brown noise aur aapke phone par bani sounds abhi bajti hain; recordings ka download baad mein ho sakta hai.';

  @override
  String get sounds_downloadFailed =>
      'Download poora nahi hua. Kuch nahi khoya; baad mein phir se download karna mumkin hai.';

  @override
  String sounds_noSpace(String size) {
    return 'Sounds ke liye lagbhag $size jagah chahiye. Thodi jagah khaali karein, ya brown noise chalayein, jise jagah ki zaroorat nahi.';
  }

  @override
  String sounds_megabytes(String size) {
    return '$size MB';
  }

  @override
  String get sounds_removeDownloads => 'Download ki gayi sounds hatayein';

  @override
  String get sounds_downloadsRemoved =>
      'Download ki gayi sounds hata di gayin. Aapke phone par bani sounds ab bhi bajti hain.';

  @override
  String get update_title => 'Please Aura update karein';

  @override
  String get update_body =>
      'Aura ko aage chalane ke liye ise update karna zaroori hai. Bas ek pal lagega.';

  @override
  String get update_safe =>
      'Is phone par sab kuch surakshit rahega. Update hote hi aapke check-ins sync ho jayenge.';

  @override
  String get update_openAppStore => 'App Store mein update karein';

  @override
  String get update_openPlayStore => 'Google Play par update karein';

  @override
  String get update_storeFailed =>
      'Store nahi khula. Please khud kholkar Aura search karein.';

  @override
  String get voice_record => 'Voice note record karein';

  @override
  String get voice_recordHint => 'Ek minute tak. Ye sirf aapko sunai dega.';

  @override
  String get voice_rationaleTitle => 'Apni awaaz add karein?';

  @override
  String get voice_rationaleBody =>
      'Voice note record karne ke liye Aura ko aapka microphone chahiye. Recordings sirf aapke paas rehti hain aur rooms mein kabhi share nahi hoti.';

  @override
  String get voice_rationaleAllow => 'Allow karein';

  @override
  String get voice_denied =>
      'Voice off hai. Iski jagah type karein, ya Settings mein ise on karein.';

  @override
  String get voice_openSettings => 'Settings';

  @override
  String get voice_recording => 'Record ho raha hai';

  @override
  String voice_elapsed(String time, String limit) {
    return '$time · $limit tak';
  }

  @override
  String voice_recordingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Record ho raha hai, $seconds seconds',
      one: 'Record ho raha hai, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_stop => 'Recording rokein';

  @override
  String get voice_started => 'Recording shuru hui';

  @override
  String voice_recorded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Voice note record hua, $seconds seconds',
      one: 'Voice note record hua, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_limitReached =>
      'Poora ek minute ho gaya, isliye recording ruk gayi. Aapka voice note ready hai.';

  @override
  String get voice_recordFailed =>
      'Abhi voice record nahi ho payi. Aapka likha hua phir bhi save hoga.';

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
  String get voice_play => 'Voice note play karein';

  @override
  String get voice_pause => 'Voice note pause karein';

  @override
  String get voice_reRecord => 'Phir se record karein';

  @override
  String get voice_remove => 'Hatayein';

  @override
  String get voice_removeSemantic => 'Voice note hatayein';

  @override
  String get voice_dropped =>
      'Aapka check-in save ho gaya hai. Voice note rakha nahi ja saka, shayad phone mein jagah kam hai.';

  @override
  String get voice_loading => 'Aapka voice note laaya ja raha hai…';

  @override
  String get voice_offline => 'Phir se online hone par voice note chalega.';

  @override
  String get voice_failed =>
      'Ye voice note abhi play nahi ho paya. Thodi der mein phir se try karein.';

  @override
  String get voice_section => 'Aapki awaaz';

  @override
  String get voice_hasVoice => 'Isme voice note hai';

  @override
  String get widget_prompt => 'Abhi kaisa lag raha hai?';

  @override
  String get widget_checkIn => 'Check-in';

  @override
  String get widget_doneToday => 'Aaj check-in ho gaya';

  @override
  String get widget_saved => 'Save ho gaya';

  @override
  String widget_savedStarlight(int amount) {
    return 'Save ho gaya · +$amount Starlight';
  }

  @override
  String get widget_needHelp => 'Madad chahiye';

  @override
  String get widget_openApp => 'Aage badhne ke liye Aura kholein';

  @override
  String get widget_openAppDiscreet => 'Aage badhne ke liye app kholein';

  @override
  String get widget_capsuleWaiting => 'Past you se kuch intezaar mein hai';

  @override
  String get widget_back => 'Wapas';

  @override
  String widget_lastMood(String mood) {
    return 'Last: $mood';
  }

  @override
  String get widget_galleryName => 'Aura check-in';

  @override
  String get widget_galleryDescription =>
      'Home screen se hi do taps mein check-in karein.';

  @override
  String get widget_lockGalleryName => 'Jhatpat check-in';

  @override
  String get widget_lockGalleryDescription =>
      'Ek taara jo aapka check-in kholta hai. Ye kabhi nahi dikhata ki aapka mann kaisa hai.';

  @override
  String get widget_settingsTitle => 'Home screen widget';

  @override
  String get widget_showLastMood => 'Mera last mood dikhayein';

  @override
  String get widget_showLastMoodNote =>
      'Sirf aapki home screen par. Lock screen par ye kabhi nahi dikhta.';

  @override
  String get widget_discreet => 'Discreet widget';

  @override
  String get widget_discreetNote =>
      'Bina app ke naam aur bina mood words ka ek simple taara. Ise tap karne par app khulta hai.';

  @override
  String get habits_commitmentsTitle => 'Sankalp';

  @override
  String get habits_commitmentsBody =>
      'Jin aadaton ko aap apne paas rakhna chahte hain, unhein chunein. Kuch din chhoot jayein to aapki duniya mein us aadat ka paudha aaraam karta hai. Ek log use jaga deta hai. Aapki Starlight aur glow days ko kabhi kuch nahi hota.';

  @override
  String get habits_commitmentSwitch => 'Sankalp ki tarah lein';

  @override
  String habits_pauseSemantic(String name) {
    return '$name ko viraam dein';
  }

  @override
  String habits_pausedUntil(String date) {
    return '$date tak viraam';
  }

  @override
  String habits_pauseDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count din',
      one: '$count din',
    );
    return '$_temp0';
  }

  @override
  String get habits_pauseEnd => 'Viraam khatam karein';

  @override
  String get universe_yourPlants => 'Aapke paudhe';

  @override
  String universe_plantsResting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count paudhe aaraam kar rahe hain. Har ek ko ek log jaga deta hai.',
      one: 'Ek paudha aaraam kar raha hai. Ek log use jaga deta hai.',
    );
    return '$_temp0';
  }

  @override
  String get universe_stage_seed => 'Beej';

  @override
  String get universe_stage_sprout => 'Ankur';

  @override
  String get universe_stage_young => 'Badhta hua';

  @override
  String get universe_stage_grown => 'Poora badha';

  @override
  String get universe_stage_flourishing => 'Hara-bhara';

  @override
  String get universe_stage_ancient => 'Praacheen';

  @override
  String get universe_vitality_dimmed => 'Aaraam mein';

  @override
  String get universe_vitality_wilting => 'Thoda jhuka hua';

  @override
  String get universe_vitality_dormant =>
      'So raha hai, aapka intezaar kar raha hai';

  @override
  String universe_plantRow(String name, String stage) {
    return '$name, $stage';
  }

  @override
  String universe_plantRowResting(String name, String stage, String state) {
    return '$name, $stage, $state';
  }
}
