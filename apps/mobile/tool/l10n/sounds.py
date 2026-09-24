# Sanctuary › Sounds (F15, Milestone B): the stem mixer, timer, night
# wind-down, saved mixes and the one-time download. Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before beta.
#
# Copy rules (PRD 06d, REQ-SAN-12): say what it is, never what it achieves.
# No "binaural", "heal", "cure", "treat", "therapy", "clinically", and no
# sleep or health outcome claims (test/sounds_screen_test.dart lints this).
# Plus copy is calm: no countdowns, no "unlock", no pressure.

# ---- Sanctuary card and screen ---------------------------------------------------
s("sounds_title", "Sounds", "Title of Sanctuary › Sounds: ambient sounds to mix (rain, ocean, wind…). Also the Sanctuary section header.", "శబ్దాలు", "Sounds")
s("sounds_cardBody", "Rain, ocean, wind and more. Nothing plays until you choose.", "Under the Sounds card on the Sanctuary tab.", "వర్షం, సముద్రం, గాలి ఇంకా మరెన్నో. మీరు ఎంచుకునే వరకు ఏదీ వినిపించదు.", "Rain, ocean, wind inka marenno. Meeru select chese varaku edi vinipinchadu.")
s("sounds_cardPlaying", "Playing now", "Under the Sounds card while sounds are playing.", "ఇప్పుడు వినిపిస్తోంది", "Ippudu play avutondi")
s("sounds_intro", "Pick a sound to begin, or mix up to four. Nothing plays until you tap.", "Intro at the top of Sounds. Promise: silent until chosen.", "మొదలుపెట్టడానికి ఒక శబ్దం ఎంచుకోండి, లేదా నాలుగు వరకు కలపండి. మీరు నొక్కే వరకు ఏదీ వినిపించదు.", "Modalupettadaaniki oka sound select cheyandi, leda naalugu varaku kalapandi. Meeru tap chese varaku edi vinipinchadu.")
s("sounds_nothingPlaying", "Nothing playing", "Status line (also for screen readers) when no sound plays.", "ఏదీ వినిపించడం లేదు", "Edi play avvadam ledu")
s("sounds_statePlaying", "Playing", "Status line while sounds play.", "వినిపిస్తోంది", "Play avutondi")
s("sounds_statePaused", "Paused", "Status line while sounds are paused.", "ఆగింది", "Aagindi")
s("sounds_backgroundNote", "Sounds keep playing with the screen off. They pause if your headphones disconnect or a call comes in.", "Small note at the bottom of Sounds.", "స్క్రీన్ ఆఫ్ అయినా శబ్దాలు వినిపిస్తూనే ఉంటాయి. హెడ్‌ఫోన్లు డిస్‌కనెక్ట్ అయినా, కాల్ వచ్చినా ఆగుతాయి.", "Screen off ayina sounds vinipistune untaayi. Headphones disconnect ayina, call vachina aagutaayi.")
s("sounds_notificationChannel", "Sounds playback", "Android notification channel name for the Sounds media controls (Settings › Notifications).", "శబ్దాల ప్లేబ్యాక్", "Sounds playback")

# ---- Night wind-down -------------------------------------------------------------
s("sounds_windDownTitle", "Night wind-down", "A ~20-minute sequence of sounds that slowly thins out to silence. No voice, no claims.", "రాత్రి ప్రశాంత శబ్దాలు", "Night wind-down")
s("sounds_windDownBody", "About 20 minutes of sounds that slowly thin out to silence. The order changes each night.", "Under the wind-down title.", "సుమారు 20 నిమిషాల శబ్దాలు, మెల్లగా తగ్గుతూ నిశ్శబ్దంలోకి వెళ్తాయి. ప్రతి రాత్రి వాటి క్రమం మారుతుంది.", "Sumaaru 20 nimishaala sounds, mellaga taggutu nishabdam loki veltaayi. Prati raatri vaati order maarutundi.")
s("sounds_windDownBegin", "Begin wind-down", "Starts the night wind-down.", "మొదలుపెట్టండి", "Wind-down modalupettandi")
s("sounds_windDownLeft", "{minutes, plural, =1{About 1 minute left} other{About {minutes} minutes left}}", "While the wind-down plays: roughly how long until it has faded to silence.", "{minutes, plural, =1{సుమారు 1 నిమిషం మిగిలింది} other{సుమారు {minutes} నిమిషాలు మిగిలాయి}}", "{minutes, plural, =1{Sumaaru 1 nimisham migilindi} other{Sumaaru {minutes} nimishaalu migilaayi}}", INT("minutes"))
s("sounds_windDownBusy", "The wind-down is playing. Stop it to make your own mix.", "Tapping a sound while the wind-down plays.", "రాత్రి శబ్దాలు వినిపిస్తున్నాయి. మీ సొంత మిక్స్ కోసం ముందు వాటిని ఆపండి.", "Wind-down play avutondi. Mee sonta mix kosam mundu daanni aapandi.")

