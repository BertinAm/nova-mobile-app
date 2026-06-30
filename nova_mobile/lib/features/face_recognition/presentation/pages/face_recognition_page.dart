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
      appBar: AppBar(title: const Text('Recognize Faces')),
      body: SafeArea(
        child: BlocBuilder<FaceBloc, FaceState>(
          builder: (context, state) {
            final contacts = state is FaceReady ? state.contacts : const [];

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ─── Recognise button ─────────────────────────────────
                      Semantics(
                        button: true,
                        label: 'Who is this? Recognize a face',
                        hint: 'Points the camera at a person and announces their name if enrolled',
                        child: ElevatedButton.icon(
                          onPressed: () => context.read<FaceBloc>().add(const RecogniseFace()),
                          icon: const Icon(Icons.face, size: 28),
                          label: const Text('Who is this?'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ─── Result / Loading / Error ─────────────────────────
                      if (state is FaceLoading)
                        Semantics(
                          liveRegion: true,
                          label: 'Processing, please wait.',
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          ),
                        ),

                      if (state is FaceError)
                        Semantics(
                          liveRegion: true,
                          label: 'Error: ${state.message}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              state.message,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),

                      if (state is FaceReady && state.lastResult != null) ...[
                        const SizedBox(height: 8),
                        _ResultCard(
                          resultText: _resultText(state),
                          isMatch: state.lastResult!.matched,
                          faceDetected: state.lastResult!.faceDetected,
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),

                      // ─── Enrolment section ────────────────────────────────
                      Semantics(
                        header: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Text(
                            'Enrol a Contact',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      Text(
                        'A caregiver can enrol known contacts here. '
                        'The blind user can then say "who is this?" to recognise them later.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        label: 'Contact name for enrolment text field',
                        hint: 'Type the name of the person you want to enrol',
                        textField: true,
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Contact name',
                            hintText: 'e.g. Mama, Doctor Mbarga…',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        button: true,
                        label: 'Enrol contact',
                        hint: 'Captures face photos and saves this contact for recognition',
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final name = _nameController.text.trim();
                            if (name.isNotEmpty) {
                              context.read<FaceBloc>().add(EnrollContact(name));
                              _nameController.clear();
                            }
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Enrol contact'),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),

                      // ─── Enrolled contacts list ───────────────────────────
                      Semantics(
                        header: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            'Enrolled Contacts (${contacts.length})',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),

                      if (contacts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No contacts enrolled yet. Enrol a contact above.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ]),
                  ),
                ),

                // Contacts in sliver
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contact = contacts[index];
                        return Semantics(
                          label: '${contact.name}, enrolled ${contact.createdAt.toLocal().toString().split(' ').first}',
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                ),
                              ),
                              title: Text(contact.name,
                                  style: Theme.of(context).textTheme.titleMedium),
                              subtitle: Text(
                                'Enrolled ${contact.createdAt.toLocal().toString().split(' ').first}',
                              ),
                              trailing: Semantics(
                                button: true,
                                label: 'Delete ${contact.name}',
                                child: IconButton(
                                  tooltip: 'Delete ${contact.name}',
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _confirmDelete(context, contact),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: contacts.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic contact) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text(
          'Delete ${contact.name} and their face data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          Semantics(
            button: true,
            label: 'Confirm delete ${contact.name}',
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(ctx, true);
                context.read<FaceBloc>().add(DeleteContact(contact.id));
              },
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  String _resultText(FaceReady state) {
    final result = state.lastResult!;
    // FR-05-06 exact logic
    if (!result.faceDetected) return ''; // silent — no face in frame
    if (result.matched) {
      final pct = ((result.similarity ?? 0) * 100).toStringAsFixed(0);
      return 'Recognised ${result.contactName} ($pct%)';
    }
    return 'Unknown person detected.'; // FR-05-06 exact wording
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.resultText,
    required this.isMatch,
    required this.faceDetected,
  });

  final String resultText;
  final bool isMatch;
  final bool faceDetected;

  @override
  Widget build(BuildContext context) {
    if (!faceDetected || resultText.isEmpty) return const SizedBox.shrink();

    final color = isMatch ? Colors.greenAccent : Colors.orangeAccent;
    final icon = isMatch ? Icons.check_circle : Icons.help_outline;

    return Semantics(
      liveRegion: true,
      label: resultText,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(resultText, style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}
