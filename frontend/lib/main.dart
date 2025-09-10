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
  String? _actorName; // Employee name for RBAC
  // Deployed Apps Script Web App URL
  final String _baseUrl = 'https://script.google.com/macros/s/AKfycbxihRlGkzFfMHZMv-K2ZA91pMXwzDKP_ydXDeZRKMiEds8XXuQsw7vIPbB1qa4rL0UV/exec';

  late final ApiService _api = ApiService(baseUrl: _baseUrl);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameWala Repairs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _role == null
          ? LoginScreen(onLogin: (role, actor) => setState(() { _role = role; _actorName = actor; }))
          : _Home(role: _role!, actorName: _actorName, api: _api),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.role, required this.actorName, required this.api});
  final String role;
  final String? actorName;
  final ApiService api;

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
              Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateStatusScreen(api: widget.api, role: widget.role, actorName: widget.actorName)));
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
      if (isOwner) AllRepairsScreen(api: widget.api),
      SearchRepairScreen(api: widget.api),
    ];

    final tabs = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
      if (isOwner) const NavigationDestination(icon: Icon(Icons.list), label: 'All Repairs'),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    ];

    final navIndex = _tab.clamp(0, tabs.length - 1);

    return Scaffold(
      body: pages[navIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        destinations: tabs,
        onDestinationSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