# ---- Mixer -----------------------------------------------------------------------
s("sounds_mixSection", "Mix your own", "Section header above the list of sounds.", "మీకు నచ్చినట్టు కలపండి", "Mee sonta mix")
s("sounds_mixHint", "Up to four at once, each with its own volume.", "Under the mixer header.", "ఒకేసారి నాలుగు వరకు, ఒక్కోదానికి వేరే వాల్యూమ్.", "Okesaari naalugu varaku, okkodaaniki vere volume.")
s("sounds_stemRain", "Rain", "Sound: steady rain.", "వర్షం", "Rain")
s("sounds_stemOcean", "Ocean", "Sound: ocean waves.", "సముద్రం", "Ocean")
s("sounds_stemWind", "Wind", "Sound: wind.", "గాలి", "Gaali")
s("sounds_stemNightInsects", "Night insects", "Sound: crickets and insects at night.", "రాత్రి కీటకాలు", "Night keetakaalu")
s("sounds_stemSingingBowl", "Singing bowl", "Sound: a singing bowl struck now and then.", "సింగింగ్ బౌల్", "Singing bowl")
s("sounds_stemChimes", "Chimes", "Sound: wind chimes.", "గాలి గంటలు", "Chimes")
s("sounds_stemBrownNoise", "Brown noise", "Sound: soft, deep steady noise (generated on the phone).", "బ్రౌన్ నాయిస్", "Brown noise")
s("sounds_stemPinkNoise", "Pink noise", "Aura Plus sound: soft steady noise.", "పింక్ నాయిస్", "Pink noise")
s("sounds_stemDeepBell", "Distant bell", "Aura Plus sound: a low bell far away.", "దూరపు గంట", "Doorapu ganta")
s("sounds_stemMonsoonRoof", "Monsoon on a roof", "Aura Plus sound: heavy monsoon rain on a roof.", "పైకప్పు మీద వాన", "Paikappu meeda vaana")
s("sounds_stemStream", "Stream", "Aura Plus sound: a flowing stream.", "వాగు", "Vaagu")
s("sounds_stemFireplace", "Fireplace", "Aura Plus sound: a crackling fire.", "మంట చిటపటలు", "Manta chitapatalu")
s("sounds_stemDistantThunder", "Distant thunder", "Aura Plus sound: soft thunder far away.", "దూరపు ఉరుములు", "Doorapu urumulu")
s("sounds_stemOn", "{name}, playing, volume {percent}%", "Screen-reader label of a sound that is on, e.g. 'Rain, playing, volume 60%'.", "{name}, వినిపిస్తోంది, వాల్యూమ్ {percent}%", "{name}, play avutondi, volume {percent}%", {"name": {"type": "String"}, "percent": {"type": "int"}})
s("sounds_stemPaused", "{name}, paused, volume {percent}%", "Screen-reader label of a sound in the mix while paused.", "{name}, ఆగింది, వాల్యూమ్ {percent}%", "{name}, aagindi, volume {percent}%", {"name": {"type": "String"}, "percent": {"type": "int"}})
s("sounds_stemOff", "{name}, off", "Screen-reader label of a sound that is not playing. Tapping it adds it.", "{name}, ఆఫ్", "{name}, off", STR("name"))
s("sounds_stemLocked", "{name}, part of Aura Plus", "Screen-reader label of an Aura Plus sound on Free. Calm, no pressure.", "{name}, Aura Plusలో భాగం", "{name}, Aura Plus lo bhaagam", STR("name"))
s("sounds_stemNeedsDownload", "{name}, {size} to download once", "Screen-reader label (and line) of a sound that downloads when first picked.", "{name}, ఒకసారి {size} డౌన్‌లోడ్ చేయాలి", "{name}, okasaari {size} download cheyaali", STR("name", "size"))
s("sounds_stemDownloading", "{name}, downloading", "Screen-reader label while a sound downloads.", "{name}, డౌన్‌లోడ్ అవుతోంది", "{name}, download avutondi", STR("name"))
s("sounds_volume", "{name} volume", "Screen-reader label of a sound's volume slider.", "{name} వాల్యూమ్", "{name} volume", STR("name"))
s("sounds_plusBadge", "Aura Plus", "Small label on a sound that comes with Aura Plus (brand, not translated).", "Aura Plus", "Aura Plus")
s("sounds_plusNote", "Coming with Aura Plus.", "Shown when a Free user taps an Aura Plus sound. Calm, no pressure, no countdown.", "Aura Plusతో వస్తుంది.", "Aura Plus tho vastundi.")
s("sounds_full", "Four sounds are playing. Turn one off to add another.", "Tapping a fifth sound.", "నాలుగు శబ్దాలు వినిపిస్తున్నాయి. ఇంకొకటి జోడించడానికి ఒకదాన్ని ఆపండి.", "Naalugu sounds play avutunnaayi. Inkokati add cheyadaaniki okadaanni aapandi.")

