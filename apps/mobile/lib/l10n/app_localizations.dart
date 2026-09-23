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

  /// Sign in with Apple. Only shown when social sign-in is enabled for the build.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signin_apple;

  /// Sign in with Google. Only shown when social sign-in is enabled for the build.
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

  /// Screen-reader label of the small progress ring inside a button while sign-in or deletion work runs.
  ///
  /// In en, this message translates to:
  /// **'One moment'**
  String get signin_busy;

  /// Quiet label on the disabled resend button during its 30-second cooldown. 's' = seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{You can ask for a fresh code in 1 s} other{You can ask for a fresh code in {seconds} s}}'**
  String signin_resendIn(int seconds);

  /// Shown after the person asked for a fresh sign-in code and it was sent.
  ///
  /// In en, this message translates to:
  /// **'A fresh code is on its way.'**
  String get signin_freshSent;

  /// Title of the choice shown when the signed-in account is scheduled for deletion (7-day grace).
  ///
  /// In en, this message translates to:
  /// **'Keep your account?'**
  String get acct_pendingTitle;

  /// Deletion is scheduled; {date} is a formatted date. Calm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Your account is set to be deleted on {date}. Keep it?'**
  String acct_pendingBody(String date);

  /// Deletion is scheduled but the date isn't known yet (offline).
  ///
  /// In en, this message translates to:
  /// **'Your account is set to be deleted soon. Keep it?'**
  String get acct_pendingBodySoon;

  /// Cancels the scheduled deletion.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get acct_keep;

  /// Leaves the deletion scheduled and signs out of this phone (clears it).
  ///
  /// In en, this message translates to:
  /// **'Let it go'**
  String get acct_letGo;

  /// Cancelling the deletion failed. No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through, so nothing has changed yet. Try again when you\'re connected.'**
  String get acct_keepFailed;

  /// Settings row, screen title and the destructive button. Explicit, not softened.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get acct_deleteTitle;

  /// Lead-in to the list of what is deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes:'**
  String get acct_deleteIntro;

  /// What is deleted (list item).
  ///
  /// In en, this message translates to:
  /// **'Your check-ins and notes'**
  String get acct_itemCheckIns;

  /// What is deleted (list item).
  ///
  /// In en, this message translates to:
  /// **'Your habits'**
  String get acct_itemHabits;

  /// What is deleted (list item). Starlight and Aura are brand terms.
  ///
  /// In en, this message translates to:
  /// **'Your Starlight and your Aura\'s growth'**
  String get acct_itemProgress;

  /// What is deleted (list item).
  ///
  /// In en, this message translates to:
  /// **'Your account and the email you sign in with'**
  String get acct_itemAccount;

  /// The 7-day grace period.
  ///
  /// In en, this message translates to:
  /// **'You have 7 days to change your mind. Sign in again before then and everything stays. After that it\'s deleted for good and can\'t be brought back.'**
  String get acct_grace;

  /// Store subscription warning (Apple 5.1.1(v)). Store names stay in English.
  ///
  /// In en, this message translates to:
  /// **'If you pay for a subscription through the App Store or Google Play, deleting your account doesn\'t cancel it. Manage or cancel it in your store\'s subscription settings.'**
  String get acct_store;

  /// What happens on this phone after the request.
  ///
  /// In en, this message translates to:
  /// **'This phone will be cleared and signed out straight away.'**
  String get acct_phone;

  /// Offline: the delete button is disabled.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account needs a connection. Connect to the internet, then try again.'**
  String get acct_needsConnection;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get acct_confirmTitle;

  /// Confirmation dialog body.
  ///
  /// In en, this message translates to:
  /// **'Your account and everything in it will be deleted in 7 days. Sign in again before then to keep it. This phone will be cleared now.'**
  String get acct_confirmBody;

  /// The deletion request failed. Nothing was wiped.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through, and nothing has been deleted. Try again in a moment.'**
  String get acct_failed;

  /// The deletion request could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach Aura, and nothing has been deleted. Check your connection and try again.'**
  String get acct_failedOffline;

  /// Retry after a failed request.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get acct_retry;

  /// Shown after the deletion was scheduled.
  ///
  /// In en, this message translates to:
  /// **'Your account is set to be deleted'**
  String get acct_scheduledTitle;

  /// {date} is a formatted date.
  ///
  /// In en, this message translates to:
  /// **'It will be deleted on {date}. Sign in again before then to keep it.'**
  String acct_scheduledBody(String date);

  /// After the deletion was scheduled and the phone wiped.
  ///
  /// In en, this message translates to:
  /// **'This phone has been cleared and signed out.'**
  String get acct_phoneCleared;

  /// Delete screen opened while signed out.
  ///
  /// In en, this message translates to:
  /// **'You\'re not signed in, so there\'s no account to delete. What you\'ve saved lives only on this phone.'**
  String get acct_signedOut;

  /// Dev builds without an API URL.
  ///
  /// In en, this message translates to:
  /// **'Account deletion isn\'t set up in this build.'**
  String get acct_unavailable;

  /// Settings section: motion, haptics, streak number.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get set_comfort;

  /// Switch (REQ-A11Y-08).
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get set_reduceMotion;

  /// Note under Reduce motion; when the phone already reduces motion the switch is on and locked.
  ///
  /// In en, this message translates to:
  /// **'Also follows your phone\'s setting'**
  String get set_reduceMotionNote;

  /// Switch for gentle vibration feedback.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get set_haptics;

  /// Note under Haptics.
  ///
  /// In en, this message translates to:
  /// **'Soft taps when you choose something'**
  String get set_hapticsNote;

  /// Switch (F3): hides the glow-streak day count on Home.
  ///
  /// In en, this message translates to:
  /// **'Hide streak number'**
  String get set_hideStreak;

  /// Note under Hide streak number. No loss framing.
  ///
  /// In en, this message translates to:
  /// **'Your glow still grows. Home just won\'t count the days.'**
  String get set_hideStreakNote;

  /// Title of the sign-out warning when items haven't synced.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Aura?'**
  String get set_signOutTitle;

  /// Settings section: disclaimer, legal links, Grievance Officer, support.
  ///
  /// In en, this message translates to:
  /// **'Help & Safety'**
  String get set_helpSafety;

  /// Row title (F9, IT Rules). Tapping writes an email.
  ///
  /// In en, this message translates to:
  /// **'Grievance Officer'**
  String get set_grievanceOfficer;

  /// Email subject pre-filled when writing to the Grievance Officer.
  ///
  /// In en, this message translates to:
  /// **'Grievance about Aura'**
  String get set_grievanceSubject;

  /// Row title. Tapping writes an email.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get set_contactSupport;

  /// Email subject pre-filled when writing to support.
  ///
  /// In en, this message translates to:
  /// **'Aura support'**
  String get set_supportSubject;

  /// Screen-reader hint on email rows.
  ///
  /// In en, this message translates to:
  /// **'Opens your email app'**
  String get set_opensEmail;

  /// No mail app could open a mailto link.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open an email app. You can write to {email}.'**
  String set_emailFailed(String email);

  /// "Keep my account" came too late: the 7-day grace is over and deletion has started. Calm, no blame. The only button is Sign out.
  ///
  /// In en, this message translates to:
  /// **'This account is already being deleted, so it can\'t be kept any more. This phone will be cleared and signed out.'**
  String get acct_inProgress;

  /// Asked when closing the check-in (or an edit) with a mood, tags or words not yet saved. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get checkin_discardTitle;

  /// Default choice in the leave-without-saving dialog: stay and keep what was entered.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get checkin_discardKeep;

  /// Leave-without-saving dialog: leave and drop what was entered.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get checkin_discardConfirm;

  /// Calm hint shown when the tag limit for one check-in is reached.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Up to 1 tag} other{Up to {count} tags}}'**
  String checkin_tagLimit(int count);

  /// Caption under a quadrant name when the mood grid is stacked one quadrant per row (large text). energy = 'More energy'/'Less energy', feel = 'Pleasant'/'Unpleasant'.
  ///
  /// In en, this message translates to:
  /// **'{energy} · {feel}'**
  String checkin_quadrantAxes(String energy, String feel);

  /// Private history screen title.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins'**
  String get history_title;

  /// Privacy line under the history title.
  ///
  /// In en, this message translates to:
  /// **'Only you can see these.'**
  String get history_private;

  /// History empty state. Calm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Your check-ins will gather here, and only you can see them.'**
  String get history_empty;

  /// Day header in history: the current Aura day.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get history_today;

  /// Day header in history: the previous Aura day.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get history_yesterday;

  /// Discreet tag count on a history row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tag} other{{count} tags}}'**
  String history_tagCount(int count);

  /// Screen-reader label for the note icon on a history row (the note itself is never shown in the list).
  ///
  /// In en, this message translates to:
  /// **'Has a note'**
  String get history_hasNote;

  /// Title of one check-in's page.
  ///
  /// In en, this message translates to:
  /// **'Your check-in'**
  String get history_entryTitle;

  /// When a check-in was made, e.g. 'Today, 3:30 PM'.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String history_when(String day, String time);

  /// Section header on a check-in's page.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get history_tags;

  /// Section header for the private note on a check-in's page.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get history_note;

  /// Sync status: this check-in is safely on the server.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get history_synced;

  /// Edit a check-in (only within a day).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get history_edit;

  /// Shown instead of Edit after 24 hours. Calm, informative.
  ///
  /// In en, this message translates to:
  /// **'You can edit a check-in for a day after you make it.'**
  String get history_editWindowOver;

  /// Delete a check-in (asks first).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get history_delete;

  /// Delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this check-in?'**
  String get history_deleteTitle;

  /// Delete confirmation body: deleting never removes progress (PRD F1).
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t change your Starlight or glow days.'**
  String get history_deleteBody;

  /// Shown when a check-in was deleted or can't be found.
  ///
  /// In en, this message translates to:
  /// **'This check-in isn\'t here anymore.'**
  String get history_missing;

  /// Shown instead of Edit when the note is still encrypted-only on this phone. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'This check-in\'s note hasn\'t reached this phone yet. You can edit it once it has.'**
  String get history_editNoteLocked;

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

  /// Asked when the Android back gesture is used on the first (onboarding) check-in after picking a mood, tags or words. Back never leaves this screen; this only offers to clear it. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get flows_startOverTitle;

  /// Body of the start-over dialog on the first check-in: what 'Start over' clears. Calm.
  ///
  /// In en, this message translates to:
  /// **'This clears what you\'ve picked and written so far.'**
  String get flows_startOverBody;

  /// Start-over dialog on the first check-in: clears the mood, tags and words and stays on the check-in. The default choice is 'Keep editing'.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get flows_startOver;

  /// Screen-reader label for the thin progress bar toward the next avatar stage. Calm, no countdown or pressure.
  ///
  /// In en, this message translates to:
  /// **'{stage}, {count} of {target} Starlight toward {next}'**
  String home_stageProgress(String stage, String next, int count, int target);

  /// Screen-reader label for the constellation stars row (final stage).
  ///
  /// In en, this message translates to:
  /// **'{stage}, {count} of {max} stars in your constellation'**
  String home_constellationProgress(String stage, int count, int max);

  /// Glow card heading when the streak number is hidden (Settings → Hide streak number).
  ///
  /// In en, this message translates to:
  /// **'Your glow'**
  String get home_glowTitle;

  /// Screen-reader hint on the rest-day row (opens a short explainer).
  ///
  /// In en, this message translates to:
  /// **'Learn how rest days work'**
  String get home_restDaysHint;

  /// Title of the rest-day explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'Rest days'**
  String get home_restInfoTitle;

  /// Rest-day explainer: how they are earned. Numbers come from the rules.
  ///
  /// In en, this message translates to:
  /// **'Every {days} glow days earn a rest day. You can keep up to {max}.'**
  String home_restInfoEarn(int days, int max);

  /// Rest-day explainer: applied automatically, never prompted.
  ///
  /// In en, this message translates to:
  /// **'When you take a short break, they fill in those days on their own. There\'s nothing you need to do.'**
  String get home_restInfoUse;

  /// Rest-day explainer: lifetime glow days never go down. No loss words.
  ///
  /// In en, this message translates to:
  /// **'Every glow day you\'ve had stays with you.'**
  String get home_restInfoKeep;

  /// Home line under the stats; opens check-in history.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in today} other{{count} check-ins today}}'**
  String home_checkInsToday(int count);

  /// Link to check-in history, after today's count.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get home_seeAll;

  /// Home link to check-in history when there is none today.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins'**
  String get home_yourCheckIns;

  /// Sync sheet: all synced.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved on this phone and in your account.'**
  String get home_syncExplainIdle;

  /// Sync sheet: items waiting to sync.
  ///
  /// In en, this message translates to:
  /// **'They\'re safe on this phone and will sync on their own.'**
  String get home_syncExplainPending;

  /// Sync sheet: offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Everything is safe on this phone and syncs when you\'re back online.'**
  String get home_syncExplainOffline;

  /// Sync sheet: signed out.
  ///
  /// In en, this message translates to:
  /// **'You\'re not signed in, so everything stays on this phone for now.'**
  String get home_syncExplainSignedOut;

  /// Sync sheet: builds without a server.
  ///
  /// In en, this message translates to:
  /// **'This version keeps everything on this phone.'**
  String get home_syncExplainUnavailable;

  /// Sync sheet button (online and signed in).
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get home_syncNow;

  /// Sync sheet button while a sync runs.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get home_syncing;

  /// Screen-reader hint on the sync indicator.
  ///
  /// In en, this message translates to:
  /// **'Show sync details'**
  String get home_syncHint;

  /// Button next to the habits title; opens the habits editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get habits_edit;

  /// Screen-reader label of the habits Edit button.
  ///
  /// In en, this message translates to:
  /// **'Edit small things'**
  String get habits_editSemantic;

  /// Habits editor title.
  ///
  /// In en, this message translates to:
  /// **'Your small things'**
  String get habits_sheetTitle;

  /// Habits editor intro.
  ///
  /// In en, this message translates to:
  /// **'Choose what shows on Home. Check-ins grow your Aura either way.'**
  String get habits_sheetBody;

  /// Habits editor section: the six presets.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get habits_presetsTitle;

  /// Habits editor section: custom habits.
  ///
  /// In en, this message translates to:
  /// **'Your own'**
  String get habits_customTitle;

  /// Label of the custom-habit name field.
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get habits_addLabel;

  /// Hint in the custom-habit name field.
  ///
  /// In en, this message translates to:
  /// **'For example, water the plants'**
  String get habits_addHint;

  /// Adds the typed custom habit.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get habits_add;

  /// Shown at the custom-habit limit (PRD States: Habits).
  ///
  /// In en, this message translates to:
  /// **'You have {count} custom habits. Swap one to add another.'**
  String habits_limit(int count);

  /// A habit change failed to save locally.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Could you try again?'**
  String get habits_saveFailed;

  /// Tooltip / screen-reader label of a custom habit's remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String habits_remove(String name);

  /// Confirm dialog title before removing a custom habit.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String habits_removeTitle(String name);

  /// Confirm dialog body before removing a custom habit.
  ///
  /// In en, this message translates to:
  /// **'It leaves your list. Starlight and glow days you earned with it stay.'**
  String get habits_removeBody;

  /// Confirm removing a custom habit.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get habits_removeConfirm;

  /// Home when every habit is hidden (PRD States: Habits empty).
  ///
  /// In en, this message translates to:
  /// **'Pick one small thing to start.'**
  String get habits_empty;

  /// Screen-reader label of the grounding progress ring. No countdown.
  ///
  /// In en, this message translates to:
  /// **'Progress through the minute'**
  String get help_groundingProgress;

  /// Grounding ring value: first third.
  ///
  /// In en, this message translates to:
  /// **'Just begun'**
  String get help_progressBegun;

  /// Grounding ring value: middle third.
  ///
  /// In en, this message translates to:
  /// **'About halfway'**
  String get help_progressHalf;

  /// Grounding ring value: last third. Never pressure.
  ///
  /// In en, this message translates to:
  /// **'Nearly through'**
  String get help_progressNearly;

  /// Grounding ring value: finished.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get help_progressDone;

  /// After the 60 s exercise auto-completes the Breathe habit (F2).
  ///
  /// In en, this message translates to:
  /// **'{habit} is marked done for today.'**
  String help_breatheLogged(String habit);

  /// Trust step title (privacy and boundaries). Calm.
  ///
  /// In en, this message translates to:
  /// **'Before we begin'**
  String get onb_trustTitle;

  /// Trust step intro under the title.
  ///
  /// In en, this message translates to:
  /// **'A few things to know about how Aura looks after you.'**
  String get onb_trustBody;

  /// Trust point heading: privacy.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get onb_trustPrivateTitle;

  /// Trust point body: privacy. Must stay true: notes are encrypted; moods are shared only by the user's choice (e.g. joining a room).
  ///
  /// In en, this message translates to:
  /// **'Your check-ins and notes are yours. Notes are encrypted, and nobody else sees how you feel unless you choose to share it.'**
  String get onb_trustPrivateBody;

  /// Trust point heading: Aura is not therapy or diagnosis (F9 App Review positioning).
  ///
  /// In en, this message translates to:
  /// **'Wellness support, not therapy'**
  String get onb_trustCareTitle;

  /// Trust point body: no diagnosis. Followed by the help_disclaimer sentence as its own line.
  ///
  /// In en, this message translates to:
  /// **'Aura helps you notice how you feel. It doesn\'t diagnose or treat anything.'**
  String get onb_trustCareBody;

  /// Trust point heading: the always-visible help button.
  ///
  /// In en, this message translates to:
  /// **'Help is always one tap away'**
  String get onb_trustHelpTitle;

  /// Trust point body. {button} is the help button's label (help_button), quoted as it appears on screen.
  ///
  /// In en, this message translates to:
  /// **'Tap “{button}” any time to call a helpline or take a minute to breathe.'**
  String onb_trustHelpBody(String button);

  /// Label of the optional typed-year field at the top of the year picker. No example year.
  ///
  /// In en, this message translates to:
  /// **'Type the year'**
  String get onb_dobYearType;

  /// Typed year is not in the picker's range. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'No year in the list matches that. Could you check it?'**
  String get onb_dobYearNoMatch;

  /// Text button on the under-13 screen; opens an email to support.
  ///
  /// In en, this message translates to:
  /// **'Entered the wrong date?'**
  String get onb_blockedWrongDate;

  /// Screen-reader hint on the wrong-date button.
  ///
  /// In en, this message translates to:
  /// **'Opens your email app'**
  String get onb_blockedWrongDateHint;

  /// Email subject only. Never add the date of birth or any personal data.
  ///
  /// In en, this message translates to:
  /// **'Aura: I entered the wrong date'**
  String get onb_blockedMailSubject;

  /// Shown when no email app opens. {email} is the support address.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open an email app. You can write to us at {email}.'**
  String onb_blockedMailFailed(String email);

  /// Calm inline note under the Privacy policy / Terms links when no browser could open the page. {url} is the public page address (not personal data). No blame.
  ///
  /// In en, this message translates to:
  /// **'Your browser didn\'t open. The page is at {url}.'**
  String polish_legalOpenFailed(String url);

  /// Button next to the note above: copies the page address.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get polish_legalCopyLink;

  /// Shown and announced after the page address was copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get polish_legalLinkCopied;

  /// Calm inline note under a helpline when the device can't dial (iPad, simulator). {number} is the helpline number as shown. Never alarming.
  ///
  /// In en, this message translates to:
  /// **'This phone can\'t place the call. The number is {number}.'**
  String polish_helpCallFailed(String number);

  /// Button next to the note above: copies the helpline number.
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get polish_helpCopyNumber;

  /// Shown and announced after the helpline number was copied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get polish_helpNumberCopied;

  /// Button in the check-in details that starts recording a voice note (also its screen-reader label).
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voice_record;

  /// Hint under the record button: the 60-second limit and that it is private. Calm.
  ///
  /// In en, this message translates to:
  /// **'Up to a minute. Only you can hear it.'**
  String get voice_recordHint;

  /// Title of the explainer shown before the microphone permission prompt (first mic tap).
  ///
  /// In en, this message translates to:
  /// **'Add your voice?'**
  String get voice_rationaleTitle;

  /// Microphone explainer before the OS prompt (PRD 15-permissions wording).
  ///
  /// In en, this message translates to:
  /// **'To record a voice note, Aura needs your microphone. Recordings stay private to you and are never shared in rooms.'**
  String get voice_rationaleBody;

  /// Microphone explainer button: shows the OS permission prompt. 'Not now' never does.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get voice_rationaleAllow;

  /// Shown when the microphone permission is denied (PRD states 'Edge: mic denied'). Typing still works. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Voice is off. Type instead, or turn it on in Settings.'**
  String get voice_denied;

  /// Link next to 'Voice is off' that opens this app's page in the phone's Settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get voice_openSettings;

  /// Status while a voice note is being recorded.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get voice_recording;

  /// Elapsed recording time next to the limit, e.g. '0:12 · up to 1:00'. Calm, not a countdown.
  ///
  /// In en, this message translates to:
  /// **'{time} · up to {limit}'**
  String voice_elapsed(String time, String limit);

  /// Screen-reader text for the recording time.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Recording, 1 second} other{Recording, {seconds} seconds}}'**
  String voice_recordingFor(int seconds);

  /// Button that stops recording (also its screen-reader label).
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get voice_stop;

  /// Screen-reader announcement when recording starts.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get voice_started;

  /// Screen-reader announcement when recording stops.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Voice note recorded, 1 second} other{Voice note recorded, {seconds} seconds}}'**
  String voice_recorded(int seconds);

  /// Calm note after recording stopped by itself at 60 seconds. No alarm.
  ///
  /// In en, this message translates to:
  /// **'That\'s the full minute, so recording stopped. Your voice note is ready.'**
  String get voice_limitReached;

  /// Recording could not start or finish (e.g. the phone is out of space). Calm.
  ///
  /// In en, this message translates to:
  /// **'Voice couldn\'t be recorded just now. Your words still save.'**
  String get voice_recordFailed;

  /// Label of a recorded voice note (in the check-in and on a history entry).
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voice_note;

  /// Screen-reader length of a voice note.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String voice_length(int seconds);

  /// Play button (screen-reader label).
  ///
  /// In en, this message translates to:
  /// **'Play voice note'**
  String get voice_play;

  /// Pause button (screen-reader label).
  ///
  /// In en, this message translates to:
  /// **'Pause voice note'**
  String get voice_pause;

  /// Replace the voice note with a new recording.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get voice_reRecord;

  /// Remove the voice note from this check-in.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get voice_remove;

  /// Screen-reader label of the Remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove voice note'**
  String get voice_removeSemantic;

  /// After saving when the voice file could not be stored (PRD F1 'Storage full: text saves; voice is dropped with a notice'). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Your check-in is saved. The voice note couldn\'t be kept, as your phone may be low on space.'**
  String get voice_dropped;

  /// While a voice note is fetched or opened for playback.
  ///
  /// In en, this message translates to:
  /// **'Getting your voice note…'**
  String get voice_loading;

  /// A voice note that is only on the server, while offline. Calm.
  ///
  /// In en, this message translates to:
  /// **'The voice note plays when you\'re back online.'**
  String get voice_offline;

  /// Playback failed (download or file problem). Calm; the play button retries.
  ///
  /// In en, this message translates to:
  /// **'This voice note couldn\'t be played just now. Try again in a moment.'**
  String get voice_failed;

  /// Section header for the voice note on a check-in's page.
  ///
  /// In en, this message translates to:
  /// **'Your voice'**
  String get voice_section;

  /// Screen-reader label for the voice icon on a history row.
  ///
  /// In en, this message translates to:
  /// **'Has a voice note'**
  String get voice_hasVoice;
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
