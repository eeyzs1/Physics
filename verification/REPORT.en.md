# Verification report

Date: 2026-11-13. Command: python tools/check_course.py --write-report --report-date 2026-11-13.

- 748 pages (374 Chinese, 374 English), 319 lessons per edition, 1276 quizzes, 38 diagrams.
- Verified manifest paths/counts, progress keys, bilingual answers, language maps, local links/fragments, unique ids, labels, and offline assets.
- Loaded every page in offline Chromium; tested every quiz with empty, invalid, correct/incorrect, zero, sign, and tolerance cases, plus representative real click/Enter actions. No script errors or network requests.
- Checked every page at 1280 px and 390 px; checked all demos at slider minimum, intermediate, and maximum values.
- Verified reload persistence, live four-tab bilingual lesson/checklist synchronization under an HTTP project prefix, language round trips, storage-clear synchronization, and storage-disabled fallback.
- Numeric inputs, buttons, and SVG labels pass 4.5:1 dark-mode contrast; taxonomy searches pass in both languages.
- Screenshots: home-desktop.png, lesson-desktop.png, lesson-mobile.png, advanced-mobile.png, dark-sample.png.

Limits: functional checks do not establish correctness of every physics statement. See REVIEW.en.md for content corrections and sources. File-URL storage depends on browser policy; the README documents a local HTTP alternative.
