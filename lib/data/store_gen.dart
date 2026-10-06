part of 'store.dart';

// The two generative side channels, as tools the model can call.
//
// They live in their own part because both engines need them: the humanize
// table and the agent table each append these when the persona has the channel
// switched on. [send] is how the caller wants a finished card to land in the
// transcript, which is the only thing the two engines disagree about.

/// The drawing and speaking tools for [c], built from the role's own switches
/// and the module defaults.
///
/// Returns nothing at all when neither channel is usable, so a persona that
/// never asked for them keeps exactly the tool table it had before this file
/// existed. A channel is only offered when it is switched on AND fully
/// configured: handing the model a tool that can only fail teaches it to stop
/// trying, and the failure it reads is not the one the user needs.
///
/// [send] appends one message the way the caller's own text path does, so the
/// humanize engine can pace a card through its bubble queue while the agent
/// loop drops it straight in. [cancel] is the run token, so a stop during a
/// slow image request ends the request instead of leaving it to finish against
/// a transcript nobody is watching any more.
extension StoreGen on Store {
  List<HTool> genTools(
    Chat c, {
    required Future<Msg?> Function(String text, {MsgKind kind, Map<String, dynamic>? data}) send,
    AiCancel? cancel,
  }) {
    final cfg = _ai;
    final voice = _speech;
    if (cfg == null || voice == null) return const [];
    final prefs = genPrefsFor(c, cfg.settings, voice);
    if (!prefs.imageReady && !prefs.ttsReady) return const [];

    final tools = <HTool>[];

    // -------------------------------------------------------------- drawing
    if (prefs.imageReady) {
      tools.add(HTool(
        'generate_image',
        'Draw a picture from a text prompt and send it to the user as an image card. '
            'Write the prompt in english, describing subject, style, lighting and framing: '
            'the image model reads it literally and has no memory of this conversation. '
            'Use it when the user asks to see something, or when a picture carries the answer '
            'better than words. For a diagram, a chart, a mockup or anything with text in it, '
            'prefer send_svg or send_html: an image model cannot spell.',
        {
          'prompt': _p('string', 'A detailed english description of the picture to draw.'),
          'caption': _p('string', 'Short line to send with the picture. May be empty.'),
          'size': _p('string', 'Pixel size such as 1024x1024, 1536x1024 or 1024x1536. Empty uses the configured default.'),
        },
        (a) async {
          final prompt = _str(a, 'prompt').trim();
          if (prompt.isEmpty) return 'Error: prompt is required.';
          final provider = prefs.imageProvider(cfg.settings);
          if (provider == null) return 'Error: the configured image provider no longer exists.';

          final size = _str(a, 'size').trim();
          try {
            final drawn = await generateImage(
              provider: provider,
              apiKey: cfg.keyOf(provider.id),
              model: prefs.imageModelId,
              prompt: prompt,
              size: size.isEmpty ? prefs.imageSize : size,
              settings: cfg.settings,
              cancel: cancel,
            );
            final bytes = drawn.bytes ?? await downloadImage(drawn.url!, cancel: cancel);
            if (bytes.isEmpty) return 'Error: the image endpoint returned an empty picture.';

            // the bytes are kept on disk because a message has to survive a
            // restart, and a url from the endpoint is short lived by design
            final f = await _docFile('ai_images', 'drawing.png');
            await f.writeAsBytes(bytes);

            final revised = drawn.revisedPrompt?.trim() ?? '';
            final m = await send(_str(a, 'caption').trim(), kind: MsgKind.photo, data: {
              'path': f.path,
              'name': 'drawing.png',
              'size': bytes.length,
              if (revised.isNotEmpty) 'prompt': revised,
            });
            return m == null ? 'Interrupted.' : 'Picture sent to the user.';
          } catch (e) {
            return 'Error: $e';
          }
        },
        required: ['prompt'],
      ));
    }

    // ------------------------------------------------------------- speaking
    if (prefs.ttsReady) {
      tools.add(HTool(
        'speak',
        'Say a line out loud in your own voice. The audio plays on the user device '
            'immediately and, when attach is true, also lands in the transcript as a voice '
            'card the user can replay. Use it for a short line worth hearing — a greeting, a '
            'tease, a goodnight — not for a normal reply: reading a whole answer aloud is '
            'slow, and the user can always ask for it themselves.',
        {
          'text': _p('string', 'What to say. Keep it short, one or two sentences.'),
          'voice': _p('string', 'Voice id overriding your configured voice for this line. Usually empty.'),
          'attach': _p('boolean', 'true also leaves a replayable voice card in the chat. Default false.'),
        },
        (a) async {
          final text = _str(a, 'text').trim();
          if (text.isEmpty) return 'Error: text is required.';
          final voiceId = _str(a, 'voice').trim();
          final wantVoice = voiceId.isEmpty ? prefs.ttsVoice : voiceId;
          final useApi = prefs.ttsEngine == TtsEngine.api;

          TtsEndpoint? endpoint;
          if (useApi) {
            if (prefs.ttsBaseUrl.isEmpty) return 'Error: no speech endpoint is configured.';
            endpoint = TtsEndpoint(
              provider: prefs.ttsProvider,
              apiKey: prefs.ttsApiKey,
              settings: cfg.settings,
            );
          }

          // the card is written first when one was asked for, so the audio the
          // user taps is the same audio that was just played
          Msg? card;
          if (a['attach'] == true && useApi) {
            try {
              final audio = await synthesize(
                provider: endpoint!.provider,
                apiKey: endpoint.apiKey,
                model: prefs.ttsModel,
                voice: wantVoice,
                text: text,
                speed: prefs.ttsSpeed,
                instructions: prefs.ttsInstructions,
                settings: cfg.settings,
                cancel: cancel,
              );
              final f = await _docFile('ai_voice', 'voice.${audio.extension}');
              await f.writeAsBytes(audio.bytes);
              card = await send('', kind: MsgKind.music, data: {
                'path': f.path,
                'name': 'voice.${audio.extension}',
                'size': audio.bytes.length,
                'voice': true,
                'text': text,
              });
            } catch (_) {
              // a failed card must not stop the line from being said
              card = null;
            }
          }

          try {
            await SpeechService.instance.speak(
              text,
              engine: prefs.ttsEngine,
              endpoint: endpoint,
              voice: wantVoice,
              model: prefs.ttsModel,
              speed: prefs.ttsSpeed,
              instructions: prefs.ttsInstructions,
            );
          } catch (e) {
            return 'Error: could not speak ($e).';
          }
          return card == null ? 'Said out loud.' : 'Said out loud and left a voice card.';
        },
        required: ['text'],
      ));
    }

    return tools;
  }
}
