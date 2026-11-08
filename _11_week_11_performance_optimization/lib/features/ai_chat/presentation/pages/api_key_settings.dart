import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';

class ApiKeySettingsPage extends ConsumerStatefulWidget {
  const ApiKeySettingsPage({super.key});

  @override
  ConsumerState<ApiKeySettingsPage> createState() => _ApiKeySettingsPageState();
}

class _ApiKeySettingsPageState extends ConsumerState<ApiKeySettingsPage> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _currentKeyPreview;

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    setState(() => _isLoading = true);
    final repo = ref.read(aiRepositoryProvider);
    final key = await repo.getApiKey();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (key != null && key.isNotEmpty) {
          _currentKeyPreview = key.length > 8
              ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
              : 'Terpasang';
        } else {
          _currentKeyPreview = null;
        }
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(aiRepositoryProvider);
    await repo.saveApiKey(key);
    ref.invalidate(hasApiKeyProvider);

    if (mounted) {
      setState(() => _isLoading = false);
      _controller.clear();
      _loadExistingKey();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key berhasil disimpan di Secure Storage!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeKey() async {
    setState(() => _isLoading = true);
    final repo = ref.read(aiRepositoryProvider);
    await repo.removeApiKey();
    ref.invalidate(hasApiKeyProvider);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentKeyPreview = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key telah dihapus.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Gemini API Key'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer.withAlpha(70),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Penyimpanan Aman (Secure Storage)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'API Key disimpan terenkripsi di perangkat menggunakan flutter_secure_storage '
                          'dan tidak pernah disimpan secara hardcoded di kode sumber aplikasi.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_currentKeyPreview != null) ...[
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: const Text('Status API Key'),
                    subtitle: Text('Tersimpan: $_currentKeyPreview'),
                    trailing: TextButton.icon(
                      onPressed: _removeKey,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Google Gemini API Key',
                    hintText: 'Masukkan kunci AI Studio Anda (AIzaSy...)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveKey,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan API Key'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cara Mendapatkan Gemini API Key:\n'
                  '1. Kunjungi https://aistudio.google.com/app/apikey\n'
                  '2. Login dengan akun Google Anda\n'
                  '3. Buat API Key baru (Create API Key)\n'
                  '4. Copy lalu paste ke kolom di atas',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }
}
