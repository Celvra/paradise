# Contributing to Paradise

Thanks for looking at this. The project is small, the bar for a patch is low, and
a plain bug report is genuinely useful.

Before you start: this app talks to an OpenAI compatible/Anthropic/Gemini endpoint that **you**
bring. There is no account, no server and no telemetry. Nothing you type here
reaches us unless you paste it into an issue yourself.

## Reporting a bug

Open an issue. The bug report template asks for the few things that actually
matter; fill in what you can and leave the rest blank if it does not apply.

Two things help more than everything else combined:

- **What you expected, and what happened instead.** Those are different sentences
  and conflating them costs a round trip.
- **The screen, in which language, and with which switches on.** A wrong string in
  a bubble comes almost always from the language setting or from the humanize
  layer, and both are per chat.

Do not paste API keys, endpoint URLs with credentials in them, or chat
transcripts you would rather not publish. A redacted screenshot beats a pasted
log.

## Setting up

You need the Flutter SDK. The project is pinned to a recent stable:

```bash
git clone git@github.com:Celvra/paradise.git
cd paradise
flutter --version   # 3.47.5 stable was used for the current state
flutter pub get
flutter run
```

There is no code generation step to run by hand and no signing config to fill
in for local work. `flutter run` on a debug build is enough.

## Before you open a pull request

```bash
flutter analyze     # must be clean
flutter test        # must be green
```

Both are non-negotiable. `analyze` is set to analyzer only, no lint pack, so
whatever it reports is worth fixing rather than silencing.

If you touch anything under `lib/l10n/`, regenerate before you commit:

```bash
flutter gen-l10n
```

`lib/l10n/gen/` is checked in. It is generated output, but committing it is what
keeps a clone buildable without a Flutter toolchain, so it belongs in the diff
alongside your change.

## Localisation

`lib/l10n/arb/app_en.arb` is the template and the source of truth.
`app_zh.arb` and `app_zh_Hant.arb` must carry the same key set. `gen-l10n`
prints an untranslated message count when they drift, and that count has to be
zero.

Two rules that have been learned the hard way:

- **Placeholders must survive verbatim.** If the English says `{count,
  plural, ...}` or `{name}`, both translations need it, including every plural
  branch. A dropped placeholder is a runtime crash, not a cosmetic problem.
- **Write the prose, do not run a converter over Simplified.** Traditional
  Chinese here is written, not generated: 佇列 not 队列, 伺服器 not 服务器,
  介面網址 not 接口网址. Running a character converter produces text that reads
  machine made, and it is the main thing reviewers will send back.

If you are adding a key, add it to all three files in the same commit. A key that
exists only in English will show up as untranslated, and the language picker
will not offer that language for the string.

## Code style

Match the file you are in. The codebase is written densely on purpose: one line
where a line will fit, no ceremony. A diff that reformats a file you are not
otherwise changing is hard to review and will be asked about.

A few things that are load bearing rather than preference:

- **Comments explain why, not what.** Most of this code has a comment above it
  saying why the obvious version was wrong. That is the house style and it is
  worth keeping up.
- **Do not swallow errors silently.** `catch (_) {}` is acceptable when the
  failure genuinely does not matter and nothing is left half done. If a user
  would want to know, say so.
- **Never leave a message half sent.** Anything that writes to the transcript
  either completes or releases what it held. A hole in the model's own history
  makes it ask what it just said.

## The humanize layer

This is the part most likely to surprise you. It streams a reply as several chat
bubbles, paced like a person, and may deliberately type a wrong character and
then recall the message.

Three pieces cooperate and all three matter:

- `lib/data/human/br_parser.dart` cuts the stream into bubbles. A line break is a
  break. Past `autoSplitChars` the parser cuts on its own at the nearest sentence
  or clause boundary, because models do not reliably write the `<i-br>` tag.
- `lib/data/ai/segmenter.dart` does the same job without the humanize layer,
  used by plain character mode.
- The prompt in `lib/data/store_human.dart` is what asks the model for bubbles,
  for `<i-br_N>` pauses, and for the typo and recall behaviour. It is phrased as a
  numbered contract and restated at the end of the prompt on purpose: a rule
  stated once at the top of a long prompt loses to hundreds of lines of character
  sheet.

If you change the pacing, change all three or the bubbles will disagree with each
other.

Note that in the default configuration, humanize **off**, agent **off**, there is
no stop button in the composer. The assistant is not running a job, it is
answering, and the next message is the interrupt. That is intentional.

## Adding a dependency

Adding a package means a new entry in the acknowledgements block of the about
dialog, with its licence. The licences are read from the package's own LICENSE
file in the pub cache rather than typed from memory, because guessing a licence
is the kind of mistake that is expensive to discover later.

Direct dependencies are listed. The transitive tree is not, it is what
`pubspec.lock` is for.

## Commit and pull request shape

One concern per change. A refactor folded into a fix is two changes wearing a
trench coat, and if the fix gets reverted the refactor goes with it.

In the description, say what you changed and what you checked. If you did not
test on a device, say that too. It is more useful than a paragraph of context.

## Licence

Contributions are accepted under the AGPL 3.0, same as the rest of the project.
See [LICENSE](LICENSE). Contributors keep their copyright; you are granting
permission to use the contribution under that licence.
