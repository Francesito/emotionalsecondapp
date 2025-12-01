import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Ánimo Escolar',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontWeight: FontWeight.w700),
            titleMedium: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        home: const EntryPoint(),
      ),
    );
  }
}

class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    if (user == null) return const AuthPage();
    return DashboardPage(user: user);
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  UserRole selectedRole = UserRole.student;
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final groupCtrl = TextEditingController();
  final groupNameCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    groupCtrl.dispose();
    groupNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Ánimo Escolar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Mide emociones, asistencia y alertas en un solo lugar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? '¿Nuevo? Regístrate' : 'Ya tengo cuenta'),
                  )
                ],
              ),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: [
                  selectedRole == UserRole.student,
                  selectedRole == UserRole.tutor
                ],
                onPressed: isLogin
                    ? null
                    : (idx) {
                        setState(
                            () => selectedRole = idx == 0 ? UserRole.student : UserRole.tutor);
                      },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Alumno'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Tutor'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!isLogin)
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Correo no válido' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 4 ? 'Mínimo 4 caracteres' : null,
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 8),
                      if (selectedRole == UserRole.tutor) ...[
                        TextFormField(
                          controller: groupNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de grupo inicial (opcional)',
                            helperText: 'Puedes crear más grupos después',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: groupCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código de grupo inicial (opcional)',
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          try {
                            if (isLogin) {
                              await app.login(emailCtrl.text.trim(), passCtrl.text);
                            } else {
                              await app.register(
                                role: selectedRole,
                                name: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                password: passCtrl.text,
                                groupCode:
                                    groupCtrl.text.trim().isEmpty ? null : groupCtrl.text.trim(),
                                groupName: groupNameCtrl.text.trim().isEmpty
                                    ? null
                                    : groupNameCtrl.text.trim(),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        child: Text(isLogin ? 'Entrar' : 'Crear cuenta'),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(user.role == UserRole.student ? 'Panel alumno' : 'Panel tutor'),
        actions: [
          IconButton(
            onPressed: () => app.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          )
        ],
      ),
      body: user.role == UserRole.student
          ? StudentDashboard(user: user)
          : TutorDashboard(user: user),
    );
  }
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final moodToday = app.moodForToday(user.id);
    final lastMood = app.lastMood(user.id);
    final group = app.groupForStudent(user.id);
    final tutor = app.tutorForStudent(user.id);
    final usedJustifications = app.justificationsForUser(user.id).length;
    final pendingAlerts = app.alertsForUser(user.id);
    final canRequestJustification = usedJustifications < 2;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${user.name}', style: Theme.of(context).textTheme.titleLarge),
                  Text(group != null ? 'Grupo ${group.name}' : 'Sin grupo asignado'),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(user.name.characters.first.toUpperCase()),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (group == null)
            SectionCard(
              title: 'Unirse a clase',
              child: JoinGroupForm(
                onJoin: (code) async {
                  try {
                    await app.joinGroup(userId: user.id, groupCode: code);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Te uniste al grupo')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
              ),
            ),
          SectionCard(
            title: 'Estado de ánimo',
            trailing: Text(moodToday != null ? 'Registrado hoy' : 'Falta registrar'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lastMood != null)
                  Row(
                    children: [
                      Text(lastMood.mood.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 8),
                      Text(describeMood(lastMood.mood)),
                      const Spacer(),
                      Text(formatDate(lastMood.date)),
                    ],
                  )
                else
                  const Text('Aún no tienes registros'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: moodToday != null
                          ? null
                          : () => _showMoodSheet(context, app, user.id),
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      label: Text(moodToday != null ? 'Listo por hoy' : 'Registrar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MoodHistoryPage(userId: user.id)),
                      ),
                      child: const Text('Ver historial'),
                    )
                  ],
                )
              ],
            ),
          ),
          SectionCard(
            title: 'Percepción semanal',
            trailing: Text('Materias: ${app.perceptionsForUser(user.id).length}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.lastPerceptionSummary(user.id)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showPerceptionSheet(context, app, user.id),
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('Capturar semana'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PerceptionHistoryPage(userId: user.id),
                        ),
                      ),
                      child: const Text('Detalle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Justificantes',
            trailing: Text('$usedJustifications / 2 usados'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(canRequestJustification
                    ? 'Puedes solicitar hasta 2 por cuatrimestre'
                    : 'Límite alcanzado'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: canRequestJustification
                          ? () => _showJustificationSheet(context, app, user.id)
                          : null,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Solicitar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JustificationListPage(userId: user.id),
                        ),
                      ),
                      child: const Text('Ver solicitudes'),
                    )
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Alertas y mensajes',
            trailing: Text('${pendingAlerts.length} alertas'),
            child: Column(
              children: [
                ...pendingAlerts.take(4).map(
                      (a) => ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: a.severityColor,
                        ),
                        title: Text(a.message),
                        subtitle: Text(formatDate(a.date)),
                        trailing: Text(a.type.label),
                      ),
                    ),
                if (pendingAlerts.isEmpty)
                  const ListTile(
                    title: Text('Sin alertas'),
                  ),
                TextButton(
                  onPressed: tutor == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagesPage(userId: tutor.id),
                            ),
                          ),
                  child: Text(tutor == null ? 'Sin tutor asignado' : 'Abrir mensajes'),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class TutorDashboard extends StatelessWidget {
  const TutorDashboard({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final groups = app.groupsForTutor(user.id);
    final alerts = app.alertsForTutor(user.id);
    final pendingJust = app.pendingJustifications(user.id);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${user.name}', style: Theme.of(context).textTheme.titleLarge),
                  Text('Grupos: ${groups.length}'),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showCreateGroupSheet(context, app, user.id),
                icon: const Icon(Icons.group_add),
                label: const Text('Nuevo grupo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...groups.map(
            (g) => SectionCard(
              title: '${g.name} (${g.code})',
              trailing: Text('${g.studentIds.length} alumnos'),
              child: Column(
                children: [
                  ...app.studentsInGroup(g).map(
                        (s) => ListTile(
                          leading: CircleAvatar(child: Text(s.name.characters.first)),
                          title: Text(s.name),
                          subtitle: Text(app.studentSnapshot(s.id)),
                          trailing: Text(app.lastMoodEmoji(s.id)),
                        ),
                      ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesPage(groupId: g.id, userId: user.id),
                      ),
                    ),
                    child: const Text('Chat grupal / 1:1'),
                  )
                ],
              ),
            ),
          ),
          SectionCard(
            title: 'Alertas',
            trailing: Text('${alerts.length} activas'),
            child: Column(
              children: alerts
                  .map(
                    (a) => ListTile(
                      leading: Icon(Icons.bolt, color: a.severityColor),
                      title: Text(a.message),
                      subtitle: Text(app.userName(a.userId)),
                      trailing: Text(a.type.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          SectionCard(
            title: 'Justificantes pendientes',
            trailing: Text('${pendingJust.length}'),
            child: Column(
              children: pendingJust
                  .map(
                    (j) => Card(
                      child: ListTile(
                        title: Text('${app.userName(j.userId)} • ${j.type}'),
                        subtitle: Text(j.evidence ?? 'Sin evidencia'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => app.resolveJustification(j.id, false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => app.resolveJustification(j.id, true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class MoodHistoryPage extends StatelessWidget {
  const MoodHistoryPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final moods = app.moodForUser(userId);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ánimo')),
      body: ListView.builder(
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final m = moods[index];
          return ListTile(
            leading: Text(m.mood.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(describeMood(m.mood)),
            subtitle: Text(m.note ?? 'Sin nota'),
            trailing: Text(formatDate(m.date)),
          );
        },
      ),
    );
  }
}

class PerceptionHistoryPage extends StatelessWidget {
  const PerceptionHistoryPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.perceptionsForUser(userId);
    return Scaffold(
      appBar: AppBar(title: const Text('Percepción semanal')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final p = items[index];
          return ListTile(
            leading: Text(p.emotion.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(p.subject),
            subtitle: Text(p.notes ?? 'Sin notas'),
            trailing: Text(formatDate(p.weekOf)),
          );
        },
      ),
    );
  }
}

class JustificationListPage extends StatelessWidget {
  const JustificationListPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.justificationsForUser(userId);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis justificantes')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final j = items[index];
          return ListTile(
            leading: Icon(
              j.status.icon,
              color: j.status.color,
            ),
            title: Text('${j.type} • ${j.status.label}'),
            subtitle: Text(j.evidence ?? 'Sin evidencia'),
            trailing: Text(formatDate(j.date)),
          );
        },
      ),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.groupId, required this.userId});
  final int? groupId;
  final String userId;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    app.loadMessages(groupId: widget.groupId, peerId: widget.groupId == null ? widget.userId : null);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.messagesFor(groupId: widget.groupId, userId: widget.userId);
    final current = app.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId != null ? 'Mensajes del grupo' : 'Mensajes directos'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final m = items[index];
                final isMine = m.fromId == current.id;
                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(app.userName(m.fromId), style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(m.body),
                        Text(formatDate(m.date),
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (ctrl.text.isEmpty) return;
                    app.sendMessage(
                      fromId: current.id,
                      body: ctrl.text,
                      groupId: widget.groupId,
                      toUserId: widget.groupId == null ? widget.userId : null,
                    );
                    ctrl.clear();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class JoinGroupForm extends StatefulWidget {
  const JoinGroupForm({super.key, required this.onJoin});
  final ValueChanged<String> onJoin;

  @override
  State<JoinGroupForm> createState() => _JoinGroupFormState();
}

class _JoinGroupFormState extends State<JoinGroupForm> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingresa el código de la clase que te compartió tu tutor.'),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Código de grupo'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            if (ctrl.text.isEmpty) return;
            widget.onJoin(ctrl.text.trim());
          },
          child: const Text('Unirme'),
        )
      ],
    );
  }
}

void _showMoodSheet(BuildContext context, AppState app, String userId) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      String note = '';
      MoodEmoji? selected;
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Cómo te sientes hoy?'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: MoodEmoji.values
                      .map(
                        (m) => ChoiceChip(
                          label: Text('${m.emoji} ${describeMood(m)}'),
                          selected: selected == m,
                          onSelected: (_) => setState(() => selected = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                  onChanged: (v) => note = v,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          app.logMood(userId: userId, mood: selected!, note: note);
                          Navigator.pop(ctx);
                        },
                  child: const Text('Guardar'),
                )
              ],
            ),
          );
        },
      );
    },
  );
}

