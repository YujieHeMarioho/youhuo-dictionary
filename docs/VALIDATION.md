# Verification

- Xcode macOS15 SDK native compilation and strict ad hoc signature verification pass.
- Read-only ECDICT SQLite integrity_check is ok; 770611 entries; source SHA256 recorded in data/ECDICT-SOURCE.json.
- Launched packaged app on this Mac and actually queried hello; Chinese/English definition, phonetic and word forms displayed.
- Saved hello with a Chinese study note through UI; verified JSON persistence outside repo.
- Opened wordbook and review card through UI; flipped card and verified saved definition.
- Imported generated bilingual PNG through native image dialog; Vision OCR returned both `Hello dictionary` and `学习让生活更有活力` correctly; saved knowledge document verified on disk.
- Apple Translation system language download prompt observed. Downloaded English/Chinese models; real translation succeeded: `Hello, welcome to your new dictionary.` → `你好，欢迎来到你的新词典。` No paid API was called.
- tools/test_frontend.js: stale lookup/translation/AI callbacks, literal newline normalization, HTML escaping, malformed backup IDs/history/settings, overwrite confirmation, optional notes normalization, async failure recovery, sentence filters, transcript callbacks and selection opt-in checks pass.
- Microphone/Speech permission and Accessibility grants were not made during validation. Recording, audio file transcription, selected-text floating monitor, screenshot capture and Services integration compile but need user-side runtime permission/host checks. OCR from an imported image is verified. Text/PDF imports, backup native dialogs and optional Youdao API have not received end-to-end runtime checks.
- No proprietary binaries/assets/data/accounts or original user's wordbook is committed. Study data, credentials, build bundles and raw corpus CSV are ignored/outside repo.
