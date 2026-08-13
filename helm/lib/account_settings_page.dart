import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/user_avatar.dart';
import 'services/supabase_service.dart';
import 'models/hive_models.dart' as hive_model;

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.userMetadata?['full_name'] ?? '';
      _avatarUrl = user.userMetadata?['avatar_url'];
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    // Auto-compress on device before upload
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70, // Balanced quality and file size
    );

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      // Enforce standardized path to overwrite and save space
      const String fileName = 'profile.jpg';
      
      final String? newUrl = await _supabaseService.uploadAvatar(bytes, fileName);
      
      if (newUrl != null && mounted) {
        setState(() {
          _avatarUrl = newUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => v != newPasswordController.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: dialogLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => dialogLoading = true);
                  try {
                    await _supabase.auth.updateUser(UserAttributes(password: newPasswordController.text.trim()));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                    }
                  } finally {
                    setDialogState(() => dialogLoading = false);
                  }
                }
              },
              child: dialogLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is permanent. All your personal tasks will be deleted. Community ownership will be transferred to other members.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final ownedCommunities = await _supabase.from('communities').select('id, name').eq('creator_id', userId);
      
      for (var community in ownedCommunities) {
        final String commId = community['id'];
        
        final members = await _supabase
            .from('community_members')
            .select('user_id, role, created_at')
            .eq('community_id', commId)
            .neq('user_id', userId)
            .order('role', ascending: true) 
            .order('created_at', ascending: true);

        if (members.isEmpty) {
          await _supabase.from('communities').delete().eq('id', commId);
        } else {
          final nextOwner = members.first;
          final nextOwnerId = nextOwner['user_id'];
          
          if (nextOwner['role'] != 'admin' && nextOwner['role'] != 'owner') {
            await _supabase.from('community_members').update({'role': 'admin'}).eq('community_id', commId).eq('user_id', nextOwnerId);
          }
          await _supabase.from('communities').update({'creator_id': nextOwnerId}).eq('id', commId);
        }
      }

      await _supabase.from('tasks').delete().eq('user_id', userId);
      await Hive.box<hive_model.Task>('tasks').clear();
      final settingsBox = Hive.box<hive_model.Settings>('settings');
      await settingsBox.clear();
      await _supabase.rpc('delete_user_account');
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (intent) => Navigator.pop(context)),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              title: const Text('Account Settings'),
              actions: [
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _updateProfile,
                    tooltip: 'Save Profile',
                  ),
              ],
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            UserAvatar(
                              fullName: _nameController.text.isNotEmpty ? _nameController.text : 'User',
                              avatarUrl: _avatarUrl,
                              radius: 50,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.surface, width: 2),
                                  ),
                                  child: Icon(Icons.camera_alt_rounded, size: 18, color: colorScheme.onPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Personal Information', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                        onFieldSubmitted: (_) => _updateProfile(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email Address (Read-only)', border: OutlineInputBorder()),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 32),
                      Text('Security', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorScheme.outlineVariant)),
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Danger Zone', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Account'),
                          onPressed: _handleDeleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
