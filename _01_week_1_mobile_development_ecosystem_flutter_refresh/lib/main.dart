import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Profil Mahasiswa')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school, size: 100, color: Colors.blue),
            Text('Politeknik Negeri Malang', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Icon(Icons.person, size: 80, color: Colors.green),
            Text('Mokhamad Rizki Hadiono Singgih', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('NIM : 2441070198', style: TextStyle(fontSize: 20)),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.book, color: Colors.orange),
                SizedBox(width: 8), 
                Text('Pemrograman Mobile — Minggu 1'),
              ],
            )
          ]),
        ),
      ),
    );
  }
}