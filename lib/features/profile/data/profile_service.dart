import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  ProfileService(this._fs);
  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _fs.collection('users').doc(uid);

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((s) => s.data());
    // OJO: si el doc no existe, s.data() será null (normal)
  }

  Future<void> ensureProfileExists(String uid) async {
  final ref = _doc(uid);

  try {
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false,
        'savingsCents': 0,
        'currency': 'MXN',
      }, SetOptions(merge: true));
    }
  } on FirebaseException catch (e) {
    // Si cerraste sesión en medio, esto es normal: no hay permisos ya
    if (e.code == 'permission-denied') return;
    rethrow;
  }
}

  Future<void> setOnboarded(String uid, bool value) async {
    await _doc(uid).set({
      'onboarded': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setSavings(String uid, int cents) async {
    await _doc(uid).set({
      'savingsCents': cents,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> adjustSavings(String uid, int deltaCents) async {
    final ref = _doc(uid);

    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['savingsCents'] as int?) ?? 0;
      tx.set(ref, {
        'savingsCents': current + deltaCents,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
