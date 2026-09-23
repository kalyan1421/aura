import 'package:aura/src/features/support/crisis_lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

/// The on-device crisis lexicon (F9 L1): positives in every shipped
/// language, the idioms that must never open the crisis sheet, and the
/// zero-width / NFC / spacing tricks (PRD 18 "Moderation lexicons").
void main() {
  void expectVerdict(String text, LexiconVerdict verdict) => expect(
    lexiconVerdict(text),
    verdict,
    reason: 'text: ${text.runes.map((r) => r.toRadixString(16)).join(' ')}',
  );

  group('English', () {
    for (final text in [
      'I want to kill myself',
      'honestly I just want to die',
      'thinking about suicide',
      'I feel suicidal tonight',
      'I want to end my life',
      'everyone would be better off without me',
      'there is no reason to live',
      "I don't want to live",
      "I can't go on like this",
      'I keep hurting myself on purpose',
      'started self-harming again',
    ]) {
      test('crisis: "$text"', () {
        expectVerdict(text, LexiconVerdict.crisis);
        expect(noteNeedsSupport(text), isTrue);
      });
    }

    for (final text in [
      'killing it at work',
      'dead tired',
      'I want to diet before the wedding',
      'my grandma died last year',
      'skill myself up this term',
      'Today was calm. Tea with Amma.',
      '',
      '   ',
    ]) {
      test('none: "$text"', () {
        expectVerdict(text, LexiconVerdict.none);
        expect(noteNeedsSupport(text), isFalse);
      });
    }

    for (final text in [
      'I could die laughing',
      'dying of boredom in this lecture',
      'bored to death',
      'I was killing myself laughing',
      'I want to die of boredom',
      'I nearly died of embarrassment',
    ]) {
      test('soft, never crisis: "$text"', () {
        expectVerdict(text, LexiconVerdict.soft);
        expect(noteNeedsSupport(text), isFalse);
      });
    }

    test('an idiom only explains crisis words in its own clause', () {
      expectVerdict(
        'I want to die. Dying of boredom too.',
        LexiconVerdict.crisis,
      );
      expectVerdict(
        'I keep killing myself. Laughing is hard.',
        LexiconVerdict.crisis,
      );
      expectVerdict(
        'I keep killing myself\nlaughing is hard',
        LexiconVerdict.crisis,
      );
    });

    test('negation is not parsed: a gentle sheet is the better mistake', () {
      expectVerdict("I don't want to kill myself", LexiconVerdict.crisis);
    });
  });

  group('Telugu', () {
    for (final text in [
      'నాకు చచ్చిపోవాలని ఉంది',
      'చనిపోవాలనిపిస్తోంది',
      'ఆత్మహత్య ఆలోచనలు వస్తున్నాయి',
      'ఇంక బతకాలని లేదు',
      'నన్ను నేను చంపుకుంటాను',
    ]) {
      test('crisis: "$text"', () => expectVerdict(text, LexiconVerdict.crisis));
    }

    test('soft: laughing / boredom idioms', () {
      expectVerdict('నవ్వి నవ్వి చచ్చిపోయాను', LexiconVerdict.soft);
      expectVerdict('బోర్ కొట్టి చచ్చిపోతున్నా', LexiconVerdict.soft);
    });

    test('none: bereavement and ordinary notes', () {
      expectVerdict('మా అమ్మమ్మ చనిపోయారు', LexiconVerdict.none);
      expectVerdict('ఈరోజు ప్రశాంతంగా ఉంది', LexiconVerdict.none);
    });

    test('in the middle of English or Tenglish text', () {
      expectVerdict('today naaku చచ్చిపోవాలని undi', LexiconVerdict.crisis);
    });
  });

  group('Tenglish', () {
    for (final text in [
      'naaku chachipovalani undi',
      'chachipovalanipistundi',
      'sachipovaali ani undi',
      'inka bratakalani ledu',
      'atmahatya gurinchi alochistunna',
      'aatmahatyalu',
      'nenu chachipotha',
    ]) {
      test('crisis: "$text"', () => expectVerdict(text, LexiconVerdict.crisis));
    }

    for (final text in [
      'navvi navvi chachipoya',
      'navvi navvi chachipoyanu ra',
      'bore kotti chachipotunna',
    ]) {
      test('soft: "$text"', () => expectVerdict(text, LexiconVerdict.soft));
    }

    test('word boundaries: a crisis word inside another word is not a hit', () {
      expectVerdict('achachipotha', LexiconVerdict.none);
      expectVerdict('chachipothaamlo', LexiconVerdict.none);
    });
  });

  group('tricks', () {
    test('zero-width characters are stripped', () {
      expectVerdict('ki\u200Bll myself', LexiconVerdict.crisis);
      expectVerdict('sui\u200Dcide', LexiconVerdict.crisis);
      expectVerdict('want\u2060 to die', LexiconVerdict.crisis);
      expectVerdict('చచ్చి\u200Cపోవాలని', LexiconVerdict.crisis);
      expectVerdict('\uFEFFsuicide\u00AD', LexiconVerdict.crisis);
    });

    test('words run together match the phrase', () {
      expectVerdict('kill\u200Bmyself', LexiconVerdict.crisis);
      expectVerdict('wanttodie', LexiconVerdict.crisis);
    });

    test('NFC and accents: composed and decomposed forms match alike', () {
      expectVerdict('I want to díe', LexiconVerdict.crisis); // U+00ED
      expectVerdict('I want to di\u0301e', LexiconVerdict.crisis);
      expectVerdict('SUİCİDE', LexiconVerdict.crisis); // U+0130
    });

    test('case, spacing and line breaks', () {
      expectVerdict('I WANT TO DIE', LexiconVerdict.crisis);
      expectVerdict('want   to\n\n die', LexiconVerdict.crisis);
      expectVerdict('want\u00A0to\u2003die', LexiconVerdict.crisis);
      expectVerdict('ఇంక బతకాలని\nలేదు', LexiconVerdict.crisis);
    });

    test('apostrophes, straight or curly, fold away', () {
      expectVerdict('I can’t go on anymore', LexiconVerdict.crisis);
      expectVerdict('I cant go on anymore', LexiconVerdict.crisis);
      expectVerdict("I can't go on anymore", LexiconVerdict.crisis);
    });

    test('digits inside words read as letters; plain numbers stay numbers', () {
      expectVerdict('k1ll mys3lf', LexiconVerdict.crisis);
      expectVerdict('su1c1de', LexiconVerdict.crisis);
      expectVerdict('slept 4 hours, 7 tasks, 0 energy', LexiconVerdict.none);
    });
  });

  group('normalizeForLexicon', () {
    test('Telugu: the decomposed ai sign composes (NFC)', () {
      expect(normalizeForLexicon('ై'), 'ై');
      expect(normalizeForLexicon('కై'), 'కై');
    });

    test('Devanagari: nukta letters compose, exclusions stay decomposed', () {
      expect(normalizeForLexicon('ऩ'), 'ऩ');
      expect(normalizeForLexicon('क़'), 'क़');
    });

    test('combining marks are put in canonical order before composing', () {
      // Nukta (class 7) after virama (class 9) is reordered first.
      expect(normalizeForLexicon('क़्'), normalizeForLexicon('क़्'));
    });

    test(
      'Latin accents and case fold; zero-width goes; whitespace collapses',
      () {
        expect(normalizeForLexicon('  Crème\u200B  BRÛLÉE \t'), 'creme brulee');
        expect(normalizeForLexicon('a \n\n b'), 'a\nb');
        expect(normalizeForLexicon('can’t'), 'cant');
      },
    );

    test('zero-width joiners are dropped for matching only', () {
      const original = 'క్\u200Dష';
      expect(normalizeForLexicon(original), 'క్ష');
      expect(original.contains('\u200D'), isTrue);
    });
  });
}
