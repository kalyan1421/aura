# Native Sign in with Apple / Google copy (F8 REQ-ACC-01). Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# Telugu / Tenglish: first drafts, NEED NATIVE REVIEW before alpha.

# Button titles: only the brands' approved phrases, localized with the same
# meaning (Apple HIG: "Continue with Apple"; Google branding: "Continue with
# Google"). Brand names stay in Latin script.
edit("signin_apple", desc="Sign in with Apple button title. Apple allows only 'Sign in with Apple', 'Sign up with Apple' or 'Continue with Apple' (localized, same meaning). Keep 'Apple' in Latin script. Shown only when Apple sign-in is set up for the build.")
edit("signin_google", desc="Sign in with Google button label. Google allows only 'Sign in with Google', 'Sign up with Google' or 'Continue with Google' (localized, same meaning). Keep 'Google' in Latin script. Shown only when Google sign-in is set up for the build.")

s("signin_or", "or", "Divider between the email sign-in and the Apple / Google buttons. Lower case, one word.", "లేదా", "leda")
s("signin_socialNotReady", "That sign-in option isn't ready yet. Use your email for now.", "Apple or Google sign-in isn't set up (server or build). Calm, no blame; points to email.", "ఆ సైన్-ఇన్ ఆప్షన్ ఇంకా సిద్ధంగా లేదు. ప్రస్తుతానికి మీ ఈమెయిల్ వాడండి.", "Aa sign-in option inka ready ga ledu. Prastutaaniki mee email vaadandi.")
s("signin_socialOffline", "It looks like you're offline. Try again when you're connected.", "Apple or Google sign-in couldn't reach the server (no connection). Calm, no blame.", "మీరు ఆఫ్‌లైన్‌లో ఉన్నట్టున్నారు. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.", "Meeru offline lo unnattunnaru. Connect ayyaaka malli try cheyandi.")
