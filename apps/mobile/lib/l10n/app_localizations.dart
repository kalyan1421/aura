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

  /// Sign in with Apple button title. Apple allows only 'Sign in with Apple', 'Sign up with Apple' or 'Continue with Apple' (localized, same meaning). Keep 'Apple' in Latin script. Shown only when Apple sign-in is set up for the build.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signin_apple;

  /// Sign in with Google button label. Google allows only 'Sign in with Google', 'Sign up with Google' or 'Continue with Google' (localized, same meaning). Keep 'Google' in Latin script. Shown only when Google sign-in is set up for the build.
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

  /// Divider between the email sign-in and the Apple / Google buttons. Lower case, one word.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signin_or;

  /// Apple or Google sign-in isn't set up (server or build). Calm, no blame; points to email.
  ///
  /// In en, this message translates to:
  /// **'That sign-in option isn\'t ready yet. Use your email for now.'**
  String get signin_socialNotReady;

  /// Apple or Google sign-in couldn't reach the server (no connection). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'It looks like you\'re offline. Try again when you\'re connected.'**
  String get signin_socialOffline;

  /// Title of the time-capsules area (Sanctuary section and the capsules list). Notes the person seals for their future self.
  ///
  /// In en, this message translates to:
  /// **'Future you'**
  String get capsules_title;

  /// Empty state of the capsules list and the Sanctuary entry (PRD 14-states). Inviting, never pushy.
  ///
  /// In en, this message translates to:
  /// **'Write to future you. Seal it for a date, or for a feeling.'**
  String get capsules_emptyBody;

  /// Button in the empty capsules list that opens the composer (PRD 14-states).
  ///
  /// In en, this message translates to:
  /// **'Seal your first capsule'**
  String get capsules_emptyCta;

  /// Button that opens the capsule composer when the person already has capsules.
  ///
  /// In en, this message translates to:
  /// **'Write a capsule'**
  String get capsules_new;

  /// Sanctuary entry: how many capsules are sealed (waiting).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing sealed yet} =1{1 capsule sealed} other{{count} capsules sealed}}'**
  String capsules_entryCount(int count);

  /// Sanctuary entry: capsules whose time has come. Calm, no urgency.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 is ready to open} other{{count} are ready to open}}'**
  String capsules_entryReady(int count);

  /// List section: capsules that can be opened now.
  ///
  /// In en, this message translates to:
  /// **'Ready to open'**
  String get capsules_sectionReady;

  /// List section: capsules still sealed.
  ///
  /// In en, this message translates to:
  /// **'Sealed'**
  String get capsules_sectionSealed;

  /// List section: capsules already opened (they can be read again).
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get capsules_sectionOpened;

  /// A sealed date capsule (PRD 14-states). date = e.g. '12 Oct 2027'. Reassuring: it is safe and waiting.
  ///
  /// In en, this message translates to:
  /// **'Sealed until {date}. It\'ll keep.'**
  String capsules_sealedUntil(String date);

  /// A sealed mood-trigger capsule in the list. Never names the feeling here.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a feeling'**
  String get capsules_waitingFeeling;

  /// A capsule in the list that can be opened now.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are'**
  String get capsules_readyRow;

  /// Shown instead of a title when the person left the title empty. date = the day it was sealed.
  ///
  /// In en, this message translates to:
  /// **'A capsule from {date}'**
  String capsules_untitled(String date);

  /// Shown instead of the title when this phone can't read it yet (e.g. a new phone before the key arrives).
  ///
  /// In en, this message translates to:
  /// **'A sealed capsule'**
  String get capsules_lockedTitle;

  /// When a capsule was sealed. date = e.g. '8 Oct 2026'.
  ///
  /// In en, this message translates to:
  /// **'Sealed {date}'**
  String capsules_sealedOn(String date);

  /// When a capsule was opened. date = e.g. '8 Oct 2027'.
  ///
  /// In en, this message translates to:
  /// **'Opened {date}'**
  String capsules_openedOn(String date);

  /// Card in the list: an unsealed capsule draft kept on this phone.
  ///
  /// In en, this message translates to:
  /// **'Your draft is here'**
  String get capsules_draftTitle;

  /// Under 'Your draft is here'.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off.'**
  String get capsules_draftBody;

  /// Title of the capsule composer.
  ///
  /// In en, this message translates to:
  /// **'Write to future you'**
  String get capsules_composeTitle;

  /// Capsule title field (up to 60 characters).
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get capsules_titleLabel;

  /// Helper under the title field: the title is the only thing visible before it opens.
  ///
  /// In en, this message translates to:
  /// **'Shown on the capsule while it\'s sealed.'**
  String get capsules_titleHelper;

  /// Capsule text field (up to 2,000 characters).
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get capsules_textLabel;

  /// Helper under the capsule text field. Private.
  ///
  /// In en, this message translates to:
  /// **'Only you will read this, when it opens.'**
  String get capsules_textHelper;

  /// Section header for capsule photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get capsules_photosTitle;

  /// Opens the system photo picker (no permission needed).
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get capsules_addPhoto;

  /// Under 'Add a photo': at most 3 photos; EXIF/GPS are stripped on the phone.
  ///
  /// In en, this message translates to:
  /// **'Up to 3. Location and camera details are removed.'**
  String get capsules_photoHint;

  /// While a picked photo is resized and cleaned on the phone.
  ///
  /// In en, this message translates to:
  /// **'Adding your photo…'**
  String get capsules_photoAdding;

  /// A picked photo could not be read or stored. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'That photo couldn\'t be added. Try another one.'**
  String get capsules_photoFailed;

  /// Screen-reader label / tooltip of a photo's remove button.
  ///
  /// In en, this message translates to:
  /// **'Remove photo {index}'**
  String capsules_photoRemove(int index);

  /// Screen-reader label of a capsule photo.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String capsules_photoSemantic(int index, int count);

  /// Hint under the record button in the capsule composer: the 2-minute limit and that it is private.
  ///
  /// In en, this message translates to:
  /// **'Up to 2 minutes. Only you can hear it.'**
  String get capsules_voiceHint;

  /// Calm note after a capsule recording stopped by itself at 2:00 (REQ-CAP-05).
  ///
  /// In en, this message translates to:
  /// **'That\'s the full two minutes, so recording stopped. Your voice note is ready.'**
  String get capsules_voiceLimit;

  /// Section header: choose a date or a feeling.
  ///
  /// In en, this message translates to:
  /// **'When should it open?'**
  String get capsules_unlockTitle;

  /// Choice: the capsule opens on a date.
  ///
  /// In en, this message translates to:
  /// **'On a date'**
  String get capsules_unlockDate;

  /// Choice: the capsule opens on the next check-in with a chosen mood.
  ///
  /// In en, this message translates to:
  /// **'For a feeling'**
  String get capsules_unlockFeeling;

  /// Opens the date picker.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get capsules_pickDate;

  /// Opens the date picker again.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get capsules_changeDate;

  /// The chosen unlock moment, e.g. 'Opens 12 Oct 2027 at 10:00 AM'.
  ///
  /// In en, this message translates to:
  /// **'Opens {date} at {time}'**
  String capsules_dateChosen(String date, String time);

  /// The allowed range for a date capsule (REQ-CAP-01).
  ///
  /// In en, this message translates to:
  /// **'Any day from a week to five years from now.'**
  String get capsules_dateHelp;

  /// Heading inside the date picker.
  ///
  /// In en, this message translates to:
  /// **'It opens at 10:00 that day'**
  String get capsules_datePickerHelp;

  /// How a mood capsule opens (REQ-CAP-02).
  ///
  /// In en, this message translates to:
  /// **'It can open from 24 hours after sealing, the next time you check in feeling this.'**
  String get capsules_feelingHelp;

  /// Choice: any mood of a quadrant, e.g. 'Any Storm feeling'.
  ///
  /// In en, this message translates to:
  /// **'Any {quadrant} feeling'**
  String capsules_anyQuadrant(String quadrant);

  /// The chosen trigger (a mood name, or 'Any Storm feeling').
  ///
  /// In en, this message translates to:
  /// **'Waits for: {feeling}'**
  String capsules_feelingChosen(String feeling);

  /// Seals the capsule (content can't change after this).
  ///
  /// In en, this message translates to:
  /// **'Seal it'**
  String get capsules_seal;

  /// Seal tapped with nothing inside. Calm.
  ///
  /// In en, this message translates to:
  /// **'Add a few words, a voice note or a photo first.'**
  String get capsules_needContent;

  /// Seal tapped without a date or feeling.
  ///
  /// In en, this message translates to:
  /// **'Choose when it should open.'**
  String get capsules_needUnlock;

  /// Sealing failed locally (e.g. storage). Nothing is lost.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t seal just now. Your capsule is still here. Try again.'**
  String get capsules_sealFailed;

  /// Heading after sealing.
  ///
  /// In en, this message translates to:
  /// **'Sealed'**
  String get capsules_sealedTitle;

  /// After sealing a mood capsule.
  ///
  /// In en, this message translates to:
  /// **'Sealed. It\'ll wait for that feeling.'**
  String get capsules_sealedFeeling;

  /// Sealed while offline, or media still uploading (PRD 14-states 'media upload failed').
  ///
  /// In en, this message translates to:
  /// **'Sealed and safe on this phone. Photos and voice back up when you\'re online.'**
  String get capsules_mediaLater;

  /// A 4th mood-trigger capsule (REQ-CAP-04, PRD 14-states). No paywall: offers a date instead.
  ///
  /// In en, this message translates to:
  /// **'Free accounts keep 3 mood capsules waiting. Date capsules are unlimited.'**
  String get capsules_limitBody;

  /// Switches a 4th mood capsule to a date capsule.
  ///
  /// In en, this message translates to:
  /// **'Pick a date instead'**
  String get capsules_limitPickDate;

  /// A mood capsule the server couldn't keep (limit): choose a date for it.
  ///
  /// In en, this message translates to:
  /// **'Make it a date capsule'**
  String get capsules_makeDate;

  /// Leaving the composer with something written.
  ///
  /// In en, this message translates to:
  /// **'Keep this draft?'**
  String get capsules_leaveTitle;

  /// Under 'Keep this draft?'.
  ///
  /// In en, this message translates to:
  /// **'It stays on this phone until you seal it or let it go.'**
  String get capsules_leaveBody;

  /// Stay in the composer (default, focused).
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get capsules_leaveEditing;

  /// Leave; the draft stays on this phone.
  ///
  /// In en, this message translates to:
  /// **'Keep draft'**
  String get capsules_leaveKeep;

  /// Leave and delete the draft.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get capsules_leaveDiscard;

  /// A sealed mood capsule's page (in the app only, never on the lock screen).
  ///
  /// In en, this message translates to:
  /// **'Waiting for a feeling: {feeling}.'**
  String capsules_detailFeeling(String feeling);

  /// A mood capsule sealed less than 24 hours ago. date = day and time it arms.
  ///
  /// In en, this message translates to:
  /// **'It can open from {date}.'**
  String capsules_detailArming(String date);

  /// Why there is no 'open' button on a sealed capsule.
  ///
  /// In en, this message translates to:
  /// **'Sealed means sealed: it can\'t be opened early or changed.'**
  String get capsules_detailNoEarly;

  /// Deletes a capsule (never shows its content).
  ///
  /// In en, this message translates to:
  /// **'Delete capsule'**
  String get capsules_delete;

  /// Confirmation before deleting.
  ///
  /// In en, this message translates to:
  /// **'Delete this capsule?'**
  String get capsules_deleteTitle;

  /// Deleting a sealed capsule.
  ///
  /// In en, this message translates to:
  /// **'It will be gone for good, without being opened.'**
  String get capsules_deleteBody;

  /// Deleting an opened capsule.
  ///
  /// In en, this message translates to:
  /// **'It will be gone for good.'**
  String get capsules_deleteBodyOpened;

  /// Confirms the deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get capsules_deleteConfirm;

  /// Cancels the deletion (default, focused).
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get capsules_deleteKeep;

  /// After a capsule was deleted.
  ///
  /// In en, this message translates to:
  /// **'Capsule deleted.'**
  String get capsules_deleted;

  /// Card after a check-in that matched a mood capsule (PRD 12-notifications, in-app only).
  ///
  /// In en, this message translates to:
  /// **'You left a note for a moment like this. Open now or later?'**
  String get capsules_triggerTitle;

  /// After the support sheet, when a capsule matched a crisis-flagged check-in (F4 crisis collision rule). Gentle; 'Later' is fine.
  ///
  /// In en, this message translates to:
  /// **'A note from past you is waiting. Open now, or later?'**
  String get capsules_holdTitle;

  /// Open the capsule now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get capsules_now;

  /// Keep it for later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get capsules_later;

  /// Home card and the local notification when a date capsule unlocks (PRD 12-notifications). Never a title, date or mood.
  ///
  /// In en, this message translates to:
  /// **'Something you sealed is ready to open.'**
  String get capsules_readyTitle;

  /// Home card when several date capsules are ready.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capsule is ready.} other{{count} capsules are ready.}}'**
  String capsules_readyMore(int count);

  /// Opens a capsule (Home card, a capsule's page, the hard-moment note).
  ///
  /// In en, this message translates to:
  /// **'Open it'**
  String get capsules_readyOpen;

  /// Android notification channel name (Settings).
  ///
  /// In en, this message translates to:
  /// **'Capsules'**
  String get capsules_channelName;

  /// The one notification re-ask, after sealing a date capsule (PRD 15-permissions). Only 'Allow' shows the OS prompt.
  ///
  /// In en, this message translates to:
  /// **'Want to know when it opens?'**
  String get capsules_notifyAskTitle;

  /// Under 'Want to know when it opens?'. Must promise: one note, nothing about the content on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'One quiet note on the day it opens. Nothing on your lock screen says what\'s inside.'**
  String get capsules_notifyAskBody;

  /// Android notification channel description.
  ///
  /// In en, this message translates to:
  /// **'When something you sealed is ready to open.'**
  String get capsules_channelDescription;

  /// Before opening a capsule sealed during a hard moment (PRD F4). A help button sits with it.
  ///
  /// In en, this message translates to:
  /// **'You wrote this during a hard moment. Open when you\'re ready.'**
  String get capsules_hardMoment;

  /// Skips the opening animation.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get capsules_skip;

  /// Screen-reader label of the short opening animation.
  ///
  /// In en, this message translates to:
  /// **'Opening your capsule'**
  String get capsules_opening;

  /// Heading of an opened capsule.
  ///
  /// In en, this message translates to:
  /// **'From past you'**
  String get capsules_openedTitle;

  /// Re-arms a mood capsule so it can open again for the same feeling.
  ///
  /// In en, this message translates to:
  /// **'Keep for next time'**
  String get capsules_keepNextTime;

  /// After 'Keep for next time'.
  ///
  /// In en, this message translates to:
  /// **'It\'ll wait for that feeling again.'**
  String get capsules_keptNextTime;

  /// Opened offline; the voice note is only on the server (PRD 14-states).
  ///
  /// In en, this message translates to:
  /// **'Your capsule is open. The voice note arrives when you\'re back online.'**
  String get capsules_voiceOffline;

  /// Opened offline; the photos are only on the server.
  ///
  /// In en, this message translates to:
  /// **'The photos arrive when you\'re back online.'**
  String get capsules_photosOffline;

  /// A capsule photo or voice note failed to load. Calm.
  ///
  /// In en, this message translates to:
  /// **'This couldn\'t be loaded just now. Try again in a moment.'**
  String get capsules_mediaFailed;

  /// Retries loading capsule media.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get capsules_retry;

  /// The data key isn't on this phone yet (new phone, offline).
  ///
  /// In en, this message translates to:
  /// **'This capsule can\'t be read on this phone yet. It opens once you\'re back online.'**
  String get capsules_cantRead;

  /// Delete-account confirmation: sealed (unopened) capsules that deletion removes (PRD F4 edge cases).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sealed capsule will be lost.} other{{count} sealed capsules will be lost.}}'**
  String capsules_accountDeletionCount(int count);

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

  /// Support sheet subtitle after a crisis-lexicon match while sealing a time capsule. The capsule still sealed.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry it alone. Your capsule is sealed.'**
  String get help_crisisSubtitleCapsule;

  /// Closes the support sheet and returns to the sealed capsule.
  ///
  /// In en, this message translates to:
  /// **'Back to my capsule'**
  String get help_backToCapsule;

  /// Room: at large text sizes the gesture tray is this one button; it opens all eight gestures in a sheet. Never 'chat'.
  ///
  /// In en, this message translates to:
  /// **'Send warmth'**
  String get rooms_trayOpen;

  /// Rooms tab: one-line link that opens the short explanation, shown once you have joined a room.
  ///
  /// In en, this message translates to:
  /// **'How rooms work'**
  String get rooms_howRoomsWork;

  /// Report sheet: helper text above 'Send report' while no reason is chosen yet (the button stays off until then). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Pick what\'s happening'**
  String get rooms_reportPickReason;

  /// Sky themes: shown instead of a greyed 'Use Stardust' button when the balance is too low. {count} = the sky's cost, {have} = the person's balance. A count, never money; no pressure.
  ///
  /// In en, this message translates to:
  /// **'Needs {count} Stardust (you have {have})'**
  String plus_skyStardustNeeds(int count, int have);

  /// Settings › Account row that opens the data export (REQ-ACC-12).
  ///
  /// In en, this message translates to:
  /// **'Download a copy of my data'**
  String get export_settingsRow;

  /// Title of the export screen.
  ///
  /// In en, this message translates to:
  /// **'A copy of your data'**
  String get export_title;

  /// What the export holds (REQ-ACC-12: own check-ins, habits, capsules, purchases). Sealed capsules are never opened by it.
  ///
  /// In en, this message translates to:
  /// **'A copy of what\'s in your Aura: check-ins and notes, habits, capsules you\'ve opened, your account details, purchases, Stardust and keepsakes. Sealed capsules stay sealed: only their titles and dates are listed.'**
  String get export_body;

  /// Where the copy goes (nothing is uploaded or linked).
  ///
  /// In en, this message translates to:
  /// **'It\'s made on this phone and goes only where you choose to save or send it.'**
  String get export_where;

  /// Media are not part of the copy (they stay playable in the app).
  ///
  /// In en, this message translates to:
  /// **'Voice notes and photos stay in the app; the copy lists when you made them.'**
  String get export_media;

  /// Privacy warning before making the copy (mood notes are sensitive).
  ///
  /// In en, this message translates to:
  /// **'The files aren\'t encrypted. Keep them somewhere private.'**
  String get export_private;

  /// Button that builds the export and opens the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Make my copy'**
  String get export_make;

  /// While the export is built (PRD 14 'Loading export').
  ///
  /// In en, this message translates to:
  /// **'Packing up your data…'**
  String get export_busy;

  /// After the share sheet opened with the files.
  ///
  /// In en, this message translates to:
  /// **'Your copy is ready.'**
  String get export_done;

  /// PRD 14 'Error: export failed or offline'. Nothing is lost.
  ///
  /// In en, this message translates to:
  /// **'The export didn\'t finish. It needs a connection to add your account details. Try again when you\'re connected.'**
  String get export_failed;

  /// Subject / text the share sheet gets with the files.
  ///
  /// In en, this message translates to:
  /// **'My Aura data'**
  String get export_shareText;

  /// HTML export: page title.
  ///
  /// In en, this message translates to:
  /// **'Your Aura data'**
  String get export_hTitle;

  /// HTML export: when the copy was made.
  ///
  /// In en, this message translates to:
  /// **'Made on {date}'**
  String export_hExported(String date);

  /// HTML export: section heading.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get export_hCheckIns;

  /// HTML export: section heading.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get export_hHabits;

  /// HTML export: section heading.
  ///
  /// In en, this message translates to:
  /// **'Capsules'**
  String get export_hCapsules;

  /// HTML export: section heading (profile, Plus, purchases, Stardust, keepsakes).
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get export_hAccount;

  /// HTML export: the person's own reflections still stored.
  ///
  /// In en, this message translates to:
  /// **'Your reflections'**
  String get export_hReflections;

  /// HTML export: content-free Sanctuary session records (same words as the Sanctuary tab).
  ///
  /// In en, this message translates to:
  /// **'Sanctuary'**
  String get export_hSanctuary;

  /// HTML export: a capsule that is still sealed (no content).
  ///
  /// In en, this message translates to:
  /// **'Sealed'**
  String get export_sealed;

  /// HTML export: a check-in or capsule had a voice note (kept in the app).
  ///
  /// In en, this message translates to:
  /// **'voice note'**
  String get export_voiceNote;

  /// HTML export: an empty section.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get export_nothing;

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

  /// Title of the full screen shown when the signed-in account was closed by a moderator. Calm, factual, no blame.
  ///
  /// In en, this message translates to:
  /// **'This account is closed'**
  String get closed_title;

  /// The only explanation shown (PRD wording). Never add a reason, a category or who reported it.
  ///
  /// In en, this message translates to:
  /// **'This account was closed for breaking Aura\'s rules.'**
  String get closed_body;

  /// How to appeal (one appeal per action, resolved in 7 days, PRD F9). Warm, no promise of the outcome.
  ///
  /// In en, this message translates to:
  /// **'If you think this is a mistake, you can ask for a review. We reply within 7 days.'**
  String get closed_review;

  /// Row that writes an email to the Grievance Officer (name and address shown under it).
  ///
  /// In en, this message translates to:
  /// **'Ask for a review'**
  String get closed_askReview;

  /// Email subject pre-filled when asking for a review. Nothing about the person is added.
  ///
  /// In en, this message translates to:
  /// **'Review of a closed account'**
  String get closed_reviewSubject;

  /// Above the 'Delete my account' button on the closed screen (deletion always stays available).
  ///
  /// In en, this message translates to:
  /// **'You can still delete your account and everything in it.'**
  String get closed_deleteNote;

  /// Small note under the actions: what Sign out does on this phone.
  ///
  /// In en, this message translates to:
  /// **'Signing out clears this account from this phone.'**
  String get closed_signOutNote;

  /// In-app notice when the 'rooms are open' push arrives while the app is open (the same line as the push; the person tapped 'Tell me when they open'). Never a mood or a room name.
  ///
  /// In en, this message translates to:
  /// **'Hindi and Hinglish rooms are open now.'**
  String get notif_roomsPoolBanner;

  /// Action on the 'rooms are open' notice: opens Rooms.
  ///
  /// In en, this message translates to:
  /// **'See rooms'**
  String get notif_roomsPoolAction;

  /// Android notification channel name for room notices (phone Settings; PRD 15-permissions).
  ///
  /// In en, this message translates to:
  /// **'Rooms & Lantern Hour'**
  String get notif_channelRooms;

  /// Android notification channel description (phone Settings).
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour, warmth from your room, and rooms you asked about.'**
  String get notif_channelRoomsDescription;

  /// Title of the in-app grievance form (Settings › Help & Safety, the closed-account and banned-device screens).
  ///
  /// In en, this message translates to:
  /// **'Contact the Grievance Officer'**
  String get grievance_title;

  /// Intro of the grievance form when no officer name is configured.
  ///
  /// In en, this message translates to:
  /// **'Tell us about a complaint, content that worries you, your data, or a decision about your account. You get a ticket number right away.'**
  String get grievance_intro;

  /// Intro of the grievance form with the officer's name (from the build's AURA_GRIEVANCE_NAME).
  ///
  /// In en, this message translates to:
  /// **'{name} is Aura\'s Grievance Officer. Tell us about a complaint, content that worries you, your data, or a decision about your account. You get a ticket number right away.'**
  String grievance_introNamed(String name);

  /// Heading over the category choices of the grievance form.
  ///
  /// In en, this message translates to:
  /// **'What is it about?'**
  String get grievance_categoryTitle;

  /// Grievance category `general` (complaint about content or conduct; resolved within 7 days).
  ///
  /// In en, this message translates to:
  /// **'Something someone posted or did'**
  String get grievance_catGeneral;

  /// Grievance category `unlawful_content` (36 h).
  ///
  /// In en, this message translates to:
  /// **'Content that may be unlawful'**
  String get grievance_catUnlawful;

  /// Grievance category `nudity_csam` (2 h, pages the officer 24x7). Plain, factual wording.
  ///
  /// In en, this message translates to:
  /// **'Nudity, sexual content or child sexual abuse material'**
  String get grievance_catNudity;

  /// Grievance category `ncii` (2 h, pages the officer 24x7).
  ///
  /// In en, this message translates to:
  /// **'Intimate images shared without consent'**
  String get grievance_catNcii;

  /// Grievance category `data_request` (7 days).
  ///
  /// In en, this message translates to:
  /// **'My data or my account'**
  String get grievance_catData;

  /// Grievance category `moderation_appeal` (7 days): the in-app appeal (one appeal per action, PRD F9).
  ///
  /// In en, this message translates to:
  /// **'Ask for a review of a decision'**
  String get grievance_catAppeal;

  /// Label of the grievance description field (10 to 5,000 characters).
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get grievance_descriptionLabel;

  /// Hint in the empty grievance description field.
  ///
  /// In en, this message translates to:
  /// **'A few sentences are enough.'**
  String get grievance_descriptionHint;

  /// Hint in the description field when asking for a review. Never asks the person to explain what they did.
  ///
  /// In en, this message translates to:
  /// **'Which decision, and why it should be looked at again.'**
  String get grievance_appealHint;

  /// Optional field: where the content was.
  ///
  /// In en, this message translates to:
  /// **'Where was it? (optional)'**
  String get grievance_whereLabel;

  /// Hint in the optional 'where' field.
  ///
  /// In en, this message translates to:
  /// **'For example: a room, a reflection, or roughly when'**
  String get grievance_whereHint;

  /// Label of the email field (pre-filled with the account's address when signed in).
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get grievance_emailLabel;

  /// Helper under the email field.
  ///
  /// In en, this message translates to:
  /// **'We send the acknowledgement and our reply here. Nobody else sees it.'**
  String get grievance_emailHelp;

  /// Optional name field.
  ///
  /// In en, this message translates to:
  /// **'Your name (optional)'**
  String get grievance_nameLabel;

  /// Button that sends the grievance.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get grievance_send;

  /// Statutory timelines under the Send button (IT Rules 2021). Facts only.
  ///
  /// In en, this message translates to:
  /// **'We acknowledge within 24 hours and resolve within 7 days. Nudity, sexual content involving a child, and intimate images shared without consent are handled within 2 hours.'**
  String get grievance_timelines;

  /// Sending failed with no connection. The form keeps everything.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection. Your words are still here.'**
  String get grievance_offline;

  /// 429 from the grievance form (per-client or global hourly limit).
  ///
  /// In en, this message translates to:
  /// **'A lot of messages came from here in the last hour. Your words are still here; please try again later.'**
  String get grievance_rateLimited;

  /// 400 from the grievance form.
  ///
  /// In en, this message translates to:
  /// **'Please check the email address and add a little more detail (at least 10 characters).'**
  String get grievance_checkFields;

  /// Any other failure of the grievance form.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Your words are still here. Try again?'**
  String get grievance_failed;

  /// Shown on a build without an API (the email row in Settings still works).
  ///
  /// In en, this message translates to:
  /// **'The form isn\'t available in this version. You can still write to the Grievance Officer by email.'**
  String get grievance_noApi;

  /// Title after the grievance was filed (this screen is the acknowledgement).
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get grievance_sentTitle;

  /// The ticket id (e.g. GRV-7K2M9Q4D), selectable.
  ///
  /// In en, this message translates to:
  /// **'Your ticket: {ticket}'**
  String grievance_ticket(String ticket);

  /// Under the ticket: the resolve-by date (from the server, by category) and where the emailed copy goes.
  ///
  /// In en, this message translates to:
  /// **'We\'ll reply by {date} at the latest. A copy of this acknowledgement is on its way to {email}.'**
  String grievance_sentBody(String date, String email);

  /// The statutory appeal route (IT Rules 2021, Rule 3A) [LEGAL wording to confirm].
  ///
  /// In en, this message translates to:
  /// **'If you\'re not satisfied with the reply, you can appeal to the Grievance Appellate Committee at gac.gov.in within 30 days.'**
  String get grievance_gac;

  /// Settings › Help & Safety row that opens the in-app grievance form.
  ///
  /// In en, this message translates to:
  /// **'Write to the Grievance Officer'**
  String get set_grievanceForm;

  /// Subtitle of the Settings row that opens the grievance form.
  ///
  /// In en, this message translates to:
  /// **'In the app, with a ticket number right away'**
  String get set_grievanceFormNote;

  /// Row on the closed-account and banned-device screens that opens the grievance form as an appeal.
  ///
  /// In en, this message translates to:
  /// **'Ask for a review in the app'**
  String get closed_askReviewInApp;

  /// Subtitle of the in-app review row.
  ///
  /// In en, this message translates to:
  /// **'You get a ticket number right away.'**
  String get closed_askReviewInAppNote;

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

  /// Title of the Insights tab: the person's check-in history drawn as a night sky. 'Aura Sky' is a brand name.
  ///
  /// In en, this message translates to:
  /// **'Aura Sky'**
  String get insights_title;

  /// Privacy line under the sky: patterns are computed on the device and never uploaded (PRD F10).
  ///
  /// In en, this message translates to:
  /// **'Only you can see your sky. It\'s worked out on this phone.'**
  String get insights_private;

  /// Empty Insights (no check-ins yet): a quiet sky and a Check in button (PRD F10 edge cases, 14-states).
  ///
  /// In en, this message translates to:
  /// **'Your sky fills in as you check in.'**
  String get insights_empty;

  /// Button that opens the full private list of check-ins (history), with edit and delete.
  ///
  /// In en, this message translates to:
  /// **'All check-ins'**
  String get insights_allCheckIns;

  /// Sky view switch: one month of days.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get insights_viewMonth;

  /// Sky view switch: a whole year of days.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get insights_viewYear;

  /// Button (icon, screen-reader label) that shows the month before.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get insights_prevMonth;

  /// Button (icon, screen-reader label) that shows the month after.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get insights_nextMonth;

  /// Button (icon, screen-reader label) that shows the year before.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get insights_prevYear;

  /// Button (icon, screen-reader label) that shows the year after.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get insights_nextYear;

  /// Screen-reader label of a day with no check-in. Neutral: an inactive day is plain sky, never 'missed'.
  ///
  /// In en, this message translates to:
  /// **'{date}, quiet sky'**
  String insights_dayEmpty(String date);

  /// Screen-reader label of a rest day (a faint ring in the sky).
  ///
  /// In en, this message translates to:
  /// **'{date}, a rest day'**
  String insights_dayRest(String date);

  /// Screen-reader label of a day whose most frequent quadrant is {quadrant} (Storm, Rain, Moonlight or Sunrise).
  ///
  /// In en, this message translates to:
  /// **'{date}, {quadrant}, {count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String insights_daySingle(String date, String quadrant, int count);

  /// Screen-reader label of a mixed day: two quadrants tied (a split star).
  ///
  /// In en, this message translates to:
  /// **'{date}, {first} and {second} equally, {count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String insights_dayPair(String date, String first, String second, int count);

  /// Screen-reader label of a mixed day: three or four quadrants tied (a split star).
  ///
  /// In en, this message translates to:
  /// **'{date}, an even mix, {count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String insights_dayMixed(String date, int count);

  /// Screen-reader hint on a day with check-ins.
  ///
  /// In en, this message translates to:
  /// **'Shows this day\'s check-ins'**
  String get insights_dayHint;

  /// Day sheet for a day without check-ins. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Nothing was logged this day. The sky was just quiet.'**
  String get insights_dayNone;

  /// Screen-reader label of one month in the year view; tapping it opens that month.
  ///
  /// In en, this message translates to:
  /// **'{month}, {count, plural, =0{a quiet sky} =1{1 day checked in} other{{count} days checked in}}'**
  String insights_monthSemantic(String month, int count);

  /// Sky legend: the faint ring.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get insights_legendRest;

  /// Sky legend: the split star (quadrants tied that day).
  ///
  /// In en, this message translates to:
  /// **'Mixed day'**
  String get insights_legendMixed;

  /// Section title: plain-language patterns from the person's own check-ins.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get insights_patternsTitle;

  /// Under the Patterns title on Free: the window the patterns come from.
  ///
  /// In en, this message translates to:
  /// **'From your last 30 days'**
  String get insights_patternsLast30;

  /// Shown instead of patterns while there are fewer than 7 check-ins in the window (PRD F10, REQ-INS-01: '6/7').
  ///
  /// In en, this message translates to:
  /// **'Patterns appear after 7 check-ins ({count}/7)'**
  String insights_patternsNeedCheckIns(int count);

  /// Shown when there are 7+ check-ins but on fewer than 5 different days (REQ-INS-01 negative).
  ///
  /// In en, this message translates to:
  /// **'Patterns appear after check-ins on 5 different days ({count}/5)'**
  String insights_patternsNeedDays(int count);

  /// Enough check-ins, but nothing passes the thresholds (weak patterns are hidden, not caveated).
  ///
  /// In en, this message translates to:
  /// **'No clear patterns right now. Your sky is still here.'**
  String get insights_patternsNone;

  /// A pattern: check-ins carrying tag {tag} were {quadrant} more often than others. Descriptive only, never 'because'. {quadrant} = Storm/Rain/Moonlight/Sunrise. One whole template: never split or concatenate.
  ///
  /// In en, this message translates to:
  /// **'When you tagged {tag}, {quadrant} showed up more often.'**
  String insights_patternTag(String tag, String quadrant);

  /// A pattern (Aura Plus): on days the habit was done, check-ins were {quadrant} more often. Descriptive only, never causal.
  ///
  /// In en, this message translates to:
  /// **'On days you did {habit}, {quadrant} showed up more often.'**
  String insights_patternHabit(String habit, String quadrant);

  /// A pattern: morning check-ins (04:00–12:00) were {quadrant} more often than the rest of the day.
  ///
  /// In en, this message translates to:
  /// **'In the mornings, {quadrant} showed up more often.'**
  String insights_patternMorning(String quadrant);

  /// A pattern: afternoon check-ins (12:00–17:00) were {quadrant} more often.
  ///
  /// In en, this message translates to:
  /// **'In the afternoons, {quadrant} showed up more often.'**
  String insights_patternAfternoon(String quadrant);

  /// A pattern: evening check-ins (17:00–21:00) were {quadrant} more often.
  ///
  /// In en, this message translates to:
  /// **'In the evenings, {quadrant} showed up more often.'**
  String insights_patternEvening(String quadrant);

  /// A pattern: late check-ins (21:00–04:00) were {quadrant} more often.
  ///
  /// In en, this message translates to:
  /// **'At night, {quadrant} showed up more often.'**
  String insights_patternNight(String quadrant);

  /// A pattern: the most frequent quadrant in the window. Same warmth for every quadrant.
  ///
  /// In en, this message translates to:
  /// **'{quadrant} showed up most often in your sky.'**
  String insights_patternMix(String quadrant);

  /// Small label on an Insights extra that comes with Aura Plus (brand name).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus'**
  String get insights_plusBadge;

  /// Locked note under the patterns on Free (PRD F10: Plus gates depth only; REQ-INS-05). Calm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Any range and habits alongside moods come with Aura Plus. Your sky and 30-day patterns are always free.'**
  String get insights_rangeLocked;

  /// Screen-reader label of the range picker (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'Patterns from'**
  String get insights_rangeLabel;

  /// Range choice (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get insights_range7;

  /// Range choice.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get insights_range30;

  /// Range choice (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get insights_range90;

  /// Range choice (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get insights_range365;

  /// Range choice (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get insights_rangeAll;

  /// Weekly insight card title, shown on the first Aura day of the week in Insights only (never pushed). The body is one pattern sentence.
  ///
  /// In en, this message translates to:
  /// **'From your past week'**
  String get insights_weeklyTitle;

  /// Hides the weekly card until next week.
  ///
  /// In en, this message translates to:
  /// **'Hide for this week'**
  String get insights_weeklyHide;

  /// Care card when most recent check-ins were Storm or Rain (PRD F10 literal). Shown in Insights only, never pushed. Warm, never diagnostic.
  ///
  /// In en, this message translates to:
  /// **'It\'s been a heavy couple of weeks'**
  String get insights_careTitle;

  /// Care card body. No pressure, no labels.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry it alone. Support and a room are here whenever you want them.'**
  String get insights_careBody;

  /// Care card button: opens the support sheet (helplines, grounding).
  ///
  /// In en, this message translates to:
  /// **'See support'**
  String get insights_careSupport;

  /// Care card button: opens Rooms.
  ///
  /// In en, this message translates to:
  /// **'Find a room'**
  String get insights_careRoom;

  /// Title of the monthly recap, shown from the first Aura day of each month (PRD F10).
  ///
  /// In en, this message translates to:
  /// **'Your month in stars'**
  String get insights_monthTitle;

  /// Monthly recap card body; month = e.g. 'October 2026'.
  ///
  /// In en, this message translates to:
  /// **'{month} in your sky'**
  String insights_monthCardBody(String month);

  /// Opens the monthly recap.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get insights_monthOpen;

  /// Hides the monthly recap card until next month.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get insights_monthHide;

  /// Recap: distinct days with a check-in in that month.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day checked in} other{{count} days checked in}}'**
  String insights_monthDays(int count);

  /// Recap: heading of the quadrant mix drawn as a sky.
  ///
  /// In en, this message translates to:
  /// **'Your skies this month'**
  String get insights_monthMixTitle;

  /// Recap legend row (glyph + name + count), also read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'{quadrant}: {count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String insights_monthMixItem(String quadrant, int count);

  /// Screen-reader label of the recap's drawn sky.
  ///
  /// In en, this message translates to:
  /// **'A sky of {count, plural, =1{1 star} other{{count} stars}}, one for each check-in in {month}'**
  String insights_monthSkySemantic(int count, String month);

  /// Section of the recap with patterns across the month and habit × mood (Aura Plus).
  ///
  /// In en, this message translates to:
  /// **'Deeper monthly review'**
  String get insights_deeperTitle;

  /// Locked note on Free (PRD 14-states: blurred deeper chart, basic sky stays free).
  ///
  /// In en, this message translates to:
  /// **'Patterns across the month, with habits alongside moods, come with Aura Plus.'**
  String get insights_deeperLocked;

  /// Plus recap: nothing passed the thresholds for that month.
  ///
  /// In en, this message translates to:
  /// **'No clear patterns this month.'**
  String get insights_deeperNone;

  /// Section title: lifetime stats (free).
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get insights_statsTitle;

  /// Lifetime stat: check-ins (not deleted).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String insights_statsCheckIns(int count);

  /// Lifetime stat: distinct days with a check-in.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day in your sky} other{{count} days in your sky}}'**
  String insights_statsDays(int count);

  /// Title of Look back: the person's sky from the same week a month, six months and a year ago. Pull-only, inside Insights.
  ///
  /// In en, this message translates to:
  /// **'Look back'**
  String get insights_lookBackTitle;

  /// Body of the Look back entry in Insights (the only way in). Calm, no pull or urgency.
  ///
  /// In en, this message translates to:
  /// **'Your sky from the same week, a while back. Open it when you want to.'**
  String get insights_lookBackTileBody;

  /// Intro line at the top of Look back. Privacy: worked out on the device, never uploaded.
  ///
  /// In en, this message translates to:
  /// **'The same week a month, six months and a year ago. Only you can see this. It stays on this phone.'**
  String get insights_lookBackIntro;

  /// Heading of the Look back week from one month ago. Words, not digits.
  ///
  /// In en, this message translates to:
  /// **'A month ago'**
  String get insights_lookBackMonth;

  /// Heading of the Look back week from six months ago. Words, not digits.
  ///
  /// In en, this message translates to:
  /// **'Six months ago'**
  String get insights_lookBackSixMonths;

  /// Heading of the Look back week from a year ago. Words, not digits.
  ///
  /// In en, this message translates to:
  /// **'A year ago'**
  String get insights_lookBackYear;

  /// Under a Look back heading: the week's first day, e.g. 'Week of 7 Sep 2026'.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String insights_lookBackWeekOf(String date);

  /// Look back with no week to show (new account, or no check-ins those weeks). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Nothing to look back on yet. Weeks you checked in will appear here.'**
  String get insights_lookBackEmpty;

  /// Shown in place of Look back if it closes while open (e.g. after help was opened). Never says why.
  ///
  /// In en, this message translates to:
  /// **'Look back is closed for now.'**
  String get insights_lookBackClosed;

  /// Further tap on a Look back entry that opens its private note (notes never show on the first tap).
  ///
  /// In en, this message translates to:
  /// **'Show note'**
  String get insights_lookBackShowNote;

  /// Further tap on a Look back entry that has only a voice note: shows its player.
  ///
  /// In en, this message translates to:
  /// **'Show voice note'**
  String get insights_lookBackShowVoice;

  /// Closes the note / voice note of a Look back entry again.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get insights_lookBackHideNote;

  /// Footer of Look back (PRD F10: it can be hidden in Settings).
  ///
  /// In en, this message translates to:
  /// **'You can turn Look back off in Settings.'**
  String get insights_lookBackSettingsHint;

  /// Settings › Comfort switch: show Look back inside Insights (on by default).
  ///
  /// In en, this message translates to:
  /// **'Look back in Aura Sky'**
  String get insights_lookBackSetting;

  /// Under the Look back switch in Settings.
  ///
  /// In en, this message translates to:
  /// **'Past weeks of your sky, only when you open them. Never sent to you as a notification.'**
  String get insights_lookBackSettingNote;

  /// Lifetime stat in Insights only: the longest glow streak so far. Never framed as a record to beat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Longest glow streak · 1 day} other{Longest glow streak · {count} days}}'**
  String insights_statsLongest(int count);

  /// Title of the private keepsake box (earned-only seals from small moments).
  ///
  /// In en, this message translates to:
  /// **'Keepsakes'**
  String get keepsakes_title;

  /// Keepsake box intro. Private, calm.
  ///
  /// In en, this message translates to:
  /// **'Small moments, kept. Only you can see these.'**
  String get keepsakes_intro;

  /// Keepsake box with no seals yet. No hint of what to do or what comes next.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Keepsakes arrive on their own, from small moments along the way.'**
  String get keepsakes_empty;

  /// Footer of the keepsake box: they are never visible to strangers.
  ///
  /// In en, this message translates to:
  /// **'Keepsakes are never shown to anyone else. One leaves your phone only if you share its card.'**
  String get keepsakes_privateNote;

  /// Under a seal in the private box: the day it was earned (a localized date).
  ///
  /// In en, this message translates to:
  /// **'Kept on {date}'**
  String keepsakes_keptOn(String date);

  /// Screen-reader label of one seal in the box.
  ///
  /// In en, this message translates to:
  /// **'{line}, kept on {date}'**
  String keepsakes_sealSemantic(String line, String date);

  /// Button on a keepsake: open its share card.
  ///
  /// In en, this message translates to:
  /// **'Share this card'**
  String get keepsakes_shareThis;

  /// Button in the keepsake box: share a card of the avatar's current stage.
  ///
  /// In en, this message translates to:
  /// **'Share your Aura'**
  String get keepsakes_shareAura;

  /// Keepsake box while offline (the box itself still shows).
  ///
  /// In en, this message translates to:
  /// **'New keepsakes arrive when you\'re back online.'**
  String get keepsakes_offline;

  /// Entry row to the private keepsake box (Settings › Account, Insights).
  ///
  /// In en, this message translates to:
  /// **'Your keepsakes'**
  String get keepsakes_entry;

  /// Subtitle of the keepsake box entry row.
  ///
  /// In en, this message translates to:
  /// **'Seals from small moments, private to you.'**
  String get keepsakes_entryNote;

  /// Home card title: a seal was just earned (shows once).
  ///
  /// In en, this message translates to:
  /// **'A new keepsake'**
  String get keepsakes_newTitle;

  /// Home card when more than one seal arrived at once (no count).
  ///
  /// In en, this message translates to:
  /// **'New keepsakes are in your box.'**
  String get keepsakes_newSeveral;

  /// Home card button: open the private box.
  ///
  /// In en, this message translates to:
  /// **'See your keepsakes'**
  String get keepsakes_newOpen;

  /// Screen-reader label of the close button on a Home card.
  ///
  /// In en, this message translates to:
  /// **'Hide this card'**
  String get keepsakes_hideCard;

  /// Keepsake line: the first capsule sealed.
  ///
  /// In en, this message translates to:
  /// **'Sealed a note for future me'**
  String get keepsake_capsuleSealedFirst;

  /// Keepsake line: the first capsule opened (PRD example).
  ///
  /// In en, this message translates to:
  /// **'Opened a capsule from past me'**
  String get keepsake_capsuleOpenedFirst;

  /// Keepsake and share-card line: lifetime glow days (7, 30, 100, 365). Never a streak.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day of glow} other{{days} days of glow}}'**
  String keepsake_glowDays(int days);

  /// Keepsake line: the first Breath Ripples session.
  ///
  /// In en, this message translates to:
  /// **'Breathed together for the first time'**
  String get keepsake_ripplesFirst;

  /// Keepsake line: the first Lantern Hour spent in a room.
  ///
  /// In en, this message translates to:
  /// **'My first Lantern Hour'**
  String get keepsake_lanternFirst;

  /// Keepsake line: 10 and 50 Lantern Hours spent in rooms.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 evening of Lantern Hour} other{{count} evenings of Lantern Hour}}'**
  String keepsake_lanternHours(int count);

  /// Keepsake line: 60, 300 and 1,000 minutes of Sanctuary activities.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 quiet minute in Sanctuary} other{{minutes} quiet minutes in Sanctuary}}'**
  String keepsake_sanctuaryMinutes(int minutes);

  /// Share-card line: an avatar evolution stage (the stage name).
  ///
  /// In en, this message translates to:
  /// **'My Aura reached {stage}'**
  String share_evolutionLine(String stage);

  /// Share-card line: a capsule anniversary (PRD example). No date.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{Sealed a capsule 1 year ago} other{Sealed a capsule {years} years ago}}'**
  String share_anniversaryLine(int years);

  /// Small store line at the foot of every share card.
  ///
  /// In en, this message translates to:
  /// **'Aura · App Store and Google Play'**
  String get share_storeLine;

  /// Text sent with the card image through the share sheet (the store link). Never about the person.
  ///
  /// In en, this message translates to:
  /// **'Aura, a quiet place to notice how you feel: {link}'**
  String share_text(String link);

  /// Title of the share-card preview sheet.
  ///
  /// In en, this message translates to:
  /// **'Share a card'**
  String get share_sheetTitle;

  /// Under the card preview: what a card can and can't show.
  ///
  /// In en, this message translates to:
  /// **'The card shows your Aura and this moment. Never your moods, notes or name.'**
  String get share_sheetNote;

  /// Button: open the system share sheet with the card.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share_button;

  /// The card image could not be made (e.g. low memory). No blame.
  ///
  /// In en, this message translates to:
  /// **'The card couldn\'t be made just now. Please try again.'**
  String get share_failed;

  /// Screen-reader label of the share-card preview.
  ///
  /// In en, this message translates to:
  /// **'Card to share: {line}. Your Aura at the {stage} stage.'**
  String share_cardSemantic(String line, String stage);

  /// Home share prompt (offered once per milestone): an evolution stage.
  ///
  /// In en, this message translates to:
  /// **'Your Aura reached {stage}. Share a card of it?'**
  String share_promptEvolution(String stage);

  /// Home share prompt: a lifetime glow-day milestone. Never shown while 'hide streak number' is on.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day of glow.} other{{days} days of glow.}} Share a card of it?'**
  String share_promptGlow(int days);

  /// Home share prompt: a capsule anniversary.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{You sealed your first capsule a year ago.} other{You sealed your first capsule {years} years ago.}} Share a card of it?'**
  String share_promptAnniversary(int years);

  /// Room card title: the room's shared lantern (lit together during Lantern Hour).
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s lantern'**
  String get rooms_lanternTitle;

  /// Room lantern during Lantern Hour, not lit yet. Invitation, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Every gesture here adds a little light.'**
  String get rooms_lanternStart;

  /// Room lantern during Lantern Hour, partly lit. Never a count or a score.
  ///
  /// In en, this message translates to:
  /// **'It glows brighter with every gesture here.'**
  String get rooms_lanternGlowing;

  /// Room lantern fully lit (all levels).
  ///
  /// In en, this message translates to:
  /// **'Fully lit, together.'**
  String get rooms_lanternFull;

  /// After Lantern Hour and in the room memory: the level the lantern reached. PRD 14-states copy; never 'failed', 'missed' or 'almost'.
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s lantern glowed this bright.'**
  String get rooms_lanternKept;

  /// Screen-reader label for the room lantern (a room total).
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s lantern, {level} of {max} lights lit'**
  String rooms_lanternSemantic(int level, int max);

  /// The one shared moment when the room's lantern becomes fully lit (announced; shown as a line under Reduce Motion).
  ///
  /// In en, this message translates to:
  /// **'The lantern is fully lit. Lanterns rise, together.'**
  String get rooms_lanternRise;

  /// Room card title: one preset intention the room can hold together during Lantern Hour.
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s intention'**
  String get rooms_intentionTitle;

  /// Button: hold tonight's intention (one tap, can't be undone). No pressure.
  ///
  /// In en, this message translates to:
  /// **'Hold this tonight'**
  String get rooms_intentionHold;

  /// After you held tonight's intention (only you see this).
  ///
  /// In en, this message translates to:
  /// **'You\'re holding this tonight'**
  String get rooms_intentionHolding;

  /// The room total holding tonight's intention (never who).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Hold it with one tap} =1{1 holding this tonight} other{{count} holding this tonight}}'**
  String rooms_intentionHolds(int count);

  /// After Lantern Hour: how many held tonight's intention. No failure copy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Resting until the next Lantern Hour} =1{1 held this tonight} other{{count} held this tonight}}'**
  String rooms_intentionHeld(int count);

  /// Under tonight's intention: holders are never named; no follow-up.
  ///
  /// In en, this message translates to:
  /// **'Nobody sees who holds it, and nobody will ask about it tomorrow.'**
  String get rooms_intentionPrivate;

  /// Holding tonight's intention failed (connection, or the hour ended). No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again.'**
  String get rooms_intentionFailed;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'Sleep before midnight'**
  String get rooms_intention_sleep_before_midnight;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'Be gentle with myself tonight'**
  String get rooms_intention_gentle_with_myself;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'Phone down for 10 minutes'**
  String get rooms_intention_phone_down_10;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'A glass of water before bed'**
  String get rooms_intention_water_before_bed;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'One kind thought about today'**
  String get rooms_intention_one_kind_thought;

  /// Tonight's intention preset (first person, gentle, never a goal to fail).
  ///
  /// In en, this message translates to:
  /// **'Three slow breaths before sleep'**
  String get rooms_intention_slow_breaths;

  /// In-app notice when the daily check-in reminder arrives while the app is open (same line as the push, PRD 12-notifications catalogue). Never guilt, never a streak.
  ///
  /// In en, this message translates to:
  /// **'A quiet minute for you. How\'s today feeling?'**
  String get notif_reminderBanner;

  /// Action on the reminder notice: opens the check-in.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get notif_reminderAction;

  /// In-app notice when a date capsule's push arrives while the app is open (PRD catalogue line). Never a title, date or mood.
  ///
  /// In en, this message translates to:
  /// **'Something you sealed is ready to open.'**
  String get notif_capsuleBanner;

  /// Action on the capsule notice: opens the capsules.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notif_capsuleAction;

  /// Android notification channel name for the daily check-in reminder (phone Settings).
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notif_channelReminders;

  /// Android notification channel description (phone Settings).
  ///
  /// In en, this message translates to:
  /// **'Your check-in, wind-down and habit reminders.'**
  String get notif_channelRemindersDescription;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get set_notifications;

  /// Master switch for every push.
  ///
  /// In en, this message translates to:
  /// **'Notifications from Aura'**
  String get set_notifMaster;

  /// Under the master switch: the daily cap and the privacy promise (PRD 12 rules 2 and 3). Calm.
  ///
  /// In en, this message translates to:
  /// **'At most two a day. Nothing on your lock screen says how you feel.'**
  String get set_notifMasterNote;

  /// Switch for the daily reminder push.
  ///
  /// In en, this message translates to:
  /// **'Daily check-in reminder'**
  String get set_notifReminder;

  /// Under the reminder switch when on; {time} is the chosen time, e.g. '8:00 PM'.
  ///
  /// In en, this message translates to:
  /// **'One gentle nudge a day, at {time}. Skipped once you\'ve checked in.'**
  String set_notifReminderNote(String time);

  /// Under the reminder switch when off.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn it on for one gentle nudge a day.'**
  String get set_notifReminderOffNote;

  /// Row that opens the time picker for the daily reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get set_notifReminderTime;

  /// Switch for the 'date capsule unlocked' push.
  ///
  /// In en, this message translates to:
  /// **'A capsule is ready to open'**
  String get set_notifCapsule;

  /// Under the capsule switch.
  ///
  /// In en, this message translates to:
  /// **'On the day you chose for something you sealed.'**
  String get set_notifCapsuleNote;

  /// Quiet hours explainer; {start}/{end} are times like '11:00 PM'.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours: nothing is sent {start}–{end}.'**
  String set_notifQuietNote(String start, String end);

  /// Row: start of quiet hours (opens a time picker).
  ///
  /// In en, this message translates to:
  /// **'Quiet from'**
  String get set_notifQuietFrom;

  /// Row: end of quiet hours (opens a time picker).
  ///
  /// In en, this message translates to:
  /// **'Quiet until'**
  String get set_notifQuietUntil;

  /// Switch: every push shows only a generic line (PRD rule 4).
  ///
  /// In en, this message translates to:
  /// **'Discreet mode'**
  String get set_notifDiscreet;

  /// Under the discreet switch; quotes the discreet line.
  ///
  /// In en, this message translates to:
  /// **'Every notification just says “Aura · You have a gentle update”.'**
  String get set_notifDiscreetNote;

  /// Calm note when the OS permission is off (PRD 15-permissions). No blame.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Aura on this phone. Your choices here still apply once they\'re on.'**
  String get set_notifOffNote;

  /// Button in the off note: shows the phone's notification prompt.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get set_notifTurnOn;

  /// Button in the off note: opens this app's page in the phone's Settings.
  ///
  /// In en, this message translates to:
  /// **'Open phone settings'**
  String get set_notifOpenSettings;

  /// Dialog title: the chosen reminder time falls inside quiet hours (one-time confirmation, PRD rule 1).
  ///
  /// In en, this message translates to:
  /// **'This time is inside your quiet hours'**
  String get set_notifQuietConfirmTitle;

  /// Dialog body; {start}/{end} quiet hours, {time} the reminder time.
  ///
  /// In en, this message translates to:
  /// **'Aura stays silent {start}–{end}. Send your reminder at {time} anyway?'**
  String set_notifQuietConfirmBody(String start, String end, String time);

  /// Dialog: keep the reminder inside quiet hours (night shifts).
  ///
  /// In en, this message translates to:
  /// **'Send it anyway'**
  String get set_notifQuietConfirmYes;

  /// Dialog: don't send inside quiet hours.
  ///
  /// In en, this message translates to:
  /// **'Keep it quiet'**
  String get set_notifQuietConfirmNo;

  /// On the notification explainer: when the daily nudge comes; {time} e.g. '8:00 PM'.
  ///
  /// In en, this message translates to:
  /// **'Every evening at {time}'**
  String push_timeRow(String time);

  /// Opens the time picker on the explainer.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get push_changeTime;

  /// Checkbox on the explainer: discreet mode (PRD 12 rule 4, a one-tap choice on the permission screen). The line under it quotes the discreet text.
  ///
  /// In en, this message translates to:
  /// **'Keep them discreet'**
  String get push_discreet;

  /// In-app notice when the 'gestures received' push arrives while the app is open. Never a pseudonym, count of gestures, theme or mood.
  ///
  /// In en, this message translates to:
  /// **'People in your room sent you warmth.'**
  String get notif_gesturesBanner;

  /// Action on the gestures notice: opens that room.
  ///
  /// In en, this message translates to:
  /// **'Open room'**
  String get notif_gesturesAction;

  /// In-app notice when the Lantern Hour push arrives while the app is open (PRD catalogue line).
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour is on. Others are here tonight.'**
  String get notif_lanternBanner;

  /// Action on the Lantern Hour notice: opens Rooms.
  ///
  /// In en, this message translates to:
  /// **'See rooms'**
  String get notif_lanternAction;

  /// In-app notice for the wind-down reminder (PRD line). Never promises better sleep (REQ-NTF-04).
  ///
  /// In en, this message translates to:
  /// **'A few quiet minutes before sleep, whenever you want them.'**
  String get notif_windDownBanner;

  /// Action on the wind-down notice: opens Sanctuary › Sounds (nothing plays until a tap).
  ///
  /// In en, this message translates to:
  /// **'Open Sounds'**
  String get notif_windDownAction;

  /// In-app notice for a habit nudge. Never a habit's name.
  ///
  /// In en, this message translates to:
  /// **'A small habit or two, whenever you\'re ready.'**
  String get notif_habitBanner;

  /// Action on the habit nudge notice: opens Home.
  ///
  /// In en, this message translates to:
  /// **'See habits'**
  String get notif_habitAction;

  /// Crisis follow-up (PRD 12): an in-app card on the next open 12–72 h after the support sheet showed. Never a push, never mentions distress or what happened.
  ///
  /// In en, this message translates to:
  /// **'Just checking in. However today feels, help is one tap away.'**
  String get notif_crisisFollowUp;

  /// Closes the follow-up card (it doesn't come back for this time).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get notif_crisisFollowUpDismiss;

  /// Switch: the 'gestures received' push (batched).
  ///
  /// In en, this message translates to:
  /// **'Warmth from your room'**
  String get set_notifGestures;

  /// Under the gestures switch.
  ///
  /// In en, this message translates to:
  /// **'When people in your room send you a gesture. One a day at most.'**
  String get set_notifGesturesNote;

  /// Switch: the opt-in Lantern Hour push.
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour'**
  String get set_notifLantern;

  /// Under the Lantern Hour switch (region clock, around 9 pm).
  ///
  /// In en, this message translates to:
  /// **'When Lantern Hour starts in your evening. Not if you\'ve already been in a room that day.'**
  String get set_notifLanternNote;

  /// Switch: the opt-in wind-down reminder (REQ-NTF-04).
  ///
  /// In en, this message translates to:
  /// **'Wind-down reminder'**
  String get set_notifWindDown;

  /// Under the wind-down switch when on; {time} e.g. '10:30 PM'. No sleep promise.
  ///
  /// In en, this message translates to:
  /// **'A few quiet minutes at {time}. Not sent once you\'ve used Sanctuary that evening.'**
  String set_notifWindDownNote(String time);

  /// Under the wind-down switch when off.
  ///
  /// In en, this message translates to:
  /// **'Off. Pick a time for a quiet nudge before sleep.'**
  String get set_notifWindDownOffNote;

  /// Row that opens the time picker for the wind-down reminder.
  ///
  /// In en, this message translates to:
  /// **'Wind-down time'**
  String get set_notifWindDownTime;

  /// Switch: the 'welcome back' push.
  ///
  /// In en, this message translates to:
  /// **'After a quiet while'**
  String get set_notifWelcomeBack;

  /// Under the welcome-back switch. No guilt.
  ///
  /// In en, this message translates to:
  /// **'If you\'ve been away a week or more, one gentle hello. Twice at most.'**
  String get set_notifWelcomeBackNote;

  /// Sub-heading: per-habit nudge times (opt-in).
  ///
  /// In en, this message translates to:
  /// **'Habit nudges'**
  String get set_notifHabits;

  /// Under the habit nudges heading.
  ///
  /// In en, this message translates to:
  /// **'A small nudge at a time you pick, for any habit on Home. One a day at most.'**
  String get set_notifHabitsNote;

  /// Habit nudges when there are no active habits.
  ///
  /// In en, this message translates to:
  /// **'Add a habit on Home to get a nudge for it.'**
  String get set_notifHabitsNone;

  /// Trailing value of a habit row without a nudge.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get set_notifHabitOff;

  /// Under a habit nudge whose time is inside quiet hours.
  ///
  /// In en, this message translates to:
  /// **'Inside your quiet hours, so it won\'t be sent.'**
  String get set_notifHabitQuiet;

  /// Dialog action on a habit with a nudge.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get set_notifHabitChange;

  /// Dialog action: remove this habit's nudge.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get set_notifHabitTurnOff;

  /// On the night wind-down card: turns on the opt-in wind-down reminder (asks for a time first). {time} e.g. '10:30 PM'.
  ///
  /// In en, this message translates to:
  /// **'Remind me at {time}'**
  String sounds_windDownRemind(String time);

  /// On the wind-down card when the reminder is on.
  ///
  /// In en, this message translates to:
  /// **'A gentle reminder comes at {time}.'**
  String sounds_windDownReminderOn(String time);

  /// Turns the wind-down reminder off from the card.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get sounds_windDownReminderOff;

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

  /// Name of the optional subscription (brand, never translated).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus'**
  String get plus_title;

  /// Paywall intro. Plus is 'more of', never 'better calm'.
  ///
  /// In en, this message translates to:
  /// **'More of what you already have. Everything that helps you feel better stays free.'**
  String get plus_intro;

  /// Paywall section header: what the subscription adds.
  ///
  /// In en, this message translates to:
  /// **'Plus adds'**
  String get plus_addsTitle;

  /// Plus perk (free keeps 3 waiting).
  ///
  /// In en, this message translates to:
  /// **'Unlimited mood-trigger capsules'**
  String get plus_addCapsules;

  /// Plus perk (free: 2 minutes).
  ///
  /// In en, this message translates to:
  /// **'Voice up to 10 minutes in a capsule'**
  String get plus_addVoice;

  /// Plus perk.
  ///
  /// In en, this message translates to:
  /// **'Deeper Insights: any range, habit × mood, the deeper month in stars'**
  String get plus_addInsights;

  /// Plus perk: extra Sounds stems and themes.
  ///
  /// In en, this message translates to:
  /// **'Extra sounds and two Plus skies'**
  String get plus_addSounds;

  /// Paywall section header: what never needs Plus.
  ///
  /// In en, this message translates to:
  /// **'Always free'**
  String get plus_freeTitle;

  /// The never-paywalled list (PRD F12).
  ///
  /// In en, this message translates to:
  /// **'Check-ins, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Breathe, grounding, Today\'s minute, every base sound and the night wind-down.'**
  String get plus_freeBody;

  /// Plan choice.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get plus_planMonthly;

  /// Plan choice.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get plus_planAnnual;

  /// Headline price line when the store account can get the free month. {price} is the store's own localized price.
  ///
  /// In en, this message translates to:
  /// **'1 month free, then {price}/month'**
  String plus_trialLineMonthly(String price);

  /// Headline for the yearly plan with the free month.
  ///
  /// In en, this message translates to:
  /// **'1 month free, then {price}/year'**
  String plus_trialLineAnnual(String price);

  /// Plain price (no free month on this store account).
  ///
  /// In en, this message translates to:
  /// **'{price}/month'**
  String plus_priceMonthly(String price);

  /// Plain yearly price.
  ///
  /// In en, this message translates to:
  /// **'{price}/year'**
  String plus_priceAnnual(String price);

  /// Trial end date on the paywall ({date} is formatted).
  ///
  /// In en, this message translates to:
  /// **'Your free month ends on {date}. The first charge is on {date} unless you cancel before then.'**
  String plus_trialEnds(String date);

  /// Auto-renew disclosure (App Review 3.1.2).
  ///
  /// In en, this message translates to:
  /// **'Renews automatically until you cancel. Paid through your {store} account.'**
  String plus_renews(String store);

  /// How to cancel on iOS (no retention screen).
  ///
  /// In en, this message translates to:
  /// **'To cancel: iPhone Settings › your name › Subscriptions › Aura. Cancel at least a day before a charge.'**
  String get plus_cancelApple;

  /// How to cancel on Android.
  ///
  /// In en, this message translates to:
  /// **'To cancel: Play Store › your profile › Payments & subscriptions › Subscriptions › Aura.'**
  String get plus_cancelGoogle;

  /// Store name (brand).
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get plus_storeApple;

  /// Store name (brand).
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get plus_storeGoogle;

  /// Buy button when the free month applies.
  ///
  /// In en, this message translates to:
  /// **'Start free month'**
  String get plus_startTrial;

  /// Buy button without the free month.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get plus_subscribe;

  /// Restore button (Apple 3.1.1).
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get plus_restore;

  /// Opens the store's own subscription page.
  ///
  /// In en, this message translates to:
  /// **'Manage in store'**
  String get plus_manage;

  /// Screen-reader label for the price skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading prices from the store'**
  String get plus_loadingPrices;

  /// PRD 14-states.
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t reachable right now. Nothing was charged.'**
  String get plus_storeUnavailable;

  /// Retry button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get plus_retry;

  /// While NestJS confirms with the store (PRD 14-states).
  ///
  /// In en, this message translates to:
  /// **'Confirming with the store…'**
  String get plus_confirming;

  /// PRD 14-states pending confirmation.
  ///
  /// In en, this message translates to:
  /// **'The store has your request. Plus unlocks the moment it\'s confirmed. You can close this.'**
  String get plus_confirmingLater;

  /// PRD 14-states validation failed. Never asks to pay again.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm this yet. If you were charged, it\'s safe. We\'ll keep checking.'**
  String get plus_validationFailed;

  /// UPI mandate / Ask to Buy pending (PRD).
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval. You won\'t be charged until it goes through.'**
  String get plus_pendingApproval;

  /// PRD 14-states declined.
  ///
  /// In en, this message translates to:
  /// **'Payment didn\'t go through. You weren\'t charged.'**
  String get plus_declined;

  /// After the server confirmed the purchase.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus is on. Thank you.'**
  String get plus_welcome;

  /// Restore / buy found a purchase linked to another Aura account.
  ///
  /// In en, this message translates to:
  /// **'This purchase belongs to another Aura account on this store account, so it stays there.'**
  String get plus_ownedElsewhere;

  /// After Restore purchases.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to restore on this store account.} =1{1 purchase restored.} other{{count} purchases restored.}}'**
  String plus_restored(int count);

  /// The only line shown where an offer isn't appropriate (after a hard check-in, in a crisis flow). PRD copy.
  ///
  /// In en, this message translates to:
  /// **'Part of Aura Plus'**
  String get plus_lockedOnly;

  /// Small link to the paywall (the person chooses).
  ///
  /// In en, this message translates to:
  /// **'About Aura Plus'**
  String get plus_about;

  /// Button on a limit explainer.
  ///
  /// In en, this message translates to:
  /// **'See Aura Plus'**
  String get plus_seePlus;

  /// Reminder under a limit explainer that a free path exists.
  ///
  /// In en, this message translates to:
  /// **'The free way stays right here.'**
  String get plus_freePath;

  /// 4th mood-trigger capsule explainer (14-states).
  ///
  /// In en, this message translates to:
  /// **'Free accounts keep 3 mood capsules waiting. Aura Plus keeps as many as you like. Date capsules are always unlimited.'**
  String get plus_explainerCapsules;

  /// Long voice explainer.
  ///
  /// In en, this message translates to:
  /// **'Voice in a capsule stops at 2 minutes on free Aura, 10 minutes with Aura Plus.'**
  String get plus_explainerVoice;

  /// Plus Sounds stem explainer.
  ///
  /// In en, this message translates to:
  /// **'This sound comes with Aura Plus. Every base sound and the night wind-down stay free.'**
  String get plus_explainerSounds;

  /// Deeper Insights explainer.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus adds any range, habit × mood and the deeper month. Your sky and history stay free.'**
  String get plus_explainerInsights;

  /// Plus sky explainer.
  ///
  /// In en, this message translates to:
  /// **'This sky comes with Aura Plus.'**
  String get plus_explainerSky;

  /// Settings Plus card, no Plus.
  ///
  /// In en, this message translates to:
  /// **'You\'re on free Aura.'**
  String get plus_statusFree;

  /// 14-states 'Trial active'.
  ///
  /// In en, this message translates to:
  /// **'Free month: {days, plural, =0{ends today} =1{1 day left} other{{days} days left}}. First charge on {date}.'**
  String plus_statusTrial(int days, String date);

  /// 14-states 'Trial cancelled'.
  ///
  /// In en, this message translates to:
  /// **'Your free month stays on until {date}. After that you\'re on free Aura, and everything you made stays yours.'**
  String plus_statusTrialCancelled(String date);

  /// Active, auto-renew on.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus renews on {date}.'**
  String plus_statusActive(String date);

  /// Active, auto-renew off.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus stays on until {date}. You won\'t be charged again.'**
  String plus_statusCancelled(String date);

  /// 14-states billing retry, in grace.
  ///
  /// In en, this message translates to:
  /// **'The store couldn\'t renew Aura Plus. Plus stays on while it tries again.'**
  String get plus_statusGrace;

  /// 14-states after grace.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus is paused until the store can renew it. Everything you made stays yours.'**
  String get plus_statusBillingRetry;

  /// Lapsed (PRD: nothing made is lost).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus has ended. Everything you made stays yours.'**
  String get plus_statusExpired;

  /// 14-states refunded.
  ///
  /// In en, this message translates to:
  /// **'Your refund went through, so Aura Plus has ended. Everything you made stays yours.'**
  String get plus_statusRefunded;

  /// Pending purchase.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the store to confirm. You won\'t be charged until it goes through.'**
  String get plus_statusPending;

  /// 14-states billing retry action.
  ///
  /// In en, this message translates to:
  /// **'Update payment in store'**
  String get plus_updatePayment;

  /// 14-states trial cancelled action (opens the store page).
  ///
  /// In en, this message translates to:
  /// **'Turn Plus back on'**
  String get plus_turnBackOn;

  /// Plus bought on the other platform (PRD edge case).
  ///
  /// In en, this message translates to:
  /// **'Bought on {store}. Manage it there.'**
  String plus_managedElsewhere(String store);

  /// Settings card in the first 24 h (no offer yet).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus opens up a day after you join. Everything you need is already free.'**
  String get plus_notYet;

  /// Quiet Home card, last 2 days of the trial (at most once a day).
  ///
  /// In en, this message translates to:
  /// **'Your free month ends on {date}. Plus then continues at {price}/month unless you cancel in the store.'**
  String plus_cardTrialEnding(String date, String price);

  /// Same, yearly plan.
  ///
  /// In en, this message translates to:
  /// **'Your free month ends on {date}. Plus then continues at {price}/year unless you cancel in the store.'**
  String plus_cardTrialEndingYear(String date, String price);

  /// Same, when no store price was captured.
  ///
  /// In en, this message translates to:
  /// **'Your free month ends on {date}. Plus then continues unless you cancel in the store.'**
  String plus_cardTrialEndingNoPrice(String date);

  /// Dismisses the trial card (14-states).
  ///
  /// In en, this message translates to:
  /// **'Keep Plus'**
  String get plus_cardKeep;

  /// One-time note when auto-renew is off in the trial (PRD 12).
  ///
  /// In en, this message translates to:
  /// **'Plus stays on until {date}. You won\'t be charged.'**
  String plus_cardTrialCancelled(String date);

  /// In-app banner only (PRD 12 'Billing issue').
  ///
  /// In en, this message translates to:
  /// **'Your Aura Plus payment didn\'t go through. Everything you\'ve made is safe.'**
  String get plus_cardBillingIssue;

  /// One small note after the trial converts (14-states).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus continues. Thank you.'**
  String get plus_cardContinues;

  /// Close a notice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get plus_dismiss;

  /// Gift name (₹10).
  ///
  /// In en, this message translates to:
  /// **'Warm Tea'**
  String get plus_giftWarmTea;

  /// Gift name (₹29).
  ///
  /// In en, this message translates to:
  /// **'Comfort Lantern'**
  String get plus_giftComfortLantern;

  /// Gift name (₹49).
  ///
  /// In en, this message translates to:
  /// **'Encouragement Bouquet'**
  String get plus_giftBouquet;

  /// What the recipient sees (PRD). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone here sent you a {gift}.'**
  String plus_giftReceived(String gift);

  /// Stardust the gift brought.
  ///
  /// In en, this message translates to:
  /// **'+{count} Stardust'**
  String plus_giftStardust(int count);

  /// Gift sheet title.
  ///
  /// In en, this message translates to:
  /// **'Send a gift'**
  String get plus_giftTitle;

  /// Gift sheet body: what the recipient sees.
  ///
  /// In en, this message translates to:
  /// **'They\'ll see “Someone here sent you a gift” and get Stardust for a sky. No message and no name.'**
  String get plus_giftBody;

  /// Gift buy button with the store price.
  ///
  /// In en, this message translates to:
  /// **'Send for {price}'**
  String plus_giftSend(String price);

  /// After the store and server confirmed a gift.
  ///
  /// In en, this message translates to:
  /// **'Sent. They\'ll see it the next time they open Aura.'**
  String get plus_giftSent;

  /// Pre-check refused (never says why).
  ///
  /// In en, this message translates to:
  /// **'This gift can\'t be sent right now. Nothing was charged.'**
  String get plus_giftUnavailable;

  /// Daily cap reached (pre-check).
  ///
  /// In en, this message translates to:
  /// **'That\'s 5 gifts today. You can send more tomorrow.'**
  String get plus_giftDailyLimit;

  /// Gifting paused / disabled / sanctioned (calm, no detail).
  ///
  /// In en, this message translates to:
  /// **'Gifts aren\'t available on this account right now.'**
  String get plus_giftPaused;

  /// Kill switch gifts_enabled off.
  ///
  /// In en, this message translates to:
  /// **'Gifts are resting for a bit. Nothing was charged.'**
  String get plus_giftsOff;

  /// Stardust balance (a count, never money).
  ///
  /// In en, this message translates to:
  /// **'{count} Stardust'**
  String plus_stardustBalance(int count);

  /// What Stardust is.
  ///
  /// In en, this message translates to:
  /// **'Stardust comes only from gifts people send you. It can\'t be bought, cashed or moved.'**
  String get plus_stardustNote;

  /// Personal sky themes screen title (Settings).
  ///
  /// In en, this message translates to:
  /// **'Your sky'**
  String get plus_skiesTitle;

  /// Intro: personal only, never shown to others.
  ///
  /// In en, this message translates to:
  /// **'A sky for your own Home, Sanctuary and Insights. Only you see it.'**
  String get plus_skiesIntro;

  /// Sky name (free).
  ///
  /// In en, this message translates to:
  /// **'Night sky'**
  String get plus_skyNight;

  /// Sky name (Plus).
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get plus_skyAurora;

  /// Sky name (Plus).
  ///
  /// In en, this message translates to:
  /// **'Monsoon dusk'**
  String get plus_skyMonsoonDusk;

  /// Sky name (₹10).
  ///
  /// In en, this message translates to:
  /// **'First light'**
  String get plus_skyFirstLight;

  /// Sky name (₹29).
  ///
  /// In en, this message translates to:
  /// **'Lantern festival'**
  String get plus_skyLanternFestival;

  /// Sky name (₹49).
  ///
  /// In en, this message translates to:
  /// **'Deep ocean'**
  String get plus_skyDeepOcean;

  /// Sky name (₹99).
  ///
  /// In en, this message translates to:
  /// **'Meteor shower'**
  String get plus_skyMeteorShower;

  /// Sky tag.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get plus_skyFree;

  /// Sky tag.
  ///
  /// In en, this message translates to:
  /// **'With Aura Plus'**
  String get plus_skyWithPlus;

  /// Sky tag: owned.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get plus_skyOwned;

  /// Sky tag: equipped.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get plus_skyInUse;

  /// Equip button.
  ///
  /// In en, this message translates to:
  /// **'Use this sky'**
  String get plus_skyUse;

  /// Buy a cosmetic sky with the store price.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String plus_skyBuy(String price);

  /// Redeem a sky with Stardust.
  ///
  /// In en, this message translates to:
  /// **'Use {count} Stardust'**
  String plus_skyStardust(int count);

  /// Redeem refused.
  ///
  /// In en, this message translates to:
  /// **'Not enough Stardust for this sky yet.'**
  String get plus_skyNotEnough;

  /// Soundscape pairing section.
  ///
  /// In en, this message translates to:
  /// **'Pair a soundscape'**
  String get plus_soundscapeTitle;

  /// No pairing.
  ///
  /// In en, this message translates to:
  /// **'No sounds'**
  String get plus_soundscapeNone;

  /// Soundscape: night insects + wind.
  ///
  /// In en, this message translates to:
  /// **'Night air'**
  String get plus_soundscapeNightAir;

  /// Soundscape: wind + chimes.
  ///
  /// In en, this message translates to:
  /// **'High wind'**
  String get plus_soundscapeHighWind;

  /// Soundscape: rain + brown noise.
  ///
  /// In en, this message translates to:
  /// **'Monsoon'**
  String get plus_soundscapeMonsoon;

  /// Soundscape: singing bowl + chimes.
  ///
  /// In en, this message translates to:
  /// **'Bells'**
  String get plus_soundscapeBells;

  /// Soundscape: ocean + wind.
  ///
  /// In en, this message translates to:
  /// **'Shore'**
  String get plus_soundscapeShore;

  /// Plays the paired soundscape in Sounds.
  ///
  /// In en, this message translates to:
  /// **'Play these sounds'**
  String get plus_soundscapePlay;

  /// Settings row to the sky screen.
  ///
  /// In en, this message translates to:
  /// **'Your sky and Stardust'**
  String get plus_settingsSky;

  /// Android notification channel (PRD 15-permissions): Aura Plus reminders.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get plus_channelAccount;

  /// Android channel description.
  ///
  /// In en, this message translates to:
  /// **'Aura Plus reminders, like your free month ending.'**
  String get plus_channelAccountDescription;

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

  /// Feature name. Rooms tab card title. Not a PRD 18 brand term: Hindi / Hinglish use their own words.
  ///
  /// In en, this message translates to:
  /// **'Quiet Together'**
  String get quiet_title;

  /// Rooms tab card body: what Quiet Together is. Calm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Study, read or rest alongside others. Just a count, a shared sound and gestures.'**
  String get quiet_cardBody;

  /// Mode button: study together.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get quiet_modeStudy;

  /// Mode button: read together.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get quiet_modeRead;

  /// Mode button: rest together.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get quiet_modeRest;

  /// Screen title for the Study session.
  ///
  /// In en, this message translates to:
  /// **'Study together'**
  String get quiet_titleStudy;

  /// Screen title for the Read session.
  ///
  /// In en, this message translates to:
  /// **'Read together'**
  String get quiet_titleRead;

  /// Screen title for the Rest session.
  ///
  /// In en, this message translates to:
  /// **'Rest together'**
  String get quiet_titleRest;

  /// How many people are in this session right now. A number only, never names.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 here} other{{count} here}}'**
  String quiet_count(int count);

  /// Shown when the count is 1 (never faked). PRD 14-states copy.
  ///
  /// In en, this message translates to:
  /// **'Just you right now. Others drop in through the hour.'**
  String get quiet_justYou;

  /// While joining a session.
  ///
  /// In en, this message translates to:
  /// **'Finding your quiet place…'**
  String get quiet_joining;

  /// Chip when the realtime link dropped. Never a failure; the shared sound keeps playing.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get quiet_reconnecting;

  /// Offline state. PRD 14-states copy.
  ///
  /// In en, this message translates to:
  /// **'Quiet Together needs a connection. Sanctuary works offline.'**
  String get quiet_offline;

  /// Button from the offline / paused state to the Sanctuary tab.
  ///
  /// In en, this message translates to:
  /// **'Open Sanctuary'**
  String get quiet_openSanctuary;

  /// Kill switch on for this region. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Quiet Together is resting for a bit. The Sanctuary is always open.'**
  String get quiet_paused;

  /// The join failed for another reason (not offline). No blame.
  ///
  /// In en, this message translates to:
  /// **'Quiet Together couldn\'t open just now. Please try again.'**
  String get quiet_failed;

  /// Retry button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get quiet_tryAgain;

  /// Near the end of a 60-minute block. A clock time, never a countdown; the next block follows by itself.
  ///
  /// In en, this message translates to:
  /// **'The next session starts at {time}.'**
  String quiet_nextBlock(String time);

  /// Leave the session. Leaving costs nothing: no confirmation, no loss copy.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get quiet_leave;

  /// Small line near Leave: leaving costs nothing.
  ///
  /// In en, this message translates to:
  /// **'Leave whenever you like. Nothing is lost.'**
  String get quiet_leaveNote;

  /// Section title: a soundscape everyone plays on their own phone from the same start.
  ///
  /// In en, this message translates to:
  /// **'The shared sound'**
  String get quiet_soundTitle;

  /// Explains the shared sound: local playback, same point in the mix, no user audio.
  ///
  /// In en, this message translates to:
  /// **'Everyone hears the same moment, played on your own phone. No microphone, nothing recorded.'**
  String get quiet_soundBody;

  /// Button: start the shared sound. Nothing plays until this tap.
  ///
  /// In en, this message translates to:
  /// **'Play the shared sound'**
  String get quiet_soundPlay;

  /// Button: stop the shared sound on this phone.
  ///
  /// In en, this message translates to:
  /// **'Stop the sound'**
  String get quiet_soundStop;

  /// Slider label: this person's own volume for the shared sound.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get quiet_soundVolume;

  /// A base recording isn't on the phone yet. The session works silently meanwhile. PRD 14-states copy.
  ///
  /// In en, this message translates to:
  /// **'The shared sound needs a one-time download.'**
  String get quiet_soundDownload;

  /// Button: download the base recordings.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get quiet_soundDownloadCta;

  /// No stem of the mix can play. Calm.
  ///
  /// In en, this message translates to:
  /// **'The sound can\'t play on this phone right now. Being here is enough.'**
  String get quiet_soundUnavailable;

  /// Switch, off by default: follow the shared 25-minute focus / 5-minute break blocks.
  ///
  /// In en, this message translates to:
  /// **'Focus rhythm (25 / 5)'**
  String get quiet_rhythm;

  /// Under the rhythm switch. No pressure.
  ///
  /// In en, this message translates to:
  /// **'Optional. Everyone\'s breaks line up.'**
  String get quiet_rhythmBody;

  /// Rhythm on, in a focus stretch: the next change as a clock time (never a countdown).
  ///
  /// In en, this message translates to:
  /// **'Focus · break at {time}'**
  String quiet_rhythmFocus(String time);

  /// Rhythm on, in a break: the next change as a clock time.
  ///
  /// In en, this message translates to:
  /// **'Break · focus again at {time}'**
  String quiet_rhythmBreak(String time);

  /// Announced (politely) when the shared break begins.
  ///
  /// In en, this message translates to:
  /// **'Break time.'**
  String get quiet_rhythmToBreak;

  /// Announced (politely) when the shared focus stretch begins.
  ///
  /// In en, this message translates to:
  /// **'Focus time.'**
  String get quiet_rhythmToFocus;

  /// Gesture tray title. Gestures go to the whole session, never to a person.
  ///
  /// In en, this message translates to:
  /// **'Send a gesture to everyone here'**
  String get quiet_gesturesTitle;

  /// Your own gesture, shown only to you.
  ///
  /// In en, this message translates to:
  /// **'You sent {gesture}'**
  String quiet_gestureSent(String gesture);

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone shared warm tea'**
  String get quiet_moment_warm_tea;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone lit a candle'**
  String get quiet_moment_light_a_candle;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone sent a hug'**
  String get quiet_moment_hug;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone said: me too'**
  String get quiet_moment_me_too;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone sent soft rain'**
  String get quiet_moment_soft_rain;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone is stargazing with you'**
  String get quiet_moment_stargaze;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone took a deep breath'**
  String get quiet_moment_deep_breath;

  /// An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.
  ///
  /// In en, this message translates to:
  /// **'Someone says: you\'re not alone'**
  String get quiet_moment_youre_not_alone;

  /// Tooltip for the session's overflow menu.
  ///
  /// In en, this message translates to:
  /// **'Session menu'**
  String get quiet_menu;

  /// Session menu: report (nobody is shown, so there is no per-person block or mute).
  ///
  /// In en, this message translates to:
  /// **'Report a problem here'**
  String get quiet_report;

  /// Session menu: hide gesture animations for yourself only.
  ///
  /// In en, this message translates to:
  /// **'Hide gestures'**
  String get quiet_hideGestures;

  /// Session menu: show gestures again.
  ///
  /// In en, this message translates to:
  /// **'Show gestures'**
  String get quiet_showGestures;

  /// Shown while you hid gestures (only for you).
  ///
  /// In en, this message translates to:
  /// **'Gestures are hidden for you.'**
  String get quiet_gesturesHidden;

  /// Report sheet intro for Quiet Together.
  ///
  /// In en, this message translates to:
  /// **'Nobody is shown here, so tell us what happened. A moderator looks at this session\'s recent gestures.'**
  String get quiet_reportBody;

  /// Optional note field in the report sheet (moderators only).
  ///
  /// In en, this message translates to:
  /// **'Anything else a moderator should know? (optional)'**
  String get quiet_reportNote;

  /// Report sheet button.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get quiet_reportSend;

  /// After a report was sent.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A moderator will take a look.'**
  String get quiet_reportThanks;

  /// Report failed (connection). No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again.'**
  String get quiet_reportFailed;

  /// Room card title and button during Lantern Hour from 22:30: a shared 20-minute wind-down.
  ///
  /// In en, this message translates to:
  /// **'Wind down together'**
  String get rooms_windDownTitle;

  /// Room card body for the wind-down. No narration, no pressure.
  ///
  /// In en, this message translates to:
  /// **'Twenty quiet minutes to end the day: one shared sound, slow breathing and a few gentle words.'**
  String get rooms_windDownBody;

  /// The room total winding down now (never who).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody winding down yet} =1{1 winding down} other{{count} winding down}}'**
  String rooms_windDownCount(int count);

  /// Room card button after you joined the wind-down.
  ///
  /// In en, this message translates to:
  /// **'Back to the wind-down'**
  String get rooms_windDownBack;

  /// Joining the wind-down failed (connection, or it just ended). No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again.'**
  String get rooms_windDownFailed;

  /// When the 20 minutes are over. Never 'finished early' or a score.
  ///
  /// In en, this message translates to:
  /// **'The wind-down has ended. Rest well.'**
  String get rooms_windDownEnded;

  /// Leave the wind-down. Costs nothing.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get rooms_windDownLeave;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Arrive. There\'s nothing to do now.'**
  String get rooms_windDownCue_arrive;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Let the day get quieter.'**
  String get rooms_windDownCue_day_quieter;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Let your shoulders soften.'**
  String get rooms_windDownCue_shoulders;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you right now.'**
  String get rooms_windDownCue_nothing_to_do;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Let each breath be a little slower.'**
  String get rooms_windDownCue_slower;

  /// A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.
  ///
  /// In en, this message translates to:
  /// **'Rest well. The night can hold the rest.'**
  String get rooms_windDownCue_rest_well;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to see who\'s here'**
  String get rooms_presenceStale;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh keepsakes just now. Your saved keepsakes are still here.'**
  String get keepsakes_refreshFailed;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to refresh your keepsakes. Your saved keepsakes are still here.'**
  String get keepsakes_signedOut;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Keepsakes aren\'t available for this account right now. Check your account settings.'**
  String get keepsakes_accountUnavailable;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Keepsake refresh isn\'t set up in this build. Your saved keepsakes are still here.'**
  String get keepsakes_unavailable;

  /// Recovery status or action; preserve cached personal data and avoid claiming live presence.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get keepsakes_accountAction;

  /// Personal universe: title copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Your universe'**
  String get universe_title;

  /// Personal universe: entry copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'A small world for habits, quiet moments and future you.'**
  String get universe_entry;

  /// Personal universe: intro copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'A little care, a little growth. Explore at your own pace.'**
  String get universe_intro;

  /// Personal universe: worldView copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Show 3D world'**
  String get universe_worldView;

  /// Personal universe: listView copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Use list view'**
  String get universe_listView;

  /// Personal universe: grove copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Habit Grove'**
  String get universe_grove;

  /// Personal universe: pool copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Tide Pool'**
  String get universe_pool;

  /// Personal universe: reflection copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Reflection Garden'**
  String get universe_reflection;

  /// Personal universe: observatory copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Observatory'**
  String get universe_observatory;

  /// Personal universe: groveBody copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Each habit is a plant that grows as you log it. Plants you commit to rest when days are missed, and a single log wakes them.'**
  String get universe_groveBody;

  /// Personal universe: poolBody copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Take a quiet breath beside the water. Start only when you are ready.'**
  String get universe_poolBody;

  /// Personal universe: reflectionBody copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Notice how you feel with a private check-in. Your feelings stay in your care space.'**
  String get universe_reflectionBody;

  /// Personal universe: observatoryBody copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Leave a kind message for future you, or return to your time capsules.'**
  String get universe_observatoryBody;

  /// Personal universe: habits copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Open habits'**
  String get universe_habits;

  /// Personal universe: breathe copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Start breathing'**
  String get universe_breathe;

  /// Personal universe: checkIn copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get universe_checkIn;

  /// Personal universe: capsules copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Open time capsules'**
  String get universe_capsules;

  /// Personal universe: left copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get universe_left;

  /// Personal universe: right copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get universe_right;

  /// Personal universe: zoomIn copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get universe_zoomIn;

  /// Personal universe: zoomOut copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get universe_zoomOut;

  /// Personal universe: reset copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Reset camera'**
  String get universe_reset;

  /// Personal universe: hint copy or accessible control label.
  ///
  /// In en, this message translates to:
  /// **'Drag to look around. Tap a light or choose a place below.'**
  String get universe_hint;

  /// Room screen: heading over the reflections (short moderated posts answered only with gestures).
  ///
  /// In en, this message translates to:
  /// **'Reflections'**
  String get reflections_title;

  /// Room screen: one line under the Reflections heading. No replies exist.
  ///
  /// In en, this message translates to:
  /// **'A few words from people here. Answered only with gestures.'**
  String get reflections_intro;

  /// Button that opens the reflection composer.
  ///
  /// In en, this message translates to:
  /// **'Share a reflection'**
  String get reflections_share;

  /// Reflections list is empty. No pressure to write.
  ///
  /// In en, this message translates to:
  /// **'No reflections here yet. You can share one, or just read and send gestures.'**
  String get reflections_empty;

  /// A memory room with no reflections.
  ///
  /// In en, this message translates to:
  /// **'No reflections were shared in this room.'**
  String get reflections_emptyMemory;

  /// Loading reflections failed (server or network). No blame.
  ///
  /// In en, this message translates to:
  /// **'Reflections couldn\'t load just now.'**
  String get reflections_loadFailed;

  /// Offline: the list can't load; drafts are kept.
  ///
  /// In en, this message translates to:
  /// **'Reflections need a connection. Anything you write stays on this phone.'**
  String get reflections_offline;

  /// A memory room: read-only list, no composer.
  ///
  /// In en, this message translates to:
  /// **'This room is a memory: its reflections can be read, not added to.'**
  String get reflections_memory;

  /// Composer paused (kill switch / reduced mode). Contract wording.
  ///
  /// In en, this message translates to:
  /// **'Reflections are resting for a bit. Gestures still work.'**
  String get reflections_paused;

  /// Daily cap reached (3 per room, or 10 across rooms, rolling 24 h). Calm; not a punishment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{That\'s 1 reflection for today. Gestures are always open.} other{That\'s {count} reflections for today. Gestures are always open.}}'**
  String reflections_limit(int count);

  /// The automatic check is degraded: sending may take longer.
  ///
  /// In en, this message translates to:
  /// **'Reflections are slower right now'**
  String get reflections_slow;

  /// Composer / section: reflections left in this room today (rolling 24 h).
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {total} left today'**
  String reflections_left(int remaining, int total);

  /// Screen reader: a reflection card (the text follows).
  ///
  /// In en, this message translates to:
  /// **'Reflection by {pseudonym}'**
  String reflections_cardLabel(String pseudonym);

  /// Label on your own reflection card.
  ///
  /// In en, this message translates to:
  /// **'Your reflection'**
  String get reflections_mine;

  /// Your own reflection that is not published (checking, held, not posted, taken down).
  ///
  /// In en, this message translates to:
  /// **'Only you can see this'**
  String get reflections_onlyYou;

  /// Your reflection is still being checked (moderation took longer than 2 s).
  ///
  /// In en, this message translates to:
  /// **'Still checking. You can keep reading.'**
  String get reflections_pending;

  /// Your reflection is held for a human review (only you see it).
  ///
  /// In en, this message translates to:
  /// **'Waiting for a quick check'**
  String get reflections_heldSoon;

  /// Held overnight (the reviewer's night).
  ///
  /// In en, this message translates to:
  /// **'Waiting for a quick check. This may take until morning.'**
  String get reflections_heldOvernight;

  /// Your own rejected reflection in the list (a reason line follows).
  ///
  /// In en, this message translates to:
  /// **'This one didn\'t go up here.'**
  String get reflections_rejectedCard;

  /// Your own reflection removed after a report was upheld. Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'This one was taken down after a review.'**
  String get reflections_removedCard;

  /// Gestures on your own published reflection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No gestures yet} =1{1 gesture} other{{count} gestures}}'**
  String reflections_gestureCount(int count);

  /// Under the gesture count on your own reflection: counts are never public.
  ///
  /// In en, this message translates to:
  /// **'Only you see this count'**
  String get reflections_countPrivate;

  /// Tooltip / screen reader: the ⋯ menu on a reflection card (report, block, mute, delete).
  ///
  /// In en, this message translates to:
  /// **'Reflection options'**
  String get reflections_options;

  /// Screen-reader hint on a gesture under someone's reflection.
  ///
  /// In en, this message translates to:
  /// **'Sends to {pseudonym} for this reflection'**
  String reflections_gestureHint(String pseudonym);

  /// After sending a gesture on a reflection (announced).
  ///
  /// In en, this message translates to:
  /// **'{gesture} sent to {pseudonym}'**
  String reflections_gestureSent(String gesture, String pseudonym);

  /// Delete your own published reflection (no editing exists).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get reflections_delete;

  /// Withdraw your own reflection while it is checked or held.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get reflections_withdraw;

  /// Delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this reflection?'**
  String get reflections_deleteTitle;

  /// Delete confirmation body.
  ///
  /// In en, this message translates to:
  /// **'It goes away for everyone here. Reflections can\'t be edited, but you can share a new one.'**
  String get reflections_deleteBody;

  /// Withdraw confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this reflection?'**
  String get reflections_withdrawTitle;

  /// Withdraw confirmation body.
  ///
  /// In en, this message translates to:
  /// **'It won\'t go up. You can share a new one any time.'**
  String get reflections_withdrawBody;

  /// After deleting or withdrawing your reflection.
  ///
  /// In en, this message translates to:
  /// **'Your reflection is gone.'**
  String get reflections_deleted;

  /// Report sheet title for a reflection (F9).
  ///
  /// In en, this message translates to:
  /// **'Report this reflection'**
  String get reflections_reportTitle;

  /// After reporting a reflection (it hides for the reporter at once).
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling us. That reflection is hidden for you now.'**
  String get reflections_reportHidden;

  /// Composer sheet title.
  ///
  /// In en, this message translates to:
  /// **'Share a reflection'**
  String get reflections_composeTitle;

  /// Composer text field label. Gentle; no pressure.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get reflections_composeLabel;

  /// Composer helper line.
  ///
  /// In en, this message translates to:
  /// **'A few words for this room. People can answer with gestures only, never replies.'**
  String get reflections_composeNote;

  /// Composer character counter (characters as a person sees them).
  ///
  /// In en, this message translates to:
  /// **'{count}/{max}'**
  String reflections_counter(int count, int max);

  /// Screen reader: the composer's character counter.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} characters'**
  String reflections_counterSemantic(int count, int max);

  /// Composer over the limit (Send is disabled).
  ///
  /// In en, this message translates to:
  /// **'A little shorter, please: up to {max} characters.'**
  String reflections_tooLong(int max);

  /// Composer send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get reflections_send;

  /// Composer while the check takes longer than usual.
  ///
  /// In en, this message translates to:
  /// **'Sending gently…'**
  String get reflections_sending;

  /// On-device block: contact details or a link in the text. Nothing was sent (14-states wording).
  ///
  /// In en, this message translates to:
  /// **'Phone numbers, links and handles can\'t be shared here. It keeps everyone safer.'**
  String get reflections_contactBlocked;

  /// Composer offline: Send is disabled, the text stays on this phone.
  ///
  /// In en, this message translates to:
  /// **'Draft kept. You can send it once you\'re back online.'**
  String get reflections_draftKept;

  /// A send failed (network / server). The draft and its id are kept.
  ///
  /// In en, this message translates to:
  /// **'It didn\'t send just now. Your words are still here: try again in a moment.'**
  String get reflections_sendFailed;

  /// Rejected by the server: contact details (PRD F6 wording). The text stays to edit.
  ///
  /// In en, this message translates to:
  /// **'Reflections can\'t include contact details. Want to try without it?'**
  String get reflections_rejectedContact;

  /// Rejected by the server: a link. The text stays to edit.
  ///
  /// In en, this message translates to:
  /// **'Reflections can\'t include links. Want to try without it?'**
  String get reflections_rejectedLink;

  /// Rejected by the server: personal questions (age, school, where someone lives, photos, meeting). Never names the rule; never mentions anyone's age.
  ///
  /// In en, this message translates to:
  /// **'Questions about someone\'s personal details can\'t go up here. Want to try without them?'**
  String get reflections_rejectedPersonal;

  /// Rejected by the server (hurtful, sexual, other). 14-states wording; no blame.
  ///
  /// In en, this message translates to:
  /// **'This one can\'t go up here. It may hurt someone or share personal details. Your words are still here to edit.'**
  String get reflections_rejectedGeneral;

  /// Support sheet subtitle after a reflection was crisis-diverted (no rejection wording). Safe messaging.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry it alone.'**
  String get reflections_supportSubtitle;

  /// Support sheet button after a crisis-diverted reflection.
  ///
  /// In en, this message translates to:
  /// **'Back to the room'**
  String get reflections_backToRoom;

  /// Settings › Help & Safety switch (REQ-SAFE-16). On by default per the privacy notice.
  ///
  /// In en, this message translates to:
  /// **'Use my reflections to improve safety filters'**
  String get set_corpusTitle;

  /// Explanation under the corpus switch: what is kept (text + decision, no identity) and what turning it off does.
  ///
  /// In en, this message translates to:
  /// **'Reflections you post in rooms, and the decisions about them, can be kept without your name, room or pseudonym to train Aura\'s own safety filters. Turning this off keeps anything you post from now on out.'**
  String get set_corpusNote;

  /// Under the corpus switch when it couldn't load or save (offline, server).
  ///
  /// In en, this message translates to:
  /// **'This choice needs a connection. Nothing has changed.'**
  String get set_corpusOffline;

  /// Title of the full-screen page shown when this phone is banned (403 device_banned, PRD 19 REQ-ADM-14). Calm; never says why (no tipping off).
  ///
  /// In en, this message translates to:
  /// **'This device can\'t use Aura'**
  String get device_bannedTitle;

  /// Body under device_bannedTitle. No reason, no blame.
  ///
  /// In en, this message translates to:
  /// **'Aura isn\'t available on this phone.'**
  String get device_bannedBody;

  /// Email subject when asking for a review of a device ban. Nothing about the person or the phone.
  ///
  /// In en, this message translates to:
  /// **'Review of a device'**
  String get device_bannedReviewSubject;

  /// Shown where rooms are offered while the rooms kill switch is off (flag rooms_enabled, 503 rooms_paused). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Rooms are resting for a bit. Try again later.'**
  String get rooms_paused;

  /// After a check-in, when the rooms kill switch is off.
  ///
  /// In en, this message translates to:
  /// **'Rooms are resting for a bit. Your check-in is saved.'**
  String get rooms_pausedJoin;

  /// Product name of the co-breathing game (brand, never translated).
  ///
  /// In en, this message translates to:
  /// **'Breath Ripples'**
  String get ripples_title;

  /// Home card: start a 3-minute co-breath with a few strangers.
  ///
  /// In en, this message translates to:
  /// **'Breathe together'**
  String get ripples_homeCard;

  /// Under the Home card. Calm; no pressure.
  ///
  /// In en, this message translates to:
  /// **'Three quiet minutes with a few others. No words, no score.'**
  String get ripples_homeCardBody;

  /// Room button: invite the room's live members to a 3-minute co-breath.
  ///
  /// In en, this message translates to:
  /// **'Breathe together'**
  String get ripples_breatheTogether;

  /// In-room banner for 20 s: someone invited the room to Breath Ripples. name = a room pseudonym.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to breathe together · {count}/{capacity}'**
  String ripples_invite(String name, int count, int capacity);

  /// Banner button: join the room's Breath Ripples invite.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get ripples_inviteJoin;

  /// Banner for the person who invited the room.
  ///
  /// In en, this message translates to:
  /// **'Your invite is open · {count}/{capacity}'**
  String ripples_inviteMine(int count, int capacity);

  /// Lobby while matching (at most 20 s). The pacer already runs.
  ///
  /// In en, this message translates to:
  /// **'Looking for others to breathe with…'**
  String get ripples_lobby;

  /// Under the lobby line.
  ///
  /// In en, this message translates to:
  /// **'Breathe along while you wait. You can leave any time.'**
  String get ripples_lobbyHint;

  /// Input hint (hold mode).
  ///
  /// In en, this message translates to:
  /// **'Hold to breathe in, let go to breathe out'**
  String get ripples_holdHint;

  /// Input hint (accessible mode: tap to switch).
  ///
  /// In en, this message translates to:
  /// **'Tap to switch between breathing in and out'**
  String get ripples_tapHint;

  /// Screen-reader label of the large area you hold (or tap) to breathe.
  ///
  /// In en, this message translates to:
  /// **'Breathing area'**
  String get ripples_breathArea;

  /// PRD 14 Offline state.
  ///
  /// In en, this message translates to:
  /// **'Breathing together needs a connection. Breathe solo instead?'**
  String get ripples_offline;

  /// Kill switch on (ripples_paused). Calm.
  ///
  /// In en, this message translates to:
  /// **'Breath Ripples is resting for a bit. Breathe solo instead?'**
  String get ripples_paused;

  /// The account's social access is paused (sanction). Never says why.
  ///
  /// In en, this message translates to:
  /// **'Breathing together is paused for this account right now. You can still breathe on your own.'**
  String get ripples_suspended;

  /// The account is closed (banned).
  ///
  /// In en, this message translates to:
  /// **'This account can\'t breathe together with others. You can still breathe on your own.'**
  String get ripples_closed;

  /// 409 guidelines_required: the guidelines are accepted in Rooms.
  ///
  /// In en, this message translates to:
  /// **'The community guidelines come first. Open Rooms to read them, or breathe on your own for now.'**
  String get ripples_guidelines;

  /// Opens the Sanctuary's Breathe pacer.
  ///
  /// In en, this message translates to:
  /// **'Breathe solo'**
  String get ripples_breatheSolo;

  /// Phase word during the 10 s settle-in before the first breath.
  ///
  /// In en, this message translates to:
  /// **'Settle in'**
  String get ripples_settle;

  /// Phase word during the 10 s fade-out after the last breath.
  ///
  /// In en, this message translates to:
  /// **'Let it fade'**
  String get ripples_fade;

  /// Intro line: the people who started this session (never echoes or guides).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Just you and the ocean} other{{count} people breathing together}}'**
  String ripples_together(int count);

  /// PRD 14: echoes fill empty seats. Honest: they are recordings, never counted as people.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 echo joined. It\'s a recording of a real person who breathed here before.} other{{count} echoes joined. They\'re recordings of real people who breathed here before.}}'**
  String ripples_echoesJoined(int count);

  /// Guide lights fill seats while the echo library is small. Never presented as people.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A guide light breathes with you.} other{{count} guide lights breathe with you.}}'**
  String ripples_guides(int count);

  /// PRD 14: no echoes available; a solo pacer.
  ///
  /// In en, this message translates to:
  /// **'Breathing on your own this time. The ocean still listens.'**
  String get ripples_solo;

  /// PRD 14: the connection dropped; the pacer continues locally. Never an error.
  ///
  /// In en, this message translates to:
  /// **'You\'re breathing on your own for a moment.'**
  String get ripples_linkLost;

  /// After the rejoin window: the session finishes on this phone, gently.
  ///
  /// In en, this message translates to:
  /// **'Keep breathing. The ocean is still here.'**
  String get ripples_alone;

  /// Tooltip of ✕: leave quietly at any time (no penalty, nothing is said to others).
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get ripples_leave;

  /// Toggle: tap to switch, tones and stronger haptics when in step (on automatically with a screen reader).
  ///
  /// In en, this message translates to:
  /// **'Accessible mode'**
  String get ripples_accessibleMode;

  /// Explains accessible mode. Sync is never a number.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch between in and out. Tones and firmer haptics tell you when you\'re in step with the others.'**
  String get ripples_accessibleModeHint;

  /// Screen-reader label of the ocean (the art itself is hidden).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A night ocean with your light} other{A night ocean with {count} lights}}'**
  String ripples_oceanSemantic(int count);

  /// Screen-reader label of your own light.
  ///
  /// In en, this message translates to:
  /// **'Your light'**
  String get ripples_lightMe;

  /// Screen-reader label of another person's light (tap for mute, block, report).
  ///
  /// In en, this message translates to:
  /// **'{name}\'s light'**
  String ripples_lightHuman(String name);

  /// Screen-reader label of an echo light (a recording, never a person here now).
  ///
  /// In en, this message translates to:
  /// **'An echo of someone who breathed here before'**
  String get ripples_lightEcho;

  /// Screen-reader label of a guide light (never a person).
  ///
  /// In en, this message translates to:
  /// **'A guide light, breathing with the pacer'**
  String get ripples_lightGuide;

  /// Tiny label under an echo light.
  ///
  /// In en, this message translates to:
  /// **'echo'**
  String get ripples_echo;

  /// Tiny label under a guide light.
  ///
  /// In en, this message translates to:
  /// **'guide'**
  String get ripples_guide;

  /// Tiny label under your own light.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get ripples_you;

  /// One-tap haptic pulse to everyone in the session.
  ///
  /// In en, this message translates to:
  /// **'Send a pulse'**
  String get ripples_pulse;

  /// In-game gesture.
  ///
  /// In en, this message translates to:
  /// **'Hug'**
  String get ripples_gestureHug;

  /// In-game gesture.
  ///
  /// In en, this message translates to:
  /// **'Deep breath'**
  String get ripples_gestureDeepBreath;

  /// In-game gesture.
  ///
  /// In en, this message translates to:
  /// **'You\'re not alone'**
  String get ripples_gestureNotAlone;

  /// Announced (and shown) when someone pulses.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a pulse'**
  String ripples_pulseFrom(String name);

  /// Shown by a light and announced: who sent which gesture (gesture = its name).
  ///
  /// In en, this message translates to:
  /// **'{name} · {gesture}'**
  String ripples_gestureFrom(String name, String gesture);

  /// Screen-reader label of the pulse + gesture row.
  ///
  /// In en, this message translates to:
  /// **'Send something kind'**
  String get ripples_contactTray;

  /// Stop this light's pulses, gestures and haptics for you, for this session.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get ripples_mute;

  /// Undo mute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get ripples_unmute;

  /// Block this person: never matched again (they aren't told).
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get ripples_block;

  /// Report this person (reasons, optional note).
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get ripples_report;

  /// After block. The other person is never told.
  ///
  /// In en, this message translates to:
  /// **'Blocked. You won\'t be matched together again.'**
  String get ripples_blocked;

  /// After a report.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Someone from Aura will look at it.'**
  String get ripples_reported;

  /// Mute/block/report failed (connection). No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Please try again.'**
  String get ripples_actionFailed;

  /// End screen. Never a score or how well it went.
  ///
  /// In en, this message translates to:
  /// **'That was a few minutes together.'**
  String get ripples_endTitle;

  /// End screen: start another session (same entry).
  ///
  /// In en, this message translates to:
  /// **'Breathe again'**
  String get ripples_again;

  /// End screen (room sessions): back to the room.
  ///
  /// In en, this message translates to:
  /// **'Back to room'**
  String get ripples_backToRoom;

  /// End screen, optional: opens a check-in (F1).
  ///
  /// In en, this message translates to:
  /// **'How do you feel now?'**
  String get ripples_feelNow;

  /// Echo opt-out switch (on by default, per the privacy notice).
  ///
  /// In en, this message translates to:
  /// **'Let my breathing become an echo'**
  String get ripples_echoToggle;

  /// Under the echo switch. Honest about what is kept.
  ///
  /// In en, this message translates to:
  /// **'An echo keeps only the timing of your breaths, never who you are, so it can\'t be traced back to you. Turning this off stops future echoes.'**
  String get ripples_echoToggleHint;

  /// Rooms tab title (mood rooms with preset gestures). Never 'chat'.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms_title;

  /// Heading over the rooms you are in (Rooms tab and the Home strip).
  ///
  /// In en, this message translates to:
  /// **'Your rooms'**
  String get rooms_yourRooms;

  /// Heading over rooms that have become read-only memories (kept 7 days).
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get rooms_memories;

  /// Rooms tab: heading of the short explanation card.
  ///
  /// In en, this message translates to:
  /// **'What rooms are'**
  String get rooms_whatTitle;

  /// Rooms tab: one-line explanation. Calm; never 'chat' or 'strangers'.
  ///
  /// In en, this message translates to:
  /// **'A small room of people who feel like you do right now, for a day.'**
  String get rooms_whatBody;

  /// Rooms tab privacy point: a new pseudonym per room.
  ///
  /// In en, this message translates to:
  /// **'A fresh name in every room. Nobody sees your account.'**
  String get rooms_pointName;

  /// Rooms tab privacy point: gestures only.
  ///
  /// In en, this message translates to:
  /// **'No messages or DMs: only eight warm gestures.'**
  String get rooms_pointGestures;

  /// Rooms tab point: lifetime.
  ///
  /// In en, this message translates to:
  /// **'Rooms last a day, then rest as a memory for 7 days.'**
  String get rooms_pointTime;

  /// Rooms tab: when Lantern Hour happens. No pressure.
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour: every night from 9 to 11 on your region\'s clock, rooms light a shared lantern and more people drop in.'**
  String get rooms_lanternNote;

  /// Label on a room card during Lantern Hour.
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour is on now'**
  String get rooms_lanternNow;

  /// Rooms tab button: rooms are found from a check-in.
  ///
  /// In en, this message translates to:
  /// **'Check in to find a room'**
  String get rooms_checkInCta;

  /// Rooms tab when you are in no room.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in a room right now. After a check-in you can join people who feel the same.'**
  String get rooms_empty;

  /// Rooms tab offline (no call is made).
  ///
  /// In en, this message translates to:
  /// **'Rooms need a connection. Your own check-ins still save on this phone.'**
  String get rooms_offline;

  /// A rooms call failed (server or network). No blame.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the rooms just now.'**
  String get rooms_loadFailed;

  /// Retry a rooms call.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rooms_tryAgain;

  /// Rooms need an account (signed out).
  ///
  /// In en, this message translates to:
  /// **'Rooms open once you\'re signed in.'**
  String get rooms_signedOut;

  /// Button to sign in (rooms need an account).
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get rooms_signIn;

  /// The account's room access is paused (pending review). Calm, no blame.
  ///
  /// In en, this message translates to:
  /// **'Rooms are paused for your account right now. Help is always here.'**
  String get rooms_suspended;

  /// The account's room access is suspended until a date.
  ///
  /// In en, this message translates to:
  /// **'Rooms are paused for your account until {date}. Help is always here.'**
  String rooms_suspendedUntil(String date);

  /// The account was closed by moderation (contract wording).
  ///
  /// In en, this message translates to:
  /// **'This account was closed for breaking Aura\'s rules.'**
  String get rooms_accountClosed;

  /// 409 profile_required: onboarding hasn't reached the server yet.
  ///
  /// In en, this message translates to:
  /// **'Rooms open once your account finishes setting up. Try again in a moment.'**
  String get rooms_profilePending;

  /// Screen-reader hint on a room card or strip item.
  ///
  /// In en, this message translates to:
  /// **'Opens the room'**
  String get rooms_openHint;

  /// Room card for a memory: when it closes for good.
  ///
  /// In en, this message translates to:
  /// **'A memory until {date}'**
  String rooms_memoryUntil(String date);

  /// Room theme for Storm (high energy, unpleasant). Never 'bad'.
  ///
  /// In en, this message translates to:
  /// **'The Lighthouse'**
  String get rooms_theme_lighthouse;

  /// Room theme for Rain (low energy, unpleasant).
  ///
  /// In en, this message translates to:
  /// **'The Rain Sanctuary'**
  String get rooms_theme_rain_sanctuary;

  /// Room theme for Moonlight (low energy, pleasant).
  ///
  /// In en, this message translates to:
  /// **'The Midnight Observatory'**
  String get rooms_theme_midnight_observatory;

  /// Room theme for Sunrise (high energy, pleasant).
  ///
  /// In en, this message translates to:
  /// **'The Sunrise Deck'**
  String get rooms_theme_sunrise_deck;

  /// Preset room gesture (a cup of tea offered). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Warm Tea'**
  String get rooms_gesture_warm_tea;

  /// Preset room gesture (a small light lit for someone). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Light a Candle'**
  String get rooms_gesture_light_a_candle;

  /// Preset room gesture (a hug). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Hug'**
  String get rooms_gesture_hug;

  /// Preset room gesture ('I feel it too'). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Me Too'**
  String get rooms_gesture_me_too;

  /// Preset room gesture (a gentle, calming rain). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Soft Rain'**
  String get rooms_gesture_soft_rain;

  /// Preset room gesture (looking at the stars together). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Stargaze'**
  String get rooms_gesture_stargaze;

  /// Preset room gesture (breathe slowly together). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'Deep Breath'**
  String get rooms_gesture_deep_breath;

  /// Preset room gesture (reassurance). Warm, short; a name, not a sentence to translate literally.
  ///
  /// In en, this message translates to:
  /// **'You\'re Not Alone'**
  String get rooms_gesture_youre_not_alone;

  /// Room header: current members seen in the last 2 min.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody here right now} =1{1 here now} other{{count} here now}}'**
  String rooms_hereNow(int count);

  /// Room header: everyone who has been a member today.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person has been here today} other{{count} people have been here today}}'**
  String rooms_today(int count);

  /// Screen reader: the room header ('7 people here now, 31 today', REQ-A11Y-06).
  ///
  /// In en, this message translates to:
  /// **'{now, plural, =1{1 person here now} other{{now} people here now}}, {today, plural, =1{1 today} other{{today} today}}'**
  String rooms_countsSemantic(int now, int today);

  /// Screen reader: a room in the Home 'Your rooms' strip.
  ///
  /// In en, this message translates to:
  /// **'{theme}, {count, plural, =1{1 person here now} other{{count} people here now}}'**
  String rooms_stripSemantic(String theme, int count);

  /// Room screen while it loads.
  ///
  /// In en, this message translates to:
  /// **'Opening the room…'**
  String get rooms_opening;

  /// Your pseudonym in this room (fresh per room; never translated).
  ///
  /// In en, this message translates to:
  /// **'You\'re {pseudonym} here'**
  String rooms_youAre(String pseudonym);

  /// Room with nobody else here right now (cold start). Honest counts, never fake presence.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You\'re the first here today. Leave a light for the next one.} other{{count} people have been here today. Leave a light for the next one.}}'**
  String rooms_coldStart(int count);

  /// Room header during Lantern Hour (the shared evening window).
  ///
  /// In en, this message translates to:
  /// **'Lantern Hour · until {time}'**
  String rooms_lanternOn(String time);

  /// Room in its last hours (no new members; gestures still work).
  ///
  /// In en, this message translates to:
  /// **'This room becomes a memory at {time}.'**
  String rooms_closing(String time);

  /// Room became read-only (24 h). Calm, not a loss.
  ///
  /// In en, this message translates to:
  /// **'This room has become a memory. You can look back for 7 days.'**
  String get rooms_memory;

  /// From a memory: start a check-in to find a new room.
  ///
  /// In en, this message translates to:
  /// **'Find a new room'**
  String get rooms_findNew;

  /// Chip while the live connection to the room is restored (gestures wait up to 30 s).
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get rooms_reconnecting;

  /// Room screen: heading over the members.
  ///
  /// In en, this message translates to:
  /// **'Here with you'**
  String get rooms_membersTitle;

  /// Your own tile among the members.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get rooms_you;

  /// Screen reader: a member seen in the last 2 min.
  ///
  /// In en, this message translates to:
  /// **'here now'**
  String get rooms_memberHereNow;

  /// Screen reader: a member not seen for a while (still in the room).
  ///
  /// In en, this message translates to:
  /// **'away for now'**
  String get rooms_memberAway;

  /// A member you muted (their gestures don't reach you).
  ///
  /// In en, this message translates to:
  /// **'muted for you'**
  String get rooms_memberMuted;

  /// Screen reader: a member tile (pseudonym, mood at join, here now / away).
  ///
  /// In en, this message translates to:
  /// **'{pseudonym}, {mood}, {status}'**
  String rooms_memberLabel(String pseudonym, String mood, String status);

  /// Screen reader: your own tile.
  ///
  /// In en, this message translates to:
  /// **'You, {pseudonym}, {mood}'**
  String rooms_youLabel(String pseudonym, String mood);

  /// Screen-reader hint on a member tile (gestures, report, block, mute).
  ///
  /// In en, this message translates to:
  /// **'Opens options'**
  String get rooms_memberHint;

  /// Room screen: heading over recent gestures.
  ///
  /// In en, this message translates to:
  /// **'Warmth in this room'**
  String get rooms_recentTitle;

  /// A gesture you received ('Quiet Comet sent you Warm Tea'); also announced.
  ///
  /// In en, this message translates to:
  /// **'{pseudonym} sent you {gesture}'**
  String rooms_receivedLine(String pseudonym, String gesture);

  /// Announcement after you send a gesture to a member (REQ-A11Y-06).
  ///
  /// In en, this message translates to:
  /// **'{gesture} sent to {pseudonym}'**
  String rooms_sentToMember(String gesture, String pseudonym);

  /// Announcement after you send a gesture to the room.
  ///
  /// In en, this message translates to:
  /// **'{gesture} sent to everyone here'**
  String rooms_sentToRoom(String gesture);

  /// Someone else's gesture (unnamed, to a member).
  ///
  /// In en, this message translates to:
  /// **'Someone sent {gesture}'**
  String rooms_someoneSent(String gesture);

  /// Someone else's gesture to the whole room (unnamed).
  ///
  /// In en, this message translates to:
  /// **'Someone sent {gesture} to everyone here'**
  String rooms_someoneSentRoom(String gesture);

  /// Your gesture in the room's list.
  ///
  /// In en, this message translates to:
  /// **'You sent {gesture} to {pseudonym}'**
  String rooms_youSentMember(String gesture, String pseudonym);

  /// Your gesture to the room in the room's list.
  ///
  /// In en, this message translates to:
  /// **'You sent {gesture} to everyone here'**
  String rooms_youSentRoom(String gesture);

  /// Gesture tray heading (tap a member to send to one person).
  ///
  /// In en, this message translates to:
  /// **'Send warmth to everyone here'**
  String get rooms_trayTitle;

  /// Screen-reader hint on a tray gesture.
  ///
  /// In en, this message translates to:
  /// **'Sends to everyone here'**
  String get rooms_trayHint;

  /// Memory rooms are read-only.
  ///
  /// In en, this message translates to:
  /// **'Gestures rest in a memory. You can still report, block or mute.'**
  String get rooms_trayResting;

  /// Tooltip of the room menu button (report a problem, leave).
  ///
  /// In en, this message translates to:
  /// **'Room options'**
  String get rooms_roomOptions;

  /// Room menu: report something in this room (F9).
  ///
  /// In en, this message translates to:
  /// **'Report a problem here'**
  String get rooms_reportRoom;

  /// Room menu: leave for good.
  ///
  /// In en, this message translates to:
  /// **'Leave this room'**
  String get rooms_leave;

  /// Room menu on a memory: leave it.
  ///
  /// In en, this message translates to:
  /// **'Remove from my rooms'**
  String get rooms_removeMemory;

  /// Leave confirmation title. Calm.
  ///
  /// In en, this message translates to:
  /// **'Leave this room?'**
  String get rooms_leaveTitle;

  /// Leave confirmation: no rejoining; the slot frees up.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to come back to it, and your seat opens up for someone else. Your next check-in can find you a new room.'**
  String get rooms_leaveBody;

  /// Leave confirmation button.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get rooms_leaveConfirm;

  /// Keep the room (the safe choice).
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get rooms_stay;

  /// Leaving a memory room: confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Remove this memory?'**
  String get rooms_removeTitle;

  /// Leaving a memory room: explanation.
  ///
  /// In en, this message translates to:
  /// **'It leaves your rooms now. Memories close for good after 7 days anyway.'**
  String get rooms_removeBody;

  /// Leaving a memory room: confirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get rooms_removeConfirm;

  /// Keep a memory room (the safe choice).
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get rooms_keep;

  /// Leaving failed (e.g. offline).
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. You\'re still in the room.'**
  String get rooms_leaveFailed;

  /// The room no longer exists for you (purged or left).
  ///
  /// In en, this message translates to:
  /// **'This room has closed. Rooms rest for 7 days as memories, then they\'re gone.'**
  String get rooms_gone;

  /// Go to the Rooms tab.
  ///
  /// In en, this message translates to:
  /// **'Back to your rooms'**
  String get rooms_backToRooms;

  /// Opening a room while offline (no call is made).
  ///
  /// In en, this message translates to:
  /// **'Rooms need a connection. This room opens again when you\'re back online.'**
  String get rooms_offlineRoom;

  /// Title while matching into a room.
  ///
  /// In en, this message translates to:
  /// **'Finding your room'**
  String get rooms_joinTitle;

  /// Loading while matching (≤ 5 s, PRD States).
  ///
  /// In en, this message translates to:
  /// **'Finding people who feel this way right now…'**
  String get rooms_finding;

  /// Joining offline (PRD States: Room offline). No call is made.
  ///
  /// In en, this message translates to:
  /// **'Rooms need a connection. Your check-in is saved.'**
  String get rooms_offlineJoin;

  /// Joining failed (server or network).
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the rooms just now. Your check-in is saved.'**
  String get rooms_joinFailed;

  /// 429 room_join_limit. Calm; returning to a room is always free.
  ///
  /// In en, this message translates to:
  /// **'That\'s 3 new rooms for this feeling today. The rooms you\'re in are still open to you.'**
  String get rooms_joinLimit;

  /// Go to the Rooms tab.
  ///
  /// In en, this message translates to:
  /// **'See your rooms'**
  String get rooms_seeYourRooms;

  /// 409 language_pool_unavailable (PRD States).
  ///
  /// In en, this message translates to:
  /// **'Hindi and Hinglish rooms are opening soon. Join an English room for now?'**
  String get rooms_poolUnavailable;

  /// Join an English room instead.
  ///
  /// In en, this message translates to:
  /// **'Join English room'**
  String get rooms_poolJoinEnglish;

  /// Ask for an in-app note when Hindi + Hinglish rooms open.
  ///
  /// In en, this message translates to:
  /// **'Tell me when they open'**
  String get rooms_poolNotify;

  /// Confirmation of 'Tell me when they open'.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know here when Hindi and Hinglish rooms open.'**
  String get rooms_poolNotifyDone;

  /// The join screen was opened without a check-in.
  ///
  /// In en, this message translates to:
  /// **'Rooms open from a check-in.'**
  String get rooms_noRequest;

  /// After a saved check-in: the room offer. Identical at every age.
  ///
  /// In en, this message translates to:
  /// **'Join a room of people feeling this'**
  String get rooms_offer;

  /// Screen-reader hint on the room offer.
  ///
  /// In en, this message translates to:
  /// **'Opens a room, with a fresh name just for it'**
  String get rooms_offerHint;

  /// Room offer while offline (REQ-ROOM-01). No call is made.
  ///
  /// In en, this message translates to:
  /// **'Rooms open when you\'re back online'**
  String get rooms_offerOffline;

  /// First check-in (during onboarding): where rooms are.
  ///
  /// In en, this message translates to:
  /// **'Rooms are in the Rooms tab whenever you\'d like company.'**
  String get rooms_offerLater;

  /// Guidelines sheet title, shown before the first room.
  ///
  /// In en, this message translates to:
  /// **'Before your first room'**
  String get rooms_guidelinesTitle;

  /// Guidelines intro.
  ///
  /// In en, this message translates to:
  /// **'Rooms stay gentle because everyone keeps to a few simple things:'**
  String get rooms_guidelinesIntro;

  /// Guideline 1.
  ///
  /// In en, this message translates to:
  /// **'Be kind. Everyone here is having a real day.'**
  String get rooms_rule1;

  /// Guideline 2.
  ///
  /// In en, this message translates to:
  /// **'No hate about caste, religion, gender, sexuality or anything else.'**
  String get rooms_rule2;

  /// Guideline 3.
  ///
  /// In en, this message translates to:
  /// **'No sexual content.'**
  String get rooms_rule3;

  /// Guideline 4 (grooming and contact-swap).
  ///
  /// In en, this message translates to:
  /// **'Never share or ask for contact details or meet-ups, or anyone\'s age, school, city or photos.'**
  String get rooms_rule4;

  /// Guideline 5.
  ///
  /// In en, this message translates to:
  /// **'No selling or spam.'**
  String get rooms_rule5;

  /// Guideline 6 (safe messaging: no method named).
  ///
  /// In en, this message translates to:
  /// **'Never encourage anyone to hurt themselves. Talking about how you feel is always okay.'**
  String get rooms_rule6;

  /// Guidelines footer.
  ///
  /// In en, this message translates to:
  /// **'You can report, block or mute anyone, and help is always one tap away.'**
  String get rooms_guidelinesSafety;

  /// Accept the guidelines and continue to the room.
  ///
  /// In en, this message translates to:
  /// **'I\'ll keep to these'**
  String get rooms_guidelinesAgree;

  /// The server asks for guidelines newer than this app version carries (REQ-SAFE-04). Calm; no blame.
  ///
  /// In en, this message translates to:
  /// **'Rooms have new community guidelines. Update Aura to read them before your next room.'**
  String get rooms_guidelinesUpdate;

  /// Member sheet: the gestures for this one person.
  ///
  /// In en, this message translates to:
  /// **'Send {pseudonym} some warmth'**
  String rooms_sendTo(String pseudonym);

  /// Screen-reader hint on a gesture in the member sheet.
  ///
  /// In en, this message translates to:
  /// **'Sends to {pseudonym}'**
  String rooms_gestureHintMember(String pseudonym);

  /// Member sheet action (F9).
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get rooms_report;

  /// Member sheet action (F9): account-level, both ways.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get rooms_block;

  /// Member sheet action: hides their gestures for you in this room.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get rooms_mute;

  /// Member sheet action: undo a mute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get rooms_unmute;

  /// Member sheet reassurance under the safety actions.
  ///
  /// In en, this message translates to:
  /// **'They\'re never told who reported, blocked or muted them.'**
  String get rooms_safetyNote;

  /// Block confirmation title. Calm.
  ///
  /// In en, this message translates to:
  /// **'Block {pseudonym}?'**
  String rooms_blockTitle(String pseudonym);

  /// Block confirmation body (the blocked person sees no change).
  ///
  /// In en, this message translates to:
  /// **'You won\'t be placed in a room together again, and gestures between you stop. They won\'t be told.'**
  String get rooms_blockBody;

  /// After blocking.
  ///
  /// In en, this message translates to:
  /// **'{pseudonym} is blocked. You won\'t share a room again.'**
  String rooms_blocked(String pseudonym);

  /// After muting (per room, for you only).
  ///
  /// In en, this message translates to:
  /// **'{pseudonym} is muted for you. Their gestures won\'t reach you here.'**
  String rooms_muted(String pseudonym);

  /// After unmuting.
  ///
  /// In en, this message translates to:
  /// **'{pseudonym} is unmuted.'**
  String rooms_unmuted(String pseudonym);

  /// Undo a mute.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get rooms_undo;

  /// A room action failed (e.g. offline). No blame.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Try again in a moment.'**
  String get rooms_actionFailed;

  /// Report sheet title for a member.
  ///
  /// In en, this message translates to:
  /// **'Report {pseudonym}'**
  String rooms_reportMember(String pseudonym);

  /// Report sheet title / button for a received gesture.
  ///
  /// In en, this message translates to:
  /// **'Report this gesture'**
  String get rooms_reportGesture;

  /// Report sheet: pick one reason.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get rooms_reportWhy;

  /// Report reason 1 (crisis lane: the reporter sees helplines). Safe messaging.
  ///
  /// In en, this message translates to:
  /// **'Someone may be in danger or hurting themselves'**
  String get rooms_reason1;

  /// Report reason 2.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get rooms_reason2;

  /// Report reason 3.
  ///
  /// In en, this message translates to:
  /// **'Sexual content or advances'**
  String get rooms_reason3;

  /// Report reason 4.
  ///
  /// In en, this message translates to:
  /// **'Hate or slurs'**
  String get rooms_reason4;

  /// Report reason 5.
  ///
  /// In en, this message translates to:
  /// **'Contact details or personal info'**
  String get rooms_reason5;

  /// Report reason 6.
  ///
  /// In en, this message translates to:
  /// **'Spam or selling'**
  String get rooms_reason6;

  /// Report reason 7 (never shows anyone's age).
  ///
  /// In en, this message translates to:
  /// **'Someone may be under 13'**
  String get rooms_reason7;

  /// Report reason 8.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get rooms_reason8;

  /// Report reason 9, shown before 'Something else' (Minors & grooming lane on the server, whatever anyone's age). Plain and warm; never mentions or asks anyone's age.
  ///
  /// In en, this message translates to:
  /// **'Seems to be targeting a young person'**
  String get rooms_reason9;

  /// Report note field label (≤ 200 characters).
  ///
  /// In en, this message translates to:
  /// **'Anything a moderator should know? (optional)'**
  String get rooms_reportNoteLabel;

  /// Report note helper text.
  ///
  /// In en, this message translates to:
  /// **'Only Aura\'s moderators read this. Please leave out phone numbers, links and handles.'**
  String get rooms_reportNoteHelp;

  /// On-device PII check on the report note (PRD States wording). Nothing was sent.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers, links and handles can\'t be shared here. It keeps everyone safer.'**
  String get rooms_reportNoteContact;

  /// Submit a report.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get rooms_reportSend;

  /// After a report (room or other).
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling us. A moderator will look at it, usually within a day.'**
  String get rooms_reportThanks;

  /// After reporting a member (they are muted for you here).
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling us. You won\'t get their gestures in this room while a moderator takes a look.'**
  String get rooms_reportHidden;

  /// After reporting a gesture.
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling us. That gesture is hidden for you now.'**
  String get rooms_reportGestureHidden;

  /// After a report in the crisis lane (the Safety Center opens first). Safe messaging.
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling us. A moderator will look soon, and help is always one tap away.'**
  String get rooms_reportCrisis;

  /// 429 report_limit (reason 1 is never limited).
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot of reports today. If someone is in danger, the help button is always here.'**
  String get rooms_reportLimit;

  /// Report failed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through, so nothing was sent. Try again in a moment.'**
  String get rooms_reportFailed;

  /// Report while offline (no call is made).
  ///
  /// In en, this message translates to:
  /// **'Reports need a connection. Nothing was sent yet.'**
  String get rooms_reportOffline;

  /// Exit micro-survey (≥ 30 s in the room, at most once a day). Aggregate only.
  ///
  /// In en, this message translates to:
  /// **'Did you feel less alone?'**
  String get rooms_surveyTitle;

  /// Survey answer.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get rooms_surveyYes;

  /// Survey answer.
  ///
  /// In en, this message translates to:
  /// **'Not really'**
  String get rooms_surveyNo;

  /// Skip the survey.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get rooms_surveySkip;

  /// Settings, after switching to English: which room pool new rooms use.
  ///
  /// In en, this message translates to:
  /// **'New rooms will match you with English speakers. A room you\'re in now keeps its language.'**
  String get settings_poolNoticeEn;

  /// Settings, after switching to Telugu or Tenglish: which room pool new rooms use.
  ///
  /// In en, this message translates to:
  /// **'New rooms will match you with Telugu and Tenglish speakers. A room you\'re in now keeps its language.'**
  String get settings_poolNoticeTe;

  /// Settings, after switching to Hindi or Hinglish while that room pool is open.
  ///
  /// In en, this message translates to:
  /// **'New rooms will match you with Hindi and Hinglish speakers. A room you\'re in now keeps its language.'**
  String get settings_poolNoticeHi;

  /// Settings, after switching to Hindi or Hinglish while that pool is still closed (F5: they join English meanwhile).
  ///
  /// In en, this message translates to:
  /// **'Hindi and Hinglish rooms are opening soon, so new rooms will match you with English speakers for now.'**
  String get settings_poolNoticeHiSoon;

  /// Title of the Sanctuary tab: a private, calm space (breathing, grounding).
  ///
  /// In en, this message translates to:
  /// **'Sanctuary'**
  String get sanctuary_title;

  /// Intro line at the top of the Sanctuary. Calm; nothing is timed against you or scored.
  ///
  /// In en, this message translates to:
  /// **'A quiet place, just for you. Go at your own pace. Nothing here is scored.'**
  String get sanctuary_intro;

  /// Section header: one gentle suggestion for today (changes each day).
  ///
  /// In en, this message translates to:
  /// **'Today\'s minute'**
  String get sanctuary_todayTitle;

  /// Section header and title of the breathing session.
  ///
  /// In en, this message translates to:
  /// **'Breathe'**
  String get sanctuary_breatheSection;

  /// Card that opens the breathing session.
  ///
  /// In en, this message translates to:
  /// **'Breathe with your Aura'**
  String get sanctuary_breatheCard;

  /// Under the breathing card: the three rhythms, any length.
  ///
  /// In en, this message translates to:
  /// **'Calm, box or 4-7-8 breathing, for as long as you like.'**
  String get sanctuary_breatheCardBody;

  /// Section header: short grounding activities (five senses, hand on heart, three small things).
  ///
  /// In en, this message translates to:
  /// **'Grounding'**
  String get sanctuary_groundingSection;

  /// Button that opens an optional activity (Today's minute, A minute for you).
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get sanctuary_begin;

  /// Starts a timed activity (breathing, hand on heart).
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sanctuary_start;

  /// Pauses an activity. Nothing is lost.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get sanctuary_pause;

  /// Resumes a paused activity.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get sanctuary_resume;

  /// Ends an activity early, gently (no penalty).
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get sanctuary_finish;

  /// Next step of a step-by-step activity.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get sanctuary_next;

  /// Screen-reader label of the quiet progress ring (no numbers, no countdown).
  ///
  /// In en, this message translates to:
  /// **'Progress through this session'**
  String get sanctuary_progress;

  /// Progress ring value: first third.
  ///
  /// In en, this message translates to:
  /// **'Just begun'**
  String get sanctuary_progressBegun;

  /// Progress ring value: middle third.
  ///
  /// In en, this message translates to:
  /// **'About halfway'**
  String get sanctuary_progressHalf;

  /// Progress ring value: last third. Never pressure.
  ///
  /// In en, this message translates to:
  /// **'Nearly through'**
  String get sanctuary_progressNearly;

  /// Progress ring value: finished.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get sanctuary_progressDone;

  /// After a breathing session or a long note ticks off a habit automatically (F2). habit = the habit's name (Breathe, Journal).
  ///
  /// In en, this message translates to:
  /// **'{habit} is marked done for today.'**
  String habits_autoLogged(String habit);

  /// Header above the three breathing patterns.
  ///
  /// In en, this message translates to:
  /// **'Rhythm'**
  String get breathe_rhythm;

  /// Breathing pattern: in 4, out 6 (the default).
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get breathe_calm;

  /// Describes the calm pattern.
  ///
  /// In en, this message translates to:
  /// **'In for 4, out for 6. Gentle and steady.'**
  String get breathe_calmBody;

  /// Breathing pattern: in 4, hold 4, out 4, hold 4.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get breathe_box;

  /// Describes box breathing.
  ///
  /// In en, this message translates to:
  /// **'In, hold, out, hold. Four counts each.'**
  String get breathe_boxBody;

  /// Breathing pattern: in 4, hold 7, out 8 (digits stay as they are).
  ///
  /// In en, this message translates to:
  /// **'4-7-8'**
  String get breathe_478;

  /// Describes 4-7-8 breathing.
  ///
  /// In en, this message translates to:
  /// **'In for 4, hold for 7, out for 8.'**
  String get breathe_478Body;

  /// Gentle safety note with 4-7-8 breathing (long holds). Calm, not alarming.
  ///
  /// In en, this message translates to:
  /// **'If you feel light-headed, stop and breathe normally.'**
  String get breathe_lightHeaded;

  /// Header above the session lengths.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get breathe_length;

  /// A session length choice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String breathe_minutes(int count);

  /// Session length choice with no set end.
  ///
  /// In en, this message translates to:
  /// **'Until I stop'**
  String get breathe_openEnded;

  /// Breathing cue: inhale. Also announced to screen readers when it begins.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get breathe_in;

  /// Breathing cue: hold the breath (box, 4-7-8).
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get breathe_hold;

  /// Breathing cue: exhale.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get breathe_out;

  /// Shown (and announced) while a breathing session is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused. Take your time.'**
  String get breathe_paused;

  /// End of a breathing session. Acknowledged, never scored; leaving early is never mentioned.
  ///
  /// In en, this message translates to:
  /// **'That was time just for you.'**
  String get breathe_done;

  /// Starts the same breathing session again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get breathe_again;

  /// 30-second grounding breath (after a Storm check-in), cue 1.
  ///
  /// In en, this message translates to:
  /// **'Feel your feet on the ground.'**
  String get breathe_land1;

  /// 30-second grounding breath, cue 2.
  ///
  /// In en, this message translates to:
  /// **'Notice three sounds around you.'**
  String get breathe_land2;

  /// After the 30-second grounding breath: opens the full breathing session.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get breathe_keepGoing;

  /// 30-second grounding breath, cue 3.
  ///
  /// In en, this message translates to:
  /// **'Let your shoulders drop.'**
  String get breathe_land3;

  /// 5-4-3-2-1 grounding: notice things with each sense, step by step.
  ///
  /// In en, this message translates to:
  /// **'Five senses'**
  String get senses_title;

  /// Under the five-senses card.
  ///
  /// In en, this message translates to:
  /// **'Notice what\'s around you, one sense at a time.'**
  String get senses_card;

  /// Five senses: intro before the first step.
  ///
  /// In en, this message translates to:
  /// **'Let\'s notice what\'s around you, one sense at a time. Go at your own pace.'**
  String get senses_intro;

  /// Five senses, step 1.
  ///
  /// In en, this message translates to:
  /// **'Five things you can see'**
  String get senses_see;

  /// Five senses, step 1 hint.
  ///
  /// In en, this message translates to:
  /// **'Look around slowly. Name them in your head or out loud.'**
  String get senses_seeBody;

  /// Five senses, step 2 (touch).
  ///
  /// In en, this message translates to:
  /// **'Four things you can touch'**
  String get senses_touch;

  /// Five senses, step 2 hint.
  ///
  /// In en, this message translates to:
  /// **'The chair under you, your clothes, the air on your skin.'**
  String get senses_touchBody;

  /// Five senses, step 3.
  ///
  /// In en, this message translates to:
  /// **'Three things you can hear'**
  String get senses_hear;

  /// Five senses, step 3 hint.
  ///
  /// In en, this message translates to:
  /// **'Near or far, loud or soft.'**
  String get senses_hearBody;

  /// Five senses, step 4.
  ///
  /// In en, this message translates to:
  /// **'Two things you can smell'**
  String get senses_smell;

  /// Five senses, step 4 hint.
  ///
  /// In en, this message translates to:
  /// **'Or two scents you like, if nothing is near.'**
  String get senses_smellBody;

  /// Five senses, step 5.
  ///
  /// In en, this message translates to:
  /// **'One thing you can taste'**
  String get senses_taste;

  /// Five senses, step 5 hint.
  ///
  /// In en, this message translates to:
  /// **'Or take a sip of water and notice it.'**
  String get senses_tasteBody;

  /// Screen-reader text for the quiet step dots. Not a score.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String senses_step(int step, int total);

  /// After the fifth sense.
  ///
  /// In en, this message translates to:
  /// **'You\'re here, in this moment. Nicely done.'**
  String get senses_done;

  /// Self-compassion touch: a hand on the heart for a minute.
  ///
  /// In en, this message translates to:
  /// **'Hand on heart'**
  String get heart_title;

  /// Under the hand-on-heart card.
  ///
  /// In en, this message translates to:
  /// **'A minute of warmth, just for you.'**
  String get heart_card;

  /// Hand on heart: first cue, shown with the first slow breath. Gentle.
  ///
  /// In en, this message translates to:
  /// **'Place a hand on your heart, or anywhere that feels comforting.'**
  String get heart_intro;

  /// Hand on heart, phrase 1.
  ///
  /// In en, this message translates to:
  /// **'Feel the warmth of your hand.'**
  String get heart_1;

  /// Hand on heart, phrase 2.
  ///
  /// In en, this message translates to:
  /// **'Breathe gently. There\'s no rush.'**
  String get heart_2;

  /// Hand on heart, phrase 3.
  ///
  /// In en, this message translates to:
  /// **'Whatever you\'re feeling is allowed here.'**
  String get heart_3;

  /// Hand on heart, phrase 4. Gender-neutral 'friend'.
  ///
  /// In en, this message translates to:
  /// **'Be as kind to yourself as you would be to a friend.'**
  String get heart_4;

  /// After the hand-on-heart minute.
  ///
  /// In en, this message translates to:
  /// **'Thank you for being gentle with yourself.'**
  String get heart_done;

  /// Gratitude: think of (or type) three small things that went okay. Nothing is stored.
  ///
  /// In en, this message translates to:
  /// **'Three small things'**
  String get gratitude_title;

  /// Under the three-small-things card.
  ///
  /// In en, this message translates to:
  /// **'Three small things that went okay today.'**
  String get gratitude_card;

  /// Three small things: intro. Prompts only, no typing; nothing is stored.
  ///
  /// In en, this message translates to:
  /// **'Bring three small things from today to mind, one at a time. There\'s nothing to write.'**
  String get gratitude_intro;

  /// Three small things, step 1.
  ///
  /// In en, this message translates to:
  /// **'One small thing that went okay'**
  String get gratitude_1;

  /// Three small things, step 1 hint.
  ///
  /// In en, this message translates to:
  /// **'It can be tiny, like a warm drink or a kind word.'**
  String get gratitude_1Body;

  /// Three small things, step 2.
  ///
  /// In en, this message translates to:
  /// **'Another small thing'**
  String get gratitude_2;

  /// Three small things, step 2 hint.
  ///
  /// In en, this message translates to:
  /// **'Something you saw, heard or did.'**
  String get gratitude_2Body;

  /// Three small things, step 3.
  ///
  /// In en, this message translates to:
  /// **'One more small thing'**
  String get gratitude_3;

  /// Three small things, step 3 hint.
  ///
  /// In en, this message translates to:
  /// **'Maybe something about yourself.'**
  String get gratitude_3Body;

  /// After the third small thing.
  ///
  /// In en, this message translates to:
  /// **'Hold onto those for a moment. They\'re yours.'**
  String get gratitude_done;

  /// Savour (Sunrise's minute; also in the library): intro. Prompts only.
  ///
  /// In en, this message translates to:
  /// **'Let\'s replay one good moment from today, slowly.'**
  String get savour_intro;

  /// Savour, step 1.
  ///
  /// In en, this message translates to:
  /// **'Bring one good moment from today to mind, however small.'**
  String get savour_1;

  /// Savour, step 2.
  ///
  /// In en, this message translates to:
  /// **'Where were you? What could you see and hear?'**
  String get savour_2;

  /// Savour, step 3.
  ///
  /// In en, this message translates to:
  /// **'Notice how it feels to remember it now.'**
  String get savour_3;

  /// After the savour steps.
  ///
  /// In en, this message translates to:
  /// **'Let it stay with you a little longer.'**
  String get savour_done;

  /// Optional card in the check-in saved moment, for every quadrant. Never shown right after the crisis sheet.
  ///
  /// In en, this message translates to:
  /// **'A minute for you'**
  String get minute_forYou;

  /// Today's minute: one minute of calm breathing.
  ///
  /// In en, this message translates to:
  /// **'One calm minute'**
  String get minute_calmTitle;

  /// Today's minute: one minute of box breathing.
  ///
  /// In en, this message translates to:
  /// **'Box breathing'**
  String get minute_boxTitle;

  /// Today's minute: 4-7-8 breathing.
  ///
  /// In en, this message translates to:
  /// **'4-7-8 breathing'**
  String get minute_478Title;

  /// One minute of slow breathing (Moonlight's minute; also in Today's minute).
  ///
  /// In en, this message translates to:
  /// **'A minute of stillness'**
  String get minute_stillnessTitle;

  /// Under 'A minute of stillness'.
  ///
  /// In en, this message translates to:
  /// **'One quiet minute with the orb.'**
  String get minute_stillnessBody;

  /// 30-second grounding breath (Storm's minute).
  ///
  /// In en, this message translates to:
  /// **'Thirty seconds to land'**
  String get minute_landTitle;

  /// Under 'Thirty seconds to land' (Storm's minute).
  ///
  /// In en, this message translates to:
  /// **'Three slow breaths with the orb.'**
  String get minute_landBody;

  /// Hand on heart, offered as Rain's minute.
  ///
  /// In en, this message translates to:
  /// **'A little comfort'**
  String get minute_comfortTitle;

  /// Under 'A little comfort'.
  ///
  /// In en, this message translates to:
  /// **'A hand on your heart, and a minute of warmth.'**
  String get minute_comfortBody;

  /// Savouring what feels good (Sunrise's minute).
  ///
  /// In en, this message translates to:
  /// **'Savour this'**
  String get minute_savourTitle;

  /// Under 'Savour this'.
  ///
  /// In en, this message translates to:
  /// **'Replay one good moment from today.'**
  String get minute_savourBody;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot at once. Your light is still here.'**
  String get companion_storm1;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Naming a storm takes courage. You showed up for yourself.'**
  String get companion_storm2;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Big, loud feelings are welcome here. So are you.'**
  String get companion_storm3;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Stormy days matter too. Thank you for checking in.'**
  String get companion_storm4;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'You named this honestly. That matters.'**
  String get companion_storm5;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Storms are part of your sky too.'**
  String get companion_storm6;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Whatever is swirling, you noticed it. That counts.'**
  String get companion_storm7;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Even in a storm, your glow is yours.'**
  String get companion_storm8;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'That feels heavy. Your light is still with you.'**
  String get companion_rain1;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Being honest about a low day takes courage. You showed up for yourself.'**
  String get companion_rain2;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Slow, heavy feelings are welcome here. So are you.'**
  String get companion_rain3;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Rainy days matter too. Thank you for checking in.'**
  String get companion_rain4;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'You were honest with yourself today. That matters.'**
  String get companion_rain5;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Rain is part of your sky too.'**
  String get companion_rain6;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'However heavy it is, you noticed it. That counts.'**
  String get companion_rain7;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Even on grey days, your glow is yours.'**
  String get companion_rain8;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'A quiet, settled moment. Your light is resting easy.'**
  String get companion_moonlight1;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Noticing a quiet moment is worth something. You showed up for yourself.'**
  String get companion_moonlight2;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Soft, easy feelings are welcome here. So are you.'**
  String get companion_moonlight3;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Gentle days matter too. Thank you for checking in.'**
  String get companion_moonlight4;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'You took a moment to notice this. That matters.'**
  String get companion_moonlight5;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Moonlight is part of your sky too.'**
  String get companion_moonlight6;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'However small this calm is, you noticed it. That counts.'**
  String get companion_moonlight7;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'In the quiet, your glow is yours.'**
  String get companion_moonlight8;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'A bright moment. Your light is shining.'**
  String get companion_sunrise1;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Noticing a good moment is worth something. You showed up for yourself.'**
  String get companion_sunrise2;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Big, bright feelings are welcome here. So are you.'**
  String get companion_sunrise3;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Bright days matter too. Thank you for checking in.'**
  String get companion_sunrise4;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'You let yourself notice this. That matters.'**
  String get companion_sunrise5;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'Sunrise is part of your sky too.'**
  String get companion_sunrise6;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'However big or small this is, you noticed it. That counts.'**
  String get companion_sunrise7;

  /// Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth.
  ///
  /// In en, this message translates to:
  /// **'In this brightness, your glow is yours.'**
  String get companion_sunrise8;

  /// Companion line after a check-in that showed the support sheet: neutral, the same for every quadrant. Never advice or a promise.
  ///
  /// In en, this message translates to:
  /// **'Thank you for checking in.'**
  String get companion_neutral1;

  /// Companion line after a check-in that showed the support sheet: neutral, the same for every quadrant. Never advice or a promise.
  ///
  /// In en, this message translates to:
  /// **'You showed up for yourself.'**
  String get companion_neutral2;

  /// Companion line after a check-in that showed the support sheet: neutral, the same for every quadrant. Never advice or a promise.
  ///
  /// In en, this message translates to:
  /// **'Your light is still here.'**
  String get companion_neutral3;

  /// Companion line after a check-in that showed the support sheet: neutral, the same for every quadrant. Never advice or a promise.
  ///
  /// In en, this message translates to:
  /// **'There\'s no rush here.'**
  String get companion_neutral4;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s one small thing that helped today?'**
  String get prompt_note1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind right now?'**
  String get prompt_note2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would you like to remember about today?'**
  String get prompt_note3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s taking up the most room right now?'**
  String get prompt_storm1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'If this feeling could speak, what would it say?'**
  String get prompt_storm2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s one thing you could set down, even for a minute?'**
  String get prompt_storm3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would feel gentle right now?'**
  String get prompt_rain1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s weighing on you today?'**
  String get prompt_rain2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'Who or what has felt kind to you lately?'**
  String get prompt_rain3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s helping you feel settled?'**
  String get prompt_moonlight1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What made today feel softer?'**
  String get prompt_moonlight2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would you like to keep from this moment?'**
  String get prompt_moonlight3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s lighting you up today?'**
  String get prompt_sunrise1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What went well that you\'d like to remember?'**
  String get prompt_sunrise2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'Who would you like to share this with?'**
  String get prompt_sunrise3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What do you want future you to know?'**
  String get prompt_capsule1;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What\'s helping you right now that you might forget?'**
  String get prompt_capsule2;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would you say to yourself on a hard day?'**
  String get prompt_capsule3;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What helps when everything feels like too much?'**
  String get prompt_capsuleStorm;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would you want to hear on a heavy day?'**
  String get prompt_capsuleRain;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What helps you find this calm again?'**
  String get prompt_capsuleMoonlight;

  /// Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.
  ///
  /// In en, this message translates to:
  /// **'What would you like to celebrate with future you?'**
  String get prompt_capsuleSunrise;

  /// Shows a different guided prompt in the empty note (the prompt is only a hint, never saved).
  ///
  /// In en, this message translates to:
  /// **'Another prompt'**
  String get prompt_another;

  /// Settings switch: show a gentle guided prompt in the empty note field.
  ///
  /// In en, this message translates to:
  /// **'Writing prompts'**
  String get prompt_settingsTitle;

  /// Under the Settings switch for guided prompts.
  ///
  /// In en, this message translates to:
  /// **'A gentle question in the empty note. Never saved.'**
  String get prompt_settingsBody;

  /// History button: add a check-in for one of the last 7 days.
  ///
  /// In en, this message translates to:
  /// **'Add a past check-in'**
  String get backfill_add;

  /// Title of the day picker for a past check-in.
  ///
  /// In en, this message translates to:
  /// **'Which day?'**
  String get backfill_pickTitle;

  /// Under the day picker title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You can add a check-in for yesterday.} other{You can add a check-in for any of the last {count} days.}}'**
  String backfill_pickBody(int count);

  /// Title of the check-in picker for a past day.
  ///
  /// In en, this message translates to:
  /// **'How were you feeling?'**
  String get backfill_title;

  /// Screen-reader label of the day chip on a past check-in, e.g. 'Check-in for Tuesday, October 6'. Tapping it changes the day.
  ///
  /// In en, this message translates to:
  /// **'Check-in for {day}'**
  String backfill_forDay(String day);

  /// Screen-reader hint on the day of a past check-in.
  ///
  /// In en, this message translates to:
  /// **'Change day'**
  String get backfill_changeDay;

  /// When the picked day has moved out of the 7-day window (e.g. past 04:00). The selection is kept.
  ///
  /// In en, this message translates to:
  /// **'Past check-ins can go up to a week back. Could you pick another day?'**
  String get backfill_outOfRange;

  /// After saving a check-in for a past day (PRD 06d edge case).
  ///
  /// In en, this message translates to:
  /// **'Added to your sky'**
  String get backfill_savedTitle;

  /// Under 'Added to your sky': the day it was saved for, e.g. 'Saved for Tuesday, October 6.'
  ///
  /// In en, this message translates to:
  /// **'Saved for {day}.'**
  String backfill_savedDay(String day);

  /// After saving a past check-in: why no Starlight shows (PRD F1: backfills earn nothing). Calm, no loss words.
  ///
  /// In en, this message translates to:
  /// **'Starlight comes from check-ins made on the day itself.'**
  String get backfill_savedBody;

  /// Shown instead of the time on a check-in that was added for a past day.
  ///
  /// In en, this message translates to:
  /// **'Added later'**
  String get history_addedLater;

  /// When a past-day check-in is for, on its page, e.g. 'Yesterday · added later'.
  ///
  /// In en, this message translates to:
  /// **'{day} · added later'**
  String history_whenAddedLater(String day);

  /// Navigation bar tab: the companion-led today view.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shell_tabHome;

  /// Navigation bar tab: the private calm space (breathing, grounding). Same name as the Sanctuary screen title.
  ///
  /// In en, this message translates to:
  /// **'Sanctuary'**
  String get shell_tabSanctuary;

  /// Navigation bar tab: mood rooms with preset gestures. Never 'chat'.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get shell_tabRooms;

  /// Navigation bar tab: private history and gentle patterns. Never clinical.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get shell_tabInsights;

  /// The distinct centre action of the navigation bar: opens a new check-in (not a tab).
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get shell_checkIn;

  /// Screen-reader hint on the centre Check in action, so it is not taken for a tab.
  ///
  /// In en, this message translates to:
  /// **'Starts a new check-in'**
  String get shell_checkInHint;

  /// Safety Center: when to call emergency services instead of a helpline. Direct and calm; never names a method (REQ-SAFE-15).
  ///
  /// In en, this message translates to:
  /// **'Call emergency services right away if you or someone near you is in immediate danger, badly hurt, or can\'t stay safe.'**
  String get safety_emergencyWhen;

  /// Safety Center link (signed in only) to Settings › Help & Safety.
  ///
  /// In en, this message translates to:
  /// **'Help & Safety in Settings'**
  String get safety_settingsLink;

  /// Screen-reader hint on the link above: what that Settings section holds.
  ///
  /// In en, this message translates to:
  /// **'Support contact, Grievance Officer and policies'**
  String get safety_settingsHint;

  /// Title of Sanctuary › Sounds: ambient sounds to mix (rain, ocean, wind…). Also the Sanctuary section header.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds_title;

  /// Under the Sounds card on the Sanctuary tab.
  ///
  /// In en, this message translates to:
  /// **'Rain, ocean, wind and more. Nothing plays until you choose.'**
  String get sounds_cardBody;

  /// Under the Sounds card while sounds are playing.
  ///
  /// In en, this message translates to:
  /// **'Playing now'**
  String get sounds_cardPlaying;

  /// Intro at the top of Sounds. Promise: silent until chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick a sound to begin, or mix up to four. Nothing plays until you tap.'**
  String get sounds_intro;

  /// Status line (also for screen readers) when no sound plays.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get sounds_nothingPlaying;

  /// Status line while sounds play.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get sounds_statePlaying;

  /// Status line while sounds are paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sounds_statePaused;

  /// Small note at the bottom of Sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds keep playing with the screen off. They pause if your headphones disconnect or a call comes in.'**
  String get sounds_backgroundNote;

  /// Android notification channel name for the Sounds media controls (Settings › Notifications).
  ///
  /// In en, this message translates to:
  /// **'Sounds playback'**
  String get sounds_notificationChannel;

  /// A ~20-minute sequence of sounds that slowly thins out to silence. No voice, no claims.
  ///
  /// In en, this message translates to:
  /// **'Night wind-down'**
  String get sounds_windDownTitle;

  /// Under the wind-down title.
  ///
  /// In en, this message translates to:
  /// **'About 20 minutes of sounds that slowly thin out to silence. The order changes each night.'**
  String get sounds_windDownBody;

  /// Starts the night wind-down.
  ///
  /// In en, this message translates to:
  /// **'Begin wind-down'**
  String get sounds_windDownBegin;

  /// While the wind-down plays: roughly how long until it has faded to silence.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{About 1 minute left} other{About {minutes} minutes left}}'**
  String sounds_windDownLeft(int minutes);

  /// Tapping a sound while the wind-down plays.
  ///
  /// In en, this message translates to:
  /// **'The wind-down is playing. Stop it to make your own mix.'**
  String get sounds_windDownBusy;

  /// Section header above the list of sounds.
  ///
  /// In en, this message translates to:
  /// **'Mix your own'**
  String get sounds_mixSection;

  /// Under the mixer header.
  ///
  /// In en, this message translates to:
  /// **'Up to four at once, each with its own volume.'**
  String get sounds_mixHint;

  /// Sound: steady rain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get sounds_stemRain;

  /// Sound: ocean waves.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get sounds_stemOcean;

  /// Sound: wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get sounds_stemWind;

  /// Sound: crickets and insects at night.
  ///
  /// In en, this message translates to:
  /// **'Night insects'**
  String get sounds_stemNightInsects;

  /// Sound: a singing bowl struck now and then.
  ///
  /// In en, this message translates to:
  /// **'Singing bowl'**
  String get sounds_stemSingingBowl;

  /// Sound: wind chimes.
  ///
  /// In en, this message translates to:
  /// **'Chimes'**
  String get sounds_stemChimes;

  /// Sound: soft, deep steady noise (generated on the phone).
  ///
  /// In en, this message translates to:
  /// **'Brown noise'**
  String get sounds_stemBrownNoise;

  /// Aura Plus sound: soft steady noise.
  ///
  /// In en, this message translates to:
  /// **'Pink noise'**
  String get sounds_stemPinkNoise;

  /// Aura Plus sound: a low bell far away.
  ///
  /// In en, this message translates to:
  /// **'Distant bell'**
  String get sounds_stemDeepBell;

  /// Aura Plus sound: heavy monsoon rain on a roof.
  ///
  /// In en, this message translates to:
  /// **'Monsoon on a roof'**
  String get sounds_stemMonsoonRoof;

  /// Aura Plus sound: a flowing stream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get sounds_stemStream;

  /// Aura Plus sound: a crackling fire.
  ///
  /// In en, this message translates to:
  /// **'Fireplace'**
  String get sounds_stemFireplace;

  /// Aura Plus sound: soft thunder far away.
  ///
  /// In en, this message translates to:
  /// **'Distant thunder'**
  String get sounds_stemDistantThunder;

  /// Screen-reader label of a sound that is on, e.g. 'Rain, playing, volume 60%'.
  ///
  /// In en, this message translates to:
  /// **'{name}, playing, volume {percent}%'**
  String sounds_stemOn(String name, int percent);

  /// Screen-reader label of a sound in the mix while paused.
  ///
  /// In en, this message translates to:
  /// **'{name}, paused, volume {percent}%'**
  String sounds_stemPaused(String name, int percent);

  /// Screen-reader label of a sound that is not playing. Tapping it adds it.
  ///
  /// In en, this message translates to:
  /// **'{name}, off'**
  String sounds_stemOff(String name);

  /// Screen-reader label of an Aura Plus sound on Free. Calm, no pressure.
  ///
  /// In en, this message translates to:
  /// **'{name}, part of Aura Plus'**
  String sounds_stemLocked(String name);

  /// Screen-reader label (and line) of a sound that downloads when first picked.
  ///
  /// In en, this message translates to:
  /// **'{name}, {size} to download once'**
  String sounds_stemNeedsDownload(String name, String size);

  /// Screen-reader label while a sound downloads.
  ///
  /// In en, this message translates to:
  /// **'{name}, downloading'**
  String sounds_stemDownloading(String name);

  /// Screen-reader label of a sound's volume slider.
  ///
  /// In en, this message translates to:
  /// **'{name} volume'**
  String sounds_volume(String name);

  /// Small label on a sound that comes with Aura Plus (brand, not translated).
  ///
  /// In en, this message translates to:
  /// **'Aura Plus'**
  String get sounds_plusBadge;

  /// Shown when a Free user taps an Aura Plus sound. Calm, no pressure, no countdown.
  ///
  /// In en, this message translates to:
  /// **'Coming with Aura Plus.'**
  String get sounds_plusNote;

  /// Tapping a fifth sound.
  ///
  /// In en, this message translates to:
  /// **'Four sounds are playing. Turn one off to add another.'**
  String get sounds_full;

  /// Resumes paused sounds (fades in).
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get sounds_play;

  /// Pauses the sounds.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get sounds_pause;

  /// Stops all sounds and clears the mix.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sounds_stop;

  /// Opens the timer choices (15, 30, 60 min or off).
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get sounds_timer;

  /// Title of the timer sheet: the sound fades out and stops after the chosen time.
  ///
  /// In en, this message translates to:
  /// **'Fade out after'**
  String get sounds_timerTitle;

  /// Timer choice: no timer.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sounds_timerOff;

  /// Timer button with its setting, e.g. 'Timer · 30 minutes' or 'Timer · Off'.
  ///
  /// In en, this message translates to:
  /// **'Timer · {value}'**
  String sounds_timerValue(String value);

  /// While a timer runs.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Fades out in about 1 minute} other{Fades out in about {minutes} minutes}}'**
  String sounds_timerLeft(int minutes);

  /// The timer's last 30 seconds: the sound is fading to silence.
  ///
  /// In en, this message translates to:
  /// **'Fading out'**
  String get sounds_fadingOut;

  /// Saves the current sounds and volumes on this phone (no name to type).
  ///
  /// In en, this message translates to:
  /// **'Save this mix'**
  String get sounds_saveMix;

  /// Section header for mixes saved on this phone.
  ///
  /// In en, this message translates to:
  /// **'Saved mixes'**
  String get sounds_savedMixes;

  /// After saving a mix.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone.'**
  String get sounds_mixSaved;

  /// Saving a mix that is already in the list.
  ///
  /// In en, this message translates to:
  /// **'This mix is already saved.'**
  String get sounds_mixAlreadySaved;

  /// Screen-reader label of a saved mix, e.g. 'Play Rain · Chimes'.
  ///
  /// In en, this message translates to:
  /// **'Play {mix}'**
  String sounds_playMix(String mix);

  /// Screen-reader label of the ✕ on a saved mix.
  ///
  /// In en, this message translates to:
  /// **'Remove {mix}'**
  String sounds_removeMix(String mix);

  /// A saved mix whose sounds are all unavailable (e.g. Plus ended, download removed).
  ///
  /// In en, this message translates to:
  /// **'This mix can\'t play right now.'**
  String get sounds_mixUnavailable;

  /// Card offering the one-time download of the recorded base sounds.
  ///
  /// In en, this message translates to:
  /// **'Recorded sounds'**
  String get sounds_downloadTitle;

  /// Download card body. size = e.g. '8.1 MB' (shown before downloading).
  ///
  /// In en, this message translates to:
  /// **'{size} to download once. After that they play offline. Until then, sounds made on your phone play instead.'**
  String sounds_downloadBody(String size);

  /// Starts the one-time download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sounds_download;

  /// While the download runs.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get sounds_downloading;

  /// Download needs a connection. Calm: most sounds still play.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Brown noise and the sounds made on your phone play now; recordings can download later.'**
  String get sounds_downloadOffline;

  /// A download failed or didn't match its checksum (it was deleted).
  ///
  /// In en, this message translates to:
  /// **'The download didn\'t finish. Nothing is lost; you can download again later.'**
  String get sounds_downloadFailed;

  /// Storage full (PRD 06d copy). size = e.g. '8 MB'.
  ///
  /// In en, this message translates to:
  /// **'Sounds need about {size}. Free some space, or play brown noise, which needs none.'**
  String sounds_noSpace(String size);

  /// A download size in megabytes, e.g. '8.1 MB'.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sounds_megabytes(String size);

  /// Deletes the downloaded recordings from this phone.
  ///
  /// In en, this message translates to:
  /// **'Remove downloaded sounds'**
  String get sounds_removeDownloads;

  /// After removing downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloaded sounds removed. The sounds made on your phone still play.'**
  String get sounds_downloadsRemoved;

  /// Title of the full screen shown when this app is too old to keep using. Calm, a request, not an error.
  ///
  /// In en, this message translates to:
  /// **'Please update Aura'**
  String get update_title;

  /// Body under update_title. Plain words, no version numbers or reasons.
  ///
  /// In en, this message translates to:
  /// **'This copy of Aura needs an update before it can keep going. It only takes a moment.'**
  String get update_body;

  /// Reassurance under the body: nothing is deleted; unsynced check-ins are kept and sync after the update.
  ///
  /// In en, this message translates to:
  /// **'Everything on this phone stays safe. Your check-ins sync as soon as you\'ve updated.'**
  String get update_safe;

  /// Primary button on iPhone: opens Aura's App Store page.
  ///
  /// In en, this message translates to:
  /// **'Update in the App Store'**
  String get update_openAppStore;

  /// Primary button on Android: opens Aura's Google Play page.
  ///
  /// In en, this message translates to:
  /// **'Update on Google Play'**
  String get update_openPlayStore;

  /// Shown under the button when the store page could not be opened.
  ///
  /// In en, this message translates to:
  /// **'The store didn\'t open. Please open it yourself and search for Aura.'**
  String get update_storeFailed;

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

  /// Home-screen widget heading (F11). Same warmth as the check-in title.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get widget_prompt;

  /// Widget button / lock-screen star label that opens the check-in (F11). Short.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get widget_checkIn;

  /// Widget line once today has a check-in. Never says which mood.
  ///
  /// In en, this message translates to:
  /// **'Checked in today'**
  String get widget_doneToday;

  /// Widget confirmation after a two-tap check-in that earned no Starlight (day's cap reached).
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get widget_saved;

  /// Widget confirmation after a two-tap check-in (F11 'Saved · +10 Starlight'). Provisional until the app imports it.
  ///
  /// In en, this message translates to:
  /// **'Saved · +{amount} Starlight'**
  String widget_savedStarlight(int amount);

  /// Widget link to the Safety Center (F9) on the larger widget sizes. Must feel safe to tap.
  ///
  /// In en, this message translates to:
  /// **'Need help'**
  String get widget_needHelp;

  /// Widget text while signed out or before setup (F11 edge case). Input is off.
  ///
  /// In en, this message translates to:
  /// **'Open Aura to continue'**
  String get widget_openApp;

  /// Discreet widget text while signed out: no app name (F11 Discreet widget).
  ///
  /// In en, this message translates to:
  /// **'Open the app to continue'**
  String get widget_openAppDiscreet;

  /// Widget line when a time capsule is ready; it only opens in the app (F11).
  ///
  /// In en, this message translates to:
  /// **'Something from past you is waiting'**
  String get widget_capsuleWaiting;

  /// Widget button: from the four moods back to the four groups.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get widget_back;

  /// Widget line with the person's last mood. Only when 'Show my last mood' is on, home screen only.
  ///
  /// In en, this message translates to:
  /// **'Last: {mood}'**
  String widget_lastMood(String mood);

  /// Name of the home-screen widget in the OS widget gallery.
  ///
  /// In en, this message translates to:
  /// **'Aura check-in'**
  String get widget_galleryName;

  /// Description of the home-screen widget in the OS widget gallery.
  ///
  /// In en, this message translates to:
  /// **'Check in with two taps, right from your home screen.'**
  String get widget_galleryDescription;

  /// Name of the lock-screen widget (a star) in the iOS widget gallery.
  ///
  /// In en, this message translates to:
  /// **'Quick check-in'**
  String get widget_lockGalleryName;

  /// Description of the lock-screen widget in the iOS widget gallery (F11: lock screen shows only a star).
  ///
  /// In en, this message translates to:
  /// **'A star that opens your check-in. It never shows how you feel.'**
  String get widget_lockGalleryDescription;

  /// Settings section for the widget (F11).
  ///
  /// In en, this message translates to:
  /// **'Home-screen widget'**
  String get widget_settingsTitle;

  /// Settings toggle (off by default): the widget shows the last mood (F11).
  ///
  /// In en, this message translates to:
  /// **'Show my last mood'**
  String get widget_showLastMood;

  /// Note under 'Show my last mood' (F11 privacy: never on the lock screen or StandBy).
  ///
  /// In en, this message translates to:
  /// **'On your home screen only. The lock screen never shows it.'**
  String get widget_showLastMoodNote;

  /// Settings toggle (off by default) for the plain-star widget (F11 Discreet widget).
  ///
  /// In en, this message translates to:
  /// **'Discreet widget'**
  String get widget_discreet;

  /// Note under 'Discreet widget'.
  ///
  /// In en, this message translates to:
  /// **'A plain star with no app name and no mood words. Tapping it opens the app.'**
  String get widget_discreetNote;

  /// Habits editor section title for the opt-in world commitments (adults only).
  ///
  /// In en, this message translates to:
  /// **'Commitments'**
  String get habits_commitmentsTitle;

  /// Explains commitments before the switches. Must say plainly that Starlight and glow days are never affected and that one log restores the plant.
  ///
  /// In en, this message translates to:
  /// **'Pick the habits you want to keep close. If you miss a few days, that habit\'s plant in your world rests. One log wakes it. Your Starlight and glow days are never touched.'**
  String get habits_commitmentsBody;

  /// Subtitle under a habit's name on the commitment switch. Read by screen readers after the habit name.
  ///
  /// In en, this message translates to:
  /// **'Treat as a commitment'**
  String get habits_commitmentSwitch;

  /// Tooltip and screen-reader label for the pause menu of a committed habit.
  ///
  /// In en, this message translates to:
  /// **'Pause {name}'**
  String habits_pauseSemantic(String name);

  /// Subtitle of a committed habit while a pause is on. {date} is a short local date.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}'**
  String habits_pausedUntil(String date);

  /// Pause length choice in the pause menu.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String habits_pauseDays(int count);

  /// Pause menu item that ends a pause early.
  ///
  /// In en, this message translates to:
  /// **'End pause'**
  String get habits_pauseEnd;

  /// Heading of the accessible list of habit plants in the Habit Grove card.
  ///
  /// In en, this message translates to:
  /// **'Your plants'**
  String get universe_yourPlants;

  /// Grove summary when committed plants are resting. Warm; never a count of missed days, never 'dead' or 'lost'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{One plant is resting. A single log wakes it.} other{{count} plants are resting. A single log wakes each one.}}'**
  String universe_plantsResting(int count);

  /// Growth stage of a habit plant: no logs yet.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get universe_stage_seed;

  /// Growth stage of a habit plant.
  ///
  /// In en, this message translates to:
  /// **'Sprout'**
  String get universe_stage_sprout;

  /// Growth stage of a habit plant.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get universe_stage_young;

  /// Growth stage of a habit plant.
  ///
  /// In en, this message translates to:
  /// **'Grown'**
  String get universe_stage_grown;

  /// Growth stage of a habit plant.
  ///
  /// In en, this message translates to:
  /// **'Flourishing'**
  String get universe_stage_flourishing;

  /// Growth stage of a habit plant after a long time of care.
  ///
  /// In en, this message translates to:
  /// **'Ancient'**
  String get universe_stage_ancient;

  /// State of a committed habit plant after a few missed days. Never negative.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get universe_vitality_dimmed;

  /// State of a committed habit plant after several missed days. Gentle.
  ///
  /// In en, this message translates to:
  /// **'Drooping a little'**
  String get universe_vitality_wilting;

  /// State of a committed habit plant after a long break. It never disappears and one log wakes it.
  ///
  /// In en, this message translates to:
  /// **'Asleep, waiting for you'**
  String get universe_vitality_dormant;

  /// Screen-reader and visible label of one habit plant that is doing well.
  ///
  /// In en, this message translates to:
  /// **'{name}, {stage}'**
  String universe_plantRow(String name, String stage);

  /// Label of one habit plant that is resting, drooping or asleep. {state} is one of the vitality words.
  ///
  /// In en, this message translates to:
  /// **'{name}, {stage}, {state}'**
  String universe_plantRowResting(String name, String stage, String state);

  /// Title of the one-time card on returning to the personal universe after time away. Warm; no guilt, no numbers.
  ///
  /// In en, this message translates to:
  /// **'Your world is here'**
  String get universe_welcomeTitle;

  /// Body of the welcome-back card. Must not mention days away, streaks or anything missed.
  ///
  /// In en, this message translates to:
  /// **'Everything is right where you left it. Come back to it whenever you like, in any way that feels doable.'**
  String get universe_welcomeBody;

  /// Welcome-back card button that opens the ordinary quick check-in.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get universe_welcomeCheckIn;

  /// Welcome-back card button that dismisses the card; nothing is required.
  ///
  /// In en, this message translates to:
  /// **'Just look around'**
  String get universe_welcomeExplore;
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
