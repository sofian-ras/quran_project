import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════
//  MODEL
// ═══════════════════════════════════════════════════════

class AsmaName {
  final int number;
  final String arabic;
  final String transliteration;
  final String meaning;
  final String explanation;
  final String reflection;
  final List<String> verses;
  final String category;

  const AsmaName({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    required this.explanation,
    required this.reflection,
    this.verses = const [],
    required this.category,
  });
}

// ═══════════════════════════════════════════════════════
//  CATEGORIES & DATA
// ═══════════════════════════════════════════════════════

const _kCategories = [
  'All', 'Mercy', 'Power', 'Knowledge',
  'Creation', 'Sovereignty', 'Forgiveness', 'Purity', 'Justice',
];

const List<AsmaName> kAsmaNames = [
  AsmaName(number: 1, arabic: 'ٱلرَّحْمَـٰنُ', transliteration: 'Ar-Rahmān', meaning: 'The Most Gracious',
    explanation: 'His mercy is vast and encompasses all of creation. This mercy is granted to all beings — believers and non-believers alike — in this world.',
    reflection: 'When you feel unworthy of mercy, remember that Ar-Rahmān\'s mercy was given before you even asked. His mercy preceded His wrath.',
    verses: ['1:1', '2:163', '17:110'], category: 'Mercy'),
  AsmaName(number: 2, arabic: 'ٱلرَّحِيمُ', transliteration: 'Ar-Rahīm', meaning: 'The Most Merciful',
    explanation: 'His mercy is specific, enduring, and reserved especially for believers in the Hereafter. While Ar-Rahmān is broad, Ar-Rahīm is intimate and personal.',
    reflection: 'Allah chose to describe Himself as Ar-Rahīm 91 times in the Quran. No matter how far you have strayed, this door is always open.',
    verses: ['1:1', '2:37', '33:5'], category: 'Mercy'),
  AsmaName(number: 3, arabic: 'ٱلْمَلِكُ', transliteration: 'Al-Malik', meaning: 'The King',
    explanation: 'The absolute sovereign over all creation, whose kingship requires no counsel, no army, no consent. All dominion belongs to Him alone.',
    reflection: 'Every earthly king will perish, but Al-Malik reigns eternally. When you feel powerless before worldly authority, remember whose kingdom truly matters.',
    verses: ['59:23', '20:114', '114:2'], category: 'Sovereignty'),
  AsmaName(number: 4, arabic: 'ٱلْقُدُّوسُ', transliteration: 'Al-Quddūs', meaning: 'The Most Holy',
    explanation: 'Perfectly pure, free from any deficiency, flaw, or partner. His holiness transcends every human concept of perfection.',
    reflection: 'The angels glorify Al-Quddūs ceaselessly. In our worship, we join that cosmic chorus of sanctification.',
    verses: ['59:23', '62:1'], category: 'Purity'),
  AsmaName(number: 5, arabic: 'ٱلسَّلَامُ', transliteration: 'As-Salām', meaning: 'The Source of Peace',
    explanation: 'He is free from all faults and imperfections, and His greeting to believers in Paradise will be "Peace." True salaam originates only from Him.',
    reflection: 'Anxiety cannot coexist with genuine trust in As-Salām. When your heart is restless, return to the One who is peace itself.',
    verses: ['59:23', '10:25'], category: 'Purity'),
  AsmaName(number: 6, arabic: 'ٱلْمُؤْمِنُ', transliteration: 'Al-Mu\'min', meaning: 'The Guardian of Faith',
    explanation: 'He gives security and affirms the truth of His messengers. He protects the believers and gives testimony to His own Oneness.',
    reflection: 'To receive faith as a gift from Al-Mu\'min is the greatest trust you can be given. Guard it, nurture it, and ask Him to keep it.',
    verses: ['59:23'], category: 'Purity'),
  AsmaName(number: 7, arabic: 'ٱلْمُهَيْمِنُ', transliteration: 'Al-Muhaymin', meaning: 'The Overseer',
    explanation: 'He watches over, guards, and oversees all affairs with complete awareness. Nothing escapes His watchful oversight.',
    reflection: 'When you feel unseen, unheard, or overlooked, know that Al-Muhaymin sees every hidden moment of your struggle and devotion.',
    verses: ['59:23'], category: 'Power'),
  AsmaName(number: 8, arabic: 'ٱلْعَزِيزُ', transliteration: 'Al-\'Azīz', meaning: 'The Almighty',
    explanation: 'Invincible in His might, unique in His power — no force can overcome Him. His strength is absolute and cannot be diminished.',
    reflection: 'Seeking honor through Al-\'Azīz is the only path that never disappoints. All might belongs to Allah, His Messenger, and the believers.',
    verses: ['59:23', '2:129', '67:2'], category: 'Power'),
  AsmaName(number: 9, arabic: 'ٱلْجَبَّارُ', transliteration: 'Al-Jabbār', meaning: 'The Compeller',
    explanation: 'He compels all things to submit to His will. He also mends broken hearts — "jabara" in Arabic also means to set a bone that was broken.',
    reflection: 'The same name that describes Allah\'s irresistible power also describes His tender mending of broken souls. He compels healing upon you.',
    verses: ['59:23'], category: 'Power'),
  AsmaName(number: 10, arabic: 'ٱلْمُتَكَبِّرُ', transliteration: 'Al-Mutakabbir', meaning: 'The Majestic',
    explanation: 'Supremely great, whose greatness is true and absolute. This quality is reserved for Allah alone — pride in humans is a sin, but in Allah it is His right.',
    reflection: 'Arrogance in a human is a disease. But in Allah, Al-Mutakabbir reminds us that all greatness is His — humbling ourselves before Him is liberation.',
    verses: ['59:23'], category: 'Sovereignty'),
  AsmaName(number: 11, arabic: 'ٱلْخَالِقُ', transliteration: 'Al-Khāliq', meaning: 'The Creator',
    explanation: 'He creates from nothing, bringing into existence what never existed before. His creation is intentional, precise, and full of wisdom.',
    reflection: 'When you marvel at a flower, a galaxy, or a child\'s laughter — you are witnessing Al-Khāliq\'s signature. Creation is His continuous act of generosity.',
    verses: ['59:24', '6:102', '13:16'], category: 'Creation'),
  AsmaName(number: 12, arabic: 'ٱلْبَارِئُ', transliteration: 'Al-Bāri\'', meaning: 'The Originator',
    explanation: 'He distinguishes each created thing and brings it forth with its unique form and nature. He separates and individualizes all of creation.',
    reflection: 'You were not made by accident. Al-Bāri\' set you apart from all others. Your uniqueness is intentional — cherish it.',
    verses: ['59:24', '2:54'], category: 'Creation'),
  AsmaName(number: 13, arabic: 'ٱلْمُصَوِّرُ', transliteration: 'Al-Musawwir', meaning: 'The Fashioner',
    explanation: 'He gives form and shape to all creation. The variety of faces, fingerprints, and voices is a testament to His infinite artistry.',
    reflection: 'No two leaves are exactly alike. No two faces are identical. In every face you see, Al-Musawwir leaves His mark of infinite creativity.',
    verses: ['59:24', '3:6'], category: 'Creation'),
  AsmaName(number: 14, arabic: 'ٱلْغَفَّارُ', transliteration: 'Al-Ghaffār', meaning: 'The Oft-Forgiving',
    explanation: 'He forgives repeatedly without limit. "Ghaffar" in the intensive form means one who forgives again and again, no matter how many times one returns.',
    reflection: 'No sin is too heavy for Al-Ghaffār to lift. Every sincere return to Him is met with a forgiveness as wide as the sky. Return. Again. And again.',
    verses: ['20:82', '71:10', '38:66'], category: 'Forgiveness'),
  AsmaName(number: 15, arabic: 'ٱلْقَهَّارُ', transliteration: 'Al-Qahhār', meaning: 'The Subduer',
    explanation: 'He overpowers everything with His might. No power in the heavens or earth can resist His will or escape His dominion.',
    reflection: 'When you are overwhelmed by what cannot be changed, rest in knowing Al-Qahhār has subdued it all. Surrender is not defeat; it is wisdom.',
    verses: ['13:16', '14:48', '38:65'], category: 'Power'),
  AsmaName(number: 16, arabic: 'ٱلْوَهَّابُ', transliteration: 'Al-Wahhāb', meaning: 'The Bestower',
    explanation: 'He gives abundantly and continuously without any expectation of return. His gifts are given out of pure generosity — not because of your deeds.',
    reflection: 'Every talent, every blessing, every ability you have — you did not earn it. Al-Wahhāb placed it in your hands as a gift. Use it well.',
    verses: ['3:8', '38:9', '38:35'], category: 'Mercy'),
  AsmaName(number: 17, arabic: 'ٱلرَّزَّاقُ', transliteration: 'Ar-Razzāq', meaning: 'The Provider',
    explanation: 'He provides for all creation — body, mind, and soul. His provision is guaranteed and reaches every living thing, even before it is sought.',
    reflection: 'Your rizq was written before you were born. Trust Ar-Razzāq and stop letting worry about provision crowd out your worship.',
    verses: ['51:58', '11:6', '35:3'], category: 'Mercy'),
  AsmaName(number: 18, arabic: 'ٱلْفَتَّاحُ', transliteration: 'Al-Fattāh', meaning: 'The Opener',
    explanation: 'He opens doors that no one else can open, and He opens the hearts of those He chooses. Every breakthrough is by His hand.',
    reflection: 'When all doors seem closed, remember Al-Fattāh. He is the Master of openings. One prayer to Him can turn impossibility into reality.',
    verses: ['34:26', '35:2'], category: 'Power'),
  AsmaName(number: 19, arabic: 'ٱلْعَلِيمُ', transliteration: 'Al-\'Alīm', meaning: 'The All-Knowing',
    explanation: 'His knowledge is infinite, encompassing every secret thought, every atom in the universe, every event past, present, and future.',
    reflection: 'You cannot hide your pain from Al-\'Alīm. He knows your grief before you speak it. Bring it all to Him — He already knows, and He still cares.',
    verses: ['2:32', '4:11', '6:59'], category: 'Knowledge'),
  AsmaName(number: 20, arabic: 'ٱلْقَابِضُ', transliteration: 'Al-Qābid', meaning: 'The Withholder',
    explanation: 'He withholds provision, souls, and blessings according to His wisdom. His withholding is never unjust — it always serves a deeper purpose.',
    reflection: 'The times Allah withholds from you are not abandonment — they are invitations to draw closer. Al-Qābid and Al-Bāsit act always in perfect wisdom.',
    verses: ['2:245'], category: 'Power'),
  AsmaName(number: 21, arabic: 'ٱلْبَاسِطُ', transliteration: 'Al-Bāsit', meaning: 'The Extender',
    explanation: 'He extends provision, mercy, and ease to whom He wills. His generosity can expand what seemed impossibly small.',
    reflection: 'After every constriction comes expansion. Al-Qābid and Al-Bāsit are always in balance. Trust the cycle — ease is coming.',
    verses: ['2:245'], category: 'Power'),
  AsmaName(number: 22, arabic: 'ٱلْخَافِضُ', transliteration: 'Al-Khāfid', meaning: 'The Abaser',
    explanation: 'He lowers and humbles those who are arrogant and oppressive. No one who exalts themselves unjustly escapes His reckoning.',
    reflection: 'Every pharaoh falls. Every tyrant is eventually humbled. Al-Khāfid ensures that the scales of justice do not remain imbalanced forever.',
    verses: ['56:3'], category: 'Justice'),
  AsmaName(number: 23, arabic: 'ٱلرَّافِعُ', transliteration: 'Ar-Rāfi\'', meaning: 'The Exalter',
    explanation: 'He raises the humble, the righteous, and the devoted. No sincere servant is too lowly to be elevated by His grace.',
    reflection: 'The people society overlooks are not overlooked by Ar-Rāfi\'. True elevation comes from Him alone — not rank, wealth, or fame.',
    verses: ['56:3', '58:11'], category: 'Justice'),
  AsmaName(number: 24, arabic: 'ٱلْمُعِزُّ', transliteration: 'Al-Mu\'izz', meaning: 'The Bestower of Honor',
    explanation: 'He grants honor and dignity to whom He wills. No amount of worldly effort can grant true honor — it comes from Allah alone.',
    reflection: 'Chase honor from Al-Mu\'izz through obedience, not through the approval of people. The honor He grants is the only kind that lasts.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 25, arabic: 'ٱلْمُذِلُّ', transliteration: 'Al-Mudhill', meaning: 'The Humiliator',
    explanation: 'He brings dishonor to those who oppose His truth or oppress His servants. Humiliation from Him is a correction, not cruelty.',
    reflection: 'Seek not the approval of those Allah has humbled. Al-Mudhill reminds us that worldly status is temporary — divine judgment is permanent.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 26, arabic: 'ٱلسَّمِيعُ', transliteration: 'As-Samī\'', meaning: 'The All-Hearing',
    explanation: 'He hears every sound, every whisper, every unspoken plea of the heart. Distance and noise do not limit His hearing.',
    reflection: 'Every du\'a you make reaches As-Samī\' instantly. You are never praying into emptiness — He hears even the thoughts you are afraid to voice.',
    verses: ['2:127', '2:186', '3:38'], category: 'Knowledge'),
  AsmaName(number: 27, arabic: 'ٱلْبَصِيرُ', transliteration: 'Al-Basīr', meaning: 'The All-Seeing',
    explanation: 'He sees all things, visible and invisible, near and far, in the depths of darkness and in the brightness of day.',
    reflection: 'Al-Basīr sees the good you do when no one is watching. The charity given in secret, the tear shed in sincerity — He sees it all, and it is counted.',
    verses: ['4:58', '17:1', '67:19'], category: 'Knowledge'),
  AsmaName(number: 28, arabic: 'ٱلْحَكَمُ', transliteration: 'Al-Hakam', meaning: 'The Judge',
    explanation: 'The ultimate judge whose verdicts are perfect and final. No injustice is possible from Him; His judgment is the most just of all.',
    reflection: 'Every wrong will be addressed. Al-Hakam ensures that no tear went in vain, no injustice was forgotten. The scales will be perfectly balanced.',
    verses: ['6:57', '40:48'], category: 'Justice'),
  AsmaName(number: 29, arabic: 'ٱلْعَدْلُ', transliteration: 'Al-\'Adl', meaning: 'The Just',
    explanation: 'Perfectly just in all His decrees. He does not wrong anyone by a single atom\'s weight. His justice is beyond all human standards.',
    reflection: 'Trust in Al-\'Adl when life feels unfair. Every imbalance will be corrected — either in this world or the next. His justice is perfect.',
    verses: ['4:40', '10:44'], category: 'Justice'),
  AsmaName(number: 30, arabic: 'ٱللَّطِيفُ', transliteration: 'Al-Latīf', meaning: 'The Subtle',
    explanation: 'He is gentle, subtle, and aware of the finest details. He provides for His servants through means they cannot see or anticipate.',
    reflection: 'Al-Latīf works in the unseen fabric of your life, weaving together moments in ways you will only understand years later. Trust the subtlety.',
    verses: ['6:103', '22:63', '67:14'], category: 'Knowledge'),
  AsmaName(number: 31, arabic: 'ٱلْخَبِيرُ', transliteration: 'Al-Khabīr', meaning: 'The All-Aware',
    explanation: 'He has complete inner knowledge of all things — not just their outward form but their inner reality, history, and consequence.',
    reflection: 'You cannot fool Al-Khabīr with outward piety while harboring hidden corruption. But also — He sees your hidden sincerity and quiet struggles.',
    verses: ['6:18', '17:30', '34:1'], category: 'Knowledge'),
  AsmaName(number: 32, arabic: 'ٱلْحَلِيمُ', transliteration: 'Al-Halīm', meaning: 'The Forbearing',
    explanation: 'He does not rush to punish despite having full power to do so. He gives respite and opportunity for repentance out of His gentleness.',
    reflection: 'Every moment you are not immediately punished for your sins is a gift from Al-Halīm. His forbearance is an invitation to return.',
    verses: ['2:225', '4:12', '17:44'], category: 'Mercy'),
  AsmaName(number: 33, arabic: 'ٱلْعَظِيمُ', transliteration: 'Al-\'Azīm', meaning: 'The Magnificent',
    explanation: 'His greatness is beyond all measure or comprehension. The greatest things humans conceive are infinitely smaller than His true magnificence.',
    reflection: 'Ayatul Kursi opens with "He is Al-\'Aliyy Al-\'Azīm." Recite it and let the magnitude of who you are worshipping settle into your heart.',
    verses: ['2:255', '42:4', '56:74'], category: 'Sovereignty'),
  AsmaName(number: 34, arabic: 'ٱلْغَفُورُ', transliteration: 'Al-Ghafūr', meaning: 'The Forgiving',
    explanation: 'He forgives sins and covers faults with His mercy. "Ghafūr" means one who forgives thoroughly — erasing, covering, and concealing the sin entirely.',
    reflection: 'When you feel ashamed of your past, remember that Al-Ghafūr doesn\'t just forgive — He covers. He will not expose what He has concealed.',
    verses: ['2:173', '4:23', '35:28'], category: 'Forgiveness'),
  AsmaName(number: 35, arabic: 'ٱلشَّكُورُ', transliteration: 'Ash-Shakūr', meaning: 'The Appreciative',
    explanation: 'He appreciates and rewards even the smallest of good deeds, multiplying them far beyond their worth. He never lets sincere effort go unrecognized.',
    reflection: 'Even an atom\'s weight of goodness is seen by Ash-Shakūr. Your most private act of worship, your most overlooked kindness — He appreciates it.',
    verses: ['35:30', '64:17', '35:34'], category: 'Mercy'),
  AsmaName(number: 36, arabic: 'ٱلْعَلِيُّ', transliteration: 'Al-\'Alī', meaning: 'The Most High',
    explanation: 'Exalted above all creation in His essence, attributes, and power. His transcendence is absolute and incomparable.',
    reflection: 'When you seek status in the eyes of people, you lower yourself. True elevation comes from connecting to Al-\'Alī — the Most High.',
    verses: ['2:255', '4:34', '42:51'], category: 'Sovereignty'),
  AsmaName(number: 37, arabic: 'ٱلْكَبِيرُ', transliteration: 'Al-Kabīr', meaning: 'The Greatest',
    explanation: 'He is truly great in every sense — in power, knowledge, mercy, and all His attributes. No thing comes close to His magnitude.',
    reflection: 'Saying "Allahu Akbar" means "Allah is greater" — greater than whatever is weighing on you in that moment. Let that settle in every salah.',
    verses: ['13:9', '22:62', '31:30'], category: 'Sovereignty'),
  AsmaName(number: 38, arabic: 'ٱلْحَفِيظُ', transliteration: 'Al-Hafīz', meaning: 'The Preserver',
    explanation: 'He preserves and protects all things, keeping meticulous account of every deed. He guards the universe from collapse and protects His servants.',
    reflection: 'Nothing you do is lost in the cosmic ledger of Al-Hafīz. Every good deed is preserved, every sincere intention kept, every dhikr recorded.',
    verses: ['11:57', '34:21', '42:6'], category: 'Knowledge'),
  AsmaName(number: 39, arabic: 'ٱلْمُقِيتُ', transliteration: 'Al-Muqīt', meaning: 'The Sustainer',
    explanation: 'He provides nourishment — physical, spiritual, and intellectual — to all created things. He sustains existence itself at every moment.',
    reflection: 'Even when you forget to eat, Al-Muqīt sustains your heartbeat, your breath, your thoughts. His sustenance is more constant than you realize.',
    verses: ['4:85'], category: 'Mercy'),
  AsmaName(number: 40, arabic: 'ٱلْحَسِيبُ', transliteration: 'Al-Hasīb', meaning: 'The Reckoner',
    explanation: 'He takes account of all things with perfect precision. Nothing escapes His reckoning, and He is sufficient as a guardian and a judge.',
    reflection: 'Make yourself accountable to yourself before Al-Hasīb holds you accountable on Judgment Day. Daily self-reckoning is the sunnah of the wise.',
    verses: ['4:6', '4:86', '33:39'], category: 'Knowledge'),
  AsmaName(number: 41, arabic: 'ٱلْجَلِيلُ', transliteration: 'Al-Jalīl', meaning: 'The Majestic',
    explanation: 'Possessing complete and perfect greatness in all attributes. His majesty commands reverence and awe in all who truly know Him.',
    reflection: 'Worship born of love for Al-Wadūd combined with awe of Al-Jalīl is the most complete form of worship — between longing and reverence.',
    verses: ['55:27', '55:78'], category: 'Sovereignty'),
  AsmaName(number: 42, arabic: 'ٱلْكَرِيمُ', transliteration: 'Al-Karīm', meaning: 'The Generous',
    explanation: 'His generosity is without end or condition. He gives before being asked, gives more than was requested, and gives without expecting anything in return.',
    reflection: 'Al-Karīm\'s generosity shames our stinginess. To reflect this name is to give, forgive, and be gracious — especially when no one is watching.',
    verses: ['27:40', '82:6', '96:3'], category: 'Mercy'),
  AsmaName(number: 43, arabic: 'ٱلرَّقِيبُ', transliteration: 'Ar-Raqīb', meaning: 'The Watchful',
    explanation: 'He watches over all things with perfect vigilance and awareness. Every thought, word, and deed is under His watchful observation.',
    reflection: 'True taqwa comes from feeling Ar-Raqīb\'s gaze even in your most private moments. That awareness transforms character.',
    verses: ['4:1', '5:117', '33:52'], category: 'Knowledge'),
  AsmaName(number: 44, arabic: 'ٱلْمُجِيبُ', transliteration: 'Al-Mujīb', meaning: 'The Responsive',
    explanation: 'He responds to every call, every prayer, every need — even if the response comes in a form or time different from what was expected.',
    reflection: 'Allah promised: "Call upon Me and I will respond." Al-Mujīb is bound by His own promise to respond. Your du\'a is never unheard.',
    verses: ['2:186', '11:61', '37:75'], category: 'Mercy'),
  AsmaName(number: 45, arabic: 'ٱلْوَاسِعُ', transliteration: 'Al-Wāsi\'', meaning: 'The Vast',
    explanation: 'His knowledge, mercy, and generosity are vast beyond any boundary or limit. He can accommodate every need of every creature simultaneously.',
    reflection: 'No matter how many people turn to Al-Wāsi\' at once, His vastness is not diminished. His mercy and provision are inexhaustible.',
    verses: ['2:115', '2:268', '5:54'], category: 'Mercy'),
  AsmaName(number: 46, arabic: 'ٱلْحَكِيمُ', transliteration: 'Al-Hakīm', meaning: 'The All-Wise',
    explanation: 'Perfect in wisdom — He places everything exactly where it belongs, does everything at the most perfect time, with the most perfect outcome.',
    reflection: 'When Allah\'s decree confuses you, return to Al-Hakīm. His wisdom sees what your eyes cannot. Trust the wisdom behind what you cannot understand.',
    verses: ['2:129', '3:6', '4:26'], category: 'Knowledge'),
  AsmaName(number: 47, arabic: 'ٱلْوَدُودُ', transliteration: 'Al-Wadūd', meaning: 'The Loving',
    explanation: 'He loves His servants with a love that is pure, unconditional, and eternally steadfast. He loves and He shows love.',
    reflection: 'Al-Wadūd loves you. Not for your perfection, but in spite of your imperfection. Let that love be the foundation of your relationship with Him.',
    verses: ['11:90', '85:14'], category: 'Mercy'),
  AsmaName(number: 48, arabic: 'ٱلْمَجِيدُ', transliteration: 'Al-Majīd', meaning: 'The Glorious',
    explanation: 'He is glorious in His essence and generous in His attributes. His glory is complete, combining the highest attributes with the most beautiful deeds.',
    reflection: 'When we ask for blessings upon the Prophet ﷺ, we invoke Allah as Al-Majīd. This name appears in every salah — it connects glorification and generosity.',
    verses: ['11:73', '85:15'], category: 'Sovereignty'),
  AsmaName(number: 49, arabic: 'ٱلْبَاعِثُ', transliteration: 'Al-Bā\'ith', meaning: 'The Resurrector',
    explanation: 'He raises the dead on the Day of Resurrection and sends messengers to rouse humanity from spiritual sleep. Resurrection is entirely in His hands.',
    reflection: 'Just as He resurrects the dead earth with rain, Al-Bā\'ith can revive a dead heart with a moment of sincere remembrance. Ask Him for that revival.',
    verses: ['22:7', '58:6'], category: 'Power'),
  AsmaName(number: 50, arabic: 'ٱلشَّهِيدُ', transliteration: 'Ash-Shahīd', meaning: 'The Witness',
    explanation: 'He witnesses all things directly and completely. His testimony is perfect because He is present to everything simultaneously.',
    reflection: 'Live your life in awareness of Ash-Shahīd. What would change if you felt His presence fully — in your speech, your dealings, your private moments?',
    verses: ['4:33', '22:17', '41:53'], category: 'Knowledge'),
  AsmaName(number: 51, arabic: 'ٱلْحَقُّ', transliteration: 'Al-Haqq', meaning: 'The Truth',
    explanation: 'He is the ultimate truth — His existence is absolute truth, His attributes are true, His words are truth, and His promises are true.',
    reflection: 'In a world full of illusions and falsehood, Al-Haqq is the only fixed point of certainty. Anchor your life to Him and nothing can shake you.',
    verses: ['20:114', '22:6', '23:116'], category: 'Purity'),
  AsmaName(number: 52, arabic: 'ٱلْوَكِيلُ', transliteration: 'Al-Wakīl', meaning: 'The Trustee',
    explanation: 'The best trustee and guardian of all affairs. When you entrust your matters to Him, He manages them with perfect wisdom and care.',
    reflection: '"Hasbunallahu wa ni\'mal wakīl" — Allah is sufficient for us and what an excellent trustee He is. This is the phrase of the prophets in their hardest moments.',
    verses: ['3:173', '4:81', '6:102'], category: 'Power'),
  AsmaName(number: 53, arabic: 'ٱلْقَوِيُّ', transliteration: 'Al-Qawiyy', meaning: 'The Most Strong',
    explanation: 'His strength is absolute, never diminishing, never fatiguing. All power in creation is derived from and subordinate to His strength.',
    reflection: 'The most powerful military, the mightiest nation, the strongest individual — all are utterly weak before Al-Qawiyy. Draw your strength from Him.',
    verses: ['8:52', '22:40', '22:74'], category: 'Power'),
  AsmaName(number: 54, arabic: 'ٱلْمَتِينُ', transliteration: 'Al-Matīn', meaning: 'The Firm',
    explanation: 'His power is completely firm, unshakeable, and inexhaustible. He is never weakened, never tired, never undermined.',
    reflection: 'When your own resolve weakens and your faith fluctuates, return to Al-Matīn. His firmness is the anchor for your inconstancy.',
    verses: ['51:58'], category: 'Power'),
  AsmaName(number: 55, arabic: 'ٱلْوَلِيُّ', transliteration: 'Al-Waliyy', meaning: 'The Protecting Friend',
    explanation: 'He is the ultimate protector and ally of the believers. To have Him as your walī is the greatest honor any soul can possess.',
    reflection: 'If Allah is your Walī, what can harm you? "Allah is the Walī of those who believe." You are never truly alone when you have the greatest Friend.',
    verses: ['2:257', '3:68', '42:28'], category: 'Mercy'),
  AsmaName(number: 56, arabic: 'ٱلْحَمِيدُ', transliteration: 'Al-Hamīd', meaning: 'The Praiseworthy',
    explanation: 'He is deserving of all praise — intrinsically and in all His actions. Every blessing, trial, and decree are all worthy of praise.',
    reflection: 'Al-Hamīd is worthy of praise not because things go well, but in spite of difficulties. True hamd is offered in hardship — that is when it means most.',
    verses: ['14:1', '31:12', '60:6'], category: 'Purity'),
  AsmaName(number: 57, arabic: 'ٱلْمُحْصِي', transliteration: 'Al-Muhsī', meaning: 'The Counter',
    explanation: 'He keeps precise count of all things — every action, every atom, every second. Nothing in all of creation exceeds His perfect enumeration.',
    reflection: 'Al-Muhsī keeps count of things you have forgotten. Every kind word, every prayer, every moment of patience — each one is counted and preserved.',
    verses: ['19:94', '78:29'], category: 'Knowledge'),
  AsmaName(number: 58, arabic: 'ٱلْمُبْدِئُ', transliteration: 'Al-Mubdi\'', meaning: 'The Originator',
    explanation: 'He initiates and brings into existence from nothing, without any precedent or model. The first creation was entirely His own origination.',
    reflection: 'Every beginning in your life is a reminder of Al-Mubdi\'. He can start something entirely new in your life, even when everything seems finished.',
    verses: ['10:34', '29:19'], category: 'Creation'),
  AsmaName(number: 59, arabic: 'ٱلْمُعِيدُ', transliteration: 'Al-Mu\'īd', meaning: 'The Restorer',
    explanation: 'He brings creation back after death. He who started creation will certainly restore it — resurrection is His promise and His power.',
    reflection: 'Whatever in your life has been lost or ended — Al-Mu\'īd can restore it. He who restores the dead can certainly restore the living.',
    verses: ['10:34', '85:13'], category: 'Creation'),
  AsmaName(number: 60, arabic: 'ٱلْمُحْيِي', transliteration: 'Al-Muhyī', meaning: 'The Giver of Life',
    explanation: 'He is the sole source of life in all its forms — biological, spiritual, and eternal. Only He can truly grant life.',
    reflection: 'When your soul feels dead, when faith seems extinguished — call upon Al-Muhyī. He gives life to the dead earth. And to the dead heart.',
    verses: ['2:258', '30:50', '41:39'], category: 'Creation'),
  AsmaName(number: 61, arabic: 'ٱلْمُمِيتُ', transliteration: 'Al-Mumīt', meaning: 'The Taker of Life',
    explanation: 'He appoints death for all living things. This is a profound reminder of life\'s purpose and the certainty of return to Him.',
    reflection: 'Remembering death is not morbid — it is clarifying. Al-Mumīt reminds you that this life is a journey, not a destination.',
    verses: ['2:258', '3:156', '7:158'], category: 'Power'),
  AsmaName(number: 62, arabic: 'ٱلْحَيُّ', transliteration: 'Al-Hayy', meaning: 'The Ever-Living',
    explanation: 'He is eternally alive — His life has no beginning, no end, and no interruption. All of creation\'s life is borrowed from His.',
    reflection: 'Al-Hayy is the name to call upon in your darkest hour. The Ever-Living will never abandon you to that which cannot see, hear, or care.',
    verses: ['2:255', '3:2', '20:111'], category: 'Purity'),
  AsmaName(number: 63, arabic: 'ٱلْقَيُّومُ', transliteration: 'Al-Qayyūm', meaning: 'The Self-Subsisting',
    explanation: 'He sustains all of existence and needs nothing in return. He is self-sufficient; all of creation depends on Him, but He depends on nothing.',
    reflection: 'The prophets used "Yā Hayyu Yā Qayyūm" in their direst moments. These two names together are a power beyond description. Use them.',
    verses: ['2:255', '3:2', '20:111'], category: 'Purity'),
  AsmaName(number: 64, arabic: 'ٱلْوَاجِدُ', transliteration: 'Al-Wājid', meaning: 'The Finder',
    explanation: 'He finds and perceives whatever He wills — He is never in need, never wanting, always fully aware and in possession of all things.',
    reflection: 'Nothing is ever truly lost from Al-Wājid\'s awareness. Every missing thing, every forgotten soul, every buried blessing — He perceives it all.',
    verses: ['38:44'], category: 'Power'),
  AsmaName(number: 65, arabic: 'ٱلْمَاجِدُ', transliteration: 'Al-Mājid', meaning: 'The Noble',
    explanation: 'He is noble, generous, and glorious in His essence. His noblemindedness is the source of all that is beautiful and elevated in creation.',
    reflection: 'When you seek nobility of character in yourself, look to Al-Mājid. Ask Him to cultivate in you what He perfectly embodies.',
    verses: ['11:73', '85:15'], category: 'Sovereignty'),
  AsmaName(number: 66, arabic: 'ٱلْوَاحِدُ', transliteration: 'Al-Wāhid', meaning: 'The One',
    explanation: 'He is alone in His divinity, His sovereignty, and His attributes. There is no partner, equal, or comparison. Unity is His absolute truth.',
    reflection: 'The entire Quran is an elaboration of Al-Wāhid. Tawhīd is not just a theological point; it is a way of organizing your entire life.',
    verses: ['2:163', '13:16', '39:4'], category: 'Purity'),
  AsmaName(number: 67, arabic: 'ٱلْأَحَدُ', transliteration: 'Al-Ahad', meaning: 'The Unique One',
    explanation: 'He is absolutely unique — not just singular in number but unmatched in essence and attributes. Al-Wāhid is oneness; Al-Ahad is uniqueness.',
    reflection: 'Surah Al-Ikhlas is a third of the Quran because Al-Ahad is the axis around which all knowledge of Allah revolves. Return to it often.',
    verses: ['112:1'], category: 'Purity'),
  AsmaName(number: 68, arabic: 'ٱلصَّمَدُ', transliteration: 'As-Samad', meaning: 'The Eternal Refuge',
    explanation: 'The one all creation turns to in need. He is complete in Himself, without any need, and all others depend on Him.',
    reflection: 'When you feel the urge to lean on a person for what only Allah can provide, remember As-Samad — the only refuge that never fails.',
    verses: ['112:2'], category: 'Purity'),
  AsmaName(number: 69, arabic: 'ٱلْقَادِرُ', transliteration: 'Al-Qādir', meaning: 'The Able',
    explanation: 'Completely capable of all things without effort, strain, or limitation. Whatever He wills comes into being by His word "Be" — and it is.',
    reflection: 'Never limit your du\'a out of thinking "that\'s too much to ask." Al-Qādir\'s ability is not constrained by the size of your request.',
    verses: ['2:20', '2:109', '6:65'], category: 'Power'),
  AsmaName(number: 70, arabic: 'ٱلْمُقْتَدِرُ', transliteration: 'Al-Muqtadir', meaning: 'The Powerful',
    explanation: 'He exercises His power with perfect authority and control. His power is not just potential but continually enacted over all creation.',
    reflection: 'When something in your life feels out of control, remember Al-Muqtadir holds mastery over it. Surrender your grip — His control is infinitely better.',
    verses: ['18:45', '54:42', '54:55'], category: 'Power'),
  AsmaName(number: 71, arabic: 'ٱلْمُقَدِّمُ', transliteration: 'Al-Muqaddim', meaning: 'The Expediter',
    explanation: 'He brings forward and advances whom and what He wills. He can elevate, prioritize, and expedite those He chooses.',
    reflection: 'Success, timing, and rank — all are in the hands of Al-Muqaddim. Do the work and let Him determine the order and timing of your elevation.',
    verses: ['50:28'], category: 'Power'),
  AsmaName(number: 72, arabic: 'ٱلْمُؤَخِّرُ', transliteration: 'Al-Mu\'akhkhir', meaning: 'The Delayer',
    explanation: 'He delays and defers whom and what He wills. Every delay in His plan is a mercy — He postpones what would harm you prematurely.',
    reflection: 'The doors that haven\'t opened yet, the prayers that haven\'t been answered yet — Al-Mu\'akhkhir is at work. His delay is never abandonment.',
    verses: ['71:4'], category: 'Power'),
  AsmaName(number: 73, arabic: 'ٱلْأَوَّلُ', transliteration: 'Al-Awwal', meaning: 'The First',
    explanation: 'He existed before all things — before time, space, and creation. There is nothing prior to Him, no cause before Him.',
    reflection: 'Before your problems existed, Al-Awwal existed. Before your worries were born, He was there. He precedes every difficulty with His presence.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 74, arabic: 'ٱلْآخِرُ', transliteration: 'Al-Ākhir', meaning: 'The Last',
    explanation: 'He will remain after all of creation ceases to exist. When the heavens fold and the stars extinguish, Al-Ākhir will be all that remains.',
    reflection: 'Invest in the one relationship that will outlast everything else. Al-Ākhir will be there when all others are gone. Prioritize accordingly.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 75, arabic: 'ٱلظَّاهِرُ', transliteration: 'Az-Zāhir', meaning: 'The Manifest',
    explanation: 'He is evident and manifest through His signs, creation, and proofs. His existence is undeniably present in everything around us.',
    reflection: 'Every sign of beauty, order, and purpose in creation is Az-Zāhir speaking. Open your eyes — He is visible everywhere.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 76, arabic: 'ٱلْبَاطِنُ', transliteration: 'Al-Bātin', meaning: 'The Hidden',
    explanation: 'His true essence is beyond human comprehension. Though His signs are manifest, His reality transcends all perception and understanding.',
    reflection: 'Al-Bātin and Az-Zāhir together: He is manifest through His creation yet hidden in His essence. Both awe and intimacy are appropriate responses.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 77, arabic: 'ٱلْوَالِي', transliteration: 'Al-Wālī', meaning: 'The Governor',
    explanation: 'He governs and administers all of creation with perfect authority. Every system in the universe operates under His governance.',
    reflection: 'When human governance fails and justice seems absent, Al-Wālī\'s governance never fails. His administration of the cosmos is perfect.',
    verses: ['13:11', '18:44'], category: 'Sovereignty'),
  AsmaName(number: 78, arabic: 'ٱلْمُتَعَالِي', transliteration: 'Al-Muta\'āli', meaning: 'The Self-Exalted',
    explanation: 'He is supremely exalted above all things by His own essence — His transcendence is intrinsic, not conferred by others.',
    reflection: 'Human pride in our accomplishments is a shadow. Al-Muta\'āli reminds us that all true exaltation belongs to Him alone.',
    verses: ['13:9'], category: 'Sovereignty'),
  AsmaName(number: 79, arabic: 'ٱلْبَرُّ', transliteration: 'Al-Barr', meaning: 'The Source of Goodness',
    explanation: 'He is immensely good and kind toward His servants. All goodness ultimately flows from Him as its original and perfect source.',
    reflection: 'Every good thing in your life traces back to Al-Barr. Recognizing this transforms gratitude from an obligation into a spontaneous overflowing of the heart.',
    verses: ['52:28'], category: 'Mercy'),
  AsmaName(number: 80, arabic: 'ٱلتَّوَّابُ', transliteration: 'At-Tawwāb', meaning: 'The Ever-Returning',
    explanation: 'He turns to His servants in mercy when they repent, and He enables repentance in the heart. He returns to you even as you return to Him.',
    reflection: 'You did not initiate your return to Allah — He opened your heart first. At-Tawwāb makes tawbah possible. Thank Him for the urge to repent.',
    verses: ['2:37', '2:54', '4:64'], category: 'Forgiveness'),
  AsmaName(number: 81, arabic: 'ٱلْمُنْتَقِمُ', transliteration: 'Al-Muntaqim', meaning: 'The Avenger',
    explanation: 'He exacts retribution from those who persist in sin and oppression without repentance. His vengeance is just, proportional, and never excessive.',
    reflection: 'The oppressed have the best advocate: Al-Muntaqim. Every cruelty witnessed by human eyes is seen by Him — and justice will come.',
    verses: ['3:4', '5:95', '44:16'], category: 'Justice'),
  AsmaName(number: 82, arabic: 'ٱلْعَفُوُّ', transliteration: 'Al-\'Afuww', meaning: 'The Pardoner',
    explanation: 'He not only forgives sins but erases them entirely — as if they never existed. "\'Afw" means to wipe clean, leaving no trace behind.',
    reflection: 'On Laylat al-Qadr, the Prophet ﷺ taught us to ask: "O Allah, You are Al-\'Afuww, You love pardon — so pardon me." This is the ultimate ask.',
    verses: ['4:43', '4:99', '22:60'], category: 'Forgiveness'),
  AsmaName(number: 83, arabic: 'ٱلرَّءُوفُ', transliteration: 'Ar-Ra\'ūf', meaning: 'The Compassionate',
    explanation: 'He is intensely compassionate — His compassion is a feeling-based mercy that moves Him to spare His servants from hardship and protect them.',
    reflection: 'Ar-Ra\'ūf\'s compassion is why He commands what He commands and forbids what He forbids. Every divine ruling is an expression of His compassion for you.',
    verses: ['2:143', '3:30', '9:117'], category: 'Mercy'),
  AsmaName(number: 84, arabic: 'مَالِكُ ٱلْمُلْكِ', transliteration: 'Mālik Al-Mulk', meaning: 'Owner of Sovereignty',
    explanation: 'He is the true owner of all kingdoms and domains. He grants dominion to whom He wills and takes it from whom He wills.',
    reflection: 'Every leader, every president, every king holds their position on loan from Mālik Al-Mulk. Authority without His sanction is transient and hollow.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 85, arabic: 'ذُو ٱلْجَلَالِ وَٱلْإِكْرَامِ', transliteration: 'Dhul-Jalāli Wal-Ikrām', meaning: 'Lord of Majesty and Bounty',
    explanation: 'He combines supreme majesty with supreme generosity. These two qualities form the axis of all worship.',
    reflection: 'The Prophet ﷺ recommended repeating this name often. It unites fear and love, awe and hope — the two wings with which the believer\'s heart takes flight.',
    verses: ['55:27', '55:78'], category: 'Sovereignty'),
  AsmaName(number: 86, arabic: 'ٱلْمُقْسِطُ', transliteration: 'Al-Muqsit', meaning: 'The Equitable',
    explanation: 'He is perfectly equitable and fair in all His judgments. He does not favor the mighty over the weak or the rich over the poor.',
    reflection: 'Perfect equity is impossible for humans, but Al-Muqsit establishes it. To love this name is to commit to being as equitable as your human nature allows.',
    verses: ['7:29', '60:8'], category: 'Justice'),
  AsmaName(number: 87, arabic: 'ٱلْجَامِعُ', transliteration: 'Al-Jāmi\'', meaning: 'The Gatherer',
    explanation: 'He gathers all of creation on the Day of Resurrection. He brings together what is separate in the world — sustenance, hearts, and truths.',
    reflection: 'Every loved one who has died, every connection that was severed — Al-Jāmi\' will gather them again. No separation is permanent before Him.',
    verses: ['3:9', '4:140'], category: 'Power'),
  AsmaName(number: 88, arabic: 'ٱلْغَنِيُّ', transliteration: 'Al-Ghanī', meaning: 'The Self-Sufficient',
    explanation: 'He is completely self-sufficient and free from any need. All of existence could vanish and He would not be diminished by a single atom.',
    reflection: 'Your worship does not enrich Al-Ghanī. You worship for your own sake — to cultivate the connection your soul needs.',
    verses: ['2:267', '3:97', '47:38'], category: 'Purity'),
  AsmaName(number: 89, arabic: 'ٱلْمُغْنِي', transliteration: 'Al-Mughnī', meaning: 'The Enricher',
    explanation: 'He enriches His servants materially, spiritually, and emotionally. True wealth — of soul, contentment, and certainty — comes from Him.',
    reflection: 'Contentment (qana\'a) is the wealth Al-Mughnī gives that no market can provide. Ask Him not just for provision, but for the contentment to enjoy it.',
    verses: ['9:28', '53:48'], category: 'Mercy'),
  AsmaName(number: 90, arabic: 'ٱلْمَانِعُ', transliteration: 'Al-Māni\'', meaning: 'The Preventer',
    explanation: 'He prevents harm from reaching His servants and withholds things for reasons of wisdom and mercy. His prevention is always for a greater good.',
    reflection: 'Every door that closed in your face was Al-Māni\' at work. His prevention is not punishment — it is often protection from what you cannot see.',
    verses: ['67:21'], category: 'Power'),
  AsmaName(number: 91, arabic: 'ٱلضَّارُّ', transliteration: 'Ad-Dārr', meaning: 'The Distresser',
    explanation: 'He alone ultimately determines what causes harm. No harm reaches you except by His permission and wisdom.',
    reflection: 'Nothing can hurt you without His permission. This name, understood correctly, gives tremendous peace — all harm passes through His filter of wisdom.',
    verses: ['6:17', '10:107'], category: 'Power'),
  AsmaName(number: 92, arabic: 'ٱلنَّافِعُ', transliteration: 'An-Nāfi\'', meaning: 'The Propitious',
    explanation: 'He alone determines what brings benefit. All benefit ultimately traces back to His will and His mercy for those He chooses.',
    reflection: 'Medicine heals by His permission. Work provides by His permission. Every benefit has His signature. Gratitude flows to the one who truly provides.',
    verses: ['6:17', '10:107'], category: 'Mercy'),
  AsmaName(number: 93, arabic: 'ٱلنُّورُ', transliteration: 'An-Nūr', meaning: 'The Light',
    explanation: 'He is the light of the heavens and the earth. His light illuminates the heart with guidance, the mind with understanding, and the cosmos with existence.',
    reflection: 'Surah An-Nur (24:35) describes His light as a lamp within a lamp, light upon light. Seek the nūr of the Quran — it is the light of An-Nūr Himself.',
    verses: ['24:35', '39:22'], category: 'Purity'),
  AsmaName(number: 94, arabic: 'ٱلْهَادِي', transliteration: 'Al-Hādī', meaning: 'The Guide',
    explanation: 'He guides to truth, to right action, and to Himself. His guidance is both general (instinct, reason) and specific (revelation, inspiration).',
    reflection: 'Guidance is not earned — it is asked for. "Ihdinas-siratal-mustaqim" — Guide us to the straight path. Ask Al-Hādī for it seventeen times a day.',
    verses: ['22:54', '25:31'], category: 'Mercy'),
  AsmaName(number: 95, arabic: 'ٱلْبَدِيعُ', transliteration: 'Al-Badī\'', meaning: 'The Incomparable Originator',
    explanation: 'He creates beautiful, unprecedented things without any prior example. Every new form, idea, and wonder in creation is an expression of His inventive power.',
    reflection: 'No artist has ever created something Al-Badī\' didn\'t give them the capacity for. All originality and beauty ultimately flows from the Incomparable Creator.',
    verses: ['2:117', '6:101'], category: 'Creation'),
  AsmaName(number: 96, arabic: 'ٱلْبَاقِي', transliteration: 'Al-Bāqī', meaning: 'The Ever-Enduring',
    explanation: 'He endures forever after all of creation has ceased. While everything perishes, His existence is permanent and everlasting.',
    reflection: 'Invest in what is permanent: your relationship with Al-Bāqī. Everything else is temporary — let that awareness reorder your priorities.',
    verses: ['20:73', '55:27'], category: 'Purity'),
  AsmaName(number: 97, arabic: 'ٱلْوَارِثُ', transliteration: 'Al-Wārith', meaning: 'The Inheritor',
    explanation: 'He is the final heir of all things — when all creation is gone, all that remains returns to Him. He outlasts every owner of every possession.',
    reflection: '"We are Allah\'s and to Him we return." Al-Wārith reminds us that we are stewards, not owners. Hold your blessings lightly.',
    verses: ['3:180', '15:23', '19:40'], category: 'Sovereignty'),
  AsmaName(number: 98, arabic: 'ٱلرَّشِيدُ', transliteration: 'Ar-Rashīd', meaning: 'The Guide to the Right Path',
    explanation: 'His guidance is always right and leads precisely to where it should. His direction is infallible and His wisdom in guiding is supreme.',
    reflection: 'When you are confused about which path to take, turn to Ar-Rashīd with istikhara. His guidance will come — perhaps not how you expect, but it will come.',
    verses: ['2:256', '18:17'], category: 'Knowledge'),
  AsmaName(number: 99, arabic: 'ٱلصَّبُورُ', transliteration: 'As-Sabūr', meaning: 'The Patient',
    explanation: 'He is infinitely patient with His servants, not rushing to punish despite witnessing every transgression. His patience is the model of perfect restraint.',
    reflection: 'As-Sabūr is the last of the ninety-nine names, and patience is the last virtue to be lost. Model yourself on His patience — it is the seal of noble character.',
    verses: ['11:115', '39:10'], category: 'Mercy'),
];

