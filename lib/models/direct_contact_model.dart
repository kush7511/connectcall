import 'package:cloud_firestore/cloud_firestore.dart';

class DirectContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DirectContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory DirectContactModel.fromMap(Map<String, dynamic> map, String id) {
    return DirectContactModel(
      id: id,
      name: map['name'] ?? 'Unknown',
      phoneNumber: map['phoneNumber'] ?? '',
      note: map['note'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'note': note,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
