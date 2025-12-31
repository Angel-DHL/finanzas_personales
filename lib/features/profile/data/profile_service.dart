import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  ProfileService(this._fs);
  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _fs.collection('users').doc(uid);

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snap) => snap.data());
  }

  Future<void> ensureProfileExists(String uid) async {
    final ref = _doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'savingsCents': null, // null = aún no configurado
        'onboarded': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setSavings(String uid, int savingsCents) async {
    await _doc(uid).set({
      'savingsCents': savingsCents,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setOnboarded(String uid, bool value) async {
    await _doc(uid).set({
      'onboarded': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> adjustSavings(String uid, int deltaCents) async {
    final ref = _doc(uid);
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final current = (data['savingsCents'] as int?) ?? 0;
      final next = current + deltaCents;
      tx.set(ref, {
        'savingsCents': next < 0 ? 0 : next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
