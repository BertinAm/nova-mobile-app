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
      appBar: AppBar(title: const Text('Scene Description')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<SceneBloc, SceneState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context
                        .read<SceneBloc>()
                        .add(const RequestSceneDescription()),
                    icon: const Icon(Icons.image_search),
                    label: const Text('Describe scene'),
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
    if (state is SceneLoading) return const Text('Describing the scene...');
    if (state is SceneOfflineError) {
      return const Text('Scene description requires internet connection.');
    }
    if (state is SceneError) return Text(state.message);
    if (state is SceneLoaded) {
      return SingleChildScrollView(
        child: Semantics(
          label: 'Scene description result',
          child: Text(state.description, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
    }
    return const Text('Press the button or say describe scene.');
  }
}
