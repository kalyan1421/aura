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
  String get signin_busy => 'One moment';

  @override
  String signin_resendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'You can ask for a fresh code in $seconds s',
      one: 'You can ask for a fresh code in 1 s',
    );
    return '$_temp0';
  }

  @override
  String get signin_freshSent => 'A fresh code is on its way.';

  @override
  String get acct_pendingTitle => 'Keep your account?';

  @override
  String acct_pendingBody(String date) {
    return 'Your account is set to be deleted on $date. Keep it?';
  }

  @override
  String get acct_pendingBodySoon =>
      'Your account is set to be deleted soon. Keep it?';

  @override
  String get acct_keep => 'Keep my account';

  @override
  String get acct_letGo => 'Let it go';

  @override
  String get acct_keepFailed =>
      'That didn\'t go through, so nothing has changed yet. Try again when you\'re connected.';

  @override
  String get acct_deleteTitle => 'Delete my account';

  @override
  String get acct_deleteIntro => 'Deleting your account removes:';

  @override
  String get acct_itemCheckIns => 'Your check-ins and notes';

  @override
  String get acct_itemHabits => 'Your habits';

  @override
  String get acct_itemProgress => 'Your Starlight and your Aura\'s growth';

  @override
  String get acct_itemAccount => 'Your account and the email you sign in with';

  @override
  String get acct_grace =>
      'You have 7 days to change your mind. Sign in again before then and everything stays. After that it\'s deleted for good and can\'t be brought back.';

  @override
  String get acct_store =>
      'If you pay for a subscription through the App Store or Google Play, deleting your account doesn\'t cancel it. Manage or cancel it in your store\'s subscription settings.';

  @override
  String get acct_phone =>
      'This phone will be cleared and signed out straight away.';

  @override
  String get acct_needsConnection =>
      'Deleting your account needs a connection. Connect to the internet, then try again.';

  @override
  String get acct_confirmTitle => 'Delete your account?';

  @override
  String get acct_confirmBody =>
      'Your account and everything in it will be deleted in 7 days. Sign in again before then to keep it. This phone will be cleared now.';

  @override
  String get acct_failed =>
      'That didn\'t go through, and nothing has been deleted. Try again in a moment.';

  @override
  String get acct_failedOffline =>
      'We couldn\'t reach Aura, and nothing has been deleted. Check your connection and try again.';

  @override
  String get acct_retry => 'Try again';

  @override
  String get acct_scheduledTitle => 'Your account is set to be deleted';

  @override
  String acct_scheduledBody(String date) {
    return 'It will be deleted on $date. Sign in again before then to keep it.';
  }

  @override
  String get acct_phoneCleared => 'This phone has been cleared and signed out.';

  @override
  String get acct_signedOut =>
      'You\'re not signed in, so there\'s no account to delete. What you\'ve saved lives only on this phone.';

  @override
  String get acct_unavailable =>
      'Account deletion isn\'t set up in this build.';

  @override
  String get set_comfort => 'Comfort';

  @override
  String get set_reduceMotion => 'Reduce motion';

  @override
  String get set_reduceMotionNote => 'Also follows your phone\'s setting';

  @override
  String get set_haptics => 'Haptics';

  @override
  String get set_hapticsNote => 'Soft taps when you choose something';

  @override
  String get set_hideStreak => 'Hide streak number';

  @override
  String get set_hideStreakNote =>
      'Your glow still grows. Home just won\'t count the days.';

  @override
  String get set_signOutTitle => 'Sign out of Aura?';

  @override
  String get set_helpSafety => 'Help & Safety';

  @override
  String get set_grievanceOfficer => 'Grievance Officer';

  @override
  String get set_grievanceSubject => 'Grievance about Aura';

  @override
  String get set_contactSupport => 'Contact support';

  @override
  String get set_supportSubject => 'Aura support';

  @override
  String get set_opensEmail => 'Opens your email app';

  @override
  String set_emailFailed(String email) {
    return 'We couldn\'t open an email app. You can write to $email.';
  }

  @override
  String get acct_inProgress =>
      'This account is already being deleted, so it can\'t be kept any more. This phone will be cleared and signed out.';

  @override
  String get checkin_discardTitle => 'Leave without saving?';

  @override
  String get checkin_discardKeep => 'Keep editing';

  @override
  String get checkin_discardConfirm => 'Discard';

  @override
  String checkin_tagLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $count tags',
      one: 'Up to 1 tag',
    );
    return '$_temp0';
  }

  @override
  String checkin_quadrantAxes(String energy, String feel) {
    return '$energy · $feel';
  }

  @override
  String get history_title => 'Your check-ins';

  @override
  String get history_private => 'Only you can see these.';

  @override
  String get history_empty =>
      'Nothing here yet. Your check-ins will gather here, and only you can see them.';

  @override
  String get history_today => 'Today';

  @override
  String get history_yesterday => 'Yesterday';

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
  String get history_hasNote => 'Has a note';

  @override
  String get history_entryTitle => 'Your check-in';

  @override
  String history_when(String day, String time) {
    return '$day, $time';
  }

  @override
  String get history_tags => 'Tags';

  @override
  String get history_note => 'Your words';

  @override
  String get history_synced => 'Synced';

  @override
  String get history_edit => 'Edit';

  @override
  String get history_editWindowOver =>
      'You can edit a check-in for a day after you make it.';

  @override
  String get history_delete => 'Delete';

  @override
  String get history_deleteTitle => 'Delete this check-in?';

  @override
  String get history_deleteBody =>
      'This doesn\'t change your Starlight or glow days.';

  @override
  String get history_missing => 'This check-in isn\'t here anymore.';

  @override
  String get history_editNoteLocked =>
      'This check-in\'s note hasn\'t reached this phone yet. You can edit it once it has.';

  @override
  String get legal_privacy => 'Privacy policy';

  @override
  String get legal_terms => 'Terms of use';

  @override
  String get legal_opensInBrowser => 'Opens in your browser';

  @override
  String home_stageProgress(String stage, String next, int count, int target) {
    return '$stage, $count of $target Starlight toward $next';
  }

  @override
  String home_constellationProgress(String stage, int count, int max) {
    return '$stage, $count of $max stars in your constellation';
  }

  @override
  String get home_glowTitle => 'Your glow';

  @override
  String get home_restDaysHint => 'Learn how rest days work';

  @override
  String get home_restInfoTitle => 'Rest days';

  @override
  String home_restInfoEarn(int days, int max) {
    return 'Every $days glow days earn a rest day. You can keep up to $max.';
  }

  @override
  String get home_restInfoUse =>
      'When you take a short break, they fill in those days on their own. There\'s nothing you need to do.';

  @override
  String get home_restInfoKeep => 'Every glow day you\'ve had stays with you.';

  @override
  String home_checkInsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins today',
      one: '1 check-in today',
    );
    return '$_temp0';
  }

  @override
  String get home_seeAll => 'See all';

  @override
  String get home_yourCheckIns => 'Your check-ins';

  @override
  String get home_syncExplainIdle =>
      'Everything is saved on this phone and in your account.';

  @override
  String get home_syncExplainPending =>
      'They\'re safe on this phone and will sync on their own.';

  @override
  String get home_syncExplainOffline =>
      'You\'re offline. Everything is safe on this phone and syncs when you\'re back online.';

  @override
  String get home_syncExplainSignedOut =>
      'You\'re not signed in, so everything stays on this phone for now.';

  @override
  String get home_syncExplainUnavailable =>
      'This version keeps everything on this phone.';

  @override
  String get home_syncNow => 'Sync now';

  @override
  String get home_syncing => 'Syncing…';

  @override
  String get home_syncHint => 'Show sync details';

  @override
  String get habits_edit => 'Edit';

  @override
  String get habits_editSemantic => 'Edit small things';

  @override
  String get habits_sheetTitle => 'Your small things';

  @override
  String get habits_sheetBody =>
      'Choose what shows on Home. Check-ins grow your Aura either way.';

  @override
  String get habits_presetsTitle => 'Suggested';

  @override
  String get habits_customTitle => 'Your own';

  @override
  String get habits_addLabel => 'Add your own';

  @override
  String get habits_addHint => 'For example, water the plants';

  @override
  String get habits_add => 'Add';

  @override
  String habits_limit(int count) {
    return 'You have $count custom habits. Swap one to add another.';
  }

  @override
  String get habits_tooLong =>
      'That name is a little long. Could you try a shorter one?';

  @override
  String get habits_saveFailed => 'That didn\'t save. Could you try again?';

  @override
  String habits_remove(String name) {
    return 'Remove $name';
  }

  @override
  String habits_removeTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get habits_removeBody =>
      'It leaves your list. Starlight and glow days you earned with it stay.';

  @override
  String get habits_removeConfirm => 'Remove';

  @override
  String get habits_empty => 'Pick one small thing to start.';

  @override
  String get help_groundingProgress => 'Progress through the minute';

  @override
  String get help_progressBegun => 'Just begun';

  @override
  String get help_progressHalf => 'About halfway';

  @override
  String get help_progressNearly => 'Nearly through';

  @override
  String get help_progressDone => 'Complete';

  @override
  String help_breatheLogged(String habit) {
    return '$habit is marked done for today.';
  }

  @override
  String get onb_trustTitle => 'Before we begin';

  @override
  String get onb_trustBody =>
      'A few things to know about how Aura looks after you.';

  @override
  String get onb_trustPrivateTitle => 'Private by default';

  @override
  String get onb_trustPrivateBody =>
      'Your check-ins and notes are yours. Notes are encrypted, and nobody else sees how you feel unless you choose to share it.';

  @override
  String get onb_trustCareTitle => 'Wellness support, not therapy';

  @override
  String get onb_trustCareBody =>
      'Aura helps you notice how you feel. It doesn\'t diagnose or treat anything.';

  @override
  String get onb_trustHelpTitle => 'Help is always one tap away';

  @override
  String onb_trustHelpBody(String button) {
    return 'Tap “$button” any time to call a helpline or take a minute to breathe.';
  }

  @override
  String get onb_dobYearType => 'Type the year';

  @override
  String get onb_dobYearNoMatch =>
      'No year in the list matches that. Could you check it?';

  @override
  String get onb_blockedWrongDate => 'Entered the wrong date?';

  @override
  String get onb_blockedWrongDateHint => 'Opens your email app';

  @override
  String get onb_blockedMailSubject => 'Aura: I entered the wrong date';

  @override
  String onb_blockedMailFailed(String email) {
    return 'We couldn\'t open an email app. You can write to us at $email.';
  }
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class AppLocalizationsHiLatn extends AppLocalizationsHi {
  AppLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get appTitle => 'Aura';
}
