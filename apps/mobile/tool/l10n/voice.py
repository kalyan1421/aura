# Voice notes (F1: ≤ 60 s, private, not crisis-scanned). Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.

# ---- capture (check-in details and the 24 h edit) ----------------------------
s("voice_record", "Record a voice note", "Button in the check-in details that starts recording a voice note (also its screen-reader label).", "వాయిస్ నోట్ రికార్డ్ చేయండి", "Voice note record cheyandi")
s("voice_recordHint", "Up to a minute. Only you can hear it.", "Hint under the record button: the 60-second limit and that it is private. Calm.", "ఒక నిమిషం వరకు. ఇది మీకు మాత్రమే వినిపిస్తుంది.", "Oka nimisham varaku. Idi meeku maatrame vinipistundi.")
s("voice_rationaleTitle", "Add your voice?", "Title of the explainer shown before the microphone permission prompt (first mic tap).", "మీ గొంతు కూడా జోడిస్తారా?", "Mee gonthu kooda jodistaara?")
s("voice_rationaleBody", "To record a voice note, Aura needs your microphone. Recordings stay private to you and are never shared in rooms.", "Microphone explainer before the OS prompt (PRD 15-permissions wording).", "వాయిస్ నోట్ రికార్డ్ చేయడానికి Auraకి మీ మైక్రోఫోన్ కావాలి. రికార్డింగ్‌లు మీకు మాత్రమే ఉంటాయి, రూమ్‌లలో ఎప్పుడూ షేర్ కావు.", "Voice note record cheyadaaniki Aura ki mee microphone kaavaali. Recordings meeku maatrame untaayi, rooms lo eppudu share kaavu.")
s("voice_rationaleAllow", "Allow", "Microphone explainer button: shows the OS permission prompt. 'Not now' never does.", "అనుమతించండి", "Allow cheyandi")
s("voice_denied", "Voice is off. Type instead, or turn it on in Settings.", "Shown when the microphone permission is denied (PRD states 'Edge: mic denied'). Typing still works. Calm, no blame.", "వాయిస్ ఆఫ్‌లో ఉంది. బదులుగా టైప్ చేయండి, లేదా సెట్టింగ్‌లలో ఆన్ చేయండి.", "Voice off lo undi. Badulu ga type cheyandi, leda Settings lo on cheyandi.")
s("voice_openSettings", "Settings", "Link next to 'Voice is off' that opens this app's page in the phone's Settings.", "సెట్టింగ్‌లు", "Settings")
s("voice_recording", "Recording", "Status while a voice note is being recorded.", "రికార్డ్ అవుతోంది", "Record avutondi")
s("voice_elapsed", "{time} · up to {limit}", "Elapsed recording time next to the limit, e.g. '0:12 · up to 1:00'. Calm, not a countdown.", "{time} · {limit} వరకు", "{time} · {limit} varaku", STR("time", "limit"))
s("voice_recordingFor", "{seconds, plural, =1{Recording, 1 second} other{Recording, {seconds} seconds}}", "Screen-reader text for the recording time.", "{seconds, plural, =1{రికార్డ్ అవుతోంది, 1 సెకను} other{రికార్డ్ అవుతోంది, {seconds} సెకన్లు}}", "{seconds, plural, =1{Record avutondi, 1 second} other{Record avutondi, {seconds} seconds}}", INT("seconds"))
s("voice_stop", "Stop recording", "Button that stops recording (also its screen-reader label).", "రికార్డింగ్ ఆపండి", "Recording aapandi")
s("voice_started", "Recording started", "Screen-reader announcement when recording starts.", "రికార్డింగ్ మొదలైంది", "Recording modalaindi")
s("voice_recorded", "{seconds, plural, =1{Voice note recorded, 1 second} other{Voice note recorded, {seconds} seconds}}", "Screen-reader announcement when recording stops.", "{seconds, plural, =1{వాయిస్ నోట్ రికార్డ్ అయింది, 1 సెకను} other{వాయిస్ నోట్ రికార్డ్ అయింది, {seconds} సెకన్లు}}", "{seconds, plural, =1{Voice note record ayyindi, 1 second} other{Voice note record ayyindi, {seconds} seconds}}", INT("seconds"))
s("voice_limitReached", "That's the full minute, so recording stopped. Your voice note is ready.", "Calm note after recording stopped by itself at 60 seconds. No alarm.", "ఒక నిమిషం పూర్తయింది, అందుకే రికార్డింగ్ ఆగింది. మీ వాయిస్ నోట్ సిద్ధంగా ఉంది.", "Oka nimisham purthayyindi, anduke recording aagindi. Mee voice note ready ga undi.")
s("voice_recordFailed", "Voice couldn't be recorded just now. Your words still save.", "Recording could not start or finish (e.g. the phone is out of space). Calm.", "ఇప్పుడు వాయిస్ రికార్డ్ కాలేదు. మీ మాటలు మాత్రం సేవ్ అవుతాయి.", "Ippudu voice record avvaledu. Mee maatalu maatram save avutaayi.")

