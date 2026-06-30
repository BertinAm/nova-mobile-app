import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/currency_bloc.dart';

class CurrencyPage extends StatelessWidget {
  const CurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CurrencyBloc>(),
      child: const _CurrencyView(),
    );
  }
}

class _CurrencyView extends StatefulWidget {
  const _CurrencyView();

  @override
  State<_CurrencyView> createState() => _CurrencyViewState();
}

class _CurrencyViewState extends State<_CurrencyView> {
  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = null; // no continuous loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) {
        context.read<CurrencyBloc>().add(const IdentifyCurrency());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Option 4 — Identify Money')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<CurrencyBloc, CurrencyState>(
            builder: (context, state) {
              final isBusy = state is CurrencyProcessing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions — always visible, read by TalkBack on focus
                  Semantics(
                    label: 'Hold a CFA franc banknote flat in front of the camera, then press the button.',
                    child: Text(
                      'Hold a CFA banknote flat in front of the camera, then press Identify.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Semantics(
                    button: true,
                    label: 'Identify money',
                    hint: 'Takes a photo and identifies the CFA franc denomination',
                    enabled: !isBusy,
                    child: ElevatedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => context.read<CurrencyBloc>().add(const IdentifyCurrency()),
                      icon: const Icon(Icons.payments, size: 28),
                      label: const Text('Identify money'),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Expanded(child: _content(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CurrencyState state) {
    if (state is CurrencyProcessing) {
      return Semantics(
        liveRegion: true,
        label: 'Processing note, please wait.',
        child: const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Processing note…'),
          ],
        )),
      );
    }

    if (state is CurrencyDetected) {
      final label = state.result.spokenLabel ?? 'Unknown denomination';
      final confidence = (state.result.confidence * 100).toStringAsFixed(0);
      return Semantics(
        liveRegion: true,
        label: 'Detected: $label. Confidence $confidence percent.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: $confidence%',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (state is CurrencyNotClear) {
      // FR-04-04: exact SRS message
      final extra = state.underExposed
          ? '\n\nTip: Try turning on your torch for better lighting.'
          : '';
      return Semantics(
        liveRegion: true,
        label: 'Could not identify the note clearly. Please try again with better lighting or closer to the camera.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 72),
            const SizedBox(height: 16),
            Text(
              'Could not identify the note clearly.\nPlease try again with better lighting or move closer to the camera.$extra',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (state is CurrencyError) {
      return Semantics(
        liveRegion: true,
        label: 'Error: ${state.message}',
        child: Center(
          child: Text(state.message, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    // Idle
    return Semantics(
      label: 'Ready. Press the button or say identify money.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, size: 80),
            const SizedBox(height: 16),
            Text(
              'Press the button or say\n"identify money".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
