import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final uidProvider = Provider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(FirebaseFirestore.instance);
});

final profileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.read(profileServiceProvider).watchProfile(uid);
});
