# Reference observations

Reference: installed 网易有道翻译 11.3.20, com.youdao.YoudaoDict.
REA open_binary bound the actual arm64 Mach-O at /Applications/网易有道翻译.app/Contents/MacOS/网易有道翻译; SHA256 24680e35505169d94e11c5e1c2dfa8e573134cac9a11a13233dc06195e56f62f. This confirms artifact identity, not decompilation or server behavior.

Observed live native UI: gray 124px sidebar; 首页/AI翻译/同传转写/知识宝库/单词本/我的翻译; red active navigation; screenshot/取词/划词 tools at bottom. Home has large search input with language selector, compact dictionary tab/definitions and right AI panel. Text translation fills remaining window and has tabs 文本/AI翻译/文档/图片 with two columns. Wordbook has 单词/句子 tabs, sort/filter controls, numbered rows and definition column.

Reconstruction uses original source and branding, an independently licensed open dictionary and native OS services. No proprietary dictionary, assets, personal wordbook, session, or credentials are published. UI similarity is a design target; 80–90% functional parity is not established until coverage is verified. Network/AI service parity cannot be inferred from UI observation.
