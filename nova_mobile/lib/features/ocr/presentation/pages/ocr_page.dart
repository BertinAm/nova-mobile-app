import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/ocr_bloc.dart';

class OcrPage extends StatelessWidget {
  const OcrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OcrBloc>(),
      child: const _OcrView(),
    );
  }
}

class _OcrView extends StatefulWidget {
  const _OcrView();

  @override
  State<_OcrView> createState() => _OcrViewState();
}

class _OcrViewState extends State<_OcrView> {
  @override
  void initState() {
    super.initState();

    // Register "stop option" hook
    globalStopCurrentOption = () {
      if (mounted) context.read<OcrBloc>().add(const CancelOcrReading());
    };

    // Auto-trigger OCR if opened via voice
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) {
        context.read<OcrBloc>().add(const TriggerOcr());
      }
    });
  }

  @override
  void dispose() {
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Option 2 — Read Text')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<OcrBloc, OcrState>(
            builder: (context, state) {
              final isBusy = state is OcrCapturing || state is OcrProcessing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: 'Point your camera at text and press Capture.',
                    child: Text(
                      'Point camera at printed text.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: Semantics(
                        button: true, enabled: !isBusy,
                        label: 'Capture and read text',
                        child: ElevatedButton.icon(
                          onPressed: isBusy ? null
                              : () => context.read<OcrBloc>().add(const TriggerOcr()),
                          icon: const Icon(Icons.document_scanner_rounded),
                          label: const Text('Capture & Read'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Stop reading',
                        child: OutlinedButton.icon(
                          onPressed: () => context.read<OcrBloc>().add(const CancelOcrReading()),
                          icon: const Icon(Icons.stop_circle_rounded),
                          label: const Text('Stop'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cs.error),
                            foregroundColor: cs.error,
                          ),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  Expanded(child: _stateContent(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stateContent(BuildContext context, OcrState state) {
    if (state is OcrCapturing) {
      return Semantics(
        liveRegion: true,
        label: 'Capturing image. Please hold the camera steady.',
        child: const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Capturing…'),
          ],
        )),
      );
    }
    if (state is OcrProcessing) {
      return Semantics(
        liveRegion: true,
        label: 'Processing image. Please wait.',
        child: const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Reading text…'),
          ],
        )),
      );
    }
    if (state is OcrNoText) {
      return Semantics(
        liveRegion: true,
        label: 'No text detected. Try moving the camera closer and press Capture again.',
        child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.text_fields_outlined, size: 48,
                color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 12),
            Text('No text detected.\nTry moving closer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          ],
        )),
      );
    }
    if (state is OcrError) {
      return Semantics(
        liveRegion: true,
        label: 'Error: ${state.message}',
        child: Center(child: Text(state.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error))),
      );
    }
    if (state is OcrReading) {
      return Semantics(
        label: 'Recognised text — ${state.text}',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recognised text:',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SelectableText(state.text,
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }
    // Idle
    return Semantics(
      label: 'Ready to capture. Press Capture and Read, or say Option 2 to auto-capture.',
      child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.document_scanner_outlined, size: 56,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Press "Capture & Read" or say "Option 2".',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center),
        ],
      )),
    );
  }
}
