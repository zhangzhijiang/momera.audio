# McRecorder — App Store listing copy

**The copy lives in [`submission_pack.md`](submission_pack.md), not here.**

This file exists so the location is not ambiguous. There is deliberately no
second copy of the strings: two sources drift, and the one that drifts is always
the one you paste into the console.

| Field | Where |
|---|---|
| App name, subtitle | [`submission_pack.md` §5](submission_pack.md#5-store-listing--reviewer-information) |
| Description | [`submission_pack.md` §5](submission_pack.md#5-store-listing--reviewer-information) |
| Keywords, promotional text | [`submission_pack.md` §4](submission_pack.md#4-discovery-metadata) |
| What's New | [`submission_pack.md` §3](submission_pack.md#3-release-notes-whats-new) |
| App information table, reviewer notes | [`submission_pack.md` §5](submission_pack.md#5-store-listing--reviewer-information) |
| App Privacy answers, age rating | [`submission_pack.md` §8](submission_pack.md#8-app-privacy-questionnaire--age-rating) |

Localizations: `en-US`, `ja`, `ko`, `zh-Hans`, `zh-Hant` — five, from
`lib/l10n/app_{en,ja,ko,zh,zh_Hant}.arb`. Apple keys Chinese on **script**, so
`zh-Hans` / `zh-Hant`; never send Play's `zh-CN` / `zh-TW` to App Store Connect.

Character counts are enforced, not eyeballed:

```bash
python3 ../shared/scripts/count_listing_strings.py   # exit 0 = every field within limit
```

Icons, screenshots and previews are owned by `/idatagear-apple-store-assets`.
They are **not** produced here, and as of 10 September 2026 the `icons/`,
`previews/` and `screenshots/` trees are still empty.