void _showPerceptionSheet(BuildContext context, AppState app, String userId) {
  final subjectCtrl = TextEditingController();
  String notes = '';
  MoodEmoji selected = MoodEmoji.bien;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Percepción semanal por materia'),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Materia'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: MoodEmoji.values
                      .map(
                        (m) => ChoiceChip(
                          label: Text('${m.emoji} ${describeMood(m)}'),
                          selected: selected == m,
                          onSelected: (_) => setState(() => selected = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: 'Notas'),
                  onChanged: (v) => notes = v,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    app.submitPerception(
                      userId: userId,
                      subject: subjectCtrl.text,
                      emotion: selected,
                      notes: notes,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                )
              ],
            ),
          );
        },
      );
    },
  );
}

void _showJustificationSheet(BuildContext context, AppState app, String userId) {
  final typeCtrl = TextEditingController();
  String evidence = '';
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solicitar justificante'),
            TextField(
              controller: typeCtrl,
              decoration: const InputDecoration(labelText: 'Motivo (ej. cita médica)'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Evidencia o nota'),
              onChanged: (v) => evidence = v,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                try {
                  app.requestJustification(
                    userId: userId,
                    type: typeCtrl.text,
                    evidence: evidence,
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Enviar'),
            )
          ],
        ),
      );
    },
  );
}

