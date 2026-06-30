import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
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

class _CurrencyView extends StatelessWidget {
  const _CurrencyView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Detection')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<CurrencyBloc, CurrencyState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context
                        .read<CurrencyBloc>()
                        .add(const IdentifyCurrency()),
                    icon: const Icon(Icons.payments),
                    label: const Text('Identify money'),
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
    if (state is CurrencyProcessing) return const Text('Processing note...');
    if (state is CurrencyDetected) {
      return Semantics(
        liveRegion: true,
        label: state.result.spokenLabel,
        child: Text(
          '${state.result.spokenLabel}\nConfidence: ${(state.result.confidence * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
    }
    if (state is CurrencyNotClear) {
      return Text(
        'Could not identify clearly. Confidence: ${(state.confidence * 100).toStringAsFixed(0)}%',
      );
    }
    if (state is CurrencyError) return Text(state.message);
    return const Text('Press the button or say identify money.');
  }
}