// ═══════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════

class AsmaulHusnaScreen extends StatefulWidget {
  const AsmaulHusnaScreen({super.key});

  @override
  State<AsmaulHusnaScreen> createState() => _AsmaulHusnaScreenState();
}

class _AsmaulHusnaScreenState extends State<AsmaulHusnaScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _category = 'All';
  bool _showFavoritesOnly = false;
  Set<int> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('asma_favorites') ?? [];
    if (mounted) {
      setState(() => _favorites = stored.map(int.parse).toSet());
    }
  }

  Future<void> _toggleFavorite(int number) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(number)) {
        _favorites.remove(number);
      } else {
        _favorites.add(number);
      }
    });
    await prefs.setStringList(
      'asma_favorites',
      _favorites.map((n) => n.toString()).toList(),
    );
  }

  List<AsmaName> get _filtered {
    return kAsmaNames.where((n) {
      if (_showFavoritesOnly && !_favorites.contains(n.number)) return false;
      if (_category != 'All' && n.category != _category) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return n.transliteration.toLowerCase().contains(q) ||
            n.meaning.toLowerCase().contains(q) ||
            n.arabic.contains(_search);
      }
      return true;
    }).toList();
  }

  AsmaName get _dailyName {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return kAsmaNames[dayOfYear % 99];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(AsmaName name, {int? startIndex}) {
    final names = _filtered;
    final idx = startIndex ?? names.indexWhere((n) => n.number == name.number);
    Navigator.of(context).push(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => _AsmaulHusnaDetailScreen(
        initialIndex: idx < 0 ? 0 : idx,
        names: names.isEmpty ? kAsmaNames : names,
        favorites: _favorites,
        onFavoriteToggle: _toggleFavorite,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    final names = _filtered;
    final showDaily = _search.isEmpty && _category == 'All' && !_showFavoritesOnly;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(child: _buildSearchAndFilter(isDark)),
          if (showDaily)
            SliverToBoxAdapter(
              child: _DailyNameBanner(
                name: _dailyName,
                isDark: isDark,
                onTap: () => _openDetail(_dailyName, startIndex: kAsmaNames.indexOf(_dailyName)),
              ),
            ),
          if (names.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No names found',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _NameGridCard(
                    name: names[i],
                    isFavorite: _favorites.contains(names[i].number),
                    onTap: () => _openDetail(names[i], startIndex: i),
                    onFavorite: () => _toggleFavorite(names[i].number),
                    isDark: isDark,
                  ),
                  childCount: names.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
              ),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(bool isDark) {
    final bg = isDark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6);
    return SliverAppBar(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 148,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _AsmaulHusnaHeader(isDark: isDark),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white70 : const Color(0xFF4A3F30),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFavoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _showFavoritesOnly
                ? const Color(0xFFD4AF37)
                : (isDark ? Colors.white54 : const Color(0xFF8B6C35)),
          ),
          onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    const gold = Color(0xFFC8A97E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withValues(alpha: 0.45)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF4A3F30),
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or meaning…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF6B5A45),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: gold),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 16,
                            color: isDark ? Colors.white38 : const Color(0xFF6B5A45)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [Color(0xFFE8D5B3), Color(0xFFCFAF7E)],
                            )
                          : null,
                      color: selected
                          ? null
                          : (isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFC8A97E)
                            : gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF4A3F30)
                            : (isDark ? Colors.white70 : const Color(0xFF6B5A45)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  HEADER WIDGET
// ═══════════════════════════════════════════════════════

class _AsmaulHusnaHeader extends StatelessWidget {
  final bool isDark;
  const _AsmaulHusnaHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? const [
                  Color(0xFF1A100A),
                  Color(0xFF2A1A0E),
                  Color(0xFF3A2810),
                  Color(0xFF2A1A0E),
                  Color(0xFF1A100A),
                ]
              : const [
                  Color(0xFF8B6C35),
                  Color(0xFFBFA878),
                  Color(0xFFD4C5A3),
                  Color(0xFFBFA878),
                  Color(0xFF8B6C35),
                ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeaderPatternPainter(isDark: isDark)),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  'أسماء الله الحسنى',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ScheherazadeNew',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFFFAF6EE),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The Most Beautiful Names of Allah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: isDark
                        ? const Color(0xFFE8D5B0).withValues(alpha: 0.7)
                        : const Color(0xFFFAF6EE).withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  final bool isDark;
  const _HeaderPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.white).withValues(alpha: 0.04)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Diamond grid pattern
    const spacing = 22.0;
    for (double x = 0; x <= size.width + spacing; x += spacing) {
      for (double y = 0; y <= size.height + spacing; y += spacing) {
        final path = Path();
        path.moveTo(x, y - 8);
        path.lineTo(x + 8, y);
        path.lineTo(x, y + 8);
        path.lineTo(x - 8, y);
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    // Corner stars
    _drawStar(canvas, Offset(size.width - 20, 20), 10, paint);
    _drawStar(canvas, const Offset(20, 20), 10, paint);
    _drawStar(canvas, Offset(size.width - 20, size.height - 20), 10, paint);
    _drawStar(canvas, Offset(20, size.height - 20), 10, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final innerAngle = angle + math.pi / 8;
      final outerPt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      final innerPt = Offset(
        center.dx + (r * 0.45) * math.cos(innerAngle),
        center.dy + (r * 0.45) * math.sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outerPt.dx, outerPt.dy);
      } else {
        path.lineTo(innerPt.dx, innerPt.dy);
        path.lineTo(outerPt.dx, outerPt.dy);
      }
      path.lineTo(innerPt.dx, innerPt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeaderPatternPainter old) => old.isDark != isDark;
}

// ═══════════════════════════════════════════════════════
//  DAILY NAME BANNER
// ═══════════════════════════════════════════════════════

class _DailyNameBanner extends StatelessWidget {
  final AsmaName name;
  final bool isDark;
  final VoidCallback onTap;

  const _DailyNameBanner({
    required this.name,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF2A1A06), Color(0xFF4A2E10), Color(0xFF3A2208)]
                  : const [Color(0xFFE8D5A3), Color(0xFFD4AF6A), Color(0xFFC8A040)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF8B6814).withValues(alpha: 0.7)
                  : const Color(0xFFB8922A).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '✦  Name of the Day',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? const Color(0xFFE8D5B0)
                                  : const Color(0xFF4A3010),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name.transliteration,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF3A2208),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.meaning,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFE8D5B0).withValues(alpha: 0.75)
                            : const Color(0xFF5A3E12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    name.arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 30,
                      color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF3A2208),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${name.number}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE8D5B0).withValues(alpha: 0.6)
                          : const Color(0xFF5A3E12).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  GRID CARD
