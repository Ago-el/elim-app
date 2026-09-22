import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/session.dart';

void main() => runApp(const ElimApp());

class ElimApp extends StatelessWidget {
  const ElimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ELIM',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF173B72)),
      ),
      home: const Boot(),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  @override
  void initState() {
    super.initState();
    go();
  }

  Future<void> go() async {
    final ok = await Session.loggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ok ? const Home() : const Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ==========================================
// SYSTÈME RBAC COMPLET
// ==========================================
class RoleHelper {
  static const String superAdmin = 'SUPERADMIN';
  static const String admin = 'ADMIN';
  static const String leader = 'LEADER';
  static const String member = 'MEMBER';

  static String normalize(String? r) {
    if (r == null) return member;
    final upper = r.toUpperCase().trim();
    if (upper == 'SUPERADMIN' || upper == 'SUPER_ADMIN') return superAdmin;
    if (upper == 'ADMIN') return admin;
    if (upper == 'LEADER') return leader;
    return member;
  }

  static bool isSuperAdmin(String role) => normalize(role) == superAdmin;
  
  static bool isAdminOrHigher(String role) {
    final norm = normalize(role);
    return norm == superAdmin || norm == admin;
  }

  static bool canManageChurch(String role) => isAdminOrHigher(role);
  static bool canApproveMembers(String role) => isAdminOrHigher(role);
  static bool canAddMembers(String role) => isAdminOrHigher(role);
  static bool canEditFunction(String role) {
    final norm = normalize(role);
    return norm == superAdmin || norm == admin || norm == leader;
  }
}

// ==========================================
// LOGIN & AUTHENTIFICATION
// ==========================================
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      msg('Veuillez renseigner vos identifiants.');
      return;
    }
    setState(() => loading = true);
    try {
      final d = await ApiClient().post('/api/v1/auth/admin', {
        'email': email.text.trim(),
        'password': password.text,
      });
      await Session.save(
        d['access_token'],
        Map<String, dynamic>.from(d['user'] ?? {}),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Home()),
        );
      }
    } catch (_) {
      msg('Connexion impossible.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const CircleAvatar(radius: 45, child: Icon(Icons.church, size: 46)),
                  const SizedBox(height: 16),
                  const Text('ELIM', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  const Text('Communauté • Églises • Membres'),
                  const SizedBox(height: 30),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : login,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(loading ? 'Connexion…' : 'Se connecter'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterStep1Screen()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Créer un compte (Inscription)'),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => msg('Mot de passe oublié : contactez l\'administrateur.'),
                    child: const Text('Mot de passe oublié?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// INSCRIPTION EN 2 ÉTAPES AVEC OTP GRATUIT
// ==========================================
class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  List<dynamic> churches = [];
  List<dynamic> roles = [];
  String? selectedChurchId;
  String? selectedRoleId;

  bool loadingChurches = true;
  bool loadingRoles = false;
  bool submitting = false;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    loadChurches();
  }

  Future<void> loadChurches() async {
    try {
      final d = await ApiClient().get('/api/v1/churches');
      if (mounted) {
        setState(() {
          churches = d is List ? d : (d['items'] ?? []);
          loadingChurches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingChurches = false);
      msg('Erreur lors du chargement des églises.');
    }
  }

  Future<void> loadRoles(String churchId) async {
    setState(() {
      loadingRoles = true;
      roles = [];
      selectedRoleId = null;
    });
    try {
      final d = await ApiClient().get('/api/v1/churches/$churchId/roles');
      if (mounted) {
        setState(() {
          roles = d is List ? d : (d['items'] ?? []);
          loadingRoles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingRoles = false);
      msg('Erreur lors du chargement des fonctions/rôles.');
    }
  }

  Future<void> sendOtpAndProceed() async {
    final fn = firstNameController.text.trim();
    final ln = lastNameController.text.trim();
    final em = emailController.text.trim();
    final ph = phoneController.text.trim();
    final pw = passwordController.text;

    if (fn.isEmpty || ln.isEmpty || em.isEmpty || ph.isEmpty || pw.isEmpty) {
      msg('Veuillez remplir tous les champs obligatoires.');
      return;
    }
    if (selectedChurchId == null) {
      msg('Veuillez sélectionner une église.');
      return;
    }

    setState(() => submitting = true);
    try {
      await ApiClient().post('/api/v1/auth/send-otp', {
        'email': em,
        'phone': ph,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterStep2OtpScreen(
            registrationData: {
              'first_name': fn,
              'last_name': ln,
              'email': em,
              'phone': ph,
              'password': pw,
              'church_id': selectedChurchId,
              'role_id': selectedRoleId,
              'status': 'pending',
            },
          ),
        ),
      );
    } catch (_) {
      msg('Erreur lors de l\'envoi du code OTP.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription - Étape 1/2')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                loadingChurches
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: selectedChurchId,
                        decoration: const InputDecoration(labelText: 'Sélectionner Église', border: OutlineInputBorder()),
                        items: churches.map((c) {
                          final item = Map<String, dynamic>.from(c);
                          return DropdownMenuItem<String>(
                            value: item['id']?.toString(),
                            child: Text(item['name']?.toString() ?? 'Église'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedChurchId = val;
                          });
                          if (val != null) loadRoles(val);
                        },
                      ),
                const SizedBox(height: 14),
                if (loadingRoles)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: selectedRoleId,
                    decoration: const InputDecoration(
                      labelText: 'Sélectionner Fonction (Optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: roles.map((r) {
                      final item = Map<String, dynamic>.from(r);
                      return DropdownMenuItem<String>(
                        value: item['id']?.toString(),
                        child: Text(item['name']?.toString() ?? 'Fonction'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedRoleId = val),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : sendOtpAndProceed,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(submitting ? 'Envoi de l\'OTP...' : 'Continuer (Envoyer OTP)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterStep2OtpScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const RegisterStep2OtpScreen({super.key, required this.registrationData});

  @override
  State<RegisterStep2OtpScreen> createState() => _RegisterStep2OtpScreenState();
}

class _RegisterStep2OtpScreenState extends State<RegisterStep2OtpScreen> {
  final otpController = TextEditingController();
  bool submitting = false;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> register() async {
    final otp = otpController.text.trim();
    if (otp.length < 6) {
      msg('Veuillez entrer le code OTP à 6 chiffres.');
      return;
    }

    setState(() => submitting = true);
    try {
      final payload = Map<String, dynamic>.from(widget.registrationData);
      payload['otp'] = otp;

      await ApiClient().post('/api/v1/auth/register', payload);

      if (!mounted) return;
      msg('Inscription réussie ! Votre compte est en attente d\'approbation.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (_) => false,
      );
    } catch (_) {
      msg('Code OTP invalide ou erreur d\'inscription.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification OTP - Étape 2/2')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Un code de vérification a été envoyé à ${widget.registrationData['email']} / ${widget.registrationData['phone']}.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Code OTP (6 chiffres)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: submitting ? null : register,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(submitting ? 'Validation...' : 'Valider mon inscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HOME & NAVIGATION
// ==========================================
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  String userRole = RoleHelper.member;
  String userName = '';

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final u = await Session.user();
    if (mounted) {
      setState(() {
        userRole = RoleHelper.normalize(u['role']);
        userName = u['name'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(userRole: userRole),
      Members(userRole: userRole),
      Churches(userRole: userRole),
      const Generic(title: 'Messages', icon: Icons.chat_bubble),
      const Profile(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ELIM')),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF173B72)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ELIM', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                    if (userName.isNotEmpty)
                      Text(userName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    Text('Rôle: $userRole', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
            for (final x in [
              ['Groupements', Icons.groups],
              ['Prédications', Icons.video_library],
              ['Actualités', Icons.newspaper],
              ['Événements', Icons.event],
              ['Bible & ressources', Icons.menu_book],
              ['Paramètres', Icons.settings]
            ])
              ListTile(
                leading: Icon(x[1] as IconData),
                title: Text(x[0] as String),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Generic(title: x[0] as String, icon: x[1] as IconData)),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnexion'),
              onTap: () async {
                await Session.clear();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const Login()),
                    (_) => false,
                  );
                }
              },
            )
          ],
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Membres'),
          NavigationDestination(icon: Icon(Icons.church_outlined), selectedIcon: Icon(Icons.church), label: 'Églises'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ==========================================
// DASHBOARD
// ==========================================
class Dashboard extends StatelessWidget {
  final String userRole;
  const Dashboard({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Bienvenue dans ELIM', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Votre espace communautaire et administratif ($userRole).'),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _card(context, 'Membres', Icons.people, Members(userRole: userRole)),
            _card(context, 'Églises', Icons.church, Churches(userRole: userRole)),
            _card(context, 'Prédications', Icons.video_library, const Generic(title: 'Prédications', icon: Icons.video_library)),
            _card(context, 'Événements', Icons.event, const Generic(title: 'Événements', icon: Icons.event)),
          ],
        ),
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications_active),
            title: Text('Notifications'),
            subtitle: Text('Les annonces de votre communauté apparaîtront ici.'),
          ),
        )
      ],
    );
  }

  Widget _card(BuildContext c, String t, IconData i, Widget p) => Card(
        child: InkWell(
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => p)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, size: 38),
              const SizedBox(height: 10),
              Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

// ==========================================
// GESTION DES MEMBRES (AVEC APPROBATION RBAC)
// ==========================================
class Members extends StatefulWidget {
  final String userRole;
  const Members({super.key, required this.userRole});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  List<dynamic> items = [];
  bool loading = true;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await ApiClient().get('/api/v1/members');
      if (mounted) {
        setState(() {
          items = d is List ? d : (d['items'] ?? []);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
      msg('Erreur lors du chargement des membres.');
    }
  }

  Future<void> updateMemberStatus(String id, String newStatus) async {
    try {
      await ApiClient().put('/api/v1/members/$id', {'status': newStatus});
      msg('Statut mis à jour ($newStatus)');
      load();
    } catch (_) {
      msg('Échec de la mise à jour du statut.');
    }
  }

  void showAddMemberDialog() {
    final fn = TextEditingController();
    final ln = TextEditingController();
    final em = TextEditingController();
    final ph = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un Membre'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fn, decoration: const InputDecoration(labelText: 'Prénom')),
              TextField(controller: ln, decoration: const InputDecoration(labelText: 'Nom')),
              TextField(controller: em, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: ph, decoration: const InputDecoration(labelText: 'Téléphone')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (fn.text.isEmpty || ln.text.isEmpty) return;
              try {
                await ApiClient().post('/api/v1/members', {
                  'first_name': fn.text.trim(),
                  'last_name': ln.text.trim(),
                  'email': em.text.trim(),
                  'phone': ph.text.trim(),
                  'status': 'approved',
                });
                if (mounted) Navigator.pop(ctx);
                load();
              } catch (_) {
                msg('Erreur lors de l\'ajout du membre.');
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = RoleHelper.canAddMembers(widget.userRole);
    final canApprove = RoleHelper.canApproveMembers(widget.userRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres'),
        actions: [
          if (canAdd)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: showAddMemberDialog,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Aucun membre disponible.'))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final m = Map<String, dynamic>.from(items[i]);
                      final n = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                      final status = m['status']?.toString() ?? 'approved';
                      
                      // Gestion de plusieurs fonctions
                      String rolesList = '';
                      if (m['roles'] is List) {
                        rolesList = (m['roles'] as List)
                            .map((e) => e is Map ? (e['name'] ?? '') : e.toString())
                            .where((s) => s.isNotEmpty)
                            .join(', ');
                      } else {
                        rolesList = m['role']?.toString() ?? '';
                      }

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(n.isEmpty ? '?' : n[0])),
                          title: Text(n.isEmpty ? 'Membre' : n),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m['phone'] ?? ''} ${m['email'] != null ? '• ${m['email']}' : ''}'),
                              if (rolesList.isNotEmpty)
                                Text('Fonctions: $rolesList', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Statut: $status', style: TextStyle(color: status == 'pending' ? Colors.orange : Colors.green)),
                            ],
                          ),
                          trailing: canApprove && status == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => updateMemberStatus(m['id'].toString(), 'approved'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => updateMemberStatus(m['id'].toString(), 'rejected'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ==========================================
// CRUD ÉGLISES & ANNEXES
// ==========================================
class Churches extends StatefulWidget {
  final String userRole;
  const Churches({super.key, required this.userRole});

  @override
  State<Churches> createState() => _ChurchesState();
}

class _ChurchesState extends State<Churches> {
  List<dynamic> items = [];
  bool loading = true;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await ApiClient().get('/api/v1/churches');
      if (mounted) {
        setState(() {
          items = d is List ? d : (d['items'] ?? []);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
      msg('Erreur lors du chargement des églises.');
    }
  }

  void showChurchDialog([Map<String, dynamic>? church]) {
    final isEdit = church != null;
    final nameCtrl = TextEditingController(text: church?['name']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: church?['city']?.toString() ?? '');
    final countryCtrl = TextEditingController(text: church?['country']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Modifier Église' : 'Ajouter une Église'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de l\'église')),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Ville')),
              TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'Pays')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final payload = {
                'name': nameCtrl.text.trim(),
                'city': cityCtrl.text.trim(),
                'country': countryCtrl.text.trim(),
              };

              try {
                if (isEdit) {
                  await ApiClient().put('/api/v1/churches/${church['id']}', payload);
                  msg('Église modifiée.');
                } else {
                  await ApiClient().post('/api/v1/churches', payload);
                  msg('Église ajoutée.');
                }
                if (mounted) Navigator.pop(ctx);
                load();
              } catch (_) {
                msg('Erreur lors de l\'enregistrement.');
              }
            },
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteChurch(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette église ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient().delete('/api/v1/churches/$id');
        msg('Église supprimée.');
        load();
      } catch (_) {
        msg('Échec de la suppression.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = RoleHelper.canManageChurch(widget.userRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Églises & annexes'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => showChurchDialog(),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Aucune église disponible.'))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final m = Map<String, dynamic>.from(items[i]);
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.church)),
                          title: Text(m['name']?.toString() ?? 'Église'),
                          subtitle: Text('${m['city'] ?? ''} ${m['country'] != null ? '• ${m['country']}' : ''}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChurchDetailScreen(church: m, userRole: widget.userRole),
                              ),
                            ).then((_) => load());
                          },
                          trailing: canManage
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => showChurchDialog(m),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => deleteChurch(m['id'].toString()),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ==========================================
// DÉTAIL ÉGLISE & GESTION DES FONCTIONS (CHURCH_ROLES)
// ==========================================
class ChurchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> church;
  final String userRole;

  const ChurchDetailScreen({super.key, required this.church, required this.userRole});

  @override
  State<ChurchDetailScreen> createState() => _ChurchDetailScreenState();
}

class _ChurchDetailScreenState extends State<ChurchDetailScreen> {
  List<dynamic> roles = [];
  bool loading = true;

  void msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void initState() {
    super.initState();
    loadRoles();
  }

  Future<void> loadRoles() async {
    try {
      final d = await ApiClient().get('/api/v1/churches/${widget.church['id']}/roles');
      if (mounted) {
        setState(() {
          roles = d is List ? d : (d['items'] ?? []);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
      msg('Erreur lors de la récupération des fonctions.');
    }
  }

  void showAddRoleDialog() {
    final roleNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une Fonction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roleNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom (ex: Chorale, Comité, Groupe de prière)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (roleNameCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient().post('/api/v1/churches/${widget.church['id']}/roles', {
                  'name': roleNameCtrl.text.trim(),
                });
                msg('Fonction ajoutée.');
                if (mounted) Navigator.pop(ctx);
                loadRoles();
              } catch (_) {
                msg('Erreur lors de l\'ajout de la fonction.');
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = RoleHelper.canEditFunction(widget.userRole);

    return Scaffold(
      appBar: AppBar(title: Text(widget.church['name']?.toString() ?? 'Détail Église')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_city, size: 36),
                title: Text(widget.church['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Ville: ${widget.church['city'] ?? '-'} | Pays: ${widget.church['country'] ?? '-'}'),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fonctions / Groupes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (canEdit)
                  ElevatedButton.icon(
                    onPressed: showAddRoleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter Fonction'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : roles.isEmpty
                      ? const Center(child: Text('Aucune fonction enregistrée pour cette église.'))
                      : ListView.builder(
                          itemCount: roles.length,
                          itemBuilder: (_, i) {
                            final r = Map<String, dynamic>.from(roles[i]);
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.group),
                                title: Text(r['name']?.toString() ?? 'Fonction'),
                                subtitle: Text(r['description']?.toString() ?? 'Fonction de l\'église'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROFIL UTILISATEUR
// ==========================================
class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, String> u = {};

  @override
  void initState() {
    super.initState();
    Session.user().then((v) {
      if (mounted) setState(() => u = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
        const SizedBox(height: 14),
        Center(
          child: Text(
            u['name'] ?? 'Membre ELIM',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('Rôle'),
            subtitle: Text(u['role'] ?? 'MEMBER'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(u['email'] ?? ''),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// COMPOSANT GÉNÉRIQUE
// ==========================================
class Generic extends StatelessWidget {
  final String title;
  final IconData icon;

  const Generic({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Module préparé pour être alimenté par les données et permissions ELIM du serveur.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
