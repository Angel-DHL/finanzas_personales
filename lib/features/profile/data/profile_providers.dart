import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final uidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(firestoreProvider));
});

final profileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  final svc = ref.read(profileServiceProvider);
  return svc.watchProfile(uid);
});
