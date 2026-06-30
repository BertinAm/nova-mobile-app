import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../bloc/face_bloc.dart';

class FaceRecognitionPage extends StatelessWidget {
  const FaceRecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<FaceBloc>()..add(const LoadContacts()),
      child: const _FaceView(),
    );
  }
}

class _FaceView extends StatefulWidget {
  const _FaceView();

  @override
  State<_FaceView> createState() => _FaceViewState();
}

class _FaceViewState extends State<_FaceView> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<FaceBloc, FaceState>(
            builder: (context, state) {
              final contacts = state is FaceReady ? state.contacts : const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Contact name for enrolment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context
                        .read<FaceBloc>()
                        .add(EnrollContact(_nameController.text)),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Enroll contact'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.read<FaceBloc>().add(const RecogniseFace()),
                    icon: const Icon(Icons.face),
                    label: const Text('Who is this?'),
                  ),
                  const SizedBox(height: 24),
                  if (state is FaceLoading) const LinearProgressIndicator(),
                  if (state is FaceError) Text(state.message),
                  if (state is FaceReady && state.lastResult != null)
                    Text(_resultText(state), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(contact.name),
                            subtitle: Text('Enrolled ${contact.createdAt.toLocal()}'),
                            trailing: IconButton(
                              tooltip: 'Delete ${contact.name}',
                              icon: const Icon(Icons.delete),
                              onPressed: () => context
                                  .read<FaceBloc>()
                                  .add(DeleteContact(contact.id)),
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

  String _resultText(FaceReady state) {
    final result = state.lastResult!;
    if (!result.faceDetected) return 'No face detected.';
    if (result.matched) {
      return 'Recognized ${result.contactName} (${((result.similarity ?? 0) * 100).toStringAsFixed(0)}%).';
    }
    return 'Unknown person detected.';
  }
}
