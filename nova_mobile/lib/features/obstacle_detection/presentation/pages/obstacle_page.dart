import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/obstacle_detection_result.dart';
import '../bloc/obstacle_bloc.dart';

class ObstaclePage extends StatelessWidget {
  const ObstaclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ObstacleBloc>(),
      child: const _ObstacleView(),
    );
  }
}

class _ObstacleView extends StatefulWidget {
  const _ObstacleView();

  @override
  State<_ObstacleView> createState() => _ObstacleViewState();
}

class _ObstacleViewState extends State<_ObstacleView> {
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Obstacle Detection')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<ObstacleBloc, ObstacleState>(
            builder: (context, state) {
              final detecting = state is ObstacleDetecting;
              final obstacles = state is ObstacleDetecting
                  ? state.obstacles
                  : const <DetectedObstacle>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: detecting
                        ? 'Obstacle detection is running'
                        : 'Obstacle detection is stopped',
                    liveRegion: true,
                    child: Text(
                      detecting ? 'Running' : 'Stopped',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: detecting
                        ? null
                        : () => context
                            .read<ObstacleBloc>()
                            .add(const StartObstacleDetection()),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start obstacle detection'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: detecting
                        ? () => context
                            .read<ObstacleBloc>()
                            .add(const StopObstacleDetection())
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop obstacle detection'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Show Camera Preview (Debug)'),
                    value: _showPreview,
                    onChanged: (val) => setState(() => _showPreview = val),
                  ),
                  if (_showPreview && getIt<CameraService>().controller != null)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CameraPreview(getIt<CameraService>().controller!),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (state is ObstacleError)
                    Text(state.message, style: const TextStyle(color: Colors.redAccent)),
                  Expanded(
                    flex: 3,
                    child: ListView.builder(
                      itemCount: obstacles.length,
                      itemBuilder: (context, index) {
                        final obstacle = obstacles[index];
                        return Semantics(
                          label:
                              '${obstacle.label}, ${obstacle.spokenDirection}, ${obstacle.estimatedDistanceMeters.toStringAsFixed(1)} meters',
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber),
                              title: Text('${obstacle.label} ${obstacle.spokenDirection}'),
                              subtitle: Text(
                                '${obstacle.zoneName} • ${obstacle.estimatedDistanceMeters.toStringAsFixed(1)} m • ${(obstacle.confidence * 100).toStringAsFixed(0)}%',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

