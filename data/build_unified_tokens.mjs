#!/usr/bin/env node
/**
 *  build_unified_tokens.mjs
 *  ------------------------
 *  يولّد الملف الموحّد المتطور `quran_asr_tokens.json` من الملفين التقليديين:
 *    - quran_tokens.txt  (فونيمات Zipformer/Sherpa)
 *    - tokens.txt        (BPE FastConformer)
 *
 *  الاستخدام:
 *    node tools/build_unified_tokens.mjs [quran_tokens.txt] [tokens.txt] [out.json]
 *
 *  المخرجات تُقرأ من قبل index.html أولًا قبل أي ملفين منفصلين، وتتضمن:
 *    - ترويسة تقنية (format/نسخة/تاريخ)
 *    - كل قاموس مرتّب بالمعرّف مع حجمه وعناصره الخاصة (blank/unknown)
 *    - فاحص سلامة FNV-1a لكل قاموس للتحقق من التوافق مع النموذج
 *    - خريطة مشتركة للحروف والحركات للمراجعة السريعة
 */
import { readFileSync, writeFileSync } from 'node:fs';
import process from 'node:process';

const [quranPath = 'quran_tokens.txt', fastPath = 'tokens.txt', outPath = 'quran_asr_tokens.json'] = process.argv.slice(2);

function fnv1a(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, '0');
}

function parseTokens(path) {
  const text = readFileSync(path, 'utf8').replace(/^\uFEFF/, '');
  const map = new Map();
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.replace(/\s+$/, '');
    if (!line.trim()) continue;
    const m = line.match(/^(.*)\s+(-?\d+)$/);
    if (!m) throw new Error(`سطر غير صالح في ${path}: "${rawLine.trim()}"`);
    const id = Number(m[2]);
    if (!Number.isInteger(id) || id < 0) throw new Error(`معرّف غير صالح ${id} في ${path}`);
    if (map.has(id)) throw new Error(`معرّف مكرر ${id} في ${path}`);
    map.set(id, m[1]);
  }
  return map;
}

function toDenseArray(map, label) {
  const size = Math.max(...map.keys()) + 1;
  const arr = Array.from({ length: size }, (_, i) => map.get(i));
  const gap = arr.findIndex((v) => v === undefined);
  if (gap !== -1) throw new Error(`فجوة في المعرفات (${gap}) في ${label}`);
  return arr;
}

const quran = toDenseArray(parseTokens(quranPath), 'quran_tokens.txt');
const fast = toDenseArray(parseTokens(fastPath), 'tokens.txt');

// --- تحقق من سلامة كلا القاموسين ---
if (quran[quran.length - 1] !== '<blank>') {
  throw new Error('قاموس Zipformer: آخر عنصر يجب أن يكون <blank>');
}
const blankId = quran.lastIndexOf('<blank>');
if (blankId !== quran.length - 1) throw new Error('قاموس Zipformer: <blank> يجب أن يكون آخر عنصر');
if (fast[0] !== '<unk>') throw new Error('قاموس FastConformer: أول عنصر يجب أن يكون <unk>');
if (fast[fast.length - 1] !== '<blk>') throw new Error('قاموس FastConformer: آخر عنصر يجب أن يكون <blk>');
if (quran.length < 100 || fast.length < 100) throw new Error('أحدي القائمتين أقصر من المفترض');

const ARABIC_LETTERS = ['ا','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص','ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','ه','و','ي'];
const CORE_HARAKAT = ['َ','ُ','ِ','ّ','ْ','ٌ','ٍ','ً','ٰ','ْ'];
const ZIPFORMER_SPECIAL = ['ؙ','ڇ','ں','ۜ','ۥ','ۦ','۪','۾'];

const doc = {
  format: 'ard-unified-tokens/v1',
  app: 'عرض — نسخة HTML محمولة مع ONNX محلي (nacer80/3erdh)',
  version: 1,
  generatedAt: new Date().toISOString(),
  description:
    'ملف رموز موحّد متطور يستبدل الملفين quran_tokens.txt وtokens.txt معًا. إن وُجد في data/onnx/ يفضّله التطبيق على الملفين المنفصلين، ويطابق كل نسخة ضد فاحص السلامة قبل الاستخدام.',
  sources: {
    zipformer: 'quran_tokens.txt (نموذج zipformer_p_arabic_v3.x.int8.onnx عبر Sherpa ONNX)',
    fastconformer: 'tokens.txt (نماذج fastconformer_ar_ctc_q8.onnx / qurankarim-fastconformer-mixed.onnx عبر ONNX Runtime)',
  },
  engines: {
    zipformer: {
      models: ['zipformer_p_arabic_v3.1.int8.onnx', 'zipformer_p_arabic_v3.int8.onnx'],
      blankToken: '<blank>',
      blankId,
      unknownToken: null,
      unknownId: null,
      size: quran.length,
      lineFormat: 'token id (صيغة sherpa-onnx tokens.txt)',
      checksumFnv1a: fnv1a(quran.join('\n')),
      tokens: quran,
    },
    fastconformer: {
      models: ['qurankarim-fastconformer-mixed.onnx', 'fastconformer_ar_ctc_q8.onnx'],
      blankToken: '<blk>',
      blankId: fast.length - 1,
      unknownToken: '<unk>',
      unknownId: 0,
      size: fast.length,
      lineFormat: 'token id (صيغة whisper-style tokens.txt)',
      checksumFnv1a: fnv1a(fast.join('\n')),
      tokens: fast,
    },
  },
  shared: {
    arabicLetters: ARABIC_LETTERS,
    harakat: ['َ','ُ','ِ','ّ','ْ','ٌ','ٍ','ً'],
    zipformerSpecialMarkers: ZIPFORMER_SPECIAL,
    fastconformerWordStartPrefix: '▁',
    notes: [
      'معرّف كل رمز = فهرسه في مصفوفة tokens (رتّبة صاعدة من 0).',
      'رموز المدة القصرانية (ا/و/ي المكررة و ۥ ۦ) هي ما يجعل Zipformer الأفضل في الحروف الفونيمية.',
      'لإعادة البناء بعد تغيير أي نموذج: node tools/build_unified_tokens.mjs',
    ],
  },
};

writeFileSync(outPath, JSON.stringify(doc, null, 2) + '\n', 'utf8');
console.log(`[ok] ${outPath}`);
console.log(`     zipformer: ${quran.length} رموز (blank=<blank>@${blankId}, fnv1a=${doc.engines.zipformer.checksumFnv1a})`);
console.log(`     fastconformer: ${fast.length} رموز (unk=<unk>@0, blk=<blk>@${fast.length - 1}, fnv1a=${doc.engines.fastconformer.checksumFnv1a})`);
