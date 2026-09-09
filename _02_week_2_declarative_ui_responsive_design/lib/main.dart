import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(const AcademicOverviewApp());

class AcademicOverviewApp extends StatefulWidget {
  const AcademicOverviewApp({super.key});

  @override
  State<AcademicOverviewApp> createState() => _AcademicOverviewAppState();
}

class _AcademicOverviewAppState extends State<AcademicOverviewApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academic Overview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: AcademicDashboardPage(
        isDark: isDark,
        onDarkChanged: (value) => setState(() => isDark = value),
      ),
    );
  }
}

class AcademicDashboardPage extends StatelessWidget {
  const AcademicDashboardPage({
    required this.isDark,
    required this.onDarkChanged,
    super.key,
  });

  final bool isDark;
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Overview'),
        actions: [
          Row(
            children: [
              Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              const SizedBox(width: 8),
              // Memenuhi Ketentuan: Label Aksesibilitas
              Semantics(
                label: 'Tombol ganti tema gelap atau terang',
                child: CupertinoSwitch(
                  value: isDark,
                  onChanged: onDarkChanged,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      // Menggunakan SingleChildScrollView agar bisa di-scroll jika layar terlalu kecil
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Memenuhi Ketentuan: Header Profil (Row, Column, Expanded, Container)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.person,
                        size: 35, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOKHAMAD RIZKI HADIONO SINGGIH',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                        Text(
                          'TI2F - PWL',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 2. Memenuhi Ketentuan: Layout Responsif 1 atau 2 Kolom
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                return GridView.count(
                  shrinkWrap: true, // Agar GridView tidak error di dalam ScrollView
                  physics: const NeverScrollableScrollPhysics(), // Scroll diatur oleh SingleChildScrollView
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: columns == 1 ? 3.0 : 2.5, // Menyesuaikan tinggi kartu
                  children: const [
                    // 3. Memenuhi Ketentuan: Minimal 4 Kartu Informasi
                    DashboardCard(title: 'Tugas Selesai', value: '12'),
                    DashboardCard(title: 'Kehadiran', value: '95%'),
                    DashboardCard(title: 'SKS Ditempuh', value: '45'),
                    DashboardCard(title: 'IPK Sementara', value: '3.85'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({required this.title, required this.value, super.key});
  
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Memenuhi Ketentuan: Label aksesibilitas pada informasi penting
    return Semantics(
      label: 'Kartu informasi $title dengan nilai $value',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title, 
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                value, 
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}