void _showCreateGroupSheet(BuildContext context, AppState app, String tutorId) {
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Crear nuevo grupo'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de grupo'),
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Código único'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                try {
                  app.createGroup(tutorId: tutorId, name: nameCtrl.text, code: codeCtrl.text);
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Crear'),
            )
          ],
        ),
      );
    },
  );
}

enum UserRole { student, tutor }

enum MoodEmoji { muyBien, bien, neutral, mal, muyMal }

String describeMood(MoodEmoji mood) {
  switch (mood) {
    case MoodEmoji.muyBien:
      return 'Excelente';
    case MoodEmoji.bien:
      return 'Bien';
    case MoodEmoji.neutral:
      return 'Neutral';
    case MoodEmoji.mal:
      return 'Bajo';
    case MoodEmoji.muyMal:
      return 'Crítico';
  }
}

extension MoodEmojiX on MoodEmoji {
  String get emoji {
    switch (this) {
      case MoodEmoji.muyBien:
        return '😄';
      case MoodEmoji.bien:
        return '🙂';
      case MoodEmoji.neutral:
        return '😐';
      case MoodEmoji.mal:
        return '🙁';
      case MoodEmoji.muyMal:
        return '😭';
    }
  }
}

enum AlertType { mood, attendance, grade }

extension AlertTypeX on AlertType {
  String get label {
    switch (this) {
      case AlertType.mood:
        return 'Ánimo';
      case AlertType.attendance:
        return 'Asistencia';
      case AlertType.grade:
        return 'Calificación';
    }
  }
}