# ---- Transport and timer ----------------------------------------------------------
s("sounds_play", "Play", "Resumes paused sounds (fades in).", "వినిపించండి", "Play")
s("sounds_pause", "Pause", "Pauses the sounds.", "ఆపండి", "Pause")
s("sounds_stop", "Stop", "Stops all sounds and clears the mix.", "ముగించండి", "Stop")
s("sounds_timer", "Timer", "Opens the timer choices (15, 30, 60 min or off).", "టైమర్", "Timer")
s("sounds_timerTitle", "Fade out after", "Title of the timer sheet: the sound fades out and stops after the chosen time.", "ఇంత సమయం తర్వాత మెల్లగా ఆగుతుంది", "Inta time tarvaata mellaga aagutundi")
s("sounds_timerOff", "Off", "Timer choice: no timer.", "ఆఫ్", "Off")
s("sounds_timerValue", "Timer · {value}", "Timer button with its setting, e.g. 'Timer · 30 minutes' or 'Timer · Off'.", "టైమర్ · {value}", "Timer · {value}", STR("value"))
s("sounds_timerLeft", "{minutes, plural, =1{Fades out in about 1 minute} other{Fades out in about {minutes} minutes}}", "While a timer runs.", "{minutes, plural, =1{సుమారు 1 నిమిషంలో మెల్లగా ఆగుతుంది} other{సుమారు {minutes} నిమిషాల్లో మెల్లగా ఆగుతుంది}}", "{minutes, plural, =1{Sumaaru 1 nimisham lo mellaga aagutundi} other{Sumaaru {minutes} nimishaallo mellaga aagutundi}}", INT("minutes"))
s("sounds_fadingOut", "Fading out", "The timer's last 30 seconds: the sound is fading to silence.", "మెల్లగా ఆగుతోంది", "Mellaga aagutondi")

# ---- Saved mixes -----------------------------------------------------------------
s("sounds_saveMix", "Save this mix", "Saves the current sounds and volumes on this phone (no name to type).", "ఈ మిక్స్ సేవ్ చేయండి", "Ee mix save cheyandi")
s("sounds_savedMixes", "Saved mixes", "Section header for mixes saved on this phone.", "సేవ్ చేసిన మిక్స్‌లు", "Save chesina mixes")
s("sounds_mixSaved", "Saved on this phone.", "After saving a mix.", "ఈ ఫోన్‌లో సేవ్ అయింది.", "Ee phone lo save ayyindi.")
s("sounds_mixAlreadySaved", "This mix is already saved.", "Saving a mix that is already in the list.", "ఈ మిక్స్ ఇప్పటికే సేవ్ అయి ఉంది.", "Ee mix ippatike save ayyi undi.")
s("sounds_playMix", "Play {mix}", "Screen-reader label of a saved mix, e.g. 'Play Rain · Chimes'.", "{mix} వినిపించండి", "{mix} play cheyandi", STR("mix"))
s("sounds_removeMix", "Remove {mix}", "Screen-reader label of the ✕ on a saved mix.", "{mix} తీసేయండి", "{mix} teeseyandi", STR("mix"))
s("sounds_mixUnavailable", "This mix can't play right now.", "A saved mix whose sounds are all unavailable (e.g. Plus ended, download removed).", "ఈ మిక్స్ ఇప్పుడు వినిపించదు.", "Ee mix ippudu play avvadu.")

