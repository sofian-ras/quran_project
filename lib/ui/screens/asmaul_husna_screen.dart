import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/quran_text_db.dart';

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

const _catFr = {
  'All': 'Tous', 'Mercy': 'Miséricorde', 'Power': 'Puissance',
  'Knowledge': 'Connaissance', 'Creation': 'Création',
  'Sovereignty': 'Souveraineté', 'Forgiveness': 'Pardon',
  'Purity': 'Pureté', 'Justice': 'Justice',
};

const List<AsmaName> kAsmaNames = [
  AsmaName(number: 1, arabic: 'ٱلرَّحْمَـٰنُ', transliteration: 'Ar-Rahmān', meaning: 'Le Très Miséricordieux',
    explanation: 'Sa miséricorde est immense et englobe toute la création. Elle est accordée à tous les êtres — croyants et non-croyants — dans ce monde.',
    reflection: 'Quand tu te sens indigne de miséricorde, souviens-toi qu\'Ar-Rahmān te l\'a accordée avant même que tu la demandes. Sa miséricorde précède Sa colère.',
    verses: ['1:1', '2:163', '17:110'], category: 'Mercy'),
  AsmaName(number: 2, arabic: 'ٱلرَّحِيمُ', transliteration: 'Ar-Rahīm', meaning: 'Le Miséricordieux',
    explanation: 'Sa miséricorde est spécifique, durable et réservée aux croyants dans l\'au-delà. Tandis qu\'Ar-Rahmān est vaste, Ar-Rahīm est intime et personnel.',
    reflection: 'Allah a choisi de Se décrire comme Ar-Rahīm 91 fois dans le Coran. Peu importe combien tu t\'es éloigné, cette porte est toujours ouverte.',
    verses: ['1:1', '2:37', '33:5'], category: 'Mercy'),
  AsmaName(number: 3, arabic: 'ٱلْمَلِكُ', transliteration: 'Al-Malik', meaning: 'Le Roi',
    explanation: 'Souverain absolu sur toute la création, dont la royauté ne nécessite ni conseil, ni armée, ni consentement. Toute la domination Lui appartient.',
    reflection: 'Chaque roi terrestre périra, mais Al-Malik règne éternellement. Quand tu te sens impuissant face à l\'autorité mondaine, souviens-toi de quel royaume compte vraiment.',
    verses: ['59:23', '20:114', '114:2'], category: 'Sovereignty'),
  AsmaName(number: 4, arabic: 'ٱلْقُدُّوسُ', transliteration: 'Al-Quddūs', meaning: 'Le Très Saint',
    explanation: 'Parfaitement pur, exempt de tout défaut, de toute imperfection ou associé. Sa sainteté transcende tout concept humain de perfection.',
    reflection: 'Les anges glorifient Al-Quddūs sans cesse. Dans notre adoration, nous rejoignons ce chœur cosmique de sanctification.',
    verses: ['59:23', '62:1'], category: 'Purity'),
  AsmaName(number: 5, arabic: 'ٱلسَّلَامُ', transliteration: 'As-Salām', meaning: 'La Source de la Paix',
    explanation: 'Il est exempt de tout défaut et de toute imperfection, et Sa salutation aux croyants au Paradis sera "Paix". La véritable paix vient uniquement de Lui.',
    reflection: 'L\'anxiété ne peut coexister avec une confiance sincère en As-Salām. Quand ton cœur est agité, retourne à Celui qui est la paix elle-même.',
    verses: ['59:23', '10:25'], category: 'Purity'),
  AsmaName(number: 6, arabic: 'ٱلْمُؤْمِنُ', transliteration: 'Al-Mu\'min', meaning: 'Le Garant de la Foi',
    explanation: 'Il accorde la sécurité et atteste la vérité de Ses messagers. Il protège les croyants et témoigne de Son propre Unicité.',
    reflection: 'Recevoir la foi en cadeau d\'Al-Mu\'min est la plus grande confiance qui puisse t\'être accordée. Garde-la, nourris-la, et demande-Lui de la préserver.',
    verses: ['59:23'], category: 'Purity'),
  AsmaName(number: 7, arabic: 'ٱلْمُهَيْمِنُ', transliteration: 'Al-Muhaymin', meaning: 'Le Gardien Vigilant',
    explanation: 'Il surveille, garde et supervise toutes les affaires avec une conscience complète. Rien n\'échappe à Sa vigilance absolue.',
    reflection: 'Quand tu te sens invisible, ignoré ou négligé, sache qu\'Al-Muhaymin voit chaque moment caché de ta lutte et de ta dévotion.',
    verses: ['59:23'], category: 'Power'),
  AsmaName(number: 8, arabic: 'ٱلْعَزِيزُ', transliteration: 'Al-\'Azīz', meaning: 'Le Tout-Puissant',
    explanation: 'Invincible dans Sa puissance, unique dans Sa force — aucune force ne peut Le surpasser. Sa puissance est absolue et ne peut être diminuée.',
    reflection: 'Chercher l\'honneur auprès d\'Al-\'Azīz est le seul chemin qui ne déçoit jamais. Toute puissance appartient à Allah, à Son Messager et aux croyants.',
    verses: ['59:23', '2:129', '67:2'], category: 'Power'),
  AsmaName(number: 9, arabic: 'ٱلْجَبَّارُ', transliteration: 'Al-Jabbār', meaning: 'L\'Irrésistible',
    explanation: 'Il contraint toutes choses à Se soumettre à Sa volonté. Il répare aussi les cœurs brisés — "jabara" en arabe signifie également réduire un os fracturé.',
    reflection: 'Le même nom qui décrit la puissance irrésistible d\'Allah décrit aussi Sa guérison tendre des âmes brisées. Il t\'impose Sa guérison.',
    verses: ['59:23'], category: 'Power'),
  AsmaName(number: 10, arabic: 'ٱلْمُتَكَبِّرُ', transliteration: 'Al-Mutakabbir', meaning: 'Le Suprêmement Grand',
    explanation: 'Souverainement grand, dont la grandeur est vraie et absolue. Cette qualité est réservée à Allah seul — l\'orgueil chez l\'homme est un péché, mais chez Allah c\'est Son droit.',
    reflection: 'L\'arrogance chez l\'homme est une maladie. Mais chez Allah, Al-Mutakabbir nous rappelle que toute grandeur est la Sienne — s\'humilier devant Lui est une libération.',
    verses: ['59:23'], category: 'Sovereignty'),
  AsmaName(number: 11, arabic: 'ٱلْخَالِقُ', transliteration: 'Al-Khāliq', meaning: 'Le Créateur',
    explanation: 'Il crée à partir de rien, faisant exister ce qui n\'a jamais existé auparavant. Sa création est intentionnelle, précise et pleine de sagesse.',
    reflection: 'Quand tu t\'émerveilles d\'une fleur, d\'une galaxie ou du rire d\'un enfant — tu contemples la signature d\'Al-Khāliq. La création est Son acte de générosité continue.',
    verses: ['59:24', '6:102', '13:16'], category: 'Creation'),
  AsmaName(number: 12, arabic: 'ٱلْبَارِئُ', transliteration: 'Al-Bāri\'', meaning: 'L\'Initiateur',
    explanation: 'Il distingue chaque chose créée et la fait advenir avec sa forme et sa nature unique. Il sépare et individualise toute la création.',
    reflection: 'Tu n\'as pas été créé par accident. Al-Bāri\' t\'a séparé de tous les autres. Ton unicité est intentionnelle — chéris-la.',
    verses: ['59:24', '2:54'], category: 'Creation'),
  AsmaName(number: 13, arabic: 'ٱلْمُصَوِّرُ', transliteration: 'Al-Musawwir', meaning: 'Le Façonneur',
    explanation: 'Il donne forme et apparence à toute la création. La variété des visages, des empreintes digitales et des voix témoigne de Son art infini.',
    reflection: 'Deux feuilles ne sont pas exactement identiques. Deux visages ne sont pas pareils. Dans chaque visage que tu vois, Al-Musawwir laisse Sa marque de créativité infinie.',
    verses: ['59:24', '3:6'], category: 'Creation'),
  AsmaName(number: 14, arabic: 'ٱلْغَفَّارُ', transliteration: 'Al-Ghaffār', meaning: 'Le Grand Pardonneur',
    explanation: 'Il pardonne à répétition et sans limite. "Ghaffār" à la forme intensive signifie celui qui pardonne encore et encore, peu importe combien de fois on revient.',
    reflection: 'Aucun péché n\'est trop lourd pour qu\'Al-Ghaffār ne le soulève. Chaque retour sincère vers Lui est accueilli par un pardon aussi vaste que le ciel. Reviens. Encore. Et encore.',
    verses: ['20:82', '71:10', '38:66'], category: 'Forgiveness'),
  AsmaName(number: 15, arabic: 'ٱلْقَهَّارُ', transliteration: 'Al-Qahhār', meaning: 'Le Dominateur',
    explanation: 'Il domine tout par Sa puissance. Aucune force dans les cieux ou sur la terre ne peut résister à Sa volonté ou échapper à Sa domination.',
    reflection: 'Quand tu es submergé par ce qui ne peut être changé, repose-toi en sachant qu\'Al-Qahhār a tout soumis. Se rendre n\'est pas une défaite ; c\'est la sagesse.',
    verses: ['13:16', '14:48', '38:65'], category: 'Power'),
  AsmaName(number: 16, arabic: 'ٱلْوَهَّابُ', transliteration: 'Al-Wahhāb', meaning: 'Le Très Généreux',
    explanation: 'Il donne abondamment et continuellement sans attente de retour. Ses dons sont accordés par pure générosité — non en raison de tes actes.',
    reflection: 'Chaque talent, chaque bénédiction, chaque capacité que tu as — tu ne les as pas méritées. Al-Wahhāb les a placés entre tes mains comme un cadeau. Utilise-les bien.',
    verses: ['3:8', '38:9', '38:35'], category: 'Mercy'),
  AsmaName(number: 17, arabic: 'ٱلرَّزَّاقُ', transliteration: 'Ar-Razzāq', meaning: 'Le Pourvoyeur',
    explanation: 'Il pourvoit à toute la création — corps, esprit et âme. Sa subsistance est garantie et atteint chaque être vivant, même avant qu\'elle soit cherchée.',
    reflection: 'Ton rizq était écrit avant ta naissance. Fais confiance à Ar-Razzāq et cesse de laisser l\'inquiétude pour la subsistance envahir ton adoration.',
    verses: ['51:58', '11:6', '35:3'], category: 'Mercy'),
  AsmaName(number: 18, arabic: 'ٱلْفَتَّاحُ', transliteration: 'Al-Fattāh', meaning: 'L\'Ouvreur',
    explanation: 'Il ouvre des portes que personne d\'autre ne peut ouvrir, et Il ouvre les cœurs de ceux qu\'Il choisit. Chaque percée vient de Sa main.',
    reflection: 'Quand toutes les portes semblent fermées, souviens-toi d\'Al-Fattāh. Il est le Maître des ouvertures. Une seule prière à Lui peut transformer l\'impossible en réalité.',
    verses: ['34:26', '35:2'], category: 'Power'),
  AsmaName(number: 19, arabic: 'ٱلْعَلِيمُ', transliteration: 'Al-\'Alīm', meaning: 'Le Très Savant',
    explanation: 'Sa connaissance est infinie, englobant chaque pensée secrète, chaque atome de l\'univers, chaque événement passé, présent et futur.',
    reflection: 'Tu ne peux pas cacher ta douleur à Al-\'Alīm. Il connaît ton chagrin avant que tu le dises. Apporte-Lui tout — Il sait déjà, et Il s\'en préoccupe toujours.',
    verses: ['2:32', '4:11', '6:59'], category: 'Knowledge'),
  AsmaName(number: 20, arabic: 'ٱلْقَابِضُ', transliteration: 'Al-Qābid', meaning: 'Celui qui Retient',
    explanation: 'Il retient la subsistance, les âmes et les bénédictions selon Sa sagesse. Son retrait n\'est jamais injuste — il sert toujours un but plus profond.',
    reflection: 'Les moments où Allah te retient quelque chose ne sont pas un abandon — ce sont des invitations à t\'approcher davantage. Al-Qābid et Al-Bāsit agissent en parfaite sagesse.',
    verses: ['2:245'], category: 'Power'),
  AsmaName(number: 21, arabic: 'ٱلْبَاسِطُ', transliteration: 'Al-Bāsit', meaning: 'Celui qui Accorde l\'Abondance',
    explanation: 'Il étend la subsistance, la miséricorde et la facilité à qui Il veut. Sa générosité peut développer ce qui semblait impossiblement petit.',
    reflection: 'Après chaque resserrement vient une expansion. Al-Qābid et Al-Bāsit sont toujours en équilibre. Fais confiance au cycle — le soulagement arrive.',
    verses: ['2:245'], category: 'Power'),
  AsmaName(number: 22, arabic: 'ٱلْخَافِضُ', transliteration: 'Al-Khāfid', meaning: 'Celui qui Abaisse',
    explanation: 'Il abaisse et humilie ceux qui sont arrogants et oppresseurs. Nul qui s\'élève injustement n\'échappe à Son jugement.',
    reflection: 'Chaque pharaon tombe. Chaque tyran est finalement humilié. Al-Khāfid veille à ce que les balances de la justice ne restent pas déséquilibrées pour toujours.',
    verses: ['56:3'], category: 'Justice'),
  AsmaName(number: 23, arabic: 'ٱلرَّافِعُ', transliteration: 'Ar-Rāfi\'', meaning: 'Celui qui Élève',
    explanation: 'Il élève les humbles, les justes et les dévoués. Aucun serviteur sincère n\'est trop bas pour être élevé par Sa grâce.',
    reflection: 'Les gens que la société ignore ne sont pas ignorés par Ar-Rāfi\'. La vraie élévation vient de Lui seul — non du rang, de la richesse ou de la célébrité.',
    verses: ['56:3', '58:11'], category: 'Justice'),
  AsmaName(number: 24, arabic: 'ٱلْمُعِزُّ', transliteration: 'Al-Mu\'izz', meaning: 'Celui qui Honore',
    explanation: 'Il accorde l\'honneur et la dignité à qui Il veut. Aucun effort mondain ne peut accorder le vrai honneur — il vient d\'Allah seul.',
    reflection: 'Cherche l\'honneur auprès d\'Al-Mu\'izz par l\'obéissance, non par l\'approbation des gens. L\'honneur qu\'Il accorde est le seul qui dure.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 25, arabic: 'ٱلْمُذِلُّ', transliteration: 'Al-Mudhill', meaning: 'Celui qui Humilie',
    explanation: 'Il apporte le déshonneur à ceux qui s\'opposent à Sa vérité ou oppriment Ses serviteurs. L\'humiliation venant de Lui est une correction, non une cruauté.',
    reflection: 'Ne cherche pas l\'approbation de ceux qu\'Allah a humiliés. Al-Mudhill nous rappelle que le statut mondain est temporaire — le jugement divin est permanent.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 26, arabic: 'ٱلسَّمِيعُ', transliteration: 'As-Samī\'', meaning: 'Le Très Entendant',
    explanation: 'Il entend chaque son, chaque murmure, chaque supplication silencieuse du cœur. La distance et le bruit ne limitent pas Son ouïe.',
    reflection: 'Chaque du\'a que tu fais atteint As-Samī\' instantanément. Tu ne pries jamais dans le vide — Il entend même les pensées que tu as peur d\'exprimer.',
    verses: ['2:127', '2:186', '3:38'], category: 'Knowledge'),
  AsmaName(number: 27, arabic: 'ٱلْبَصِيرُ', transliteration: 'Al-Basīr', meaning: 'Le Très Voyant',
    explanation: 'Il voit toutes choses, visibles et invisibles, proches et lointaines, dans les profondeurs des ténèbres et dans la clarté du jour.',
    reflection: 'Al-Basīr voit le bien que tu fais quand personne ne regarde. La charité donnée en secret, la larme versée sincèrement — Il voit tout, et c\'est compté.',
    verses: ['4:58', '17:1', '67:19'], category: 'Knowledge'),
  AsmaName(number: 28, arabic: 'ٱلْحَكَمُ', transliteration: 'Al-Hakam', meaning: 'Le Juge',
    explanation: 'Le juge suprême dont les verdicts sont parfaits et définitifs. Aucune injustice n\'est possible venant de Lui ; Son jugement est le plus juste de tous.',
    reflection: 'Chaque tort sera adressé. Al-Hakam veille à ce qu\'aucune larme ne soit tombée en vain, qu\'aucune injustice n\'ait été oubliée. Les balances seront parfaitement équilibrées.',
    verses: ['6:57', '40:48'], category: 'Justice'),
  AsmaName(number: 29, arabic: 'ٱلْعَدْلُ', transliteration: 'Al-\'Adl', meaning: 'Le Juste',
    explanation: 'Parfaitement juste dans tous Ses décrets. Il ne lèse personne du poids d\'un atome. Sa justice dépasse tous les standards humains.',
    reflection: 'Fais confiance en Al-\'Adl quand la vie semble injuste. Chaque déséquilibre sera corrigé — soit dans ce monde, soit dans l\'autre. Sa justice est parfaite.',
    verses: ['4:40', '10:44'], category: 'Justice'),
  AsmaName(number: 30, arabic: 'ٱللَّطِيفُ', transliteration: 'Al-Latīf', meaning: 'Le Subtil',
    explanation: 'Il est doux, subtil et attentif aux détails les plus fins. Il pourvoit à Ses serviteurs par des moyens qu\'ils ne peuvent voir ou anticiper.',
    reflection: 'Al-Latīf travaille dans le tissu invisible de ta vie, tissant ensemble des moments d\'une façon que tu ne comprendras que des années plus tard. Fais confiance à la subtilité.',
    verses: ['6:103', '22:63', '67:14'], category: 'Knowledge'),
  AsmaName(number: 31, arabic: 'ٱلْخَبِيرُ', transliteration: 'Al-Khabīr', meaning: 'Le Parfaitement Informé',
    explanation: 'Il a une connaissance intérieure complète de toutes choses — non seulement leur forme extérieure mais leur réalité intérieure, leur histoire et leur conséquence.',
    reflection: 'Tu ne peux pas tromper Al-Khabīr avec une piété extérieure en cachant une corruption intérieure. Mais aussi — Il voit ta sincérité cachée et tes luttes silencieuses.',
    verses: ['6:18', '17:30', '34:1'], category: 'Knowledge'),
  AsmaName(number: 32, arabic: 'ٱلْحَلِيمُ', transliteration: 'Al-Halīm', meaning: 'Le Très Indulgent',
    explanation: 'Il ne se hâte pas à punir malgré tout Son pouvoir pour le faire. Il accorde du répit et une opportunité de repentir par Sa douceur.',
    reflection: 'Chaque moment où tu n\'es pas immédiatement puni pour tes péchés est un cadeau d\'Al-Halīm. Son indulgence est une invitation à revenir.',
    verses: ['2:225', '4:12', '17:44'], category: 'Mercy'),
  AsmaName(number: 33, arabic: 'ٱلْعَظِيمُ', transliteration: 'Al-\'Azīm', meaning: 'Le Très Grand',
    explanation: 'Sa grandeur est au-delà de toute mesure ou compréhension. Les plus grandes choses que les humains conçoivent sont infiniment plus petites que Sa véritable magnificence.',
    reflection: 'Ayat al-Kursi s\'ouvre avec "Il est Al-\'Aliyy Al-\'Azīm." Récite-la et laisse la magnitude de Celui que tu adores s\'installer dans ton cœur.',
    verses: ['2:255', '42:4', '56:74'], category: 'Sovereignty'),
  AsmaName(number: 34, arabic: 'ٱلْغَفُورُ', transliteration: 'Al-Ghafūr', meaning: 'Le Très Pardonnant',
    explanation: 'Il pardonne les péchés et couvre les fautes de Sa miséricorde. "Ghafūr" signifie celui qui pardonne totalement — effaçant, couvrant et dissimulant le péché.',
    reflection: 'Quand tu te sens honteux de ton passé, souviens-toi qu\'Al-Ghafūr ne fait pas que pardonner — Il couvre. Il ne révèlera pas ce qu\'Il a dissimulé.',
    verses: ['2:173', '4:23', '35:28'], category: 'Forgiveness'),
  AsmaName(number: 35, arabic: 'ٱلشَّكُورُ', transliteration: 'Ash-Shakūr', meaning: 'Le Très Reconnaissant',
    explanation: 'Il apprécie et récompense même les plus petites bonnes actions, les multipliant bien au-delà de leur valeur. Il ne laisse jamais un effort sincère sans reconnaissance.',
    reflection: 'Même le poids d\'un atome de bonté est vu par Ash-Shakūr. Ton acte d\'adoration le plus privé, ta gentillesse la plus oubliée — Il l\'apprécie.',
    verses: ['35:30', '64:17', '35:34'], category: 'Mercy'),
  AsmaName(number: 36, arabic: 'ٱلْعَلِيُّ', transliteration: 'Al-\'Alī', meaning: 'Le Très Élevé',
    explanation: 'Exalté au-dessus de toute la création dans Son essence, Ses attributs et Sa puissance. Sa transcendance est absolue et incomparable.',
    reflection: 'Quand tu cherches le statut aux yeux des gens, tu t\'abaisses. La vraie élévation vient du lien avec Al-\'Alī — le Très Élevé.',
    verses: ['2:255', '4:34', '42:51'], category: 'Sovereignty'),
  AsmaName(number: 37, arabic: 'ٱلْكَبِيرُ', transliteration: 'Al-Kabīr', meaning: 'Le Plus Grand',
    explanation: 'Il est vraiment grand en tout sens — en puissance, en connaissance, en miséricorde et dans tous Ses attributs. Rien ne s\'approche de Sa magnitude.',
    reflection: 'Dire "Allahu Akbar" signifie "Allah est plus grand" — plus grand que tout ce qui te pèse en ce moment. Laisse cela s\'établir dans chaque salah.',
    verses: ['13:9', '22:62', '31:30'], category: 'Sovereignty'),
  AsmaName(number: 38, arabic: 'ٱلْحَفِيظُ', transliteration: 'Al-Hafīz', meaning: 'Le Gardien',
    explanation: 'Il préserve et protège toutes choses, tenant un compte minutieux de chaque action. Il garde l\'univers de l\'effondrement et protège Ses serviteurs.',
    reflection: 'Rien de ce que tu fais n\'est perdu dans le registre cosmique d\'Al-Hafīz. Chaque bonne action est préservée, chaque intention sincère gardée, chaque dhikr enregistré.',
    verses: ['11:57', '34:21', '42:6'], category: 'Knowledge'),
  AsmaName(number: 39, arabic: 'ٱلْمُقِيتُ', transliteration: 'Al-Muqīt', meaning: 'Le Soutien',
    explanation: 'Il fournit la nourriture — physique, spirituelle et intellectuelle — à toutes les créatures. Il soutient l\'existence elle-même à chaque instant.',
    reflection: 'Même quand tu oublies de manger, Al-Muqīt soutient ton battement de cœur, ta respiration, tes pensées. Sa subsistance est plus constante que tu ne le réalises.',
    verses: ['4:85'], category: 'Mercy'),
  AsmaName(number: 40, arabic: 'ٱلْحَسِيبُ', transliteration: 'Al-Hasīb', meaning: 'Le Calculateur',
    explanation: 'Il compte toutes choses avec une précision parfaite. Rien n\'échappe à Son décompte, et Il suffit en tant que gardien et juge.',
    reflection: 'Rends-toi comptable à toi-même avant qu\'Al-Hasīb ne te demande des comptes au Jour du Jugement. L\'auto-examen quotidien est la sunna des sages.',
    verses: ['4:6', '4:86', '33:39'], category: 'Knowledge'),
  AsmaName(number: 41, arabic: 'ٱلْجَلِيلُ', transliteration: 'Al-Jalīl', meaning: 'Le Majestueux',
    explanation: 'Possédant une grandeur complète et parfaite dans tous les attributs. Sa majesté commande révérence et crainte chez tous ceux qui Le connaissent vraiment.',
    reflection: 'L\'adoration née de l\'amour pour Al-Wadūd combinée à la révérence d\'Al-Jalīl est la forme d\'adoration la plus complète — entre aspiration et vénération.',
    verses: ['55:27', '55:78'], category: 'Sovereignty'),
  AsmaName(number: 42, arabic: 'ٱلْكَرِيمُ', transliteration: 'Al-Karīm', meaning: 'Le Noble Généreux',
    explanation: 'Sa générosité est sans fin ni condition. Il donne avant d\'être demandé, donne plus que ce qui a été demandé, et donne sans rien attendre en retour.',
    reflection: 'La générosité d\'Al-Karīm fait honte à notre avarice. Refléter ce nom, c\'est donner, pardonner et être généreux — surtout quand personne ne regarde.',
    verses: ['27:40', '82:6', '96:3'], category: 'Mercy'),
  AsmaName(number: 43, arabic: 'ٱلرَّقِيبُ', transliteration: 'Ar-Raqīb', meaning: 'Le Très Vigilant',
    explanation: 'Il surveille toutes choses avec une vigilance et une conscience parfaites. Chaque pensée, chaque parole et chaque acte sont sous Son observation attentive.',
    reflection: 'La vraie taqwa vient de ressentir le regard d\'Ar-Raqīb même dans tes moments les plus privés. Cette conscience transforme le caractère.',
    verses: ['4:1', '5:117', '33:52'], category: 'Knowledge'),
  AsmaName(number: 44, arabic: 'ٱلْمُجِيبُ', transliteration: 'Al-Mujīb', meaning: 'Celui qui Répond',
    explanation: 'Il répond à chaque appel, chaque prière, chaque besoin — même si la réponse arrive sous une forme ou à un moment différent de ce qui était attendu.',
    reflection: 'Allah a promis : "Invoquez-Moi, Je vous répondrai." Al-Mujīb est lié par Sa propre promesse de répondre. Ton du\'a n\'est jamais sans réponse.',
    verses: ['2:186', '11:61', '37:75'], category: 'Mercy'),
  AsmaName(number: 45, arabic: 'ٱلْوَاسِعُ', transliteration: 'Al-Wāsi\'', meaning: 'L\'Immense',
    explanation: 'Sa connaissance, Sa miséricorde et Sa générosité sont vastes au-delà de toute frontière ou limite. Il peut satisfaire chaque besoin de chaque créature simultanément.',
    reflection: 'Peu importe combien de personnes se tournent vers Al-Wāsi\' en même temps, Son immensité n\'est pas diminuée. Sa miséricorde et Sa subsistance sont inépuisables.',
    verses: ['2:115', '2:268', '5:54'], category: 'Mercy'),
  AsmaName(number: 46, arabic: 'ٱلْحَكِيمُ', transliteration: 'Al-Hakīm', meaning: 'Le Très Sage',
    explanation: 'Parfait en sagesse — Il place chaque chose exactement où elle doit être, fait chaque chose au moment le plus parfait, avec le résultat le plus parfait.',
    reflection: 'Quand le décret d\'Allah te confond, reviens à Al-Hakīm. Sa sagesse voit ce que tes yeux ne peuvent pas. Fais confiance à la sagesse derrière ce que tu ne comprends pas.',
    verses: ['2:129', '3:6', '4:26'], category: 'Knowledge'),
  AsmaName(number: 47, arabic: 'ٱلْوَدُودُ', transliteration: 'Al-Wadūd', meaning: 'Le Plein d\'Amour',
    explanation: 'Il aime Ses serviteurs d\'un amour pur, inconditionnel et éternellement constant. Il aime et Il manifeste Son amour.',
    reflection: 'Al-Wadūd t\'aime. Pas pour ta perfection, mais malgré ton imperfection. Laisse cet amour être le fondement de ta relation avec Lui.',
    verses: ['11:90', '85:14'], category: 'Mercy'),
  AsmaName(number: 48, arabic: 'ٱلْمَجِيدُ', transliteration: 'Al-Majīd', meaning: 'Le Très Glorieux',
    explanation: 'Il est glorieux dans Son essence et généreux dans Ses attributs. Sa gloire est complète, combinant les attributs les plus élevés avec les actes les plus beaux.',
    reflection: 'Quand nous demandons des bénédictions sur le Prophète ﷺ, nous invoquons Allah comme Al-Majīd. Ce nom apparaît dans chaque salah — il relie glorification et générosité.',
    verses: ['11:73', '85:15'], category: 'Sovereignty'),
  AsmaName(number: 49, arabic: 'ٱلْبَاعِثُ', transliteration: 'Al-Bā\'ith', meaning: 'Celui qui Ressuscite',
    explanation: 'Il ressuscite les morts au Jour de la Résurrection et envoie des messagers pour réveiller l\'humanité de son sommeil spirituel. La résurrection est entièrement entre Ses mains.',
    reflection: 'Tout comme Il ressuscite la terre morte avec la pluie, Al-Bā\'ith peut raviver un cœur mort par un moment de souvenir sincère. Demande-Lui ce renouveau.',
    verses: ['22:7', '58:6'], category: 'Power'),
  AsmaName(number: 50, arabic: 'ٱلشَّهِيدُ', transliteration: 'Ash-Shahīd', meaning: 'Le Témoin',
    explanation: 'Il témoigne de toutes choses directement et complètement. Son témoignage est parfait car Il est présent à tout simultanément.',
    reflection: 'Vis ta vie dans la conscience d\'Ash-Shahīd. Que changerait-il si tu ressentais pleinement Sa présence — dans ta parole, tes transactions, tes moments privés ?',
    verses: ['4:33', '22:17', '41:53'], category: 'Knowledge'),
  AsmaName(number: 51, arabic: 'ٱلْحَقُّ', transliteration: 'Al-Haqq', meaning: 'La Vérité',
    explanation: 'Il est la vérité ultime — Son existence est la vérité absolue, Ses attributs sont vrais, Ses paroles sont vérité et Ses promesses sont vraies.',
    reflection: 'Dans un monde plein d\'illusions et de mensonges, Al-Haqq est le seul point fixe de certitude. Ancre ta vie en Lui et rien ne peut t\'ébranler.',
    verses: ['20:114', '22:6', '23:116'], category: 'Purity'),
  AsmaName(number: 52, arabic: 'ٱلْوَكِيلُ', transliteration: 'Al-Wakīl', meaning: 'Le Garant',
    explanation: 'Le meilleur mandataire et gardien de toutes les affaires. Quand tu Lui confies tes affaires, Il les gère avec une sagesse et un soin parfaits.',
    reflection: '"Hasbunallahu wa ni\'mal wakīl" — Allah nous suffit et quel excellent garant Il est. C\'est la formule des prophètes dans leurs moments les plus difficiles.',
    verses: ['3:173', '4:81', '6:102'], category: 'Power'),
  AsmaName(number: 53, arabic: 'ٱلْقَوِيُّ', transliteration: 'Al-Qawiyy', meaning: 'Le Très Fort',
    explanation: 'Sa force est absolue, ne diminue jamais, ne se fatigue jamais. Toute la puissance dans la création est dérivée de Sa force et lui est subordonnée.',
    reflection: 'L\'armée la plus puissante, la nation la plus forte, l\'individu le plus robuste — tous sont absolument faibles devant Al-Qawiyy. Puise ta force en Lui.',
    verses: ['8:52', '22:40', '22:74'], category: 'Power'),
  AsmaName(number: 54, arabic: 'ٱلْمَتِينُ', transliteration: 'Al-Matīn', meaning: 'Le Très Ferme',
    explanation: 'Sa puissance est complètement ferme, inébranlable et inépuisable. Il n\'est jamais affaibli, jamais fatigué, jamais ébranlé.',
    reflection: 'Quand ta propre résolution faiblit et que ta foi fluctue, reviens à Al-Matīn. Sa fermeté est l\'ancre de ton inconstance.',
    verses: ['51:58'], category: 'Power'),
  AsmaName(number: 55, arabic: 'ٱلْوَلِيُّ', transliteration: 'Al-Waliyy', meaning: 'Le Protecteur Fidèle',
    explanation: 'Il est le protecteur ultime et l\'allié des croyants. L\'avoir comme walī est le plus grand honneur qu\'une âme puisse posséder.',
    reflection: 'Si Allah est ton Walī, qu\'est-ce qui peut te nuire ? "Allah est le Walī de ceux qui croient." Tu n\'es jamais vraiment seul quand tu as le meilleur Ami.',
    verses: ['2:257', '3:68', '42:28'], category: 'Mercy'),
  AsmaName(number: 56, arabic: 'ٱلْحَمِيدُ', transliteration: 'Al-Hamīd', meaning: 'Le Très Loué',
    explanation: 'Il mérite toute louange — intrinsèquement et dans toutes Ses actions. Chaque bénédiction, chaque épreuve et chaque décret méritent la louange.',
    reflection: 'Al-Hamīd mérite la louange non parce que tout va bien, mais malgré les difficultés. La vraie hamd est offerte dans l\'épreuve — c\'est là qu\'elle signifie le plus.',
    verses: ['14:1', '31:12', '60:6'], category: 'Purity'),
  AsmaName(number: 57, arabic: 'ٱلْمُحْصِي', transliteration: 'Al-Muhsī', meaning: 'Celui qui Dénombre',
    explanation: 'Il compte avec précision toutes choses — chaque action, chaque atome, chaque seconde. Rien dans toute la création ne dépasse Son dénombrement parfait.',
    reflection: 'Al-Muhsī compte des choses que tu as oubliées. Chaque parole aimable, chaque prière, chaque moment de patience — chacun est compté et préservé.',
    verses: ['19:94', '78:29'], category: 'Knowledge'),
  AsmaName(number: 58, arabic: 'ٱلْمُبْدِئُ', transliteration: 'Al-Mubdi\'', meaning: 'L\'Initiateur',
    explanation: 'Il initie et fait exister à partir de rien, sans aucun précédent ni modèle. La première création était entièrement Sa propre initiation.',
    reflection: 'Chaque début dans ta vie est un rappel d\'Al-Mubdi\'. Il peut commencer quelque chose d\'entièrement nouveau dans ta vie, même quand tout semble terminé.',
    verses: ['10:34', '29:19'], category: 'Creation'),
  AsmaName(number: 59, arabic: 'ٱلْمُعِيدُ', transliteration: 'Al-Mu\'īd', meaning: 'Le Restaurateur',
    explanation: 'Il ramène la création après la mort. Celui qui a commencé la création la restaurera certainement — la résurrection est Sa promesse et Sa puissance.',
    reflection: 'Tout ce qui dans ta vie a été perdu ou s\'est terminé — Al-Mu\'īd peut le restaurer. Celui qui ressuscite les morts peut certainement restaurer les vivants.',
    verses: ['10:34', '85:13'], category: 'Creation'),
  AsmaName(number: 60, arabic: 'ٱلْمُحْيِي', transliteration: 'Al-Muhyī', meaning: 'Celui qui Donne la Vie',
    explanation: 'Il est la seule source de vie sous toutes ses formes — biologique, spirituelle et éternelle. Lui seul peut véritablement accorder la vie.',
    reflection: 'Quand ton âme se sent morte, quand la foi semble éteinte — invoque Al-Muhyī. Il donne la vie à la terre morte. Et au cœur mort.',
    verses: ['2:258', '30:50', '41:39'], category: 'Creation'),
  AsmaName(number: 61, arabic: 'ٱلْمُمِيتُ', transliteration: 'Al-Mumīt', meaning: 'Celui qui Donne la Mort',
    explanation: 'Il désigne la mort pour tous les êtres vivants. C\'est un profond rappel du but de la vie et de la certitude du retour vers Lui.',
    reflection: 'Se souvenir de la mort n\'est pas morbide — c\'est clarificateur. Al-Mumīt te rappelle que cette vie est un voyage, non une destination.',
    verses: ['2:258', '3:156', '7:158'], category: 'Power'),
  AsmaName(number: 62, arabic: 'ٱلْحَيُّ', transliteration: 'Al-Hayy', meaning: 'Le Vivant',
    explanation: 'Il est éternellement vivant — Sa vie n\'a ni début, ni fin, ni interruption. Toute la vie de la création est empruntée de la Sienne.',
    reflection: 'Al-Hayy est le nom à invoquer dans tes heures les plus sombres. Le Vivant ne t\'abandonnera jamais à ce qui ne peut ni voir, ni entendre, ni se soucier.',
    verses: ['2:255', '3:2', '20:111'], category: 'Purity'),
  AsmaName(number: 63, arabic: 'ٱلْقَيُّومُ', transliteration: 'Al-Qayyūm', meaning: 'L\'Immuable',
    explanation: 'Il soutient toute l\'existence et n\'a besoin de rien en retour. Il est auto-suffisant ; toute la création dépend de Lui, mais Il ne dépend de rien.',
    reflection: 'Les prophètes utilisaient "Yā Hayyu Yā Qayyūm" dans leurs moments les plus désespérés. Ces deux noms ensemble sont une puissance au-delà de toute description. Utilise-les.',
    verses: ['2:255', '3:2', '20:111'], category: 'Purity'),
  AsmaName(number: 64, arabic: 'ٱلْوَاجِدُ', transliteration: 'Al-Wājid', meaning: 'Celui qui Trouve',
    explanation: 'Il trouve et perçoit tout ce qu\'Il veut — Il n\'est jamais dans le besoin, jamais manquant, toujours pleinement conscient et en possession de toutes choses.',
    reflection: 'Rien n\'est jamais vraiment perdu de la conscience d\'Al-Wājid. Chaque chose manquante, chaque âme oubliée, chaque bénédiction enfouie — Il les perçoit toutes.',
    verses: ['38:44'], category: 'Power'),
  AsmaName(number: 65, arabic: 'ٱلْمَاجِدُ', transliteration: 'Al-Mājid', meaning: 'Le Noble',
    explanation: 'Il est noble, généreux et glorieux dans Son essence. Sa noblesse est la source de tout ce qui est beau et élevé dans la création.',
    reflection: 'Quand tu cherches la noblesse de caractère en toi-même, regarde vers Al-Mājid. Demande-Lui de cultiver en toi ce qu\'Il incarne parfaitement.',
    verses: ['11:73', '85:15'], category: 'Sovereignty'),
  AsmaName(number: 66, arabic: 'ٱلْوَاحِدُ', transliteration: 'Al-Wāhid', meaning: 'L\'Unique',
    explanation: 'Il est seul dans Sa divinité, Sa souveraineté et Ses attributs. Il n\'y a ni associé, ni égal, ni comparaison. L\'unité est Sa vérité absolue.',
    reflection: 'Tout le Coran est une élaboration d\'Al-Wāhid. Le tawhīd n\'est pas seulement un point théologique ; c\'est une façon d\'organiser toute ta vie.',
    verses: ['2:163', '13:16', '39:4'], category: 'Purity'),
  AsmaName(number: 67, arabic: 'ٱلْأَحَدُ', transliteration: 'Al-Ahad', meaning: 'L\'Un Absolu',
    explanation: 'Il est absolument unique — non seulement singulier en nombre mais sans égal dans Son essence et Ses attributs. Al-Wāhid est l\'unicité ; Al-Ahad est l\'unicité absolue.',
    reflection: 'La sourate Al-Ikhlās est un tiers du Coran car Al-Ahad est l\'axe autour duquel toute connaissance d\'Allah tourne. Reviens-y souvent.',
    verses: ['112:1'], category: 'Purity'),
  AsmaName(number: 68, arabic: 'ٱلصَّمَدُ', transliteration: 'As-Samad', meaning: 'Le Refuge Éternel',
    explanation: 'Celui vers lequel toute la création se tourne dans le besoin. Il est complet en Lui-même, sans aucun besoin, et tous les autres dépendent de Lui.',
    reflection: 'Quand tu ressens l\'envie de t\'appuyer sur une personne pour ce qu\'Allah seul peut fournir, souviens-toi d\'As-Samad — le seul refuge qui ne faillit jamais.',
    verses: ['112:2'], category: 'Purity'),
  AsmaName(number: 69, arabic: 'ٱلْقَادِرُ', transliteration: 'Al-Qādir', meaning: 'Le Tout-Capable',
    explanation: 'Complètement capable de toutes choses sans effort, contrainte ou limitation. Tout ce qu\'Il veut vient à l\'existence par Son mot "Sois" — et cela est.',
    reflection: 'Ne limite jamais ton du\'a en pensant "c\'est trop demander." La capacité d\'Al-Qādir n\'est pas limitée par la taille de ta demande.',
    verses: ['2:20', '2:109', '6:65'], category: 'Power'),
  AsmaName(number: 70, arabic: 'ٱلْمُقْتَدِرُ', transliteration: 'Al-Muqtadir', meaning: 'Le Puissant',
    explanation: 'Il exerce Sa puissance avec une autorité et un contrôle parfaits. Sa puissance n\'est pas seulement potentielle mais continuellement exercée sur toute la création.',
    reflection: 'Quand quelque chose dans ta vie semble hors de contrôle, souviens-toi qu\'Al-Muqtadir en a la maîtrise. Lâche prise — Son contrôle est infiniment meilleur.',
    verses: ['18:45', '54:42', '54:55'], category: 'Power'),
  AsmaName(number: 71, arabic: 'ٱلْمُقَدِّمُ', transliteration: 'Al-Muqaddim', meaning: 'Celui qui Avance',
    explanation: 'Il fait avancer et progresse qui et ce qu\'Il veut. Il peut élever, prioriser et accélérer ceux qu\'Il choisit.',
    reflection: 'Succès, timing et rang — tout est entre les mains d\'Al-Muqaddim. Accomplis le travail et laisse-Le déterminer l\'ordre et le timing de ton élévation.',
    verses: ['50:28'], category: 'Power'),
  AsmaName(number: 72, arabic: 'ٱلْمُؤَخِّرُ', transliteration: 'Al-Mu\'akhkhir', meaning: 'Celui qui Diffère',
    explanation: 'Il retarde et diffère qui et ce qu\'Il veut. Chaque délai dans Son plan est une miséricorde — Il reporte ce qui te nuirait prématurément.',
    reflection: 'Les portes qui ne se sont pas encore ouvertes, les prières qui n\'ont pas encore reçu de réponse — Al-Mu\'akhkhir est à l\'œuvre. Son délai n\'est jamais un abandon.',
    verses: ['71:4'], category: 'Power'),
  AsmaName(number: 73, arabic: 'ٱلْأَوَّلُ', transliteration: 'Al-Awwal', meaning: 'Le Premier',
    explanation: 'Il existait avant toutes choses — avant le temps, l\'espace et la création. Il n\'y a rien avant Lui, aucune cause antérieure à Lui.',
    reflection: 'Avant que tes problèmes existent, Al-Awwal existait. Avant que tes soucis soient nés, Il était là. Il précède chaque difficulté par Sa présence.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 74, arabic: 'ٱلْآخِرُ', transliteration: 'Al-Ākhir', meaning: 'Le Dernier',
    explanation: 'Il demeurera après que toute la création aura cessé d\'exister. Quand les cieux se replieront et les étoiles s\'éteindront, Al-Ākhir sera tout ce qui reste.',
    reflection: 'Investis dans la seule relation qui survivra à tout le reste. Al-Ākhir sera là quand tout le reste sera parti. Priorise en conséquence.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 75, arabic: 'ٱلظَّاهِرُ', transliteration: 'Az-Zāhir', meaning: 'L\'Apparent',
    explanation: 'Il est évident et manifeste à travers Ses signes, Sa création et Ses preuves. Son existence est indéniablement présente dans tout ce qui nous entoure.',
    reflection: 'Chaque signe de beauté, d\'ordre et de but dans la création est Az-Zāhir qui parle. Ouvre les yeux — Il est visible partout.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 76, arabic: 'ٱلْبَاطِنُ', transliteration: 'Al-Bātin', meaning: 'Le Caché',
    explanation: 'Sa véritable essence est au-delà de la compréhension humaine. Bien que Ses signes soient manifestes, Sa réalité transcende toute perception et compréhension.',
    reflection: 'Al-Bātin et Az-Zāhir ensemble : Il est manifeste à travers Sa création mais caché dans Son essence. La révérence et l\'intimité sont toutes deux des réponses appropriées.',
    verses: ['57:3'], category: 'Purity'),
  AsmaName(number: 77, arabic: 'ٱلْوَالِي', transliteration: 'Al-Wālī', meaning: 'Le Gouverneur',
    explanation: 'Il gouverne et administre toute la création avec une autorité parfaite. Chaque système dans l\'univers fonctionne sous Sa gouvernance.',
    reflection: 'Quand la gouvernance humaine échoue et que la justice semble absente, la gouvernance d\'Al-Wālī ne faillit jamais. Son administration du cosmos est parfaite.',
    verses: ['13:11', '18:44'], category: 'Sovereignty'),
  AsmaName(number: 78, arabic: 'ٱلْمُتَعَالِي', transliteration: 'Al-Muta\'āli', meaning: 'Le Suprêmement Élevé',
    explanation: 'Il est souverainement exalté au-dessus de toutes choses par Son essence propre — Sa transcendance est intrinsèque, non conférée par d\'autres.',
    reflection: 'L\'orgueil humain dans nos accomplissements n\'est qu\'une ombre. Al-Muta\'āli nous rappelle que toute vraie exaltation Lui appartient seul.',
    verses: ['13:9'], category: 'Sovereignty'),
  AsmaName(number: 79, arabic: 'ٱلْبَرُّ', transliteration: 'Al-Barr', meaning: 'La Source de la Bonté',
    explanation: 'Il est immensément bon et bienveillant envers Ses serviteurs. Toute bonté lui appartient en dernier ressort comme source originelle et parfaite.',
    reflection: 'Chaque bonne chose dans ta vie remonte à Al-Barr. Reconnaître cela transforme la gratitude d\'une obligation en un débordement spontané du cœur.',
    verses: ['52:28'], category: 'Mercy'),
  AsmaName(number: 80, arabic: 'ٱلتَّوَّابُ', transliteration: 'At-Tawwāb', meaning: 'Celui qui Accueille le Repentir',
    explanation: 'Il se tourne vers Ses serviteurs en miséricorde quand ils se repentent, et Il permet le repentir dans le cœur. Il revient vers toi même quand tu reviens vers Lui.',
    reflection: 'Ce n\'est pas toi qui as initié ton retour vers Allah — Il a ouvert ton cœur en premier. At-Tawwāb rend la tawba possible. Remercie-Le pour l\'envie de se repentir.',
    verses: ['2:37', '2:54', '4:64'], category: 'Forgiveness'),
  AsmaName(number: 81, arabic: 'ٱلْمُنْتَقِمُ', transliteration: 'Al-Muntaqim', meaning: 'Le Vengeur Juste',
    explanation: 'Il exerce une rétribution envers ceux qui persistent dans le péché et l\'oppression sans repentir. Sa vengeance est juste, proportionnelle et jamais excessive.',
    reflection: 'Les opprimés ont le meilleur avocat : Al-Muntaqim. Chaque cruauté vue par les yeux humains est vue par Lui — et la justice viendra.',
    verses: ['3:4', '5:95', '44:16'], category: 'Justice'),
  AsmaName(number: 82, arabic: 'ٱلْعَفُوُّ', transliteration: 'Al-\'Afuww', meaning: 'Le Très Indulgent',
    explanation: 'Il ne fait pas que pardonner les péchés mais les efface complètement — comme s\'ils n\'avaient jamais existé. "\'Afw" signifie essuyer, ne laissant aucune trace.',
    reflection: 'Durant Laylat al-Qadr, le Prophète ﷺ nous a appris à demander : "Ô Allah, Tu es Al-\'Afuww, Tu aimes l\'indulgence — alors pardonne-moi." C\'est la demande ultime.',
    verses: ['4:43', '4:99', '22:60'], category: 'Forgiveness'),
  AsmaName(number: 83, arabic: 'ٱلرَّءُوفُ', transliteration: 'Ar-Ra\'ūf', meaning: 'Le Très Compatissant',
    explanation: 'Il est intensément compatissant — Sa compassion est une miséricorde ressentie qui L\'incite à préserver Ses serviteurs des épreuves et à les protéger.',
    reflection: 'La compassion d\'Ar-Ra\'ūf est pourquoi Il commande ce qu\'Il commande et interdit ce qu\'Il interdit. Chaque règle divine est une expression de Sa compassion pour toi.',
    verses: ['2:143', '3:30', '9:117'], category: 'Mercy'),
  AsmaName(number: 84, arabic: 'مَالِكُ ٱلْمُلْكِ', transliteration: 'Mālik Al-Mulk', meaning: 'Maître du Royaume',
    explanation: 'Il est le vrai propriétaire de tous les royaumes et domaines. Il accorde la domination à qui Il veut et la retire à qui Il veut.',
    reflection: 'Chaque dirigeant, chaque président, chaque roi détient sa position en prêt de Mālik Al-Mulk. L\'autorité sans Sa sanction est transitoire et vide.',
    verses: ['3:26'], category: 'Sovereignty'),
  AsmaName(number: 85, arabic: 'ذُو ٱلْجَلَالِ وَٱلْإِكْرَامِ', transliteration: 'Dhul-Jalāli Wal-Ikrām', meaning: 'Seigneur de la Majesté et de la Générosité',
    explanation: 'Il combine la majesté suprême avec la générosité suprême. Ces deux qualités forment l\'axe de toute adoration.',
    reflection: 'Le Prophète ﷺ recommandait de répéter souvent ce nom. Il unit crainte et amour, révérence et espoir — les deux ailes avec lesquelles le cœur du croyant prend son envol.',
    verses: ['55:27', '55:78'], category: 'Sovereignty'),
  AsmaName(number: 86, arabic: 'ٱلْمُقْسِطُ', transliteration: 'Al-Muqsit', meaning: 'L\'Équitable',
    explanation: 'Il est parfaitement équitable et juste dans tous Ses jugements. Il ne favorise pas le puissant sur le faible ni le riche sur le pauvre.',
    reflection: 'L\'équité parfaite est impossible pour les humains, mais Al-Muqsit l\'établit. Aimer ce nom, c\'est s\'engager à être aussi équitable que notre nature humaine le permet.',
    verses: ['7:29', '60:8'], category: 'Justice'),
  AsmaName(number: 87, arabic: 'ٱلْجَامِعُ', transliteration: 'Al-Jāmi\'', meaning: 'Le Rassembleur',
    explanation: 'Il rassemble toute la création au Jour de la Résurrection. Il réunit ce qui est séparé dans le monde — subsistance, cœurs et vérités.',
    reflection: 'Chaque être cher qui est décédé, chaque lien qui a été rompu — Al-Jāmi\' les réunira. Aucune séparation n\'est permanente devant Lui.',
    verses: ['3:9', '4:140'], category: 'Power'),
  AsmaName(number: 88, arabic: 'ٱلْغَنِيُّ', transliteration: 'Al-Ghanī', meaning: 'L\'Indépendant',
    explanation: 'Il est complètement auto-suffisant et exempt de tout besoin. Toute l\'existence pourrait disparaître et Il ne serait pas diminué d\'un seul atome.',
    reflection: 'Ton adoration n\'enrichit pas Al-Ghanī. Tu adores pour toi-même — pour cultiver le lien dont ton âme a besoin.',
    verses: ['2:267', '3:97', '47:38'], category: 'Purity'),
  AsmaName(number: 89, arabic: 'ٱلْمُغْنِي', transliteration: 'Al-Mughnī', meaning: 'Celui qui Enrichit',
    explanation: 'Il enrichit Ses serviteurs matériellement, spirituellement et émotionnellement. La vraie richesse — d\'âme, de contentement et de certitude — vient de Lui.',
    reflection: 'Le contentement (qana\'a) est la richesse qu\'Al-Mughnī donne et qu\'aucun marché ne peut fournir. Demande-Lui non seulement la subsistance, mais le contentement pour en jouir.',
    verses: ['9:28', '53:48'], category: 'Mercy'),
  AsmaName(number: 90, arabic: 'ٱلْمَانِعُ', transliteration: 'Al-Māni\'', meaning: 'Celui qui Prévient',
    explanation: 'Il empêche le mal d\'atteindre Ses serviteurs et retient des choses pour des raisons de sagesse et de miséricorde. Sa prévention est toujours pour un bien supérieur.',
    reflection: 'Chaque porte qui s\'est fermée devant toi était Al-Māni\' à l\'œuvre. Sa prévention n\'est pas une punition — c\'est souvent une protection contre ce que tu ne peux pas voir.',
    verses: ['67:21'], category: 'Power'),
  AsmaName(number: 91, arabic: 'ٱلضَّارُّ', transliteration: 'Ad-Dārr', meaning: 'Celui qui Éprouve',
    explanation: 'Lui seul détermine ultimement ce qui cause du mal. Aucun mal ne t\'atteint sauf par Sa permission et Sa sagesse.',
    reflection: 'Rien ne peut te blesser sans Sa permission. Ce nom, bien compris, donne une paix immense — tout mal passe par Son filtre de sagesse.',
    verses: ['6:17', '10:107'], category: 'Power'),
  AsmaName(number: 92, arabic: 'ٱلنَّافِعُ', transliteration: 'An-Nāfi\'', meaning: 'Celui qui Profite',
    explanation: 'Lui seul détermine ce qui apporte du bienfait. Tout bienfait retrace finalement Sa volonté et Sa miséricorde pour ceux qu\'Il choisit.',
    reflection: 'La médecine guérit par Sa permission. Le travail pourvoit par Sa permission. Chaque bienfait porte Sa signature. La gratitude coule vers Celui qui fournit vraiment.',
    verses: ['6:17', '10:107'], category: 'Mercy'),
  AsmaName(number: 93, arabic: 'ٱلنُّورُ', transliteration: 'An-Nūr', meaning: 'La Lumière',
    explanation: 'Il est la lumière des cieux et de la terre. Sa lumière illumine le cœur avec la guidance, l\'esprit avec la compréhension et le cosmos avec l\'existence.',
    reflection: 'La sourate An-Nūr (24:35) décrit Sa lumière comme une lampe dans une lampe, lumière sur lumière. Cherche le nūr du Coran — c\'est la lumière d\'An-Nūr Lui-même.',
    verses: ['24:35', '39:22'], category: 'Purity'),
  AsmaName(number: 94, arabic: 'ٱلْهَادِي', transliteration: 'Al-Hādī', meaning: 'Le Guide',
    explanation: 'Il guide vers la vérité, vers l\'action juste et vers Lui-même. Sa guidance est à la fois générale (instinct, raison) et spécifique (révélation, inspiration).',
    reflection: 'La guidance ne se mérite pas — elle se demande. "Ihdinas-siratal-mustaqim" — Guide-nous vers le droit chemin. Demande à Al-Hādī dix-sept fois par jour.',
    verses: ['22:54', '25:31'], category: 'Mercy'),
  AsmaName(number: 95, arabic: 'ٱلْبَدِيعُ', transliteration: 'Al-Badī\'', meaning: 'L\'Inventeur Incomparable',
    explanation: 'Il crée de belles choses sans précédent sans aucun exemple préalable. Chaque nouvelle forme, idée et merveille dans la création est une expression de Son pouvoir inventif.',
    reflection: 'Aucun artiste n\'a jamais créé quelque chose qu\'Al-Badī\' ne lui a pas donné la capacité de faire. Toute originalité et beauté découle en fin de compte du Créateur Incomparable.',
    verses: ['2:117', '6:101'], category: 'Creation'),
  AsmaName(number: 96, arabic: 'ٱلْبَاقِي', transliteration: 'Al-Bāqī', meaning: 'L\'Éternel',
    explanation: 'Il perdure pour toujours après que toute la création a cessé. Alors que tout périt, Son existence est permanente et éternelle.',
    reflection: 'Investis dans ce qui est permanent : ta relation avec Al-Bāqī. Tout le reste est temporaire — laisse cette conscience réorganiser tes priorités.',
    verses: ['20:73', '55:27'], category: 'Purity'),
  AsmaName(number: 97, arabic: 'ٱلْوَارِثُ', transliteration: 'Al-Wārith', meaning: 'L\'Héritier',
    explanation: 'Il est l\'héritier final de toutes choses — quand toute la création est partie, tout ce qui reste revient à Lui. Il survit à chaque propriétaire de chaque possession.',
    reflection: '"Nous appartenons à Allah et vers Lui nous retournons." Al-Wārith nous rappelle que nous sommes des gestionnaires, non des propriétaires. Tiens tes bénédictions légèrement.',
    verses: ['3:180', '15:23', '19:40'], category: 'Sovereignty'),
  AsmaName(number: 98, arabic: 'ٱلرَّشِيدُ', transliteration: 'Ar-Rashīd', meaning: 'Le Guide vers la Rectitude',
    explanation: 'Sa guidance est toujours juste et mène précisément où elle doit. Sa direction est infaillible et Sa sagesse à guider est suprême.',
    reflection: 'Quand tu es confus sur quel chemin emprunter, tourne-toi vers Ar-Rashīd avec l\'istikhara. Sa guidance viendra — peut-être pas comme tu l\'attends, mais elle viendra.',
    verses: ['2:256', '18:17'], category: 'Knowledge'),
  AsmaName(number: 99, arabic: 'ٱلصَّبُورُ', transliteration: 'As-Sabūr', meaning: 'Le Patient',
    explanation: 'Il est infiniment patient avec Ses serviteurs, ne se hâtant pas à punir malgré qu\'Il témoigne de chaque transgression. Sa patience est le modèle de la parfaite retenue.',
    reflection: 'As-Sabūr est le dernier des quatre-vingt-dix-neuf noms, et la patience est la dernière vertu à se perdre. Modèle-toi sur Sa patience — c\'est le sceau du noble caractère.',
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
                  'Aucun résultat',
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
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 230,
      pinned: false,
      floating: false,
      stretch: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Halo radial blanc — identique hadith/dua
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.88,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.30 : 0.55),
                      Colors.white.withValues(alpha: isDark ? 0.10 : 0.20),
                      Colors.white.withValues(alpha: isDark ? 0.03 : 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.72, 1.0],
                  ),
                ),
              ),
            ),
            // Contenu centré
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Asmaul Husna',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'أسماء الله الحسنى',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'UthmanTahaNaskh',
                      color: Color(0xFFC8A97E),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      '« Allah possède quatre-vingt-dix-neuf noms. Quiconque les dénombre entrera au Paradis. »  — Bukhari & Muslim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bouton retour
            Positioned(
              top: 0,
              left: 4,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            // Bouton favoris
            Positioned(
              top: 0,
              right: 4,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(
                    _showFavoritesOnly
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 22,
                    color: _showFavoritesOnly
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFFC8A97E),
                  ),
                  onPressed: () =>
                      setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    const gold = Color(0xFFC8A97E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    cursorColor: gold,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom ou signification…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.only(bottom: 2),
                    ),
                  ),
                ),
                if (_search.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                  )
                else
                  const SizedBox(width: 12),
              ],
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
                      _catFr[cat] ?? cat,
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
                            '✦  اسم اليوم  ·  Nom du Jour',
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
                      fontFamily: 'UthmanTahaNaskh',
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
                  fontFamily: 'UthmanTahaNaskh',
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
  final Map<int, List<QVerse?>> _versesCache = {};

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
    _fetchVerses(widget.names[_currentIndex]);
  }

  Future<void> _fetchVerses(AsmaName name) async {
    if (_versesCache.containsKey(name.number)) return;
    if (name.verses.isEmpty) {
      if (mounted) setState(() => _versesCache[name.number] = []);
      return;
    }
    final results = await Future.wait(
      name.verses.map((v) => QuranTextDb.instance.getVerseByKey(v)),
    );
    if (mounted) setState(() => _versesCache[name.number] = results);
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
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _fetchVerses(widget.names[i]);
              },
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
                    tooltip: 'Mode méditation',
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
                      '${name.number} sur 99  ·  ${_catFr[name.category] ?? name.category}',
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
                      fontFamily: 'UthmanTahaNaskh',
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
                      'Sens & Explication',
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
                      'Réflexion',
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

          // Versets coraniques
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
                        'Versets coraniques',
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
                  if (!_versesCache.containsKey(name.number))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: gold,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: List.generate(name.verses.length, (i) {
                        final verse = _versesCache[name.number]![i];
                        return Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                          child: _VerseCard(
                            ref: name.verses[i],
                            verse: verse,
                            isDark: isDark,
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              '﴿ Faites glisser pour explorer d\'autres noms ﴾',
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
              label: 'Précédent',
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
              label: 'Suivant',
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
                        fontFamily: 'UthmanTahaNaskh',
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
                    '${name.number} sur 99',
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
                'Appuyez pour quitter',
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
//  VERSE CARD
// ═══════════════════════════════════════════════════════

class _VerseCard extends StatelessWidget {
  final String ref;
  final QVerse? verse;
  final bool isDark;

  const _VerseCard({required this.ref, required this.verse, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final parts = ref.split(':');
    final surah = parts[0];
    final ayah = parts.length > 1 ? parts[1] : '';
    final cardBg = isDark ? const Color(0xFF0C1220) : const Color(0xFFFAF6EE);
    final arabicColor = isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3F30);
    final secColor = isDark ? Colors.white54 : const Color(0xFF6B5A45);
    const gold = Color(0xFFC8A97E);

    final ar = verse?.ar ?? '';
    final fr = verse?.fr ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: isDark ? 0.3 : 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge référence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF4A2E06), Color(0xFF6B4510)]
                    : const [Color(0xFFE8D5B3), Color(0xFFCFAF7E)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              'Sourate $surah  —  V. $ayah',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE8D5B0) : const Color(0xFF4A3010),
              ),
            ),
          ),
          if (ar.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ar,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'UthmanTahaNaskh',
                fontSize: 18,
                height: 1.8,
                color: arabicColor,
              ),
            ),
            Divider(color: gold.withValues(alpha: 0.3), height: 16, thickness: 0.6),
            Text(
              fr.isNotEmpty ? fr : 'Traduction non disponible',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: fr.isNotEmpty ? secColor : secColor.withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Verset non disponible',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: secColor.withValues(alpha: 0.5),
              ),
            ),
          ],
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
