import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../bloc/scene_bloc.dart';

class ScenePage extends StatelessWidget {
  const ScenePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SceneBloc>(),
      child: const _SceneView(),
    );
  }
}

class _SceneView extends StatelessWidget {
  const _SceneView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe Scene')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<SceneBloc, SceneState>(
            builder: (context, state) {
              final isBusy = state is SceneLoading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cloud-dependency notice (SRS FR-03-02 user-facing explanation)
                  Semantics(
                    label: 'This feature requires an internet connection. Point the camera at a scene then press Describe Scene.',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Requires internet. Point camera at a scene.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Semantics(
                    button: true,
                    label: 'Describe scene',
                    hint: 'Takes a photo and sends it to the cloud for a description. Requires internet.',
                    enabled: !isBusy,
                    child: ElevatedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => context.read<SceneBloc>().add(const RequestSceneDescription()),
                      icon: const Icon(Icons.image_search, size: 28),
                      label: const Text('Describe scene'),
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

  Widget _content(BuildContext context, SceneState state) {
    if (state is SceneLoading) {
      return Semantics(
        liveRegion: true,
        // FR-03-06 exact wording
        label: 'Describing the scene, please wait.',
        child: const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Describing the scene, please wait…'),
          ],
        )),
      );
    }

    if (state is SceneOfflineError) {
      return Semantics(
        liveRegion: true,
        // FR-03-02 exact wording
        label: 'Scene description requires an internet connection. Please try again when connected.',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Scene description requires an internet connection.\nPlease try again when connected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (state is SceneError) {
      return Semantics(
        liveRegion: true,
        // FR-03-07 exact wording
        label: 'Scene description is unavailable right now. Please try again later.',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              Text(
                'Scene description is unavailable right now.\nPlease try again later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (state is SceneLoaded) {
      return Semantics(
        liveRegion: true,
        label: 'Scene description: ${state.description}',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scene:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                state.description,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Idle
    return Semantics(
      label: 'Ready. Press the button or say describe scene.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_search_outlined, size: 80),
            const SizedBox(height: 16),
            Text(
              'Press the button or say\n"describe scene".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
