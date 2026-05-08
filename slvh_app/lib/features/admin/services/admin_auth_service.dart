import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email & password (admin)
  Future<User?> signInWithEmail({
    required String email,
    required String password,
    required Function(String errorMessage) onError,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Check if user has admin role
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          onError('User document not found');
          await _auth.signOut();
          return null;
        }

        String? role = userDoc.get('role') as String?;
        if (role != 'admin') {
          onError('You do not have admin access');
          await _auth.signOut();
          return null;
        }

        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        onError('Email not found');
      } else if (e.code == 'wrong-password') {
        onError('Incorrect password');
      } else if (e.code == 'invalid-email') {
        onError('Invalid email address');
      } else {
        onError(e.message ?? 'Authentication failed');
      }
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc.get('role') == 'admin';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
