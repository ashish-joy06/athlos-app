import 'package:athletix/components/achievements_box.dart';
import 'package:athletix/components/alertDialog_signOut_confitmation.dart';
import 'package:athletix/components/bottom_nav_bar.dart';
import 'package:athletix/components/notification_bell.dart';
import 'package:athletix/views/screens/announcements_inbox_screen.dart';
import 'package:athletix/views/screens/athlete/tournaments_screen.dart';
import 'package:athletix/views/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:athletix/views/screens/coach/make_announcement_screen.dart';
import 'package:athletix/views/screens/coach/team_injuries_screen.dart';

import 'admin_sessions_screen.dart';
import 'admin_users_screen.dart';
import 'admin_appeals_screen.dart';
import 'widgets/admin_activity_feed.dart';
import 'widgets/admin_attendance_chart.dart';
import 'widgets/admin_snapshot_grid.dart';

/// Admin dashboard — monitoring across the whole system.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  String? _selectedSport; // null = All Sports
  String _timeRange = 'week'; // 'week' | 'month' | 'all'

  List<String> _sports = const ['Athletics'];

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('sport', isNotEqualTo: '')
        .get();
    final set = <String>{};
    for (final d in snap.docs) {
      final s = (d.data()['sport'] ?? '').toString();
      if (s.isNotEmpty) set.add(s);
    }
    if (set.isEmpty) set.add('Athletics');
    if (!mounted) return;
    setState(() {
      _sports = set.toList()..sort();
    });
  }

  Duration? get _window {
    switch (_timeRange) {
      case 'week':
        return const Duration(days: 7);
      case 'month':
        return const Duration(days: 30);
      default:
        return null;
    }
  }

  DateTime? get _startTime {
    final w = _window;
    if (w == null) return null;
    return DateTime.now().subtract(w);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      const AdminSessionsScreen(),
      const TournamentsScreen(),
      const AdminUsersScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        role: 'Admin',
      ),
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),
                  _sectionHeader('System Snapshot'),
                  const SizedBox(height: 12),
                  AdminSnapshotGrid(
                    sportFilter: _selectedSport,
                    timeWindow: _window,
                    timeStart: _startTime,
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader('Attendance Trend'),
                  const SizedBox(height: 12),
                  AdminAttendanceChart(
                    sportFilter: _selectedSport,
                    timeWindow: _window,
                    timeStart: _startTime,
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader('Quick Actions'),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _sectionHeader('Recent Activity'),
                  const SizedBox(height: 12),
                  AdminActivityFeed(sportFilter: _selectedSport),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: AchievementsBox(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        const NotificationBell(),
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () async {
              await signoutConfirmation(context);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sign Out',
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final sportLabel = _selectedSport ?? 'All Sports';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _getMyDoc(),
            builder: (context, snap) {
              final name = snap.data?.data()?['name']?.toString() ?? 'Admin';
              return Text(
                '$greeting, $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Administrator • $sportLabel',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _sportDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _timeDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sportDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedSport,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: const TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Sports'),
            ),
            ..._sports.map(
              (s) => DropdownMenuItem<String?>(
                value: s,
                child: Text(s),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedSport = v),
        ),
      ),
    );
  }

  Widget _timeDropdown() {
    const labels = {'week': 'This Week', 'month': 'This Month', 'all': 'All Time'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeRange,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: const TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: labels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _timeRange = v);
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final items = [
      _QA(
        icon: Icons.people_alt_rounded,
        label: 'Users',
        color: const Color(0xFF667EEA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
          );
        },
      ),
      _QA(
  icon: Icons.inbox_rounded,
  label: 'Appeals',
  color: const Color(0xFFF59E0B),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminAppealsScreen(),
      ),
    );
  },
),
      _QA(
  icon: Icons.campaign_rounded,
  label: 'Announce',
  color: const Color(0xFF3B82F6),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MakeAnnouncementScreen(),
      ),
    );
  },
),
     _QA(
  icon: Icons.event_available_rounded,
  label: 'Sessions',
  color: const Color(0xFF10B981),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminSessionsScreen(),
      ),
    );
  },
),
      _QA(
  icon: Icons.healing_rounded,
  label: 'Injuries',
  color: const Color(0xFFEF4444),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeamInjuriesScreen(),
      ),
    );
  },
),
      _QA(
        icon: Icons.notifications_active_rounded,
        label: 'Inbox',
        color: const Color(0xFF14B8A6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementsInboxScreen(),
            ),
          );
        },
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: items.map((qa) => _buildQACard(qa)).toList(),
    );
  }

  Widget _buildQACard(_QA qa) {
    return GestureDetector(
      onTap: qa.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [qa.color, qa.color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: qa.color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(qa.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              qa.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getMyDoc() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QA({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}