# ---- a recorded / saved voice note ------------------------------------------
s("voice_note", "Voice note", "Label of a recorded voice note (in the check-in and on a history entry).", "వాయిస్ నోట్", "Voice note")
s("voice_length", "{seconds, plural, =1{1 second} other{{seconds} seconds}}", "Screen-reader length of a voice note.", "{seconds, plural, =1{1 సెకను} other{{seconds} సెకన్లు}}", "{seconds, plural, =1{1 second} other{{seconds} seconds}}", INT("seconds"))
s("voice_play", "Play voice note", "Play button (screen-reader label).", "వాయిస్ నోట్ ప్లే చేయండి", "Voice note play cheyandi")
s("voice_pause", "Pause voice note", "Pause button (screen-reader label).", "వాయిస్ నోట్ ఆపండి", "Voice note pause cheyandi")
s("voice_reRecord", "Record again", "Replace the voice note with a new recording.", "మళ్ళీ రికార్డ్ చేయండి", "Malli record cheyandi")
s("voice_remove", "Remove", "Remove the voice note from this check-in.", "తీసేయండి", "Teeseyandi")
s("voice_removeSemantic", "Remove voice note", "Screen-reader label of the Remove button.", "వాయిస్ నోట్ తీసేయండి", "Voice note teeseyandi")
s("voice_dropped", "Your check-in is saved. The voice note couldn't be kept, as your phone may be low on space.", "After saving when the voice file could not be stored (PRD F1 'Storage full: text saves; voice is dropped with a notice'). Calm, no blame.", "మీ చెక్-ఇన్ సేవ్ అయింది. ఫోన్‌లో స్థలం తక్కువగా ఉండటం వల్ల వాయిస్ నోట్ ఉంచలేకపోయాం.", "Mee check-in save ayyindi. Phone lo space takkuva ga undatam valla voice note unchalekapoyaam.")

# ---- playback on a history entry -------------------------------------------
s("voice_loading", "Getting your voice note…", "While a voice note is fetched or opened for playback.", "మీ వాయిస్ నోట్ తెస్తున్నాం…", "Mee voice note testunnaam…")
s("voice_offline", "The voice note plays when you're back online.", "A voice note that is only on the server, while offline. Calm.", "మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక వాయిస్ నోట్ ప్లే అవుతుంది.", "Meeru malli online ki vachaaka voice note play avutundi.")
s("voice_failed", "This voice note couldn't be played just now. Try again in a moment.", "Playback failed (download or file problem). Calm; the play button retries.", "ఈ వాయిస్ నోట్ ఇప్పుడు ప్లే కాలేదు. కాసేపాగి మళ్ళీ ప్రయత్నించండి.", "Ee voice note ippudu play avvaledu. Kaasepaagi malli try cheyandi.")
s("voice_section", "Your voice", "Section header for the voice note on a check-in's page.", "మీ గొంతు", "Mee gonthu")
s("voice_hasVoice", "Has a voice note", "Screen-reader label for the voice icon on a history row.", "ఒక వాయిస్ నోట్ ఉంది", "Oka voice note undi")
