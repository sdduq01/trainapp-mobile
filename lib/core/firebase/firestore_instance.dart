import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

final db = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'trainapp',
);
