import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/settings/settings_service.dart';
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

class _ObstacleView extends StatelessWidget {
  const _ObstacleView();

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
                  // Status indicator — live region for TalkBack
                  Semantics(
                    label: detecting
                        ? 'Obstacle detection is running'
                        : 'Obstacle detection is stopped',
                    liveRegion: true,
                    child: Text(
                      detecting ? '🟢 Running' : '🔴 Stopped',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Semantics(
                    button: true,
                    label: 'Start obstacle detection',
                    enabled: !detecting,
                    child: ElevatedButton.icon(
                      onPressed: detecting
                          ? null
                          : () => context
                              .read<ObstacleBloc>()
                              .add(const StartObstacleDetection()),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start obstacle detection'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Semantics(
                    button: true,
                    label: 'Stop obstacle detection',
                    enabled: detecting,
                    child: ElevatedButton.icon(
                      onPressed: detecting
                          ? () => context
                              .read<ObstacleBloc>()
                              .add(const StopObstacleDetection())
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop obstacle detection'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Camera preview driven by global SettingsService ──────────
                  ValueListenableBuilder<bool>(
                    valueListenable: getIt<SettingsService>().debugCameraPreview,
                    builder: (_, showPreview, __) {
                      final ctrl = getIt<CameraService>().controller;
                      if (!showPreview || ctrl == null) return const SizedBox.shrink();
                      return Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Camera Preview (Debug)',
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CameraPreview(ctrl),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (state is ObstacleError) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      label: 'Error: ${state.message}',
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // ─── Detection list ────────────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: obstacles.isEmpty
                        ? Center(
                            child: Semantics(
                              liveRegion: true,
                              label: detecting ? 'Scanning for obstacles' : 'Press start to begin scanning',
                              child: Text(
                                detecting ? 'Scanning…' : 'Press Start to begin.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: obstacles.length,
                            itemBuilder: (context, index) {
                              final obstacle = obstacles[index];
                              final semanticDesc =
                                  '${obstacle.label} detected ${obstacle.spokenDirection}, '
                                  '${obstacle.estimatedDistanceMeters.toStringAsFixed(1)} metres, '
                                  '${obstacle.zoneName} zone.';
                              return Semantics(
                                label: semanticDesc,
                                liveRegion: true,
                                child: Card(
                                  child: ListTile(
                                    leading: Icon(
                                      obstacle.zone == ObstacleZone.near
                                          ? Icons.warning
                                          : Icons.warning_amber,
                                      color: obstacle.zone == ObstacleZone.near
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                    title: Text('${obstacle.label} — ${obstacle.spokenDirection}'),
                                    subtitle: Text(
                                      '${obstacle.zoneName} • '
                                      '${obstacle.estimatedDistanceMeters.toStringAsFixed(1)} m • '
                                      '${(obstacle.confidence * 100).toStringAsFixed(0)}%',
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
