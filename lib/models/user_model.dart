import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String sport;
  final String gender;
  final List<String> events;
  final DateTime dob;
  final bool emailVerified;
  final bool signupCompleted;
  final DateTime createdAt;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.sport,
    required this.gender,
    required this.events,
    required this.dob,
    required this.emailVerified,
    required this.signupCompleted,
    required this.createdAt,
    this.fcmToken,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'Athlete',
      sport: data['sport'] ?? '',
      gender: data['gender'] ?? '',
      events: List<String>.from(data['events'] ?? const []),
      dob: DateTime.parse(data['dob'] ?? DateTime.now().toIso8601String()),
      emailVerified: data['emailVerified'] ?? false,
      signupCompleted: data['signupCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'sport': sport,
      'gender': gender,
      'events': events,
      'dob': dob.toIso8601String(),
      'emailVerified': emailVerified,
      'signupCompleted': signupCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? sport,
    String? gender,
    List<String>? events,
    DateTime? dob,
    bool? emailVerified,
    bool? signupCompleted,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      sport: sport ?? this.sport,
      gender: gender ?? this.gender,
      events: events ?? this.events,
      dob: dob ?? this.dob,
      emailVerified: emailVerified ?? this.emailVerified,
      signupCompleted: signupCompleted ?? this.signupCompleted,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}