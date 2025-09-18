import 'package:flutter/material.dart';
import 'package:gamewala_repairs/screens/add_repair_screen.dart';
import 'package:gamewala_repairs/screens/all_repairs_screen.dart';
import 'package:gamewala_repairs/screens/dashboard_screen.dart';
import 'package:gamewala_repairs/screens/login_screen.dart';
import 'package:gamewala_repairs/screens/masters_screen.dart';
import 'package:gamewala_repairs/screens/search_repair_screen.dart';
import 'package:gamewala_repairs/screens/update_status_screen.dart';
import 'package:gamewala_repairs/services/api_service.dart';

void main() {
  runApp(const GameWalaApp());
}

class GameWalaApp extends StatefulWidget {
  const GameWalaApp({super.key});

  @override
  State<GameWalaApp> createState() => _GameWalaAppState();
}

class _GameWalaAppState extends State<GameWalaApp> {
  String? _role; // 'Owner' or 'Employee'
  String? _actorEmail; // user email for RBAC
  String? _ownerEmail; // Owner's email for Google Sheets
  // Deployed Apps Script Web App URL
  final String _baseUrl = 'https://script.google.com/macros/s/AKfycbyLXkyAcKhqWX_eTmDioTJFErNyV28KSwB8MnaVsQbvZMcDJkzxRuKK8PqPaa0E0oHC/exec';

  ApiService get _api => ApiService(baseUrl: _baseUrl, ownerEmail: _ownerEmail, actorEmail: _actorEmail);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameWala Repairs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _role == null
          ? LoginScreen(onLogin: (role, actorEmail, ownerEmail) => setState(() { _role = role; _actorEmail = actorEmail; _ownerEmail = ownerEmail; }), api: _api)
          : _Home(role: _role!, actorEmail: _actorEmail, ownerEmail: _ownerEmail, api: _api, onLogout: () => setState(() { _role = null; _actorEmail = null; _ownerEmail = null; })),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.role, required this.actorEmail, required this.ownerEmail, required this.api, required this.onLogout});
  final String role;
  final String? actorEmail;
  final String? ownerEmail;
  final ApiService api;
  final VoidCallback onLogout;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _tab = 0;

  bool get isOwner => widget.role == 'Owner';

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        role: widget.role,
        onNavigate: (route) {
          switch (route) {
            case '/add':
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddRepairScreen(api: widget.api)));
              break;
            case '/update':
              Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateStatusScreen(api: widget.api, role: widget.role, actorEmail: widget.actorEmail)));
              break;
            case '/search':
              Navigator.push(context, MaterialPageRoute(builder: (_) => SearchRepairScreen(api: widget.api)));
              break;
            case '/all':
              Navigator.push(context, MaterialPageRoute(builder: (_) => AllRepairsScreen(api: widget.api)));
              break;
            case '/masters':
              Navigator.push(context, MaterialPageRoute(builder: (_) => MastersScreen(api: widget.api)));
              break;
          }
        },
      ),
      AllRepairsScreen(api: widget.api),
      SearchRepairScreen(api: widget.api),
    ];

    final tabs = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.list), label: 'All Repairs'),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    ];

    final navIndex = _tab.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('GameWala Repairs - ${widget.role}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: pages[navIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        destinations: tabs,
        onDestinationSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
