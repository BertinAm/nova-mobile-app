import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
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

class _OcrView extends StatelessWidget {
  const _OcrView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read Text (OCR)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<OcrBloc, OcrState>(
            builder: (context, state) {
              final isBusy = state is OcrCapturing || state is OcrProcessing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Semantics(
                    label: 'Point your camera at text and press Capture and read text.',
                    child: Text(
                      'Point camera at printed text, then press the button.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Semantics(
                    button: true,
                    label: 'Capture and read text',
                    enabled: !isBusy,
                    hint: 'Takes a photo and reads any text aloud',
                    child: ElevatedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => context.read<OcrBloc>().add(const TriggerOcr()),
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Capture and read text'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Stop reading',
                    child: OutlinedButton.icon(
                      onPressed: () => context.read<OcrBloc>().add(const CancelOcrReading()),
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('Stop reading'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
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
        label: 'Capturing image, please hold steady.',
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
        label: 'Processing OCR, please wait.',
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
        label: 'No text detected. Try moving the camera closer.',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.text_fields_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'No text detected.\nTry moving the camera closer.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }
    if (state is OcrError) {
      return Semantics(
        liveRegion: true,
        label: 'Error: ${state.message}',
        child: Center(
          child: Text(state.message, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    if (state is OcrReading) {
      return Semantics(
        label: 'Recognised text',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recognised text:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SelectableText(
                state.text,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: 'Ready to capture text. Press the button or say read text.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Press the button or say "read text".',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
