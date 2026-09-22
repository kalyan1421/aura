import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
    Locale('te'),
    Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
  ];

  /// App name (brand, never translated).
  ///
  /// In en, this message translates to:
  /// **'Aura'**
  String get appTitle;

  /// Primary button to go to the next step. Calm.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// Back button label.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_back;

  /// Finish a flow.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// Gentle dismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get common_notNow;

  /// Cancel an action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// Close a sheet or screen.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// Label on features not built yet. Warm, not a tease.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get common_comingSoon;

  /// Always-visible help button on Home and other screens. Must feel safe to tap.
  ///
  /// In en, this message translates to:
  /// **'I need help now'**
  String get help_button;

  /// Support sheet title when opened from the help button.
  ///
  /// In en, this message translates to:
  /// **'Help is here'**
  String get help_title;

  /// Support sheet subtitle. Warm, never clinical.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry this alone. Reach out now, or take a minute to breathe.'**
  String get help_subtitle;

  /// Support sheet title after a note matched the crisis lexicon. Never alarming.
  ///
  /// In en, this message translates to:
  /// **'It sounds like a lot right now.'**
  String get help_crisisTitle;

  /// Support sheet subtitle after a crisis-lexicon match.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry it alone. Your check-in is saved.'**
  String get help_crisisSubtitle;

  /// India national mental-health helpline 14416.
  ///
  /// In en, this message translates to:
  /// **'Tele-MANAS · free, 24×7'**
  String get help_teleManas;

  /// India Tele-MANAS toll-free number 1-800-891-4416.
  ///
  /// In en, this message translates to:
  /// **'Tele-MANAS toll-free'**
  String get help_teleManasTollFree;

  /// India emergency number 112 (the number is shown separately).
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get help_emergency112;

  /// India Childline 1098, shown to under-18s (number shown separately).
  ///
  /// In en, this message translates to:
  /// **'Childline · for under-18s'**
  String get help_childline;

  /// US crisis line 988 (number shown separately).
  ///
  /// In en, this message translates to:
  /// **'Suicide & Crisis Lifeline · call or text'**
  String get help_us988;

  /// Shown in countries without a listed helpline. Never an empty list.
  ///
  /// In en, this message translates to:
  /// **'If you\'re in danger right now, please call your local emergency number.'**
  String get help_otherEmergency;

  /// Screen-reader label for a tap-to-call helpline row.
  ///
  /// In en, this message translates to:
  /// **'Call {name}, {number}'**
  String help_callSemantic(String name, String number);

  /// Title of the 60-second grounding exercise.
  ///
  /// In en, this message translates to:
  /// **'Sixty seconds to land'**
  String get help_groundingTitle;

  /// Grounding exercise intro.
  ///
  /// In en, this message translates to:
  /// **'Breathe with the circle. Everything else can wait a minute.'**
  String get help_groundingBody;

  /// Start grounding.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get help_groundingStart;

  /// Pause grounding.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get help_groundingPause;

  /// Resume grounding.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get help_groundingResume;

  /// Grounding pacer, inhale.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get help_breatheIn;

  /// Grounding pacer, exhale.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get help_breatheOut;

  /// Grounding prompt 1.
  ///
  /// In en, this message translates to:
  /// **'Feel your feet on the ground.'**
  String get help_ground1;

  /// Grounding prompt 2.
  ///
  /// In en, this message translates to:
  /// **'Notice five things you can see.'**
  String get help_ground2;

  /// Grounding prompt 3.
  ///
  /// In en, this message translates to:
  /// **'Notice three sounds around you.'**
  String get help_ground3;

  /// Grounding prompt 4.
  ///
  /// In en, this message translates to:
  /// **'Let your shoulders drop.'**
  String get help_ground4;

  /// Grounding prompt 5.
  ///
  /// In en, this message translates to:
  /// **'You\'re here. That\'s enough for now.'**
  String get help_ground5;

  /// Grounding finished.
  ///
  /// In en, this message translates to:
  /// **'Well done. Stay as long as you need.'**
  String get help_groundingDone;

  /// Grounding countdown (also read by screen readers).
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second left} other{{seconds} seconds left}}'**
  String help_secondsLeft(int seconds);

  /// Legal disclaimer (Play health policy, Apple 1.4.1).
  ///
  /// In en, this message translates to:
  /// **'Aura is not a medical device or an emergency service.'**
  String get help_disclaimer;

  /// Close the crisis sheet after saving.
  ///
  /// In en, this message translates to:
  /// **'Back to my check-in'**
  String get help_backToCheckin;

  /// Welcome screen title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aura'**
  String get welcome_title;

  /// Welcome screen body. Calm, inviting.
  ///
  /// In en, this message translates to:
  /// **'A quiet place to notice how you feel. Your check-ins stay private, and your Aura grows a little each time you show up.'**
  String get welcome_body;

  /// Welcome CTA.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get welcome_begin;

  /// DOB gate title. Neutral; never mentions 13 or 18.
  ///
  /// In en, this message translates to:
  /// **'When\'s your birthday?'**
  String get dob_title;

  /// DOB gate body.
  ///
  /// In en, this message translates to:
  /// **'We ask everyone. It stays private and is never shown to anyone.'**
  String get dob_body;

  /// DOB picker: day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dob_day;

  /// DOB picker: month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dob_month;

  /// DOB picker: year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get dob_year;

  /// DOB validation (e.g. 30 Feb).
  ///
  /// In en, this message translates to:
  /// **'That date doesn\'t exist. Could you check it?'**
  String get dob_invalid;

  /// DOB validation (future date).
  ///
  /// In en, this message translates to:
  /// **'That date hasn\'t happened yet. Could you check it?'**
  String get dob_future;

  /// Under-13 block screen title. Kind.
  ///
  /// In en, this message translates to:
  /// **'Aura is made for people 13 and older.'**
  String get blocked_title;

  /// Under-13 block screen body.
  ///
  /// In en, this message translates to:
  /// **'We\'d love to see you then.'**
  String get blocked_body;

  /// Under-13 help line, India.
  ///
  /// In en, this message translates to:
  /// **'If you want to talk to someone now, Childline is free on 1098. In an emergency, call 112.'**
  String get blocked_helpIndia;

  /// Under-13 help line, other countries.
  ///
  /// In en, this message translates to:
  /// **'If you want to talk to someone now, please reach out to an adult you trust.'**
  String get blocked_helpOther;

  /// Language picker title.
  ///
  /// In en, this message translates to:
  /// **'Which language feels like home?'**
  String get language_title;

  /// Language picker body.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings.'**
  String get language_body;

  /// Explains Tenglish.
  ///
  /// In en, this message translates to:
  /// **'Telugu in English letters'**
  String get language_teLatnHint;

  /// Explains Hinglish.
  ///
  /// In en, this message translates to:
  /// **'Hindi in English letters'**
  String get language_hiLatnHint;

  /// Badge on beta languages.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get language_beta;

  /// Sign-in title.
  ///
  /// In en, this message translates to:
  /// **'Keep your Aura safe'**
  String get signin_title;

  /// Sign-in body. Reassuring about privacy.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email so your Aura can follow you to a new phone. No name, no phone number, no password.'**
  String get signin_body;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get signin_emailLabel;

  /// Send OTP button.
  ///
  /// In en, this message translates to:
  /// **'Email me a code'**
  String get signin_sendCode;

  /// After sending the OTP.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. You can also tap the link in that email.'**
  String signin_codeSent(String email);

  /// OTP field label.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get signin_codeLabel;

  /// Verify OTP button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get signin_verify;

  /// Resend OTP.
  ///
  /// In en, this message translates to:
  /// **'Send a fresh code'**
  String get signin_resend;

  /// Go back to the email step.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get signin_changeEmail;

  /// Sign-in failed. No blame, no exclamation.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Try again, or sign in another way.'**
  String get signin_error;

  /// OTP expired.
  ///
  /// In en, this message translates to:
  /// **'This code has timed out. We\'ll send a fresh one.'**
  String get signin_codeExpired;

  /// Wrong OTP.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Could you check it?'**
  String get signin_invalidCode;

  /// Invalid email.
  ///
  /// In en, this message translates to:
  /// **'That email doesn\'t look quite right.'**
  String get signin_invalidEmail;

  /// Sign in with Apple (disabled until enabled by flag).
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signin_apple;

  /// Sign in with Google (disabled until enabled by flag).
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signin_google;

  /// Offline at first launch (PRD States).
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Pick your first mood now. We\'ll finish setting up when you\'re connected.'**
  String get signin_offline;

  /// Continue offline to the first check-in.
  ///
  /// In en, this message translates to:
  /// **'Check in now'**
  String get signin_offlineContinue;

  /// Dev builds without Supabase config.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t set up in this build yet. Your check-ins will stay on this phone for now.'**
  String get signin_unavailable;

  /// Skip sign-in when unavailable.
  ///
  /// In en, this message translates to:
  /// **'Continue on this phone'**
  String get signin_continueLocal;

  /// Check-in screen title.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get checkin_title;

  /// Check-in subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the closest one. There\'s no wrong answer.'**
  String get checkin_subtitle;

  /// Grid axis label (top).
  ///
  /// In en, this message translates to:
  /// **'More energy'**
  String get checkin_moreEnergy;

  /// Grid axis label (bottom).
  ///
  /// In en, this message translates to:
  /// **'Less energy'**
  String get checkin_lessEnergy;

  /// Grid axis label (right).
  ///
  /// In en, this message translates to:
  /// **'Pleasant'**
  String get checkin_pleasant;

  /// Grid axis label (left).
  ///
  /// In en, this message translates to:
  /// **'Unpleasant'**
  String get checkin_unpleasant;

  /// High energy, unpleasant quadrant. Never 'bad'.
  ///
  /// In en, this message translates to:
  /// **'Storm'**
  String get quadrant_storm;

  /// Low energy, unpleasant quadrant.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get quadrant_rain;

  /// Low energy, pleasant quadrant.
  ///
  /// In en, this message translates to:
  /// **'Moonlight'**
  String get quadrant_moonlight;

  /// High energy, pleasant quadrant.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get quadrant_sunrise;

  /// Screen-reader label for a mood tile (REQ-A11Y-04).
  ///
  /// In en, this message translates to:
  /// **'{mood}, {quadrant} group, {energy}, {feel}'**
  String mood_semantic(
    String mood,
    String quadrant,
    String energy,
    String feel,
  );

  /// Screen-reader part.
  ///
  /// In en, this message translates to:
  /// **'high energy'**
  String get semantic_highEnergy;

  /// Screen-reader part.
  ///
  /// In en, this message translates to:
  /// **'low energy'**
  String get semantic_lowEnergy;

  /// Screen-reader part.
  ///
  /// In en, this message translates to:
  /// **'pleasant'**
  String get semantic_pleasant;

  /// Screen-reader part.
  ///
  /// In en, this message translates to:
  /// **'unpleasant'**
  String get semantic_unpleasant;

  /// Optional details toggle.
  ///
  /// In en, this message translates to:
  /// **'Add a tag or a few words'**
  String get checkin_addDetails;

  /// Tags section title.
  ///
  /// In en, this message translates to:
  /// **'What\'s it about?'**
  String get checkin_tagsTitle;

  /// Context tag 'study'.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get tag_study;

  /// Context tag 'work'.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get tag_work;

  /// Context tag 'family'.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get tag_family;

  /// Context tag 'friends'.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get tag_friends;

  /// Context tag 'sleep'.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get tag_sleep;

  /// Context tag 'health'.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get tag_health;

  /// Context tag 'money'.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get tag_money;

  /// Context tag 'love'.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get tag_love;

  /// Context tag 'alone'.
  ///
  /// In en, this message translates to:
  /// **'Alone'**
  String get tag_alone;

  /// Context tag 'commute'.
  ///
  /// In en, this message translates to:
  /// **'Commute'**
  String get tag_commute;

  /// Custom tag field.
  ///
  /// In en, this message translates to:
  /// **'Your own tag'**
  String get checkin_customTag;

  /// Add custom tag button.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get checkin_customTagAdd;

  /// Note field label.
  ///
  /// In en, this message translates to:
  /// **'A few words, if you like'**
  String get checkin_noteLabel;

  /// Note privacy hint.
  ///
  /// In en, this message translates to:
  /// **'Only you can read this.'**
  String get checkin_noteHint;

  /// Save check-in (tap 2).
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get checkin_save;

  /// Local write failed. Selection is kept.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save that. Your phone may be low on space.'**
  String get checkin_saveFailed;

  /// Reward moment after saving.
  ///
  /// In en, this message translates to:
  /// **'+{amount} Starlight'**
  String checkin_savedStarlight(int amount);

  /// Saved confirmation.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get checkin_saved;

  /// Saved while offline / before sync.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get checkin_savedOffline;

  /// After saving.
  ///
  /// In en, this message translates to:
  /// **'Thank you for checking in.'**
  String get checkin_savedThanks;

  /// When the day's Starlight is already capped.
  ///
  /// In en, this message translates to:
  /// **'You\'ve gathered all of today\'s Starlight. Your check-in still counts.'**
  String get checkin_savedFull;

  /// Room prompt after saving (F5, coming soon).
  ///
  /// In en, this message translates to:
  /// **'Join a room of people feeling this'**
  String get checkin_roomButton;

  /// Primary Home button.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get home_checkIn;

  /// Today's Starlight.
  ///
  /// In en, this message translates to:
  /// **'{count} Starlight today'**
  String home_todayStarlight(int count);

  /// All-time Starlight.
  ///
  /// In en, this message translates to:
  /// **'{count} in all'**
  String home_totalStarlight(int count);

  /// New user empty state.
  ///
  /// In en, this message translates to:
  /// **'This is your Aura. Check in to give it light.'**
  String get home_empty;

  /// Resting Nebula copy. No guilt.
  ///
  /// In en, this message translates to:
  /// **'Your Aura has been resting. Say hi when you\'re ready.'**
  String get home_resting;

  /// Current glow streak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Glow streak · 1 day} other{Glow streak · {count} days}}'**
  String home_glowStreak(int count);

  /// Rest-day bank.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rest days saved yet} =1{1 rest day saved} other{{count} rest days saved}}'**
  String home_restDays(int count);

  /// Gap covered by rest days (F3). Never a countdown.
  ///
  /// In en, this message translates to:
  /// **'Resting · your glow is safe'**
  String get home_restingSafe;

  /// Shown once when a new streak starts. No loss words.
  ///
  /// In en, this message translates to:
  /// **'Your glow carries on'**
  String get home_glowCarriesOn;

  /// Lifetime glow days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 glow day in all} other{{count} glow days in all}}'**
  String home_lifetimeGlow(int count);

  /// Habits section title.
  ///
  /// In en, this message translates to:
  /// **'Small things today'**
  String get home_habitsTitle;

  /// Screen-reader label, habit done.
  ///
  /// In en, this message translates to:
  /// **'{habit}, done today'**
  String home_habitDone(String habit);

  /// Screen-reader label, habit not done (no 'missed').
  ///
  /// In en, this message translates to:
  /// **'{habit}, not yet today'**
  String home_habitNotYet(String habit);

  /// Offline banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Your own things still save here.'**
  String get home_offline;

  /// Signed-out banner.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up so your Aura is kept safe.'**
  String get home_finishSetup;

  /// Sign-in button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get home_signIn;

  /// Sync indicator: synced.
  ///
  /// In en, this message translates to:
  /// **'All saved'**
  String get home_syncIdle;

  /// Sync indicator: pending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing waiting to sync} other{{count} things waiting to sync}}'**
  String home_syncPending(int count);

  /// Sync indicator: local only.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get home_syncLocal;

  /// Settings button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get home_settings;

  /// Wake-up moment micro-goal. Never a list of what was missed.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. One small thing today is plenty.'**
  String get home_welcomeBack;

  /// Evolution moment.
  ///
  /// In en, this message translates to:
  /// **'Your Aura grew into {stage}.'**
  String home_evolved(String stage);

  /// Avatar stage 'spark'.
  ///
  /// In en, this message translates to:
  /// **'Spark'**
  String get stage_spark;

  /// Avatar stage 'ember'.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get stage_ember;

  /// Avatar stage 'glow'.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get stage_glow;

  /// Avatar stage 'radiance'.
  ///
  /// In en, this message translates to:
  /// **'Radiance'**
  String get stage_radiance;

  /// Avatar stage 'constellation'.
  ///
  /// In en, this message translates to:
  /// **'Constellation'**
  String get stage_constellation;

  /// Preset habit 'hydrate'.
  ///
  /// In en, this message translates to:
  /// **'Hydrate'**
  String get habit_hydrate;

  /// Preset habit 'sleep_on_time'.
  ///
  /// In en, this message translates to:
  /// **'Sleep on time'**
  String get habit_sleep_on_time;

  /// Preset habit 'move'.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get habit_move;

  /// Preset habit 'breathe'.
  ///
  /// In en, this message translates to:
  /// **'Breathe'**
  String get habit_breathe;

  /// Preset habit 'journal'.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get habit_journal;

  /// Preset habit 'go_outside'.
  ///
  /// In en, this message translates to:
  /// **'Go outside'**
  String get habit_go_outside;

  /// Avatar description for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Your Aura, {stage} stage, {hue} glow'**
  String avatar_semantic(String stage, String hue);

  /// Appended when resting.
  ///
  /// In en, this message translates to:
  /// **'resting in a soft nebula'**
  String get avatar_semanticResting;

  /// Rings trait for screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{one orbiting light} other{{count} orbiting lights}}'**
  String avatar_semanticRings(int count);

  /// Constellation stars for screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{one star in its constellation} other{{count} stars in its constellation}}'**
  String avatar_semanticStars(int count);

  /// Avatar hue name 'gold'.
  ///
  /// In en, this message translates to:
  /// **'golden'**
  String get hue_gold;

  /// Avatar hue name 'green'.
  ///
  /// In en, this message translates to:
  /// **'green'**
  String get hue_green;

  /// Avatar hue name 'teal'.
  ///
  /// In en, this message translates to:
  /// **'teal'**
  String get hue_teal;

  /// Avatar hue name 'silverBlue'.
  ///
  /// In en, this message translates to:
  /// **'silver-blue'**
  String get hue_silverBlue;

  /// Avatar hue name 'violet'.
  ///
  /// In en, this message translates to:
  /// **'violet'**
  String get hue_violet;

  /// Avatar hue name 'rose'.
  ///
  /// In en, this message translates to:
  /// **'rose'**
  String get hue_rose;

  /// Settings title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// Language row.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// Account section.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_account;

  /// Account row.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String settings_signedInAs(String email);

  /// Sign out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settings_signOut;

  /// Unsynced warning on sign-out.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing hasn\'t synced yet. Stay signed in until it does?} other{{count} things haven\'t synced yet. Stay signed in until they do?}}'**
  String settings_signOutPending(int count);

  /// Keep session.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get settings_stay;

  /// Confirm sign out.
  ///
  /// In en, this message translates to:
  /// **'Sign out anyway'**
  String get settings_signOutAnyway;

  /// Signed-out row.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your Aura safe'**
  String get settings_signIn;

  /// Debug-only entry.
  ///
  /// In en, this message translates to:
  /// **'Avatar lab'**
  String get settings_avatarLab;

  /// About section.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// App version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settings_version(String version);

  /// Pre-permission explainer title, shown once after the first check-in. PRD copy. Warm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Want a gentle nudge each evening?'**
  String get push_title;

  /// Pre-permission explainer body. Must promise: at most one a day, never streaks, never a mood on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'One a day at most, and never about streaks. Nothing on your lock screen will say how you feel.'**
  String get push_body;

  /// Explainer button that opens the system notification prompt.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get push_allow;

  /// Link to the privacy policy (opens the browser).
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legal_privacy;

  /// Link to the terms of use (opens the browser).
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legal_terms;

  /// Screen-reader hint on legal links.
  ///
  /// In en, this message translates to:
  /// **'Opens in your browser'**
  String get legal_opensInBrowser;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsHiLatn();
        }
        break;
      }
    case 'te':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsTeLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
