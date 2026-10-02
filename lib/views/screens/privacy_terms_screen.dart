import 'package:flutter/material.dart';

/// Displays the privacy policy and terms of service for the Athlos app.
class PrivacyTermsPage extends StatelessWidget {
  const PrivacyTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = screenWidth < 600 ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Privacy & Terms',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withValues(alpha: 0.3),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Column(
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),
                _buildPrivacyPolicyCard(),
                const SizedBox(height: 24),
                _buildTermsConditionsCard(),
                const SizedBox(height: 24),
                _buildDataSharingCard(),
                const SizedBox(height: 32),
                _buildFooterCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.security,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Athlos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your privacy and security matter to us',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyCard() {
    return _buildSectionCard(
      icon: Icons.privacy_tip,
      iconColor: Colors.green,
      title: 'Privacy Policy',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Athlos is an athletics team management platform for athletes, coaches, '
            'captains, and administrators. This policy describes what information we '
            'collect, how we use it, and who can access it.',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          _buildBulletPoint(
            'Account information: name, email, date of birth, gender, sport, and event preferences.',
            Icons.person_outline,
            Colors.blue,
          ),
          _buildBulletPoint(
            'Team data: attendance records, absence appeals, injuries, and training sessions you participate in.',
            Icons.groups_outlined,
            Colors.purple,
          ),
          _buildBulletPoint(
            'Device data: a push notification token so we can send session reminders and coach announcements.',
            Icons.notifications_outlined,
            Colors.orange,
          ),
          _buildBulletPoint(
            'We never sell your data to third parties, and we do not use your information for advertising.',
            Icons.block,
            Colors.red,
          ),
          _buildBulletPoint(
            'You may request deletion of your account and associated data at any time by contacting your administrator.',
            Icons.delete_outline,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsConditionsCard() {
    return _buildSectionCard(
      icon: Icons.gavel,
      iconColor: Colors.orange,
      title: 'Terms & Conditions',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By using Athlos, you agree to:',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _buildNumberedPoint(
            1,
            'Provide accurate registration and profile information, and keep it up to date.',
            Colors.blue,
          ),
          _buildNumberedPoint(
            2,
            'Use the platform respectfully. Attendance, appeals, and injury reports must reflect reality.',
            Colors.green,
          ),
          _buildNumberedPoint(
            3,
            'Not misuse access to other users\' data. Your permissions are defined by your role.',
            Colors.orange,
          ),
          _buildNumberedPoint(
            4,
            'Understand that Athlos does not provide medical advice. Always consult a qualified professional for health decisions.',
            Colors.red,
          ),
          const SizedBox(height: 20),
          _buildInfoBox(
            'Roles and permissions: Athletes see their own data. Coaches see athletes in their sport. '
            'Captains see their assigned squad. Administrators see system-wide data for monitoring and support.',
          ),
        ],
      ),
    );
  }

  Widget _buildDataSharingCard() {
    return _buildSectionCard(
      icon: Icons.share_outlined,
      iconColor: Colors.blueGrey,
      title: 'Data Storage & Sharing',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Athlos uses Google Firebase to store your data securely. Information is transmitted over HTTPS '
            'and stored in Firebase Authentication, Cloud Firestore, and Cloud Messaging.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          _buildBulletPoint(
            'Your data is visible only to people whose role grants them access.',
            Icons.lock_outline,
            Colors.blue,
          ),
          _buildBulletPoint(
            'Push notifications are routed through Firebase Cloud Messaging.',
            Icons.cloud_outlined,
            Colors.purple,
          ),
          _buildBulletPoint(
            'Data is retained until your account is deleted or your administrator removes it.',
            Icons.schedule_outlined,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint(int number, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.amber, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.amber[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            'Last Updated',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'October 2026',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}