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
  String get common_continue => 'Continue';

  @override
  String get common_back => 'Back';

  @override
  String get common_done => 'Done';

  @override
  String get common_notNow => 'Not now';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_close => 'Close';

  @override
  String get common_comingSoon => 'Coming soon';

  @override
  String get help_button => 'I need help now';

  @override
  String get help_title => 'Help is here';

  @override
  String get help_subtitle =>
      'You don\'t have to carry this alone. Reach out now, or take a minute to breathe.';

  @override
  String get help_crisisTitle => 'It sounds like a lot right now.';

  @override
  String get help_crisisSubtitle =>
      'You don\'t have to carry it alone. Your check-in is saved.';

  @override
  String get help_teleManas => 'Tele-MANAS · free, 24×7';

  @override
  String get help_teleManasTollFree => 'Tele-MANAS toll-free';

  @override
  String get help_emergency112 => 'Emergency';

  @override
  String get help_childline => 'Childline · for under-18s';

  @override
  String get help_us988 => 'Suicide & Crisis Lifeline · call or text';

  @override
  String get help_otherEmergency =>
      'If you\'re in danger right now, please call your local emergency number.';

  @override
  String help_callSemantic(String name, String number) {
    return 'Call $name, $number';
  }

  @override
  String get help_groundingTitle => 'Sixty seconds to land';

  @override
  String get help_groundingBody =>
      'Breathe with the circle. Everything else can wait a minute.';

  @override
  String get help_groundingStart => 'Start';

  @override
  String get help_groundingPause => 'Pause';

  @override
  String get help_groundingResume => 'Resume';

  @override
  String get help_breatheIn => 'Breathe in';

  @override
  String get help_breatheOut => 'Breathe out';

  @override
  String get help_ground1 => 'Feel your feet on the ground.';

  @override
  String get help_ground2 => 'Notice five things you can see.';

  @override
  String get help_ground3 => 'Notice three sounds around you.';

  @override
  String get help_ground4 => 'Let your shoulders drop.';

  @override
  String get help_ground5 => 'You\'re here. That\'s enough for now.';

  @override
  String get help_groundingDone => 'Well done. Stay as long as you need.';

  @override
  String help_secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds left',
      one: '1 second left',
    );
    return '$_temp0';
  }

  @override
  String get help_disclaimer =>
      'Aura is not a medical device or an emergency service.';

  @override
  String get help_backToCheckin => 'Back to my check-in';

  @override
  String get welcome_title => 'Welcome to Aura';

  @override
  String get welcome_body =>
      'A quiet place to notice how you feel. Your check-ins stay private, and your Aura grows a little each time you show up.';

  @override
  String get welcome_begin => 'Begin';

  @override
  String get dob_title => 'When\'s your birthday?';

  @override
  String get dob_body =>
      'We ask everyone. It stays private and is never shown to anyone.';

  @override
  String get dob_day => 'Day';

  @override
  String get dob_month => 'Month';

  @override
  String get dob_year => 'Year';

  @override
  String get dob_invalid => 'That date doesn\'t exist. Could you check it?';

  @override
  String get dob_future =>
      'That date hasn\'t happened yet. Could you check it?';

  @override
  String get blocked_title => 'Aura is made for people 13 and older.';

  @override
  String get blocked_body => 'We\'d love to see you then.';

  @override
  String get blocked_helpIndia =>
      'If you want to talk to someone now, Childline is free on 1098. In an emergency, call 112.';

  @override
  String get blocked_helpOther =>
      'If you want to talk to someone now, please reach out to an adult you trust.';

  @override
  String get language_title => 'Which language feels like home?';

  @override
  String get language_body => 'You can change this any time in Settings.';

  @override
  String get language_teLatnHint => 'Telugu in English letters';

  @override
  String get language_hiLatnHint => 'Hindi in English letters';

  @override
  String get language_beta => 'Beta';

  @override
  String get signin_title => 'Keep your Aura safe';

  @override
  String get signin_body =>
      'Sign in with your email so your Aura can follow you to a new phone. No name, no phone number, no password.';

  @override
  String get signin_emailLabel => 'Email';

  @override
  String get signin_sendCode => 'Email me a code';

  @override
  String signin_codeSent(String email) {
    return 'We sent a 6-digit code to $email. You can also tap the link in that email.';
  }

  @override
  String get signin_codeLabel => '6-digit code';

  @override
  String get signin_verify => 'Continue';

  @override
  String get signin_resend => 'Send a fresh code';

  @override
  String get signin_changeEmail => 'Use a different email';

  @override
  String get signin_error =>
      'That didn\'t go through. Try again, or sign in another way.';

  @override
  String get signin_codeExpired =>
      'This code has timed out. We\'ll send a fresh one.';

  @override
  String get signin_invalidCode =>
      'That code doesn\'t match. Could you check it?';

  @override
  String get signin_invalidEmail => 'That email doesn\'t look quite right.';

  @override
  String get signin_apple => 'Continue with Apple';

  @override
  String get signin_google => 'Continue with Google';

  @override
  String get signin_offline =>
      'You\'re offline. Pick your first mood now. We\'ll finish setting up when you\'re connected.';

  @override
  String get signin_offlineContinue => 'Check in now';

  @override
  String get signin_unavailable =>
      'Sign-in isn\'t set up in this build yet. Your check-ins will stay on this phone for now.';

  @override
  String get signin_continueLocal => 'Continue on this phone';

  @override
  String get checkin_title => 'How are you feeling?';

  @override
  String get checkin_subtitle =>
      'Pick the closest one. There\'s no wrong answer.';

  @override
  String get checkin_moreEnergy => 'More energy';

  @override
  String get checkin_lessEnergy => 'Less energy';

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
  String get semantic_highEnergy => 'high energy';

  @override
  String get semantic_lowEnergy => 'low energy';

  @override
  String get semantic_pleasant => 'pleasant';

  @override
  String get semantic_unpleasant => 'unpleasant';

  @override
  String get checkin_addDetails => 'Add a tag or a few words';

  @override
  String get checkin_tagsTitle => 'What\'s it about?';

  @override
  String get tag_study => 'Study';

  @override
  String get tag_work => 'Work';

  @override
  String get tag_family => 'Family';

  @override
  String get tag_friends => 'Friends';

  @override
  String get tag_sleep => 'Sleep';

  @override
  String get tag_health => 'Health';

  @override
  String get tag_money => 'Money';

  @override
  String get tag_love => 'Love';

  @override
  String get tag_alone => 'Alone';

  @override
  String get tag_commute => 'Commute';

  @override
  String get checkin_customTag => 'Your own tag';

  @override
  String get checkin_customTagAdd => 'Add tag';

  @override
  String get checkin_noteLabel => 'A few words, if you like';

  @override
  String get checkin_noteHint => 'Only you can read this.';

  @override
  String get checkin_save => 'Save';

  @override
  String get checkin_saveFailed =>
      'We couldn\'t save that. Your phone may be low on space.';

  @override
  String checkin_savedStarlight(int amount) {
    return '+$amount Starlight';
  }

  @override
  String get checkin_saved => 'Saved';

  @override
  String get checkin_savedOffline => 'Saved on this phone';

  @override
  String get checkin_savedThanks => 'Thank you for checking in.';

  @override
  String get checkin_savedFull =>
      'You\'ve gathered all of today\'s Starlight. Your check-in still counts.';

  @override
  String get checkin_roomButton => 'Join a room of people feeling this';

  @override
  String get home_checkIn => 'Check in';

  @override
  String home_todayStarlight(int count) {
    return '$count Starlight today';
  }

  @override
  String home_totalStarlight(int count) {
    return '$count in all';
  }

  @override
  String get home_empty => 'This is your Aura. Check in to give it light.';

  @override
  String get home_resting =>
      'Your Aura has been resting. Say hi when you\'re ready.';

  @override
  String home_glowStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Glow streak · $count days',
      one: 'Glow streak · 1 day',
    );
    return '$_temp0';
  }

  @override
  String home_restDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rest days saved',
      one: '1 rest day saved',
      zero: 'No rest days saved yet',
    );
    return '$_temp0';
  }

  @override
  String get home_restingSafe => 'Resting · your glow is safe';

  @override
  String get home_glowCarriesOn => 'Your glow carries on';

  @override
  String home_lifetimeGlow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count glow days in all',
      one: '1 glow day in all',
    );
    return '$_temp0';
  }

  @override
  String get home_habitsTitle => 'Small things today';

  @override
  String home_habitDone(String habit) {
    return '$habit, done today';
  }

  @override
  String home_habitNotYet(String habit) {
    return '$habit, not yet today';
  }

  @override
  String get home_offline =>
      'You\'re offline. Your own things still save here.';

  @override
  String get home_finishSetup => 'Finish setting up so your Aura is kept safe.';

  @override
  String get home_signIn => 'Sign in';

  @override
  String get home_syncIdle => 'All saved';

  @override
  String home_syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things waiting to sync',
      one: '1 thing waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get home_syncLocal => 'Saved on this phone';

  @override
  String get home_settings => 'Settings';

  @override
  String get home_welcomeBack =>
      'Welcome back. One small thing today is plenty.';

  @override
  String home_evolved(String stage) {
    return 'Your Aura grew into $stage.';
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
  String get habit_hydrate => 'Hydrate';

  @override
  String get habit_sleep_on_time => 'Sleep on time';

  @override
  String get habit_move => 'Move';

  @override
  String get habit_breathe => 'Breathe';

  @override
  String get habit_journal => 'Journal';

  @override
  String get habit_go_outside => 'Go outside';

  @override
  String avatar_semantic(String stage, String hue) {
    return 'Your Aura, $stage stage, $hue glow';
  }

  @override
  String get avatar_semanticResting => 'resting in a soft nebula';

  @override
  String avatar_semanticRings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orbiting lights',
      one: 'one orbiting light',
    );
    return '$_temp0';
  }

  @override
  String avatar_semanticStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars in its constellation',
      one: 'one star in its constellation',
    );
    return '$_temp0';
  }

  @override
  String get hue_gold => 'golden';

  @override
  String get hue_green => 'green';

  @override
  String get hue_teal => 'teal';

  @override
  String get hue_silverBlue => 'silver-blue';

  @override
  String get hue_violet => 'violet';

  @override
  String get hue_rose => 'rose';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_account => 'Account';

  @override
  String settings_signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get settings_signOut => 'Sign out';

  @override
  String settings_signOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things haven\'t synced yet. Stay signed in until they do?',
      one: '1 thing hasn\'t synced yet. Stay signed in until it does?',
    );
    return '$_temp0';
  }

  @override
  String get settings_stay => 'Stay signed in';

  @override
  String get settings_signOutAnyway => 'Sign out anyway';

  @override
  String get settings_signIn => 'Sign in to keep your Aura safe';

  @override
  String get settings_avatarLab => 'Avatar lab';

  @override
  String get settings_about => 'About';

  @override
  String settings_version(String version) {
    return 'Version $version';
  }

  @override
  String get push_title => 'Want a gentle nudge each evening?';

  @override
  String get push_body =>
      'One a day at most, and never about streaks. Nothing on your lock screen will say how you feel.';

  @override
  String get push_allow => 'Allow';

  @override
  String get legal_privacy => 'Privacy policy';

  @override
  String get legal_terms => 'Terms of use';

  @override
  String get legal_opensInBrowser => 'Opens in your browser';
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class AppLocalizationsHiLatn extends AppLocalizationsHi {
  AppLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get appTitle => 'Aura';
}
