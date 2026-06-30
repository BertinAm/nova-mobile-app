import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/settings/settings_service.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
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
  @override
  void initState() {
    super.initState();
    // Register global stop hook so "stop option" voice command works
    globalStopCurrentOption = () {
      if (mounted) context.read<ObstacleBloc>().add(const StopObstacleDetection());
    };

    // Auto-start if navigated via voice (arguments == true)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) {
        context.read<ObstacleBloc>().add(const StartObstacleDetection());
      }
    });
  }

  @override
  void dispose() {
    // Clear stop hook when leaving page
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Option 1 — Obstacle Detection'),
        leading: BackButton(onPressed: () {
          context.read<ObstacleBloc>().add(const StopObstacleDetection());
          Navigator.pop(context);
        }),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<ObstacleBloc, ObstacleState>(
            builder: (context, state) {
              final detecting = state is ObstacleDetecting;
              final obstacles = detecting ? state.obstacles : const <DetectedObstacle>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status card ────────────────────────────────────────────
                  Semantics(
                    label: detecting ? 'Obstacle detection is running' : 'Obstacle detection is stopped',
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: detecting
                            ? cs.primaryContainer.withValues(alpha: 0.6)
                            : cs.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(detecting ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                            color: detecting ? cs.primary : cs.error),
                        const SizedBox(width: 12),
                        Text(
                          detecting ? 'Running — listening for obstacles' : 'Stopped',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Start / Stop ────────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: Semantics(
                        button: true, enabled: !detecting,
                        label: 'Start obstacle detection',
                        child: ElevatedButton.icon(
                          onPressed: detecting ? null : () =>
                              context.read<ObstacleBloc>().add(const StartObstacleDetection()),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true, enabled: detecting,
                        label: 'Stop obstacle detection',
                        child: OutlinedButton.icon(
                          onPressed: detecting ? () =>
                              context.read<ObstacleBloc>().add(const StopObstacleDetection()) : null,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // ── Camera preview (always shown here) ─────────────────────
                  _CameraPreviewWidget(),

                  const SizedBox(height: 8),

                  if (state is ObstacleError) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Error: ${state.message}',
                      child: Text(state.message,
                          style: TextStyle(color: cs.error)),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Obstacle list ────────────────────────────────────────────
                  Expanded(
                    child: obstacles.isEmpty
                        ? Center(
                            child: Semantics(
                              liveRegion: true,
                              label: detecting ? 'Scanning for obstacles' : 'Press start to begin scanning',
                              child: Text(
                                detecting ? 'Scanning…' : 'Press Start to begin.',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: obstacles.length,
                            itemBuilder: (context, i) {
                              final o = obstacles[i];
                              final desc =
                                  '${o.label} — ${o.spokenDirection}, '
                                  '${o.estimatedDistanceMeters.toStringAsFixed(1)} metres, '
                                  '${o.zoneName} zone.';
                              return Semantics(
                                label: desc, liveRegion: true,
                                child: Card(
                                  child: ListTile(
                                    leading: Icon(
                                      o.zone == ObstacleZone.near
                                          ? Icons.warning_rounded
                                          : Icons.warning_amber_rounded,
                                      color: o.zone == ObstacleZone.near
                                          ? cs.error : cs.secondary,
                                    ),
                                    title: Text('${o.label} — ${o.spokenDirection}'),
                                    subtitle: Text(
                                      '${o.zoneName} • '
                                      '${o.estimatedDistanceMeters.toStringAsFixed(1)} m • '
                                      '${(o.confidence * 100).toStringAsFixed(0)}%',
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

// ─── Camera preview inside obstacle page ──────────────────────────────────────
class _CameraPreviewWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: getIt<SettingsService>().debugCameraPreview,
      builder: (_, showDebugLabel, __) {
        final ctrl = getIt<CameraService>().controller;
        if (ctrl == null || !ctrl.value.isInitialized) return const SizedBox.shrink();
        return Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(ctrl),
                if (showDebugLabel)
                  Positioned(
                    top: 6, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: Colors.black54,
                      child: const Text('Debug', style: TextStyle(color: Colors.white60, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