# ---- Download and storage (PRD 16-offline: full after one download) -------------------
s("sounds_downloadTitle", "Recorded sounds", "Card offering the one-time download of the recorded base sounds.", "రికార్డ్ చేసిన శబ్దాలు", "Recorded sounds")
s("sounds_downloadBody", "{size} to download once. After that they play offline. Until then, sounds made on your phone play instead.", "Download card body. size = e.g. '8.1 MB' (shown before downloading).", "ఒకసారి {size} డౌన్‌లోడ్ చేయాలి. ఆ తర్వాత ఇంటర్నెట్ లేకుండానే వినిపిస్తాయి. అప్పటివరకు మీ ఫోన్‌లోనే తయారైన శబ్దాలు వినిపిస్తాయి.", "Okasaari {size} download cheyaali. Aa tarvaata internet lekundaane vinipistaayi. Appativaraku mee phone lone tayaaraina sounds vinipistaayi.", STR("size"))
s("sounds_download", "Download", "Starts the one-time download.", "డౌన్‌లోడ్ చేయండి", "Download cheyandi")
s("sounds_downloading", "Downloading…", "While the download runs.", "డౌన్‌లోడ్ అవుతోంది…", "Download avutondi…")
s("sounds_downloadOffline", "You're offline. Brown noise and the sounds made on your phone play now; recordings can download later.", "Download needs a connection. Calm: most sounds still play.", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. బ్రౌన్ నాయిస్, మీ ఫోన్‌లో తయారైన శబ్దాలు ఇప్పుడే వినిపిస్తాయి; రికార్డింగ్‌లు తర్వాత డౌన్‌లోడ్ చేసుకోవచ్చు.", "Meeru offline lo unnaru. Brown noise, mee phone lo tayaaraina sounds ippude vinipistaayi; recordings tarvaata download chesukovachu.")
s("sounds_downloadFailed", "The download didn't finish. Nothing is lost; you can download again later.", "A download failed or didn't match its checksum (it was deleted).", "డౌన్‌లోడ్ పూర్తి కాలేదు. ఏదీ పోలేదు; తర్వాత మళ్ళీ డౌన్‌లోడ్ చేసుకోవచ్చు.", "Download purti kaaledu. Edi poledu; tarvaata malli download chesukovachu.")
s("sounds_noSpace", "Sounds need about {size}. Free some space, or play brown noise, which needs none.", "Storage full (PRD 06d copy). size = e.g. '8 MB'.", "శబ్దాలకు సుమారు {size} కావాలి. కొంత స్థలం ఖాళీ చేయండి, లేదా బ్రౌన్ నాయిస్ వినండి, దానికి ఏమీ అవసరం లేదు.", "Sounds ki sumaaru {size} kaavaali. Konta space khaali cheyandi, leda brown noise vinandi, daaniki emi avasaram ledu.", STR("size"))
s("sounds_megabytes", "{size} MB", "A download size in megabytes, e.g. '8.1 MB'.", "{size} MB", "{size} MB", STR("size"))
s("sounds_removeDownloads", "Remove downloaded sounds", "Deletes the downloaded recordings from this phone.", "డౌన్‌లోడ్ చేసిన శబ్దాలు తీసేయండి", "Download chesina sounds teeseyandi")
s("sounds_downloadsRemoved", "Downloaded sounds removed. The sounds made on your phone still play.", "After removing downloads.", "డౌన్‌లోడ్ చేసిన శబ్దాలు తీసేశాం. మీ ఫోన్‌లో తయారైన శబ్దాలు ఇంకా వినిపిస్తాయి.", "Download chesina sounds teesesaam. Mee phone lo tayaaraina sounds inka vinipistaayi.")
