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
      appBar: AppBar(title: const Text('Read Text')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<OcrBloc, OcrState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.read<OcrBloc>().add(const TriggerOcr()),
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Capture and read text'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.read<OcrBloc>().add(const CancelOcrReading()),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Stop reading'),
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
    if (state is OcrCapturing) return const Text('Capturing text...');
    if (state is OcrProcessing) return const Text('Processing OCR...');
    if (state is OcrNoText) return const Text('No text detected.');
    if (state is OcrError) return Text(state.message);
    if (state is OcrReading) {
      return SingleChildScrollView(
        child: Semantics(
          label: 'Recognized text',
          child: Text(state.text, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
    }
    return const Text('Press the button or say read text.');
  }
}
