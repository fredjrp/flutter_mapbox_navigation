import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AppUser? _appUser;
  AppUser? get appUser => _appUser;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ─── Email & Password ────────────────────────────────────────────────────────

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user!.updateDisplayName(name);
      await _createUserRecord(cred.user!, name);
      await _loadAppUser(cred.user!.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _loadAppUser(cred.user!.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      // Create user record if first login
      final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
      if (!userDoc.exists) {
        await _createUserRecord(
            cred.user!, cred.user!.displayName ?? 'User');
      }
      await _loadAppUser(cred.user!.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _appUser = null;
    notifyListeners();
  }

  // ─── Password Reset ──────────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _createUserRecord(User user, String name) async {
    final appUser = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: name,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(appUser.toFirestore());
  }

  Future<void> _loadAppUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      _appUser = AppUser.fromFirestore(doc);
      notifyListeners();
    }
  }

  Future<void> loadCurrentUser() async {
    if (_auth.currentUser != null) {
      await _loadAppUser(_auth.currentUser!.uid);
    }
  }

  void _setLoading(bool val) {
    _loading = val;
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