// ═══════════════════════════════════════════════════════

class _NameGridCard extends StatelessWidget {
  final AsmaName name;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool isDark;

  const _NameGridCard({
    required this.name,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    final borderColor = const Color(0xFFC8A97E).withValues(alpha: isDark ? 0.25 : 0.5);
    final numColor = const Color(0xFFC8A97E).withValues(alpha: isDark ? 0.55 : 0.65);
    final arabicColor = isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);
    final latinColor = isDark ? Colors.white54 : const Color(0xFF6B5A45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${name.number}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: numColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: onFavorite,
                    child: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 14,
                      color: isFavorite
                          ? const Color(0xFFD4AF37)
                          : numColor,
                    ),
                  ),
                ],
              ),
              Text(
                name.arabic,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 20,
                  height: 1.3,
                  color: arabicColor,
                ),
              ),
              Column(
                children: [
                  Text(
                    name.transliteration,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: latinColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.meaning,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontStyle: FontStyle.italic,
                      color: latinColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DETAIL SCREEN
// ═══════════════════════════════════════════════════════

class _AsmaulHusnaDetailScreen extends StatefulWidget {
  final int initialIndex;
  final List<AsmaName> names;
  final Set<int> favorites;
  final void Function(int) onFavoriteToggle;

  const _AsmaulHusnaDetailScreen({
    required this.initialIndex,
    required this.names,
    required this.favorites,
    required this.onFavoriteToggle,
  });

  @override
  State<_AsmaulHusnaDetailScreen> createState() => _AsmaulHusnaDetailScreenState();
}

class _AsmaulHusnaDetailScreenState extends State<_AsmaulHusnaDetailScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late int _currentIndex;
  Set<int> _localFavorites = {};
  bool _meditationMode = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _localFavorites = Set.from(widget.favorites);
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleFavorite(int number) {
    setState(() {
      if (_localFavorites.contains(number)) {
        _localFavorites.remove(number);
      } else {
        _localFavorites.add(number);
      }
    });
    widget.onFavoriteToggle(number);
  }

  void _toggleMeditation() {
    setState(() => _meditationMode = !_meditationMode);
    if (_meditationMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = widget.names[_currentIndex];
    final isFav = _localFavorites.contains(current.number);

    if (_meditationMode) {
      return _buildMeditationOverlay(current, isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1220) : const Color(0xFFF5F0E6),
      body: Column(
        children: [
          _buildDetailHeader(context, current, isFav, isDark),
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.names.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) => _buildDetailContent(widget.names[i], isDark),
            ),
          ),
          _buildNavBar(isDark),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(
      BuildContext context, AsmaName name, bool isFav, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? const [Color(0xFF1A100A), Color(0xFF2A1A0E), Color(0xFF3A2810), Color(0xFF2A1A0E), Color(0xFF1A100A)]
              : const [Color(0xFF8B6C35), Color(0xFFBFA878), Color(0xFFD4C5A3), Color(0xFFBFA878), Color(0xFF8B6C35)],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFFFAF6EE),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Meditation mode',
                    icon: Icon(
                      Icons.self_improvement_rounded,
                      size: 20,
                      color: isDark
                          ? const Color(0xFFE8D5B0).withValues(alpha: 0.8)
                          : const Color(0xFFFAF6EE),
                    ),
                    onPressed: _toggleMeditation,
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20,
                      color: isFav
                          ? const Color(0xFFD4AF37)
                          : (isDark
                              ? const Color(0xFFE8D5B0).withValues(alpha: 0.8)
                              : const Color(0xFFFAF6EE)),
                    ),
                    onPressed: () => _toggleFavorite(name.number),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${name.number} of 99  •  ${name.category}',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: isDark
                            ? const Color(0xFFE8D5B0).withValues(alpha: 0.7)
                            : const Color(0xFFFAF6EE).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name.arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 40,
                      color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFFFAF6EE),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.transliteration,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark
                          ? const Color(0xFFE8D5B0).withValues(alpha: 0.85)
                          : const Color(0xFFFAF6EE),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name.meaning,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? const Color(0xFFE8D5B0).withValues(alpha: 0.65)
                          : const Color(0xFFFAF6EE).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(AsmaName name, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    final textPrimary = isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);
    final textSec = isDark ? Colors.white60 : const Color(0xFF6B5A45);
    const gold = Color(0xFFC8A97E);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation
          _SectionCard(
            isDark: isDark,
            cardBg: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 15, color: gold),
                    SizedBox(width: 6),
                    Text(
                      'Meaning & Explanation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name.explanation,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Reflection
          _SectionCard(
            isDark: isDark,
            cardBg: isDark ? const Color(0xFF1A1428) : const Color(0xFFF0EAD8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('✦', style: TextStyle(fontSize: 13, color: gold)),
                    SizedBox(width: 6),
                    Text(
                      'Reflection',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name.reflection,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    fontStyle: FontStyle.italic,
                    color: textSec,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quran Verses
          if (name.verses.isNotEmpty)
            _SectionCard(
              isDark: isDark,
              cardBg: cardBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 15, color: gold),
                      SizedBox(width: 6),
                      Text(
                        'Mentioned in the Quran',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: name.verses.map((v) {
                      final parts = v.split(':');
                      final surah = parts[0];
                      final ayah = parts.length > 1 ? parts[1] : '';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8D5B3), Color(0xFFCFAF7E)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          'Surah $surah : $ayah',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A3010),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              '﴿ Swipe to explore more names ﴾',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? Colors.white24
                    : const Color(0xFF6B5A45).withValues(alpha: 0.5),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavBar(bool isDark) {
    final bg = isDark ? const Color(0xFF1C2333) : const Color(0xFFEDE6D9);
    const gold = Color(0xFFC8A97E);
    final count = widget.names.length;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              icon: Icons.arrow_back_ios_rounded,
              label: 'Previous',
              enabled: _currentIndex > 0,
              isDark: isDark,
              onTap: () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentIndex + 1} / $count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 80,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ((_currentIndex + 1) / count).clamp(0.0, 1.0),
                      backgroundColor: gold.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(gold),
                    ),
                  ),
                ),
              ],
            ),
            _NavButton(
              icon: Icons.arrow_forward_ios_rounded,
              label: 'Next',
              enabled: _currentIndex < count - 1,
              isDark: isDark,
              isForward: true,
              onTap: () => _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeditationOverlay(AsmaName name, bool isDark) {
    return GestureDetector(
      onTap: _toggleMeditation,
      child: Scaffold(
        backgroundColor: const Color(0xFF05080F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Radial glow
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD4AF37).withValues(alpha: 0.12),
                          const Color(0xFFD4AF37).withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Geometric pattern (subtle)
            Positioned.fill(
              child: CustomPaint(
                painter: _MeditationPatternPainter(),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: 0.95 + (_pulseAnim.value - 0.92) * 0.5,
                      child: child,
                    ),
                    child: Text(
                      name.arabic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 64,
                        color: Color(0xFFE8D5B0),
                        shadows: [
                          Shadow(
                            color: Color(0xFFD4AF37),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name.transliteration,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.5,
                      color: Color(0xFFE8D5B0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name.meaning,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.8,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    '${name.number} of 99',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.2),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Tap to exit hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'Tap anywhere to exit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.18),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.cardBg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC8A97E).withValues(alpha: isDark ? 0.2 : 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isForward;
  final bool isDark;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.isDark,
    required this.onTap,
    this.isForward = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30))
        : (isDark ? Colors.white12 : Colors.black12);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isForward
            ? [
                Text(label, style: TextStyle(fontSize: 12, color: color)),
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: color),
              ]
            : [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MEDITATION PATTERN PAINTER
// ═══════════════════════════════════════════════════════

class _MeditationPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(Offset(cx, cy), i * 60.0, paint);
    }

    // Radial lines
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + 360 * math.cos(angle), cy + 360 * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MeditationPatternPainter old) => false;
}
