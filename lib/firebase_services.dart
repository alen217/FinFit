import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "535390883975-b25kgfeovprmupmsat050l7ptbq5eknc.apps.googleusercontent.com", // 🔥 Replace with actual Web Client ID
  );

  /// ✅ **Sign Up & Send Email Verification**
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      User? user = credential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification(); // 🔥 Send verification email
      }

      return user;
    } 
    on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("This email is already registered. Please log in.");
      } else if (e.code == 'weak-password') {
        throw Exception("Password is too weak. Try a stronger password.");
      } else {
        throw Exception("Sign-up failed. Please try again.");
      }
    }
  }

  /// ✅ **Login (Block Unverified Users)**
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      User? user = credential.user;
      if (user != null && !user.emailVerified) {
        await _auth.signOut(); // 🔴 Prevent login
        throw Exception("Please verify your email before signing in.");
      }

      return user;
    } 
    on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("No user found with this email.");
      } else if (e.code == 'wrong-password') {
        throw Exception("Incorrect password. Please try again.");
      } else {
        throw Exception("Login failed. Please try again.");
      }
    }
  }

  /// ✅ **Google Sign-In**
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception("Google sign-in canceled.");
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      return userCredential.user;
    } 
    catch (e) {
      print("Google Sign-In Error: $e");
      throw Exception("Google Sign-In failed. Please try again.");
    }
  }
  Future<void> signOutUser() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