enum JustificationStatus { pending, approved, rejected }

extension JustificationStatusX on JustificationStatus {
  String get label {
    switch (this) {
      case JustificationStatus.pending:
        return 'Pendiente';
      case JustificationStatus.approved:
        return 'Aprobado';
      case JustificationStatus.rejected:
        return 'Rechazado';
    }
  }

  Color get color {
    switch (this) {
      case JustificationStatus.pending:
        return Colors.orange;
      case JustificationStatus.approved:
        return Colors.green;
      case JustificationStatus.rejected:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case JustificationStatus.pending:
        return Icons.hourglass_bottom;
      case JustificationStatus.approved:
        return Icons.check_circle;
      case JustificationStatus.rejected:
        return Icons.cancel;
    }
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? groupCode;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.groupCode,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? groupCode,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      groupCode: groupCode ?? this.groupCode,
    );
  }
}

class Group {
  final int? id;
  final String code;
  final String name;
  final String tutorId;
  final String? tutorName;
  final List<String> studentIds;

  Group({
    this.id,
    required this.code,
    required this.name,
    required this.tutorId,
    this.tutorName,
    List<String>? studentIds,
  }) : studentIds = studentIds ?? [];
}

class MoodRecord {
  final String userId;
  final DateTime date;
  final MoodEmoji mood;
  final String? note;

  MoodRecord({
    required this.userId,
    required this.date,
    required this.mood,
    this.note,
  });
}

class WeeklyPerception {
  final String userId;
  final String subject;
  final DateTime weekOf;
  final MoodEmoji emotion;
  final String? notes;

  WeeklyPerception({
    required this.userId,
    required this.subject,
    required this.weekOf,
    required this.emotion,
    this.notes,
  });
}

class JustificationRequest {
  final String id;
  final String userId;
  final String type;
  final String? evidence;
  JustificationStatus status;
  final DateTime date;

  JustificationRequest({
    required this.id,
    required this.userId,
    required this.type,
    this.evidence,
    required this.status,
    required this.date,
  });
}

class AlertItem {
  final String id;
  final String userId;
  final AlertType type;
  final String message;
  final DateTime date;
  final String severity;

  AlertItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.date,
    required this.severity,
  });

  Color get severityColor {
    switch (severity) {
      case 'alto':
        return Colors.red;
      case 'medio':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}

class MessageItem {
  final String id;
  final String fromId;
  final String? toUserId;
  final int? groupId;
  final String body;
  final DateTime date;

  MessageItem({
    required this.id,
    required this.fromId,
    required this.body,
    required this.date,
    this.toUserId,
    this.groupId,
  });
}

class AppState extends ChangeNotifier {
  final ApiClient _api = ApiClient(baseUrl: 'https://emotionalsecondapp.onrender.com');
  AppUser? currentUser;
  Group? currentGroup;
  List<Group> tutorGroups = [];
  List<MoodRecord> moods = [];
  List<WeeklyPerception> perceptions = [];
  List<JustificationRequest> justifications = [];
  List<AlertItem> alerts = [];
  List<MessageItem> messages = [];

  Future<void> loadMessages({int? groupId, String? peerId}) async {
    messages = await _api.fetchMessages(
      groupId: groupId,
      currentUserId: currentUser?.id,
      peerId: peerId,
    );
    notifyListeners();
  }

  Future<void> register({
    required UserRole role,
    required String name,
    required String email,
    required String password,
    String? groupCode,
    String? groupName,
  }) async {
    final user = await _api.register(role: role, name: name, email: email, password: password);
    currentUser = user;
    if (role == UserRole.tutor && groupCode != null && groupName != null && groupCode.isNotEmpty && groupName.isNotEmpty) {
      await createGroup(tutorId: user.id, name: groupName, code: groupCode);
    }
    await _refresh();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final user = await _api.login(email: email, password: password);
    currentUser = user;
    await _refresh();
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    currentGroup = null;
    tutorGroups = [];
    moods = [];
    perceptions = [];
    justifications = [];
    alerts = [];
    messages = [];
    notifyListeners();
  }

  Future<void> _refresh() async {
    if (currentUser == null) return;
    if (currentUser!.role == UserRole.student) {
      final group = await _api.groupForStudent(currentUser!.id);
      currentGroup = group;
      moods = await _api.fetchMood(currentUser!.id);
      perceptions = await _api.fetchPerceptions(currentUser!.id);
      justifications = await _api.fetchJustifications(studentId: currentUser!.id);
      alerts = await _api.fetchAlerts(studentId: currentUser!.id);
      if (group != null) {
        messages = await _api.fetchMessages(groupId: group.id);
      }
    } else {
      tutorGroups = await _api.fetchGroupsForTutor(currentUser!.id);
      alerts = await _api.fetchAlerts(tutorId: currentUser!.id);
      justifications = await _api.fetchJustifications(tutorId: currentUser!.id);
    }
  }

  Future<void> logMood({
    required String userId,
    required MoodEmoji mood,
    String? note,
  }) async {
    await _api.logMood(studentId: userId, mood: mood, note: note);
    moods = await _api.fetchMood(userId);
    alerts = await _api.fetchAlerts(studentId: userId);
    notifyListeners();
  }

  Future<void> submitPerception({
    required String userId,
    required String subject,
    required MoodEmoji emotion,
    String? notes,
  }) async {
    await _api.submitPerception(studentId: userId, subject: subject, emotion: emotion, notes: notes);
    perceptions = await _api.fetchPerceptions(userId);
    notifyListeners();
  }

  Future<void> requestJustification({
    required String userId,
    required String type,
    String? evidence,
  }) async {
    await _api.requestJustification(studentId: userId, type: type, evidence: evidence);
    justifications = await _api.fetchJustifications(studentId: userId);
    notifyListeners();
  }

  Future<void> resolveJustification(String id, bool approve) async {
    await _api.resolveJustification(id: id, status: approve ? 'approved' : 'rejected', reviewerId: currentUser?.id);
    justifications = await _api.fetchJustifications(tutorId: currentUser?.id);
    notifyListeners();
  }

  Future<void> sendMessage({
    required String fromId,
    required String body,
    String? toUserId,
    int? groupId,
  }) async {
    await _api.sendMessage(fromId: fromId, body: body, toUserId: toUserId, groupId: groupId);
    messages = await _api.fetchMessages(
      groupId: groupId,
      currentUserId: currentUser?.id,
      peerId: toUserId,
    );
    notifyListeners();
  }

  Future<void> createGroup({
    required String tutorId,
    required String name,
    required String code,
  }) async {
    await _api.createGroup(tutorId: tutorId, name: name, code: code);
    tutorGroups = await _api.fetchGroupsForTutor(tutorId);
    notifyListeners();
  }

  Future<void> joinGroup({required String userId, required String groupCode}) async {
    await _api.joinGroup(studentId: userId, groupCode: groupCode);
    currentGroup = await _api.groupForStudent(userId);
    notifyListeners();
  }

  List<Group> groupsForTutor(String tutorId) => tutorGroups;

  Group? groupForStudent(String userId) => currentGroup;

  AppUser? tutorForStudent(String studentId) {
    if (currentGroup == null) return null;
    return _api.cachedUsers[currentGroup!.tutorId] ??
        AppUser(
          id: currentGroup!.tutorId,
          name: currentGroup!.tutorName ?? 'Tutor',
          email: '',
          password: '',
          role: UserRole.tutor,
        );
  }

  List<MoodRecord> moodForUser(String userId) => moods;

  MoodRecord? moodForToday(String userId) {
    final today = DateTime.now();
    return moods.where((m) => DateUtils.isSameDay(m.date, today)).firstOrNull;
  }

  MoodRecord? lastMood(String userId) => moodForUser(userId).firstOrNull;

  String lastMoodEmoji(String userId) {
    final last = lastMood(userId);
    return last?.mood.emoji ?? '—';
  }

  List<WeeklyPerception> perceptionsForUser(String userId) => perceptions;

  String lastPerceptionSummary(String userId) {
    final last = perceptionsForUser(userId).firstOrNull;
    if (last == null) return 'Sin capturas esta semana';
    return '${last.subject}: ${describeMood(last.emotion)}';
  }

  List<JustificationRequest> justificationsForUser(String userId) => justifications;

  List<JustificationRequest> pendingJustifications(String tutorId) =>
      justifications.where((j) => j.status == JustificationStatus.pending).toList();

  List<AlertItem> alertsForUser(String userId) => alerts;

  List<AlertItem> alertsForTutor(String tutorId) => alerts;

  List<MessageItem> messagesFor({int? groupId, String? userId}) {
    return messages.where((m) {
      if (groupId != null) return m.groupId == groupId;
      if (userId != null && currentUser != null) {
        return (m.fromId == userId && m.toUserId == currentUser!.id) ||
            (m.fromId == currentUser!.id && m.toUserId == userId);
      }
      return false;
    }).toList();
  }

  String userName(String id) => _api.cachedUsers[id]?.name ?? 'Usuario';

  List<AppUser> studentsInGroup(Group group) => group.studentIds
      .map((id) => _api.cachedUsers[id])
      .whereType<AppUser>()
      .toList();

  String studentSnapshot(String userId) {
    final last = lastMood(userId);
    final pending = justifications.where(
      (j) => j.userId == userId && j.status == JustificationStatus.pending,
    );
    return [
      if (last != null) 'Ánimo: ${describeMood(last.mood)}',
      if (pending.isNotEmpty) '${pending.length} justificante(s) pendiente(s)',
    ].join(' • ');
  }
}

class ApiClient {
  final String baseUrl;
  final http.Client _client = http.Client();
  final Map<String, AppUser> cachedUsers = {};

  ApiClient({required this.baseUrl});

  Future<AppUser> register({
    required UserRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'role': role.name,
      'name': name,
      'email': email,
      'password': password,
    });
    final user = _userFromJson(data);
    cachedUsers[user.id] = user;
    return user;
  }

  Future<AppUser> login({required String email, required String password}) async {
    final data = await _post('/auth/login', {'email': email, 'password': password});
    final user = _userFromJson(data);
    cachedUsers[user.id] = user;
    return user;
  }

  Future<Group?> groupForStudent(String studentId) async {
    final resp = await _get('/groups/by-student', {'studentId': studentId});
    if (resp is List && resp.isNotEmpty) {
      final g = resp.first;
      cachedUsers[(g['tutorId'] ?? '').toString()] = AppUser(
        id: (g['tutorId'] ?? '').toString(),
        name: g['tutorName'] ?? 'Tutor',
        email: '',
        password: '',
        role: UserRole.tutor,
      );
      return Group(
        id: g['id'],
        code: g['code'],
        name: g['name'],
        tutorId: (g['tutorId'] ?? '').toString(),
        tutorName: g['tutorName'],
        studentIds: const [],
      );
    }
    return null;
  }

  Future<void> createGroup({required String tutorId, required String name, required String code}) =>
      _post('/groups', {'tutorId': tutorId, 'name': name, 'code': code});

  Future<void> joinGroup({required String studentId, required String groupCode}) =>
      _post('/groups/join', {'studentId': studentId, 'groupCode': groupCode});

  Future<List<Group>> fetchGroupsForTutor(String tutorId) async {
    final resp = await _get('/groups', {'tutorId': tutorId});
    if (resp is! List) return [];
    return resp.map<Group>((g) {
      final students = (g['students'] as List? ?? [])
          .map((s) => (s['id'] ?? '').toString())
          .toList();
      for (final s in g['students'] ?? []) {
        cachedUsers[(s['id'] ?? '').toString()] = AppUser(
          id: (s['id'] ?? '').toString(),
          name: s['name'] ?? 'Alumno',
          email: '',
          password: '',
          role: UserRole.student,
        );
      }
      return Group(
        id: g['id'],
        code: g['code'],
        name: g['name'],
        tutorId: tutorId,
        studentIds: students,
      );
    }).toList();
  }

  Future<void> logMood({required String studentId, required MoodEmoji mood, String? note}) =>
      _post('/mood', {'studentId': studentId, 'mood': mood.name, 'note': note});

  Future<List<MoodRecord>> fetchMood(String studentId) async {
    final resp = await _get('/mood', {'studentId': studentId});
    if (resp is! List) return [];
    return resp
        .map<MoodRecord>((m) => MoodRecord(
              userId: studentId,
              date: DateTime.parse(m['loggedDate']),
              mood: MoodEmoji.values.firstWhere((e) => e.name == m['mood']),
              note: m['note'],
            ))
        .toList();
  }

  Future<void> submitPerception({
    required String studentId,
    required String subject,
    required MoodEmoji emotion,
    String? notes,
  }) =>
      _post('/perception', {
        'studentId': studentId,
        'subject': subject,
        'emotion': emotion.name,
        'notes': notes
      });

  Future<List<WeeklyPerception>> fetchPerceptions(String studentId) async {
    final resp = await _get('/perception', {'studentId': studentId});
    if (resp is! List) return [];
    return resp
        .map<WeeklyPerception>((p) => WeeklyPerception(
              userId: studentId,
              subject: p['subject'],
              weekOf: DateTime.parse(p['weekStart']),
              emotion: MoodEmoji.values.firstWhere((e) => e.name == p['emotion']),
              notes: p['notes'],
            ))
        .toList();
  }

  Future<void> requestJustification({
    required String studentId,
    required String type,
    String? evidence,
  }) =>
      _post('/justifications', {'studentId': studentId, 'type': type, 'evidenceUrl': evidence});

  Future<List<JustificationRequest>> fetchJustifications({String? studentId, String? tutorId}) async {
    final query = <String, String>{};
    if (studentId != null) query['studentId'] = studentId;
    if (tutorId != null) query['tutorId'] = tutorId;
    final resp = await _get('/justifications', query);
    if (resp is! List) return [];
    return resp
        .map<JustificationRequest>((j) => JustificationRequest(
              id: (j['id'] ?? '').toString(),
              userId: studentId ?? (j['studentId'] ?? '').toString(),
              type: j['type'],
              evidence: j['evidenceUrl'],
              status: JustificationStatus.values.firstWhere((e) => e.name == j['status']),
              date: DateTime.parse(j['createdAt']),
            ))
        .toList();
  }

  Future<void> resolveJustification({
    required String id,
    required String status,
    String? reviewerId,
  }) =>
      _patch('/justifications/$id', {'status': status, 'reviewerId': reviewerId});

  Future<List<AlertItem>> fetchAlerts({String? studentId, String? tutorId}) async {
    final query = <String, String>{};
    if (studentId != null) query['studentId'] = studentId;
    if (tutorId != null) query['tutorId'] = tutorId;
    final resp = await _get('/alerts', query);
    if (resp is! List) return [];
    return resp
        .map<AlertItem>((a) => AlertItem(
              id: (a['id'] ?? '').toString(),
              userId: studentId ?? '',
              type: AlertType.values.firstWhere((e) => e.name == a['type']),
              message: a['message'],
              date: DateTime.parse(a['createdAt']),
              severity: a['severity'],
            ))
        .toList();
  }

  Future<void> sendMessage({
    required String fromId,
    required String body,
    String? toUserId,
    int? groupId,
  }) =>
      _post('/messages', {
        'fromUserId': fromId,
        'toUserId': toUserId,
        'groupId': groupId,
        'body': body,
      });

  Future<List<MessageItem>> fetchMessages({int? groupId, String? currentUserId, String? peerId}) async {
    final query = <String, String>{};
    if (groupId != null) query['groupId'] = groupId.toString();
    if (currentUserId != null && peerId != null) {
      query['fromUserId'] = currentUserId;
      query['toUserId'] = peerId;
    }
    final resp = await _get('/messages', query);
    if (resp is! List) return [];
    return resp
        .map<MessageItem>((m) => MessageItem(
              id: (m['id'] ?? '').toString(),
              fromId: (m['fromUserId'] ?? m['from_user_id'] ?? '').toString(),
              toUserId: (m['toUserId'] ?? m['to_user_id'])?.toString(),
              groupId: m['groupId'] ?? m['group_id'],
              body: m['body'],
              date: DateTime.parse(m['createdAt']),
            ))
        .toList();
  }

  Future<dynamic> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode >= 400) throw Exception(_err(res));
    return jsonDecode(res.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) throw Exception(_err(res));
    return jsonDecode(res.body);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) throw Exception(_err(res));
    return jsonDecode(res.body);
  }

  String _err(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['error'] != null) return data['error'];
    } catch (_) {}
    return 'Error ${res.statusCode}';
  }

  AppUser _userFromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        password: '',
        role: (json['role']?.toString() == 'tutor') ? UserRole.tutor : UserRole.student,
      );
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
