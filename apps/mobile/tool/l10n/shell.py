# App shell (five-position navigation) and Safety Center copy. Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta. The
# Safety Center line also needs the safe-messaging self-review (A9).

# ---- Navigation bar: Home · Sanctuary · [Check in] · Rooms · Insights ------
# Tab labels are short nouns; they may wrap to two lines at large text.
s("shell_tabHome", "Home", "Navigation bar tab: the companion-led today view.", "హోమ్", "Home", hi="होम", hl="Home")
s("shell_tabSanctuary", "Sanctuary", "Navigation bar tab: the private calm space (breathing, grounding). Same name as the Sanctuary screen title.", "ప్రశాంత నిలయం", "Sanctuary", hi="सुकून", hl="Sanctuary")
s("shell_tabRooms", "Rooms", "Navigation bar tab: mood rooms with preset gestures. Never 'chat'.", "రూమ్‌లు", "Rooms", hi="रूम", hl="Rooms")
s("shell_tabInsights", "Insights", "Navigation bar tab: private history and gentle patterns. Never clinical.", "అవగాహన", "Insights", hi="समझ", hl="Insights")
s("shell_checkIn", "Check in", "The distinct centre action of the navigation bar: opens a new check-in (not a tab).", "చెక్-ఇన్", "Check in", hi="चेक-इन", hl="Check-in")
s("shell_checkInHint", "Starts a new check-in", "Screen-reader hint on the centre Check in action, so it is not taken for a tab.", "కొత్త చెక్-ఇన్ మొదలవుతుంది", "Kotha check-in modalavutundi", hi="नया चेक-इन शुरू करता है", hl="Naya check-in shuru karta hai")

# ---- Safety Center (/safety, F9) --------------------------------------------
# Title and intro reuse help_title / help_subtitle; helplines, grounding and
# the disclaimer reuse the support sheet's copy.
s("safety_emergencyWhen", "Call emergency services right away if you or someone near you is in immediate danger, badly hurt, or can't stay safe.", "Safety Center: when to call emergency services instead of a helpline. Direct and calm; never names a method (REQ-SAFE-15).", "మీరు గానీ, మీ దగ్గర ఉన్నవారు గానీ తక్షణ ప్రమాదంలో ఉన్నా, తీవ్రంగా గాయపడినా, సురక్షితంగా ఉండలేకపోయినా వెంటనే అత్యవసర సేవలకు కాల్ చేయండి.", "Meeru gaani, mee daggara unnavaallu gaani ventane danger lo unna, baaga gaayapadina, leda safe ga undaleka poyina, ventane emergency services ki call cheyandi.", hi="अगर आपको या आपके आसपास किसी को तुरंत खतरा है, गंभीर चोट लगी है, या सुरक्षित रह पाना मुश्किल है, तो तुरंत इमरजेंसी सेवाओं को कॉल करें।", hl="Agar aapko ya aapke aas-paas kisi ko turant khatra hai, gambhir chot lagi hai, ya safe reh paana mushkil hai, to turant emergency services ko call karein.")
s("safety_settingsLink", "Help & Safety in Settings", "Safety Center link (signed in only) to Settings › Help & Safety.", "సెట్టింగ్‌లలో సహాయం & భద్రత", "Settings lo Help & Safety", hi="सेटिंग्स में मदद और सुरक्षा", hl="Settings mein Help & Safety")
s("safety_settingsHint", "Support contact, Grievance Officer and policies", "Screen-reader hint on the link above: what that Settings section holds.", "సపోర్ట్ సంప్రదింపు, గ్రీవెన్స్ ఆఫీసర్, విధానాలు", "Support contact, Grievance Officer, policies", hi="सपोर्ट संपर्क, शिकायत अधिकारी और नीतियाँ", hl="Support contact, Grievance Officer aur policies")
