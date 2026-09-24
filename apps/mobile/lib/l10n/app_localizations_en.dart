// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get signin_or => 'or';

  @override
  String get signin_socialNotReady =>
      'That sign-in option isn\'t ready yet. Use your email for now.';

  @override
  String get signin_socialOffline =>
      'It looks like you\'re offline. Try again when you\'re connected.';

  @override
  String get capsules_title => 'Future you';

  @override
  String get capsules_emptyBody =>
      'Write to future you. Seal it for a date, or for a feeling.';

  @override
  String get capsules_emptyCta => 'Seal your first capsule';

  @override
  String get capsules_new => 'Write a capsule';

  @override
  String capsules_entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules sealed',
      one: '1 capsule sealed',
      zero: 'Nothing sealed yet',
    );
    return '$_temp0';
  }

  @override
  String capsules_entryReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are ready to open',
      one: '1 is ready to open',
    );
    return '$_temp0';
  }

  @override
  String get capsules_sectionReady => 'Ready to open';

  @override
  String get capsules_sectionSealed => 'Sealed';

  @override
  String get capsules_sectionOpened => 'Opened';

  @override
  String capsules_sealedUntil(String date) {
    return 'Sealed until $date. It\'ll keep.';
  }

  @override
  String get capsules_waitingFeeling => 'Waiting for a feeling';

  @override
  String get capsules_readyRow => 'Ready when you are';

  @override
  String capsules_untitled(String date) {
    return 'A capsule from $date';
  }

  @override
  String get capsules_lockedTitle => 'A sealed capsule';

  @override
  String capsules_sealedOn(String date) {
    return 'Sealed $date';
  }

  @override
  String capsules_openedOn(String date) {
    return 'Opened $date';
  }

  @override
  String get capsules_draftTitle => 'Your draft is here';

  @override
  String get capsules_draftBody => 'Pick up where you left off.';

  @override
  String get capsules_composeTitle => 'Write to future you';

  @override
  String get capsules_titleLabel => 'Title';

  @override
  String get capsules_titleHelper => 'Shown on the capsule while it\'s sealed.';

  @override
  String get capsules_textLabel => 'Your note';

  @override
  String get capsules_textHelper => 'Only you will read this, when it opens.';

  @override
  String get capsules_photosTitle => 'Photos';

  @override
  String get capsules_addPhoto => 'Add a photo';

  @override
  String get capsules_photoHint =>
      'Up to 3. Location and camera details are removed.';

  @override
  String get capsules_photoAdding => 'Adding your photo…';

  @override
  String get capsules_photoFailed =>
      'That photo couldn\'t be added. Try another one.';

  @override
  String capsules_photoRemove(int index) {
    return 'Remove photo $index';
  }

  @override
  String capsules_photoSemantic(int index, int count) {
    return 'Photo $index of $count';
  }

  @override
  String get capsules_voiceHint => 'Up to 2 minutes. Only you can hear it.';

  @override
  String get capsules_voiceLimit =>
      'That\'s the full two minutes, so recording stopped. Your voice note is ready.';

  @override
  String get capsules_unlockTitle => 'When should it open?';

  @override
  String get capsules_unlockDate => 'On a date';

  @override
  String get capsules_unlockFeeling => 'For a feeling';

  @override
  String get capsules_pickDate => 'Pick a date';

  @override
  String get capsules_changeDate => 'Change date';

  @override
  String capsules_dateChosen(String date, String time) {
    return 'Opens $date at $time';
  }

  @override
  String get capsules_dateHelp => 'Any day from a week to five years from now.';

  @override
  String get capsules_datePickerHelp => 'It opens at 10:00 that day';

  @override
  String get capsules_feelingHelp =>
      'It can open from 24 hours after sealing, the next time you check in feeling this.';

  @override
  String capsules_anyQuadrant(String quadrant) {
    return 'Any $quadrant feeling';
  }

  @override
  String capsules_feelingChosen(String feeling) {
    return 'Waits for: $feeling';
  }

  @override
  String get capsules_seal => 'Seal it';

  @override
  String get capsules_needContent =>
      'Add a few words, a voice note or a photo first.';

  @override
  String get capsules_needUnlock => 'Choose when it should open.';

  @override
  String get capsules_sealFailed =>
      'That didn\'t seal just now. Your capsule is still here. Try again.';

  @override
  String get capsules_sealedTitle => 'Sealed';

  @override
  String get capsules_sealedFeeling => 'Sealed. It\'ll wait for that feeling.';

  @override
  String get capsules_mediaLater =>
      'Sealed and safe on this phone. Photos and voice back up when you\'re online.';

  @override
  String get capsules_limitBody =>
      'Free accounts keep 3 mood capsules waiting. Date capsules are unlimited.';

  @override
  String get capsules_limitPickDate => 'Pick a date instead';

  @override
  String get capsules_makeDate => 'Make it a date capsule';

  @override
  String get capsules_leaveTitle => 'Keep this draft?';

  @override
  String get capsules_leaveBody =>
      'It stays on this phone until you seal it or let it go.';

  @override
  String get capsules_leaveEditing => 'Keep editing';

  @override
  String get capsules_leaveKeep => 'Keep draft';

  @override
  String get capsules_leaveDiscard => 'Discard';

  @override
  String capsules_detailFeeling(String feeling) {
    return 'Waiting for a feeling: $feeling.';
  }

  @override
  String capsules_detailArming(String date) {
    return 'It can open from $date.';
  }

  @override
  String get capsules_detailNoEarly =>
      'Sealed means sealed: it can\'t be opened early or changed.';

  @override
  String get capsules_delete => 'Delete capsule';

  @override
  String get capsules_deleteTitle => 'Delete this capsule?';

  @override
  String get capsules_deleteBody =>
      'It will be gone for good, without being opened.';

  @override
  String get capsules_deleteBodyOpened => 'It will be gone for good.';

  @override
  String get capsules_deleteConfirm => 'Delete';

  @override
  String get capsules_deleteKeep => 'Keep it';

  @override
  String get capsules_deleted => 'Capsule deleted.';

  @override
  String get capsules_triggerTitle =>
      'You left a note for a moment like this. Open now or later?';

  @override
  String get capsules_holdTitle =>
      'A note from past you is waiting. Open now, or later?';

  @override
  String get capsules_now => 'Now';

  @override
  String get capsules_later => 'Later';

  @override
  String get capsules_readyTitle => 'Something you sealed is ready to open.';

  @override
  String capsules_readyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capsules are ready.',
      one: '1 capsule is ready.',
    );
    return '$_temp0';
  }

  @override
  String get capsules_readyOpen => 'Open it';

  @override
  String get capsules_channelName => 'Capsules';

  @override
  String get capsules_notifyAskTitle => 'Want to know when it opens?';

  @override
  String get capsules_notifyAskBody =>
      'One quiet note on the day it opens. Nothing on your lock screen says what\'s inside.';

  @override
  String get capsules_channelDescription =>
      'When something you sealed is ready to open.';

  @override
  String get capsules_hardMoment =>
      'You wrote this during a hard moment. Open when you\'re ready.';

  @override
  String get capsules_skip => 'Skip';

  @override
  String get capsules_opening => 'Opening your capsule';

  @override
  String get capsules_openedTitle => 'From past you';

  @override
  String get capsules_keepNextTime => 'Keep for next time';

  @override
  String get capsules_keptNextTime => 'It\'ll wait for that feeling again.';

  @override
  String get capsules_voiceOffline =>
      'Your capsule is open. The voice note arrives when you\'re back online.';

  @override
  String get capsules_photosOffline =>
      'The photos arrive when you\'re back online.';

  @override
  String get capsules_mediaFailed =>
      'This couldn\'t be loaded just now. Try again in a moment.';

  @override
  String get capsules_retry => 'Try again';

  @override
  String get capsules_cantRead =>
      'This capsule can\'t be read on this phone yet. It opens once you\'re back online.';

  @override
  String capsules_accountDeletionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sealed capsules will be lost.',
      one: '1 sealed capsule will be lost.',
    );
    return '$_temp0';
  }

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
  String get help_crisisSubtitleCapsule =>
      'You don\'t have to carry it alone. Your capsule is sealed.';

  @override
  String get help_backToCapsule => 'Back to my capsule';

  @override
  String get flows_startOverTitle => 'Start over?';

  @override
  String get flows_startOverBody =>
      'This clears what you\'ve picked and written so far.';

  @override
  String get flows_startOver => 'Start over';

  @override
  String get closed_title => 'This account is closed';

  @override
  String get closed_body =>
      'This account was closed for breaking Aura\'s rules.';

  @override
  String get closed_review =>
      'If you think this is a mistake, you can ask for a review. We reply within 7 days.';

  @override
  String get closed_askReview => 'Ask for a review';

  @override
  String get closed_reviewSubject => 'Review of a closed account';

  @override
  String get closed_deleteNote =>
      'You can still delete your account and everything in it.';

  @override
  String get closed_signOutNote =>
      'Signing out clears this account from this phone.';

  @override
  String get notif_roomsPoolBanner => 'Hindi and Hinglish rooms are open now.';

  @override
  String get notif_roomsPoolAction => 'See rooms';

  @override
  String get notif_channelRooms => 'Rooms & Lantern Hour';

  @override
  String get notif_channelRoomsDescription =>
      'Lantern Hour, warmth from your room, and rooms you asked about.';

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
  String get insights_title => 'Aura Sky';

  @override
  String get insights_private =>
      'Only you can see your sky. It\'s worked out on this phone.';

  @override
  String get insights_empty => 'Your sky fills in as you check in.';

  @override
  String get insights_allCheckIns => 'All check-ins';

  @override
  String get insights_viewMonth => 'Month';

  @override
  String get insights_viewYear => 'Year';

  @override
  String get insights_prevMonth => 'Previous month';

  @override
  String get insights_nextMonth => 'Next month';

  @override
  String get insights_prevYear => 'Previous year';

  @override
  String get insights_nextYear => 'Next year';

  @override
  String insights_dayEmpty(String date) {
    return '$date, quiet sky';
  }

  @override
  String insights_dayRest(String date) {
    return '$date, a rest day';
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
    return '$date, $first and $second equally, $_temp0';
  }

  @override
  String insights_dayMixed(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$date, an even mix, $_temp0';
  }

  @override
  String get insights_dayHint => 'Shows this day\'s check-ins';

  @override
  String get insights_dayNone =>
      'Nothing was logged this day. The sky was just quiet.';

  @override
  String insights_monthSemantic(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days checked in',
      one: '1 day checked in',
      zero: 'a quiet sky',
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
  String get insights_patternsLast30 => 'From your last 30 days';

  @override
  String insights_patternsNeedCheckIns(int count) {
    return 'Patterns appear after 7 check-ins ($count/7)';
  }

  @override
  String insights_patternsNeedDays(int count) {
    return 'Patterns appear after check-ins on 5 different days ($count/5)';
  }

  @override
  String get insights_patternsNone =>
      'No clear patterns right now. Your sky is still here.';

  @override
  String insights_patternTag(String tag, String quadrant) {
    return 'On check-ins with $tag, $quadrant showed up more often.';
  }

  @override
  String insights_patternHabit(String habit, String quadrant) {
    return 'On days you did $habit, $quadrant showed up more often.';
  }

  @override
  String insights_patternMorning(String quadrant) {
    return 'In the mornings, $quadrant showed up more often.';
  }

  @override
  String insights_patternAfternoon(String quadrant) {
    return 'In the afternoons, $quadrant showed up more often.';
  }

  @override
  String insights_patternEvening(String quadrant) {
    return 'In the evenings, $quadrant showed up more often.';
  }

  @override
  String insights_patternNight(String quadrant) {
    return 'At night, $quadrant showed up more often.';
  }

  @override
  String insights_patternMix(String quadrant) {
    return '$quadrant showed up most often in your sky.';
  }

  @override
  String get insights_plusBadge => 'Aura Plus';

  @override
  String get insights_rangeLocked =>
      'Any range and habits alongside moods come with Aura Plus. Your sky and 30-day patterns are always free.';

  @override
  String get insights_rangeLabel => 'Patterns from';

  @override
  String get insights_range7 => '7 days';

  @override
  String get insights_range30 => '30 days';

  @override
  String get insights_range90 => '90 days';

  @override
  String get insights_range365 => '1 year';

  @override
  String get insights_rangeAll => 'All time';

  @override
  String get insights_weeklyTitle => 'From your past week';

  @override
  String get insights_weeklyHide => 'Hide for this week';

  @override
  String get insights_careTitle => 'It\'s been a heavy couple of weeks';

  @override
  String get insights_careBody =>
      'You don\'t have to carry it alone. Support and a room are here whenever you want them.';

  @override
  String get insights_careSupport => 'See support';

  @override
  String get insights_careRoom => 'Find a room';

  @override
  String get insights_monthTitle => 'Your month in stars';

  @override
  String insights_monthCardBody(String month) {
    return '$month in your sky';
  }

  @override
  String get insights_monthOpen => 'Open';

  @override
  String get insights_monthHide => 'Hide';

  @override
  String insights_monthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days checked in',
      one: '1 day checked in',
    );
    return '$_temp0';
  }

  @override
  String get insights_monthMixTitle => 'Your skies this month';

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
    return 'A sky of $_temp0, one for each check-in in $month';
  }

  @override
  String get insights_deeperTitle => 'Deeper monthly review';

  @override
  String get insights_deeperLocked =>
      'Patterns across the month, with habits alongside moods, come with Aura Plus.';

  @override
  String get insights_deeperNone => 'No clear patterns this month.';

  @override
  String get insights_statsTitle => 'All time';

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
      other: '$count days in your sky',
      one: '1 day in your sky',
    );
    return '$_temp0';
  }

  @override
  String get rooms_lanternTitle => 'Tonight\'s lantern';

  @override
  String get rooms_lanternStart => 'Every gesture here adds a little light.';

  @override
  String get rooms_lanternGlowing =>
      'It glows brighter with every gesture here.';

  @override
  String get rooms_lanternFull => 'Fully lit, together.';

  @override
  String get rooms_lanternKept => 'Tonight\'s lantern glowed this bright.';

  @override
  String rooms_lanternSemantic(int level, int max) {
    return 'Tonight\'s lantern, $level of $max lights lit';
  }

  @override
  String get rooms_lanternRise =>
      'The lantern is fully lit. Lanterns rise, together.';

  @override
  String get rooms_intentionTitle => 'Tonight\'s intention';

  @override
  String get rooms_intentionHold => 'Hold this tonight';

  @override
  String get rooms_intentionHolding => 'You\'re holding this tonight';

  @override
  String rooms_intentionHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count holding this tonight',
      one: '1 holding this tonight',
      zero: 'Hold it with one tap',
    );
    return '$_temp0';
  }

  @override
  String rooms_intentionHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count held this tonight',
      one: '1 held this tonight',
      zero: 'Resting until the next Lantern Hour',
    );
    return '$_temp0';
  }

  @override
  String get rooms_intentionPrivate =>
      'Nobody sees who holds it, and nobody will ask about it tomorrow.';

  @override
  String get rooms_intentionFailed =>
      'That didn\'t go through. Please try again.';

  @override
  String get rooms_intention_sleep_before_midnight => 'Sleep before midnight';

  @override
  String get rooms_intention_gentle_with_myself =>
      'Be gentle with myself tonight';

  @override
  String get rooms_intention_phone_down_10 => 'Phone down for 10 minutes';

  @override
  String get rooms_intention_water_before_bed => 'A glass of water before bed';

  @override
  String get rooms_intention_one_kind_thought => 'One kind thought about today';

  @override
  String get rooms_intention_slow_breaths => 'Three slow breaths before sleep';

  @override
  String get notif_reminderBanner =>
      'A quiet minute for you. How\'s today feeling?';

  @override
  String get notif_reminderAction => 'Check in';

  @override
  String get notif_capsuleBanner => 'Something you sealed is ready to open.';

  @override
  String get notif_capsuleAction => 'Open';

  @override
  String get notif_channelReminders => 'Reminders';

  @override
  String get notif_channelRemindersDescription =>
      'Your check-in, wind-down and habit reminders.';

  @override
  String get set_notifications => 'Notifications';

  @override
  String get set_notifMaster => 'Notifications from Aura';

  @override
  String get set_notifMasterNote =>
      'At most two a day. Nothing on your lock screen says how you feel.';

  @override
  String get set_notifReminder => 'Daily check-in reminder';

  @override
  String set_notifReminderNote(String time) {
    return 'One gentle nudge a day, at $time. Skipped once you\'ve checked in.';
  }

  @override
  String get set_notifReminderOffNote =>
      'Off. Turn it on for one gentle nudge a day.';

  @override
  String get set_notifReminderTime => 'Reminder time';

  @override
  String get set_notifCapsule => 'A capsule is ready to open';

  @override
  String get set_notifCapsuleNote =>
      'On the day you chose for something you sealed.';

  @override
  String set_notifQuietNote(String start, String end) {
    return 'Quiet hours: nothing is sent $start–$end.';
  }

  @override
  String get set_notifQuietFrom => 'Quiet from';

  @override
  String get set_notifQuietUntil => 'Quiet until';

  @override
  String get set_notifDiscreet => 'Discreet mode';

  @override
  String get set_notifDiscreetNote =>
      'Every notification just says “Aura · You have a gentle update”.';

  @override
  String get set_notifOffNote =>
      'Notifications are off for Aura on this phone. Your choices here still apply once they\'re on.';

  @override
  String get set_notifTurnOn => 'Turn on';

  @override
  String get set_notifOpenSettings => 'Open phone settings';

  @override
  String get set_notifQuietConfirmTitle =>
      'This time is inside your quiet hours';

  @override
  String set_notifQuietConfirmBody(String start, String end, String time) {
    return 'Aura stays silent $start–$end. Send your reminder at $time anyway?';
  }

  @override
  String get set_notifQuietConfirmYes => 'Send it anyway';

  @override
  String get set_notifQuietConfirmNo => 'Keep it quiet';

  @override
  String push_timeRow(String time) {
    return 'Every evening at $time';
  }

  @override
  String get push_changeTime => 'Change time';

  @override
  String get push_discreet => 'Keep them discreet';

  @override
  String get notif_gesturesBanner => 'People in your room sent you warmth.';

  @override
  String get notif_gesturesAction => 'Open room';

  @override
  String get notif_lanternBanner =>
      'Lantern Hour is on. Others are here tonight.';

  @override
  String get notif_lanternAction => 'See rooms';

  @override
  String get notif_windDownBanner =>
      'A few quiet minutes before sleep, whenever you want them.';

  @override
  String get notif_windDownAction => 'Open Sounds';

  @override
  String get notif_habitBanner =>
      'A small habit or two, whenever you\'re ready.';

  @override
  String get notif_habitAction => 'See habits';

  @override
  String get notif_crisisFollowUp =>
      'Just checking in. However today feels, help is one tap away.';

  @override
  String get notif_crisisFollowUpDismiss => 'Close';

  @override
  String get set_notifGestures => 'Warmth from your room';

  @override
  String get set_notifGesturesNote =>
      'When people in your room send you a gesture. One a day at most.';

  @override
  String get set_notifLantern => 'Lantern Hour';

  @override
  String get set_notifLanternNote =>
      'When Lantern Hour starts in your evening. Not if you\'ve already been in a room that day.';

  @override
  String get set_notifWindDown => 'Wind-down reminder';

  @override
  String set_notifWindDownNote(String time) {
    return 'A few quiet minutes at $time. Not sent once you\'ve used Sanctuary that evening.';
  }

  @override
  String get set_notifWindDownOffNote =>
      'Off. Pick a time for a quiet nudge before sleep.';

  @override
  String get set_notifWindDownTime => 'Wind-down time';

  @override
  String get set_notifWelcomeBack => 'After a quiet while';

  @override
  String get set_notifWelcomeBackNote =>
      'If you\'ve been away a week or more, one gentle hello. Twice at most.';

  @override
  String get set_notifHabits => 'Habit nudges';

  @override
  String get set_notifHabitsNote =>
      'A small nudge at a time you pick, for any habit on Home. One a day at most.';

  @override
  String get set_notifHabitsNone =>
      'Add a habit on Home to get a nudge for it.';

  @override
  String get set_notifHabitOff => 'Off';

  @override
  String get set_notifHabitQuiet =>
      'Inside your quiet hours, so it won\'t be sent.';

  @override
  String get set_notifHabitChange => 'Change time';

  @override
  String get set_notifHabitTurnOff => 'Turn off';

  @override
  String sounds_windDownRemind(String time) {
    return 'Remind me at $time';
  }

  @override
  String sounds_windDownReminderOn(String time) {
    return 'A gentle reminder comes at $time.';
  }

  @override
  String get sounds_windDownReminderOff => 'Turn off';

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

  @override
  String get plus_title => 'Aura Plus';

  @override
  String get plus_intro =>
      'More of what you already have. Everything that helps you feel better stays free.';

  @override
  String get plus_addsTitle => 'Plus adds';

  @override
  String get plus_addCapsules => 'Unlimited mood-trigger capsules';

  @override
  String get plus_addVoice => 'Voice up to 10 minutes in a capsule';

  @override
  String get plus_addInsights =>
      'Deeper Insights: any range, habit × mood, the deeper month in stars';

  @override
  String get plus_addSounds => 'Extra sounds and two Plus skies';

  @override
  String get plus_freeTitle => 'Always free';

  @override
  String get plus_freeBody =>
      'Check-ins, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Breathe, grounding, Today\'s minute, every base sound and the night wind-down.';

  @override
  String get plus_planMonthly => 'Monthly';

  @override
  String get plus_planAnnual => 'Yearly';

  @override
  String plus_trialLineMonthly(String price) {
    return '1 month free, then $price/month';
  }

  @override
  String plus_trialLineAnnual(String price) {
    return '1 month free, then $price/year';
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
    return 'Your free month ends on $date. The first charge is on $date unless you cancel before then.';
  }

  @override
  String plus_renews(String store) {
    return 'Renews automatically until you cancel. Paid through your $store account.';
  }

  @override
  String get plus_cancelApple =>
      'To cancel: iPhone Settings › your name › Subscriptions › Aura. Cancel at least a day before a charge.';

  @override
  String get plus_cancelGoogle =>
      'To cancel: Play Store › your profile › Payments & subscriptions › Subscriptions › Aura.';

  @override
  String get plus_storeApple => 'App Store';

  @override
  String get plus_storeGoogle => 'Google Play';

  @override
  String get plus_startTrial => 'Start free month';

  @override
  String get plus_subscribe => 'Subscribe';

  @override
  String get plus_restore => 'Restore purchases';

  @override
  String get plus_manage => 'Manage in store';

  @override
  String get plus_loadingPrices => 'Loading prices from the store';

  @override
  String get plus_storeUnavailable =>
      'The store isn\'t reachable right now. Nothing was charged.';

  @override
  String get plus_retry => 'Try again';

  @override
  String get plus_confirming => 'Confirming with the store…';

  @override
  String get plus_confirmingLater =>
      'The store has your request. Plus unlocks the moment it\'s confirmed. You can close this.';

  @override
  String get plus_validationFailed =>
      'We couldn\'t confirm this yet. If you were charged, it\'s safe. We\'ll keep checking.';

  @override
  String get plus_pendingApproval =>
      'Waiting for approval. You won\'t be charged until it goes through.';

  @override
  String get plus_declined =>
      'Payment didn\'t go through. You weren\'t charged.';

  @override
  String get plus_welcome => 'Aura Plus is on. Thank you.';

  @override
  String get plus_ownedElsewhere =>
      'This purchase belongs to another Aura account on this store account, so it stays there.';

  @override
  String plus_restored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases restored.',
      one: '1 purchase restored.',
      zero: 'Nothing to restore on this store account.',
    );
    return '$_temp0';
  }

  @override
  String get plus_lockedOnly => 'Part of Aura Plus';

  @override
  String get plus_about => 'About Aura Plus';

  @override
  String get plus_seePlus => 'See Aura Plus';

  @override
  String get plus_freePath => 'The free way stays right here.';

  @override
  String get plus_explainerCapsules =>
      'Free accounts keep 3 mood capsules waiting. Aura Plus keeps as many as you like. Date capsules are always unlimited.';

  @override
  String get plus_explainerVoice =>
      'Voice in a capsule stops at 2 minutes on free Aura, 10 minutes with Aura Plus.';

  @override
  String get plus_explainerSounds =>
      'This sound comes with Aura Plus. Every base sound and the night wind-down stay free.';

  @override
  String get plus_explainerInsights =>
      'Aura Plus adds any range, habit × mood and the deeper month. Your sky and history stay free.';

  @override
  String get plus_explainerSky => 'This sky comes with Aura Plus.';

  @override
  String get plus_statusFree => 'You\'re on free Aura.';

  @override
  String plus_statusTrial(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'ends today',
    );
    return 'Free month: $_temp0. First charge on $date.';
  }

  @override
  String plus_statusTrialCancelled(String date) {
    return 'Your free month stays on until $date. After that you\'re on free Aura, and everything you made stays yours.';
  }

  @override
  String plus_statusActive(String date) {
    return 'Aura Plus renews on $date.';
  }

  @override
  String plus_statusCancelled(String date) {
    return 'Aura Plus stays on until $date. You won\'t be charged again.';
  }

  @override
  String get plus_statusGrace =>
      'The store couldn\'t renew Aura Plus. Plus stays on while it tries again.';

  @override
  String get plus_statusBillingRetry =>
      'Aura Plus is paused until the store can renew it. Everything you made stays yours.';

  @override
  String get plus_statusExpired =>
      'Aura Plus has ended. Everything you made stays yours.';

  @override
  String get plus_statusRefunded =>
      'Your refund went through, so Aura Plus has ended. Everything you made stays yours.';

  @override
  String get plus_statusPending =>
      'Waiting for the store to confirm. You won\'t be charged until it goes through.';

  @override
  String get plus_updatePayment => 'Update payment in store';

  @override
  String get plus_turnBackOn => 'Turn Plus back on';

  @override
  String plus_managedElsewhere(String store) {
    return 'Bought on $store. Manage it there.';
  }

  @override
  String get plus_notYet =>
      'Aura Plus opens up a day after you join. Everything you need is already free.';

  @override
  String plus_cardTrialEnding(String date, String price) {
    return 'Your free month ends on $date. Plus then continues at $price/month unless you cancel in the store.';
  }

  @override
  String plus_cardTrialEndingYear(String date, String price) {
    return 'Your free month ends on $date. Plus then continues at $price/year unless you cancel in the store.';
  }

  @override
  String plus_cardTrialEndingNoPrice(String date) {
    return 'Your free month ends on $date. Plus then continues unless you cancel in the store.';
  }

  @override
  String get plus_cardKeep => 'Keep Plus';

  @override
  String plus_cardTrialCancelled(String date) {
    return 'Plus stays on until $date. You won\'t be charged.';
  }

  @override
  String get plus_cardBillingIssue =>
      'Your Aura Plus payment didn\'t go through. Everything you\'ve made is safe.';

  @override
  String get plus_cardContinues => 'Aura Plus continues. Thank you.';

  @override
  String get plus_dismiss => 'Dismiss';

  @override
  String get plus_giftWarmTea => 'Warm Tea';

  @override
  String get plus_giftComfortLantern => 'Comfort Lantern';

  @override
  String get plus_giftBouquet => 'Encouragement Bouquet';

  @override
  String plus_giftReceived(String gift) {
    return 'Someone here sent you a $gift.';
  }

  @override
  String plus_giftStardust(int count) {
    return '+$count Stardust';
  }

  @override
  String get plus_giftTitle => 'Send a gift';

  @override
  String get plus_giftBody =>
      'They\'ll see “Someone here sent you a gift” and get Stardust for a sky. No message and no name.';

  @override
  String plus_giftSend(String price) {
    return 'Send for $price';
  }

  @override
  String get plus_giftSent =>
      'Sent. They\'ll see it the next time they open Aura.';

  @override
  String get plus_giftUnavailable =>
      'This gift can\'t be sent right now. Nothing was charged.';

  @override
  String get plus_giftDailyLimit =>
      'That\'s 5 gifts today. You can send more tomorrow.';

  @override
  String get plus_giftPaused =>
      'Gifts aren\'t available on this account right now.';

  @override
  String get plus_giftsOff =>
      'Gifts are resting for a bit. Nothing was charged.';

  @override
  String plus_stardustBalance(int count) {
    return '$count Stardust';
  }

  @override
  String get plus_stardustNote =>
      'Stardust comes only from gifts people send you. It can\'t be bought, cashed or moved.';

  @override
  String get plus_skiesTitle => 'Your sky';

  @override
  String get plus_skiesIntro =>
      'A sky for your own Home, Sanctuary and Insights. Only you see it.';

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
  String get plus_skyWithPlus => 'With Aura Plus';

  @override
  String get plus_skyOwned => 'Yours';

  @override
  String get plus_skyInUse => 'In use';

  @override
  String get plus_skyUse => 'Use this sky';

  @override
  String plus_skyBuy(String price) {
    return 'Buy for $price';
  }

  @override
  String plus_skyStardust(int count) {
    return 'Use $count Stardust';
  }

  @override
  String get plus_skyNotEnough => 'Not enough Stardust for this sky yet.';

  @override
  String get plus_soundscapeTitle => 'Pair a soundscape';

  @override
  String get plus_soundscapeNone => 'No sounds';

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
  String get plus_soundscapePlay => 'Play these sounds';

  @override
  String get plus_settingsSky => 'Your sky and Stardust';

  @override
  String get plus_channelAccount => 'Account';

  @override
  String get plus_channelAccountDescription =>
      'Aura Plus reminders, like your free month ending.';

  @override
  String polish_legalOpenFailed(String url) {
    return 'Your browser didn\'t open. The page is at $url.';
  }

  @override
  String get polish_legalCopyLink => 'Copy link';

  @override
  String get polish_legalLinkCopied => 'Link copied';

  @override
  String polish_helpCallFailed(String number) {
    return 'This phone can\'t place the call. The number is $number.';
  }

  @override
  String get polish_helpCopyNumber => 'Copy number';

  @override
  String get polish_helpNumberCopied => 'Number copied';

  @override
  String get reflections_title => 'Reflections';

  @override
  String get reflections_intro =>
      'A few words from people here. Answered only with gestures.';

  @override
  String get reflections_share => 'Share a reflection';

  @override
  String get reflections_empty =>
      'No reflections here yet. You can share one, or just read and send gestures.';

  @override
  String get reflections_emptyMemory =>
      'No reflections were shared in this room.';

  @override
  String get reflections_loadFailed => 'Reflections couldn\'t load just now.';

  @override
  String get reflections_offline =>
      'Reflections need a connection. Anything you write stays on this phone.';

  @override
  String get reflections_memory =>
      'This room is a memory: its reflections can be read, not added to.';

  @override
  String get reflections_paused =>
      'Reflections are resting for a bit. Gestures still work.';

  @override
  String reflections_limit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'That\'s $count reflections for today. Gestures are always open.',
      one: 'That\'s 1 reflection for today. Gestures are always open.',
    );
    return '$_temp0';
  }

  @override
  String get reflections_slow => 'Reflections are slower right now';

  @override
  String reflections_left(int remaining, int total) {
    return '$remaining of $total left today';
  }

  @override
  String reflections_cardLabel(String pseudonym) {
    return 'Reflection by $pseudonym';
  }

  @override
  String get reflections_mine => 'Your reflection';

  @override
  String get reflections_onlyYou => 'Only you can see this';

  @override
  String get reflections_pending => 'Still checking. You can keep reading.';

  @override
  String get reflections_heldSoon => 'Waiting for a quick check';

  @override
  String get reflections_heldOvernight =>
      'Waiting for a quick check. This may take until morning.';

  @override
  String get reflections_rejectedCard => 'This one didn\'t go up here.';

  @override
  String get reflections_removedCard =>
      'This one was taken down after a review.';

  @override
  String reflections_gestureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gestures',
      one: '1 gesture',
      zero: 'No gestures yet',
    );
    return '$_temp0';
  }

  @override
  String get reflections_countPrivate => 'Only you see this count';

  @override
  String get reflections_options => 'Reflection options';

  @override
  String reflections_gestureHint(String pseudonym) {
    return 'Sends to $pseudonym for this reflection';
  }

  @override
  String reflections_gestureSent(String gesture, String pseudonym) {
    return '$gesture sent to $pseudonym';
  }

  @override
  String get reflections_delete => 'Delete';

  @override
  String get reflections_withdraw => 'Withdraw';

  @override
  String get reflections_deleteTitle => 'Delete this reflection?';

  @override
  String get reflections_deleteBody =>
      'It goes away for everyone here. Reflections can\'t be edited, but you can share a new one.';

  @override
  String get reflections_withdrawTitle => 'Withdraw this reflection?';

  @override
  String get reflections_withdrawBody =>
      'It won\'t go up. You can share a new one any time.';

  @override
  String get reflections_deleted => 'Your reflection is gone.';

  @override
  String get reflections_reportTitle => 'Report this reflection';

  @override
  String get reflections_reportHidden =>
      'Thank you for telling us. That reflection is hidden for you now.';

  @override
  String get reflections_composeTitle => 'Share a reflection';

  @override
  String get reflections_composeLabel => 'What\'s on your mind?';

  @override
  String get reflections_composeNote =>
      'A few words for this room. People can answer with gestures only, never replies.';

  @override
  String reflections_counter(int count, int max) {
    return '$count/$max';
  }

  @override
  String reflections_counterSemantic(int count, int max) {
    return '$count of $max characters';
  }

  @override
  String reflections_tooLong(int max) {
    return 'A little shorter, please: up to $max characters.';
  }

  @override
  String get reflections_send => 'Send';

  @override
  String get reflections_sending => 'Sending gently…';

  @override
  String get reflections_contactBlocked =>
      'Phone numbers, links and handles can\'t be shared here. It keeps everyone safer.';

  @override
  String get reflections_draftKept =>
      'Draft kept. You can send it once you\'re back online.';

  @override
  String get reflections_sendFailed =>
      'It didn\'t send just now. Your words are still here: try again in a moment.';

  @override
  String get reflections_rejectedContact =>
      'Reflections can\'t include contact details. Want to try without it?';

  @override
  String get reflections_rejectedLink =>
      'Reflections can\'t include links. Want to try without it?';

  @override
  String get reflections_rejectedPersonal =>
      'Questions about someone\'s personal details can\'t go up here. Want to try without them?';

  @override
  String get reflections_rejectedGeneral =>
      'This one can\'t go up here. It may hurt someone or share personal details. Your words are still here to edit.';

  @override
  String get reflections_supportSubtitle =>
      'You don\'t have to carry it alone.';

  @override
  String get reflections_backToRoom => 'Back to the room';

  @override
  String get device_bannedTitle => 'This device can\'t use Aura';

  @override
  String get device_bannedBody => 'Aura isn\'t available on this phone.';

  @override
  String get device_bannedReviewSubject => 'Review of a device';

  @override
  String get rooms_paused => 'Rooms are resting for a bit. Try again later.';

  @override
  String get rooms_pausedJoin =>
      'Rooms are resting for a bit. Your check-in is saved.';

  @override
  String get ripples_title => 'Breath Ripples';

  @override
  String get ripples_homeCard => 'Breathe together';

  @override
  String get ripples_homeCardBody =>
      'Three quiet minutes with a few others. No words, no score.';

  @override
  String get ripples_breatheTogether => 'Breathe together';

  @override
  String ripples_invite(String name, int count, int capacity) {
    return '$name wants to breathe together · $count/$capacity';
  }

  @override
  String get ripples_inviteJoin => 'Join';

  @override
  String ripples_inviteMine(int count, int capacity) {
    return 'Your invite is open · $count/$capacity';
  }

  @override
  String get ripples_lobby => 'Looking for others to breathe with…';

  @override
  String get ripples_lobbyHint =>
      'Breathe along while you wait. You can leave any time.';

  @override
  String get ripples_holdHint => 'Hold to breathe in, let go to breathe out';

  @override
  String get ripples_tapHint => 'Tap to switch between breathing in and out';

  @override
  String get ripples_breathArea => 'Breathing area';

  @override
  String get ripples_offline =>
      'Breathing together needs a connection. Breathe solo instead?';

  @override
  String get ripples_paused =>
      'Breath Ripples is resting for a bit. Breathe solo instead?';

  @override
  String get ripples_suspended =>
      'Breathing together is paused for this account right now. You can still breathe on your own.';

  @override
  String get ripples_closed =>
      'This account can\'t breathe together with others. You can still breathe on your own.';

  @override
  String get ripples_guidelines =>
      'The community guidelines come first. Open Rooms to read them, or breathe on your own for now.';

  @override
  String get ripples_breatheSolo => 'Breathe solo';

  @override
  String get ripples_settle => 'Settle in';

  @override
  String get ripples_fade => 'Let it fade';

  @override
  String ripples_together(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people breathing together',
      one: 'Just you and the ocean',
    );
    return '$_temp0';
  }

  @override
  String ripples_echoesJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count echoes joined. They\'re recordings of real people who breathed here before.',
      one: '1 echo joined. It\'s a recording of a real person who breathed here before.',
    );
    return '$_temp0';
  }

  @override
  String ripples_guides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guide lights breathe with you.',
      one: 'A guide light breathes with you.',
    );
    return '$_temp0';
  }

  @override
  String get ripples_solo =>
      'Breathing on your own this time. The ocean still listens.';

  @override
  String get ripples_linkLost => 'You\'re breathing on your own for a moment.';

  @override
  String get ripples_alone => 'Keep breathing. The ocean is still here.';

  @override
  String get ripples_leave => 'Leave';

  @override
  String get ripples_accessibleMode => 'Accessible mode';

  @override
  String get ripples_accessibleModeHint =>
      'Tap to switch between in and out. Tones and firmer haptics tell you when you\'re in step with the others.';

  @override
  String ripples_oceanSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A night ocean with $count lights',
      one: 'A night ocean with your light',
    );
    return '$_temp0';
  }

  @override
  String get ripples_lightMe => 'Your light';

  @override
  String ripples_lightHuman(String name) {
    return '$name\'s light';
  }

  @override
  String get ripples_lightEcho => 'An echo of someone who breathed here before';

  @override
  String get ripples_lightGuide => 'A guide light, breathing with the pacer';

  @override
  String get ripples_echo => 'echo';

  @override
  String get ripples_guide => 'guide';

  @override
  String get ripples_you => 'you';

  @override
  String get ripples_pulse => 'Send a pulse';

  @override
  String get ripples_gestureHug => 'Hug';

  @override
  String get ripples_gestureDeepBreath => 'Deep breath';

  @override
  String get ripples_gestureNotAlone => 'You\'re not alone';

  @override
  String ripples_pulseFrom(String name) {
    return '$name sent a pulse';
  }

  @override
  String ripples_gestureFrom(String name, String gesture) {
    return '$name · $gesture';
  }

  @override
  String get ripples_contactTray => 'Send something kind';

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
      'Blocked. You won\'t be matched together again.';

  @override
  String get ripples_reported =>
      'Thank you. Someone from Aura will look at it.';

  @override
  String get ripples_actionFailed =>
      'That didn\'t go through. Please try again.';

  @override
  String get ripples_endTitle => 'That was a few minutes together.';

  @override
  String get ripples_again => 'Breathe again';

  @override
  String get ripples_backToRoom => 'Back to room';

  @override
  String get ripples_feelNow => 'How do you feel now?';

  @override
  String get ripples_echoToggle => 'Let my breathing become an echo';

  @override
  String get ripples_echoToggleHint =>
      'An echo keeps only the timing of your breaths, never who you are, so it can\'t be traced back to you. Turning this off stops future echoes.';

  @override
  String get rooms_title => 'Rooms';

  @override
  String get rooms_yourRooms => 'Your rooms';

  @override
  String get rooms_memories => 'Memories';

  @override
  String get rooms_whatTitle => 'What rooms are';

  @override
  String get rooms_whatBody =>
      'A small room of people who feel like you do right now, for a day.';

  @override
  String get rooms_pointName =>
      'A fresh name in every room. Nobody sees your account.';

  @override
  String get rooms_pointGestures =>
      'No messages or DMs: only eight warm gestures.';

  @override
  String get rooms_pointTime =>
      'Rooms last a day, then rest as a memory for 7 days.';

  @override
  String get rooms_lanternNote =>
      'Lantern Hour: every night from 9 to 11 on your region\'s clock, rooms light a shared lantern and more people drop in.';

  @override
  String get rooms_lanternNow => 'Lantern Hour is on now';

  @override
  String get rooms_checkInCta => 'Check in to find a room';

  @override
  String get rooms_empty =>
      'You\'re not in a room right now. After a check-in you can join people who feel the same.';

  @override
  String get rooms_offline =>
      'Rooms need a connection. Your own check-ins still save on this phone.';

  @override
  String get rooms_loadFailed => 'We couldn\'t reach the rooms just now.';

  @override
  String get rooms_tryAgain => 'Try again';

  @override
  String get rooms_signedOut => 'Rooms open once you\'re signed in.';

  @override
  String get rooms_signIn => 'Sign in';

  @override
  String get rooms_suspended =>
      'Rooms are paused for your account right now. Help is always here.';

  @override
  String rooms_suspendedUntil(String date) {
    return 'Rooms are paused for your account until $date. Help is always here.';
  }

  @override
  String get rooms_accountClosed =>
      'This account was closed for breaking Aura\'s rules.';

  @override
  String get rooms_profilePending =>
      'Rooms open once your account finishes setting up. Try again in a moment.';

  @override
  String get rooms_openHint => 'Opens the room';

  @override
  String rooms_memoryUntil(String date) {
    return 'A memory until $date';
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
  String get rooms_gesture_warm_tea => 'Warm Tea';

  @override
  String get rooms_gesture_light_a_candle => 'Light a Candle';

  @override
  String get rooms_gesture_hug => 'Hug';

  @override
  String get rooms_gesture_me_too => 'Me Too';

  @override
  String get rooms_gesture_soft_rain => 'Soft Rain';

  @override
  String get rooms_gesture_stargaze => 'Stargaze';

  @override
  String get rooms_gesture_deep_breath => 'Deep Breath';

  @override
  String get rooms_gesture_youre_not_alone => 'You\'re Not Alone';

  @override
  String rooms_hereNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count here now',
      one: '1 here now',
      zero: 'Nobody here right now',
    );
    return '$_temp0';
  }

  @override
  String rooms_today(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people have been here today',
      one: '1 person has been here today',
    );
    return '$_temp0';
  }

  @override
  String rooms_countsSemantic(int now, int today) {
    String _temp0 = intl.Intl.pluralLogic(
      now,
      locale: localeName,
      other: '$now people here now',
      one: '1 person here now',
    );
    String _temp1 = intl.Intl.pluralLogic(
      today,
      locale: localeName,
      other: '$today today',
      one: '1 today',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String rooms_stripSemantic(String theme, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people here now',
      one: '1 person here now',
    );
    return '$theme, $_temp0';
  }

  @override
  String get rooms_opening => 'Opening the room…';

  @override
  String rooms_youAre(String pseudonym) {
    return 'You\'re $pseudonym here';
  }

  @override
  String rooms_coldStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count people have been here today. Leave a light for the next one.',
      one: 'You\'re the first here today. Leave a light for the next one.',
    );
    return '$_temp0';
  }

  @override
  String rooms_lanternOn(String time) {
    return 'Lantern Hour · until $time';
  }

  @override
  String rooms_closing(String time) {
    return 'This room becomes a memory at $time.';
  }

  @override
  String get rooms_memory =>
      'This room has become a memory. You can look back for 7 days.';

  @override
  String get rooms_findNew => 'Find a new room';

  @override
  String get rooms_reconnecting => 'Reconnecting…';

  @override
  String get rooms_membersTitle => 'Here with you';

  @override
  String get rooms_you => 'You';

  @override
  String get rooms_memberHereNow => 'here now';

  @override
  String get rooms_memberAway => 'away for now';

  @override
  String get rooms_memberMuted => 'muted for you';

  @override
  String rooms_memberLabel(String pseudonym, String mood, String status) {
    return '$pseudonym, $mood, $status';
  }

  @override
  String rooms_youLabel(String pseudonym, String mood) {
    return 'You, $pseudonym, $mood';
  }

  @override
  String get rooms_memberHint => 'Opens options';

  @override
  String get rooms_recentTitle => 'Warmth in this room';

  @override
  String rooms_receivedLine(String pseudonym, String gesture) {
    return '$pseudonym sent you $gesture';
  }

  @override
  String rooms_sentToMember(String gesture, String pseudonym) {
    return '$gesture sent to $pseudonym';
  }

  @override
  String rooms_sentToRoom(String gesture) {
    return '$gesture sent to everyone here';
  }

  @override
  String rooms_someoneSent(String gesture) {
    return 'Someone sent $gesture';
  }

  @override
  String rooms_someoneSentRoom(String gesture) {
    return 'Someone sent $gesture to everyone here';
  }

  @override
  String rooms_youSentMember(String gesture, String pseudonym) {
    return 'You sent $gesture to $pseudonym';
  }

  @override
  String rooms_youSentRoom(String gesture) {
    return 'You sent $gesture to everyone here';
  }

  @override
  String get rooms_trayTitle => 'Send warmth to everyone here';

  @override
  String get rooms_trayHint => 'Sends to everyone here';

  @override
  String get rooms_trayResting =>
      'Gestures rest in a memory. You can still report, block or mute.';

  @override
  String get rooms_roomOptions => 'Room options';

  @override
  String get rooms_reportRoom => 'Report a problem here';

  @override
  String get rooms_leave => 'Leave this room';

  @override
  String get rooms_removeMemory => 'Remove from my rooms';

  @override
  String get rooms_leaveTitle => 'Leave this room?';

  @override
  String get rooms_leaveBody =>
      'You won\'t be able to come back to it, and your seat opens up for someone else. Your next check-in can find you a new room.';

  @override
  String get rooms_leaveConfirm => 'Leave room';

  @override
  String get rooms_stay => 'Stay';

  @override
  String get rooms_removeTitle => 'Remove this memory?';

  @override
  String get rooms_removeBody =>
      'It leaves your rooms now. Memories close for good after 7 days anyway.';

  @override
  String get rooms_removeConfirm => 'Remove';

  @override
  String get rooms_keep => 'Keep it';

  @override
  String get rooms_leaveFailed =>
      'That didn\'t go through. You\'re still in the room.';

  @override
  String get rooms_gone =>
      'This room has closed. Rooms rest for 7 days as memories, then they\'re gone.';

  @override
  String get rooms_backToRooms => 'Back to your rooms';

  @override
  String get rooms_offlineRoom =>
      'Rooms need a connection. This room opens again when you\'re back online.';

  @override
  String get rooms_joinTitle => 'Finding your room';

  @override
  String get rooms_finding => 'Finding people who feel this way right now…';

  @override
  String get rooms_offlineJoin =>
      'Rooms need a connection. Your check-in is saved.';

  @override
  String get rooms_joinFailed =>
      'We couldn\'t reach the rooms just now. Your check-in is saved.';

  @override
  String get rooms_joinLimit =>
      'That\'s 3 new rooms for this feeling today. The rooms you\'re in are still open to you.';

  @override
  String get rooms_seeYourRooms => 'See your rooms';

  @override
  String get rooms_poolUnavailable =>
      'Hindi and Hinglish rooms are opening soon. Join an English room for now?';

  @override
  String get rooms_poolJoinEnglish => 'Join English room';

  @override
  String get rooms_poolNotify => 'Tell me when they open';

  @override
  String get rooms_poolNotifyDone =>
      'We\'ll let you know here when Hindi and Hinglish rooms open.';

  @override
  String get rooms_noRequest => 'Rooms open from a check-in.';

  @override
  String get rooms_offer => 'Join a room of people feeling this';

  @override
  String get rooms_offerHint => 'Opens a room, with a fresh name just for it';

  @override
  String get rooms_offerOffline => 'Rooms open when you\'re back online';

  @override
  String get rooms_offerLater =>
      'Rooms are in the Rooms tab whenever you\'d like company.';

  @override
  String get rooms_guidelinesTitle => 'Before your first room';

  @override
  String get rooms_guidelinesIntro =>
      'Rooms stay gentle because everyone keeps to a few simple things:';

  @override
  String get rooms_rule1 => 'Be kind. Everyone here is having a real day.';

  @override
  String get rooms_rule2 =>
      'No hate about caste, religion, gender, sexuality or anything else.';

  @override
  String get rooms_rule3 => 'No sexual content.';

  @override
  String get rooms_rule4 =>
      'Never share or ask for contact details or meet-ups, or anyone\'s age, school, city or photos.';

  @override
  String get rooms_rule5 => 'No selling or spam.';

  @override
  String get rooms_rule6 =>
      'Never encourage anyone to hurt themselves. Talking about how you feel is always okay.';

  @override
  String get rooms_guidelinesSafety =>
      'You can report, block or mute anyone, and help is always one tap away.';

  @override
  String get rooms_guidelinesAgree => 'I\'ll keep to these';

  @override
  String get rooms_guidelinesUpdate =>
      'Rooms have new community guidelines. Update Aura to read them before your next room.';

  @override
  String rooms_sendTo(String pseudonym) {
    return 'Send $pseudonym some warmth';
  }

  @override
  String rooms_gestureHintMember(String pseudonym) {
    return 'Sends to $pseudonym';
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
      'They\'re never told who reported, blocked or muted them.';

  @override
  String rooms_blockTitle(String pseudonym) {
    return 'Block $pseudonym?';
  }

  @override
  String get rooms_blockBody =>
      'You won\'t be placed in a room together again, and gestures between you stop. They won\'t be told.';

  @override
  String rooms_blocked(String pseudonym) {
    return '$pseudonym is blocked. You won\'t share a room again.';
  }

  @override
  String rooms_muted(String pseudonym) {
    return '$pseudonym is muted for you. Their gestures won\'t reach you here.';
  }

  @override
  String rooms_unmuted(String pseudonym) {
    return '$pseudonym is unmuted.';
  }

  @override
  String get rooms_undo => 'Undo';

  @override
  String get rooms_actionFailed =>
      'That didn\'t go through. Try again in a moment.';

  @override
  String rooms_reportMember(String pseudonym) {
    return 'Report $pseudonym';
  }

  @override
  String get rooms_reportGesture => 'Report this gesture';

  @override
  String get rooms_reportWhy => 'What\'s happening?';

  @override
  String get rooms_reason1 => 'Someone may be in danger or hurting themselves';

  @override
  String get rooms_reason2 => 'Harassment or bullying';

  @override
  String get rooms_reason3 => 'Sexual content or advances';

  @override
  String get rooms_reason4 => 'Hate or slurs';

  @override
  String get rooms_reason5 => 'Contact details or personal info';

  @override
  String get rooms_reason6 => 'Spam or selling';

  @override
  String get rooms_reason7 => 'Someone may be under 13';

  @override
  String get rooms_reason8 => 'Something else';

  @override
  String get rooms_reason9 => 'Seems to be targeting a young person';

  @override
  String get rooms_reportNoteLabel =>
      'Anything a moderator should know? (optional)';

  @override
  String get rooms_reportNoteHelp =>
      'Only Aura\'s moderators read this. Please leave out phone numbers, links and handles.';

  @override
  String get rooms_reportNoteContact =>
      'Phone numbers, links and handles can\'t be shared here. It keeps everyone safer.';

  @override
  String get rooms_reportSend => 'Send report';

  @override
  String get rooms_reportThanks =>
      'Thank you for telling us. A moderator will look at it, usually within a day.';

  @override
  String get rooms_reportHidden =>
      'Thank you for telling us. You won\'t get their gestures in this room while a moderator takes a look.';

  @override
  String get rooms_reportGestureHidden =>
      'Thank you for telling us. That gesture is hidden for you now.';

  @override
  String get rooms_reportCrisis =>
      'Thank you for telling us. A moderator will look soon, and help is always one tap away.';

  @override
  String get rooms_reportLimit =>
      'That\'s a lot of reports today. If someone is in danger, the help button is always here.';

  @override
  String get rooms_reportFailed =>
      'That didn\'t go through, so nothing was sent. Try again in a moment.';

  @override
  String get rooms_reportOffline =>
      'Reports need a connection. Nothing was sent yet.';

  @override
  String get rooms_surveyTitle => 'Did you feel less alone?';

  @override
  String get rooms_surveyYes => 'Yes';

  @override
  String get rooms_surveyNo => 'Not really';

  @override
  String get rooms_surveySkip => 'Skip';

  @override
  String get sanctuary_title => 'Sanctuary';

  @override
  String get sanctuary_intro =>
      'A quiet place, just for you. Go at your own pace. Nothing here is scored.';

  @override
  String get sanctuary_todayTitle => 'Today\'s minute';

  @override
  String get sanctuary_breatheSection => 'Breathe';

  @override
  String get sanctuary_breatheCard => 'Breathe with your Aura';

  @override
  String get sanctuary_breatheCardBody =>
      'Calm, box or 4-7-8 breathing, for as long as you like.';

  @override
  String get sanctuary_groundingSection => 'Grounding';

  @override
  String get sanctuary_begin => 'Begin';

  @override
  String get sanctuary_start => 'Start';

  @override
  String get sanctuary_pause => 'Pause';

  @override
  String get sanctuary_resume => 'Resume';

  @override
  String get sanctuary_finish => 'Finish';

  @override
  String get sanctuary_next => 'Next';

  @override
  String get sanctuary_progress => 'Progress through this session';

  @override
  String get sanctuary_progressBegun => 'Just begun';

  @override
  String get sanctuary_progressHalf => 'About halfway';

  @override
  String get sanctuary_progressNearly => 'Nearly through';

  @override
  String get sanctuary_progressDone => 'Complete';

  @override
  String habits_autoLogged(String habit) {
    return '$habit is marked done for today.';
  }

  @override
  String get breathe_rhythm => 'Rhythm';

  @override
  String get breathe_calm => 'Calm';

  @override
  String get breathe_calmBody => 'In for 4, out for 6. Gentle and steady.';

  @override
  String get breathe_box => 'Box';

  @override
  String get breathe_boxBody => 'In, hold, out, hold. Four counts each.';

  @override
  String get breathe_478 => '4-7-8';

  @override
  String get breathe_478Body => 'In for 4, hold for 7, out for 8.';

  @override
  String get breathe_lightHeaded =>
      'If you feel light-headed, stop and breathe normally.';

  @override
  String get breathe_length => 'Length';

  @override
  String breathe_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get breathe_openEnded => 'Until I stop';

  @override
  String get breathe_in => 'Breathe in';

  @override
  String get breathe_hold => 'Hold';

  @override
  String get breathe_out => 'Breathe out';

  @override
  String get breathe_paused => 'Paused. Take your time.';

  @override
  String get breathe_done => 'That was time just for you.';

  @override
  String get breathe_again => 'Again';

  @override
  String get breathe_land1 => 'Feel your feet on the ground.';

  @override
  String get breathe_land2 => 'Notice three sounds around you.';

  @override
  String get breathe_keepGoing => 'Keep going';

  @override
  String get breathe_land3 => 'Let your shoulders drop.';

  @override
  String get senses_title => 'Five senses';

  @override
  String get senses_card => 'Notice what\'s around you, one sense at a time.';

  @override
  String get senses_intro =>
      'Let\'s notice what\'s around you, one sense at a time. Go at your own pace.';

  @override
  String get senses_see => 'Five things you can see';

  @override
  String get senses_seeBody =>
      'Look around slowly. Name them in your head or out loud.';

  @override
  String get senses_touch => 'Four things you can touch';

  @override
  String get senses_touchBody =>
      'The chair under you, your clothes, the air on your skin.';

  @override
  String get senses_hear => 'Three things you can hear';

  @override
  String get senses_hearBody => 'Near or far, loud or soft.';

  @override
  String get senses_smell => 'Two things you can smell';

  @override
  String get senses_smellBody => 'Or two scents you like, if nothing is near.';

  @override
  String get senses_taste => 'One thing you can taste';

  @override
  String get senses_tasteBody => 'Or take a sip of water and notice it.';

  @override
  String senses_step(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get senses_done => 'You\'re here, in this moment. Nicely done.';

  @override
  String get heart_title => 'Hand on heart';

  @override
  String get heart_card => 'A minute of warmth, just for you.';

  @override
  String get heart_intro =>
      'Place a hand on your heart, or anywhere that feels comforting.';

  @override
  String get heart_1 => 'Feel the warmth of your hand.';

  @override
  String get heart_2 => 'Breathe gently. There\'s no rush.';

  @override
  String get heart_3 => 'Whatever you\'re feeling is allowed here.';

  @override
  String get heart_4 => 'Be as kind to yourself as you would be to a friend.';

  @override
  String get heart_done => 'Thank you for being gentle with yourself.';

  @override
  String get gratitude_title => 'Three small things';

  @override
  String get gratitude_card => 'Three small things that went okay today.';

  @override
  String get gratitude_intro =>
      'Bring three small things from today to mind, one at a time. There\'s nothing to write.';

  @override
  String get gratitude_1 => 'One small thing that went okay';

  @override
  String get gratitude_1Body =>
      'It can be tiny, like a warm drink or a kind word.';

  @override
  String get gratitude_2 => 'Another small thing';

  @override
  String get gratitude_2Body => 'Something you saw, heard or did.';

  @override
  String get gratitude_3 => 'One more small thing';

  @override
  String get gratitude_3Body => 'Maybe something about yourself.';

  @override
  String get gratitude_done => 'Hold onto those for a moment. They\'re yours.';

  @override
  String get savour_intro =>
      'Let\'s replay one good moment from today, slowly.';

  @override
  String get savour_1 =>
      'Bring one good moment from today to mind, however small.';

  @override
  String get savour_2 => 'Where were you? What could you see and hear?';

  @override
  String get savour_3 => 'Notice how it feels to remember it now.';

  @override
  String get savour_done => 'Let it stay with you a little longer.';

  @override
  String get minute_forYou => 'A minute for you';

  @override
  String get minute_calmTitle => 'One calm minute';

  @override
  String get minute_boxTitle => 'Box breathing';

  @override
  String get minute_478Title => '4-7-8 breathing';

  @override
  String get minute_stillnessTitle => 'A minute of stillness';

  @override
  String get minute_stillnessBody => 'One quiet minute with the orb.';

  @override
  String get minute_landTitle => 'Thirty seconds to land';

  @override
  String get minute_landBody => 'Three slow breaths with the orb.';

  @override
  String get minute_comfortTitle => 'A little comfort';

  @override
  String get minute_comfortBody =>
      'A hand on your heart, and a minute of warmth.';

  @override
  String get minute_savourTitle => 'Savour this';

  @override
  String get minute_savourBody => 'Replay one good moment from today.';

  @override
  String get companion_storm1 =>
      'That\'s a lot at once. Your light is still here.';

  @override
  String get companion_storm2 =>
      'Naming a storm takes courage. You showed up for yourself.';

  @override
  String get companion_storm3 =>
      'Big, loud feelings are welcome here. So are you.';

  @override
  String get companion_storm4 =>
      'Stormy days matter too. Thank you for checking in.';

  @override
  String get companion_storm5 => 'You named this honestly. That matters.';

  @override
  String get companion_storm6 => 'Storms are part of your sky too.';

  @override
  String get companion_storm7 =>
      'Whatever is swirling, you noticed it. That counts.';

  @override
  String get companion_storm8 => 'Even in a storm, your glow is yours.';

  @override
  String get companion_rain1 =>
      'That feels heavy. Your light is still with you.';

  @override
  String get companion_rain2 =>
      'Being honest about a low day takes courage. You showed up for yourself.';

  @override
  String get companion_rain3 =>
      'Slow, heavy feelings are welcome here. So are you.';

  @override
  String get companion_rain4 =>
      'Rainy days matter too. Thank you for checking in.';

  @override
  String get companion_rain5 =>
      'You were honest with yourself today. That matters.';

  @override
  String get companion_rain6 => 'Rain is part of your sky too.';

  @override
  String get companion_rain7 =>
      'However heavy it is, you noticed it. That counts.';

  @override
  String get companion_rain8 => 'Even on grey days, your glow is yours.';

  @override
  String get companion_moonlight1 =>
      'A quiet, settled moment. Your light is resting easy.';

  @override
  String get companion_moonlight2 =>
      'Noticing a quiet moment is worth something. You showed up for yourself.';

  @override
  String get companion_moonlight3 =>
      'Soft, easy feelings are welcome here. So are you.';

  @override
  String get companion_moonlight4 =>
      'Gentle days matter too. Thank you for checking in.';

  @override
  String get companion_moonlight5 =>
      'You took a moment to notice this. That matters.';

  @override
  String get companion_moonlight6 => 'Moonlight is part of your sky too.';

  @override
  String get companion_moonlight7 =>
      'However small this calm is, you noticed it. That counts.';

  @override
  String get companion_moonlight8 => 'In the quiet, your glow is yours.';

  @override
  String get companion_sunrise1 => 'A bright moment. Your light is shining.';

  @override
  String get companion_sunrise2 =>
      'Noticing a good moment is worth something. You showed up for yourself.';

  @override
  String get companion_sunrise3 =>
      'Big, bright feelings are welcome here. So are you.';

  @override
  String get companion_sunrise4 =>
      'Bright days matter too. Thank you for checking in.';

  @override
  String get companion_sunrise5 =>
      'You let yourself notice this. That matters.';

  @override
  String get companion_sunrise6 => 'Sunrise is part of your sky too.';

  @override
  String get companion_sunrise7 =>
      'However big or small this is, you noticed it. That counts.';

  @override
  String get companion_sunrise8 => 'In this brightness, your glow is yours.';

  @override
  String get companion_neutral1 => 'Thank you for checking in.';

  @override
  String get companion_neutral2 => 'You showed up for yourself.';

  @override
  String get companion_neutral3 => 'Your light is still here.';

  @override
  String get companion_neutral4 => 'There\'s no rush here.';

  @override
  String get prompt_note1 => 'What\'s one small thing that helped today?';

  @override
  String get prompt_note2 => 'What\'s on your mind right now?';

  @override
  String get prompt_note3 => 'What would you like to remember about today?';

  @override
  String get prompt_storm1 => 'What\'s taking up the most room right now?';

  @override
  String get prompt_storm2 => 'If this feeling could speak, what would it say?';

  @override
  String get prompt_storm3 =>
      'What\'s one thing you could set down, even for a minute?';

  @override
  String get prompt_rain1 => 'What would feel gentle right now?';

  @override
  String get prompt_rain2 => 'What\'s weighing on you today?';

  @override
  String get prompt_rain3 => 'Who or what has felt kind to you lately?';

  @override
  String get prompt_moonlight1 => 'What\'s helping you feel settled?';

  @override
  String get prompt_moonlight2 => 'What made today feel softer?';

  @override
  String get prompt_moonlight3 =>
      'What would you like to keep from this moment?';

  @override
  String get prompt_sunrise1 => 'What\'s lighting you up today?';

  @override
  String get prompt_sunrise2 => 'What went well that you\'d like to remember?';

  @override
  String get prompt_sunrise3 => 'Who would you like to share this with?';

  @override
  String get prompt_capsule1 => 'What do you want future you to know?';

  @override
  String get prompt_capsule2 =>
      'What\'s helping you right now that you might forget?';

  @override
  String get prompt_capsule3 => 'What would you say to yourself on a hard day?';

  @override
  String get prompt_capsuleStorm =>
      'What helps when everything feels like too much?';

  @override
  String get prompt_capsuleRain =>
      'What would you want to hear on a heavy day?';

  @override
  String get prompt_capsuleMoonlight => 'What helps you find this calm again?';

  @override
  String get prompt_capsuleSunrise =>
      'What would you like to celebrate with future you?';

  @override
  String get prompt_another => 'Another prompt';

  @override
  String get prompt_settingsTitle => 'Writing prompts';

  @override
  String get prompt_settingsBody =>
      'A gentle question in the empty note. Never saved.';

  @override
  String get backfill_add => 'Add a past check-in';

  @override
  String get backfill_pickTitle => 'Which day?';

  @override
  String backfill_pickBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can add a check-in for any of the last $count days.',
      one: 'You can add a check-in for yesterday.',
    );
    return '$_temp0';
  }

  @override
  String get backfill_title => 'How were you feeling?';

  @override
  String backfill_forDay(String day) {
    return 'Check-in for $day';
  }

  @override
  String get backfill_changeDay => 'Change day';

  @override
  String get backfill_outOfRange =>
      'Past check-ins can go up to a week back. Could you pick another day?';

  @override
  String get backfill_savedTitle => 'Added to your sky';

  @override
  String backfill_savedDay(String day) {
    return 'Saved for $day.';
  }

  @override
  String get backfill_savedBody =>
      'Starlight comes from check-ins made on the day itself.';

  @override
  String get history_addedLater => 'Added later';

  @override
  String history_whenAddedLater(String day) {
    return '$day · added later';
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
  String get shell_checkInHint => 'Starts a new check-in';

  @override
  String get safety_emergencyWhen =>
      'Call emergency services right away if you or someone near you is in immediate danger, badly hurt, or can\'t stay safe.';

  @override
  String get safety_settingsLink => 'Help & Safety in Settings';

  @override
  String get safety_settingsHint =>
      'Support contact, Grievance Officer and policies';

  @override
  String get sounds_title => 'Sounds';

  @override
  String get sounds_cardBody =>
      'Rain, ocean, wind and more. Nothing plays until you choose.';

  @override
  String get sounds_cardPlaying => 'Playing now';

  @override
  String get sounds_intro =>
      'Pick a sound to begin, or mix up to four. Nothing plays until you tap.';

  @override
  String get sounds_nothingPlaying => 'Nothing playing';

  @override
  String get sounds_statePlaying => 'Playing';

  @override
  String get sounds_statePaused => 'Paused';

  @override
  String get sounds_backgroundNote =>
      'Sounds keep playing with the screen off. They pause if your headphones disconnect or a call comes in.';

  @override
  String get sounds_notificationChannel => 'Sounds playback';

  @override
  String get sounds_windDownTitle => 'Night wind-down';

  @override
  String get sounds_windDownBody =>
      'About 20 minutes of sounds that slowly thin out to silence. The order changes each night.';

  @override
  String get sounds_windDownBegin => 'Begin wind-down';

  @override
  String sounds_windDownLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'About $minutes minutes left',
      one: 'About 1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get sounds_windDownBusy =>
      'The wind-down is playing. Stop it to make your own mix.';

  @override
  String get sounds_mixSection => 'Mix your own';

  @override
  String get sounds_mixHint => 'Up to four at once, each with its own volume.';

  @override
  String get sounds_stemRain => 'Rain';

  @override
  String get sounds_stemOcean => 'Ocean';

  @override
  String get sounds_stemWind => 'Wind';

  @override
  String get sounds_stemNightInsects => 'Night insects';

  @override
  String get sounds_stemSingingBowl => 'Singing bowl';

  @override
  String get sounds_stemChimes => 'Chimes';

  @override
  String get sounds_stemBrownNoise => 'Brown noise';

  @override
  String get sounds_stemPinkNoise => 'Pink noise';

  @override
  String get sounds_stemDeepBell => 'Distant bell';

  @override
  String get sounds_stemMonsoonRoof => 'Monsoon on a roof';

  @override
  String get sounds_stemStream => 'Stream';

  @override
  String get sounds_stemFireplace => 'Fireplace';

  @override
  String get sounds_stemDistantThunder => 'Distant thunder';

  @override
  String sounds_stemOn(String name, int percent) {
    return '$name, playing, volume $percent%';
  }

  @override
  String sounds_stemPaused(String name, int percent) {
    return '$name, paused, volume $percent%';
  }

  @override
  String sounds_stemOff(String name) {
    return '$name, off';
  }

  @override
  String sounds_stemLocked(String name) {
    return '$name, part of Aura Plus';
  }

  @override
  String sounds_stemNeedsDownload(String name, String size) {
    return '$name, $size to download once';
  }

  @override
  String sounds_stemDownloading(String name) {
    return '$name, downloading';
  }

  @override
  String sounds_volume(String name) {
    return '$name volume';
  }

  @override
  String get sounds_plusBadge => 'Aura Plus';

  @override
  String get sounds_plusNote => 'Coming with Aura Plus.';

  @override
  String get sounds_full =>
      'Four sounds are playing. Turn one off to add another.';

  @override
  String get sounds_play => 'Play';

  @override
  String get sounds_pause => 'Pause';

  @override
  String get sounds_stop => 'Stop';

  @override
  String get sounds_timer => 'Timer';

  @override
  String get sounds_timerTitle => 'Fade out after';

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
      other: 'Fades out in about $minutes minutes',
      one: 'Fades out in about 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get sounds_fadingOut => 'Fading out';

  @override
  String get sounds_saveMix => 'Save this mix';

  @override
  String get sounds_savedMixes => 'Saved mixes';

  @override
  String get sounds_mixSaved => 'Saved on this phone.';

  @override
  String get sounds_mixAlreadySaved => 'This mix is already saved.';

  @override
  String sounds_playMix(String mix) {
    return 'Play $mix';
  }

  @override
  String sounds_removeMix(String mix) {
    return 'Remove $mix';
  }

  @override
  String get sounds_mixUnavailable => 'This mix can\'t play right now.';

  @override
  String get sounds_downloadTitle => 'Recorded sounds';

  @override
  String sounds_downloadBody(String size) {
    return '$size to download once. After that they play offline. Until then, sounds made on your phone play instead.';
  }

  @override
  String get sounds_download => 'Download';

  @override
  String get sounds_downloading => 'Downloading…';

  @override
  String get sounds_downloadOffline =>
      'You\'re offline. Brown noise and the sounds made on your phone play now; recordings can download later.';

  @override
  String get sounds_downloadFailed =>
      'The download didn\'t finish. Nothing is lost; you can download again later.';

  @override
  String sounds_noSpace(String size) {
    return 'Sounds need about $size. Free some space, or play brown noise, which needs none.';
  }

  @override
  String sounds_megabytes(String size) {
    return '$size MB';
  }

  @override
  String get sounds_removeDownloads => 'Remove downloaded sounds';

  @override
  String get sounds_downloadsRemoved =>
      'Downloaded sounds removed. The sounds made on your phone still play.';

  @override
  String get voice_record => 'Record a voice note';

  @override
  String get voice_recordHint => 'Up to a minute. Only you can hear it.';

  @override
  String get voice_rationaleTitle => 'Add your voice?';

  @override
  String get voice_rationaleBody =>
      'To record a voice note, Aura needs your microphone. Recordings stay private to you and are never shared in rooms.';

  @override
  String get voice_rationaleAllow => 'Allow';

  @override
  String get voice_denied =>
      'Voice is off. Type instead, or turn it on in Settings.';

  @override
  String get voice_openSettings => 'Settings';

  @override
  String get voice_recording => 'Recording';

  @override
  String voice_elapsed(String time, String limit) {
    return '$time · up to $limit';
  }

  @override
  String voice_recordingFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Recording, $seconds seconds',
      one: 'Recording, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_stop => 'Stop recording';

  @override
  String get voice_started => 'Recording started';

  @override
  String voice_recorded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Voice note recorded, $seconds seconds',
      one: 'Voice note recorded, 1 second',
    );
    return '$_temp0';
  }

  @override
  String get voice_limitReached =>
      'That\'s the full minute, so recording stopped. Your voice note is ready.';

  @override
  String get voice_recordFailed =>
      'Voice couldn\'t be recorded just now. Your words still save.';

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
  String get voice_play => 'Play voice note';

  @override
  String get voice_pause => 'Pause voice note';

  @override
  String get voice_reRecord => 'Record again';

  @override
  String get voice_remove => 'Remove';

  @override
  String get voice_removeSemantic => 'Remove voice note';

  @override
  String get voice_dropped =>
      'Your check-in is saved. The voice note couldn\'t be kept, as your phone may be low on space.';

  @override
  String get voice_loading => 'Getting your voice note…';

  @override
  String get voice_offline => 'The voice note plays when you\'re back online.';

  @override
  String get voice_failed =>
      'This voice note couldn\'t be played just now. Try again in a moment.';

  @override
  String get voice_section => 'Your voice';

  @override
  String get voice_hasVoice => 'Has a voice note';
}
