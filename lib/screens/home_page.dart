// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<void> _initializationFuture;
  Stream<QuerySnapshot>? _articlesStream;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  String? token;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      debugPrint('Token retrieved from SharedPreferences: $token');

      if (token == null) {
        var user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          var id = const Uuid().v1();
          debugPrint('No existing user, creating a new user with ID: $id');
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: "$id@gma.ci", password: 'jjkwdw');
          user = FirebaseAuth.instance.currentUser;
        }

        if (user != null) {
          token = user.uid;
          debugPrint('New user created with UID: $token');
          await prefs.setString('token', token!);
        }
      }

      if (token != null) {
        _articlesStream = FirebaseFirestore.instance
            .collection(token!)
            .orderBy('timestamp', descending: true)
            .snapshots();
        debugPrint('Stream initialized for token: $token');
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
    }
  }

  Future<void> _addArticle(String title, String content) async {
    if (token != null) {
      await FirebaseFirestore.instance.collection(token!).add({
        "title": title,
        "content": content,
        "timestamp": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _updateArticle(
      String docId, String newTitle, String newContent) async {
    if (token != null) {
      await FirebaseFirestore.instance.collection(token!).doc(docId).update({
        "title": newTitle,
        "content": newContent,
      });
    }
  }

  Future<void> _deleteArticle(String docId) async {
    if (token != null) {
      await FirebaseFirestore.instance.collection(token!).doc(docId).delete();
    }
  }

  void _showAddArticleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Article"),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 10,
                  minLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await _addArticle(
                      titleController.text, contentController.text);
                  titleController.clear();
                  contentController.clear();
                  Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title cannot be empty')));
                }
              },
              child: const Text('Add Article'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateArticleDialog(
      String docId, String currentTitle, String currentContent) {
    titleController.text = currentTitle;
    contentController.text = currentContent;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Article"),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 10,
                  minLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  await _updateArticle(
                      docId, titleController.text, contentController.text);
                  titleController.clear();
                  contentController.clear();
                  Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title cannot be empty')));
                }
              },
              child: const Text('Update Article'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("TODO with Firebase"),
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Initialization error: ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(
              title: const Text("TODO with Firebase"),
              centerTitle: true,
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        debugPrint('Initialization complete, building UI');

        return Scaffold(
          appBar: AppBar(
            title: const Text("TODO with Firebase"),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _articlesStream,
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('Stream error: ${snapshot.error}');
                return const Text('Something went wrong');
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No articles found'));
              }

              return ListView(
                reverse: true,
                shrinkWrap: true,
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data =
                      document.data() as Map<String, dynamic>;
                  return Dismissible(
                    key: Key(document.id),
                    background: Container(
                      color: Colors.green,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        _showUpdateArticleDialog(
                            document.id, data['title'], data['content']);
                        return false; // Prevents dismissing
                      } else if (direction == DismissDirection.endToStart) {
                        await _deleteArticle(document.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${data['title']} deleted')),
                        );
                        return true; // Allows dismissing
                      }
                      return false;
                    },
                    child: ListTile(
                      title: Text(data['title']),
                      subtitle: Text(data['content']),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddArticleDialog,
            tooltip: 'Add Article',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
