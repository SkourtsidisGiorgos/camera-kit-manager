import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import '../../../infastructure/services/backup_service.dart';
import '../../../infastructure/services/google_drive_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/ui_components.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _backupService = BackupService();
  final _driveService = GoogleDriveService();

  bool _isLoading = false;
  bool _includeImages = true;
  List<drive.File> _backupFiles = [];
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _refreshDriveFiles();
  }

  // Display success message
  void _showSuccess(String message) {
    setState(() {
      _errorMessage = null;
      _successMessage = message;
    });
  }

  // Display error message
  void _showError(String message) {
    setState(() {
      _successMessage = null;
      _errorMessage = message;
    });
  }

  // Handle async operations with loading state
  Future<void> _performOperation(
    Future<void> Function() operation,
    String errorPrefix,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await operation();
    } catch (e) {
      _showError('$errorPrefix: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDriveFiles() async {
    if (!_driveService.isSignedIn) return;

    _performOperation(() async {
      final files = await _driveService.getBackupFiles();
      setState(() {
        _backupFiles = files;
      });
    }, 'Failed to load backup files');
  }

  Future<void> _signInToGoogleDrive() async {
    await _performOperation(() async {
      final success = await _driveService.signIn();
      if (success) {
        _showSuccess('Signed in successfully to Google Drive');
        await _refreshDriveFiles();
      } else {
        _showError('Google Drive sign-in was canceled');
      }
    }, 'Failed to sign in to Google Drive');
  }

  Future<void> _signOutFromGoogleDrive() async {
    await _performOperation(() async {
      await _driveService.signOut();
      setState(() {
        _backupFiles = [];
        _showSuccess('Signed out from Google Drive');
      });
    }, 'Failed to sign out');
  }

  Future<void> _createBackup() async {
    await _performOperation(() async {
      final backupFile =
          await _backupService.createBackup(includeImages: _includeImages);
      _showSuccess('Backup created successfully');

      // Show options dialog
      if (!mounted) return;
      _showBackupOptionsDialog(backupFile);
    }, 'Failed to create backup');
  }

  void _showBackupOptionsDialog(File backupFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Created'),
        content: const Text('What would you like to do with this backup?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _shareBackup();
            },
            child: const Text('Share'),
          ),
          if (_driveService.isSignedIn)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadBackupToDrive(backupFile);
              },
              child: const Text('Save to Drive'),
            ),
        ],
      ),
    );
  }

  Future<void> _shareBackup() async {
    await _performOperation(() async {
      await _backupService.shareBackup(includeImages: _includeImages);
    }, 'Failed to share backup');
  }

  Future<void> _uploadBackupToDrive(File backupFile) async {
    if (!_driveService.isSignedIn) {
      await _signInToGoogleDrive();
      if (!_driveService.isSignedIn) return;
    }

    await _performOperation(() async {
      final fileName = backupFile.path.split('/').last;
      final fileId = await _driveService.uploadBackup(backupFile, fileName);

      if (fileId != null) {
        _showSuccess('Backup uploaded to Google Drive successfully');
        await _refreshDriveFiles();
      } else {
        _showError('Failed to upload backup to Google Drive');
      }
    }, 'Failed to upload to Google Drive');
  }

  Future<void> _importBackup() async {
    await _performOperation(() async {
      // Show warning dialog
      if (!mounted) return;
      final proceedWithImport = await _showImportWarningDialog();
      if (!proceedWithImport) {
        setState(() => _isLoading = false);
        return;
      }

      final backupFile = await _backupService.pickBackupFile();
      if (backupFile == null) {
        _showError('No backup file selected');
        return;
      }

      final success = await _backupService.restoreFromBackup(backupFile);
      if (success) {
        _showSuccess('Backup restored successfully');
      } else {
        _showError('Failed to restore backup');
      }
    }, 'Failed to import backup');
  }

  Future<void> _restoreFromDrive(drive.File driveFile) async {
    await _performOperation(() async {
      // Show warning dialog
      if (!mounted) return;
      final proceedWithImport = await _showImportWarningDialog();
      if (!proceedWithImport) {
        setState(() => _isLoading = false);
        return;
      }

      final localFile = await _driveService.downloadBackup(driveFile.id!);
      if (localFile == null) {
        _showError('Failed to download backup file');
        return;
      }

      final success = await _backupService.restoreFromBackup(localFile);
      if (success) {
        _showSuccess('Backup restored successfully');
      } else {
        _showError('Failed to restore backup');
      }
    }, 'Failed to restore from Google Drive');
  }

  Future<void> _deleteFromDrive(drive.File driveFile) async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Backup',
      message:
          'Are you sure you want to delete "${driveFile.name}" from Google Drive?',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (!confirm) return;

    await _performOperation(() async {
      final success = await _driveService.deleteFile(driveFile.id!);
      if (success) {
        _showSuccess('Backup deleted successfully');
        await _refreshDriveFiles();
      } else {
        _showError('Failed to delete backup');
      }
    }, 'Failed to delete from Google Drive');
  }

  Future<bool> _showImportWarningDialog() async {
    return await ConfirmationDialog.show(
      context: context,
      title: 'Warning',
      message:
          'Importing a backup will REPLACE ALL CURRENT DATA. This cannot be undone.\n\nDo you want to continue?',
      confirmText: 'Import & Replace Data',
      isDangerous: true,
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error/Success Messages
                  if (_errorMessage != null)
                    _buildMessageCard(_errorMessage!, Colors.red.shade100,
                        Colors.red.shade700, Icons.error_outline),

                  if (_successMessage != null)
                    _buildMessageCard(_successMessage!, Colors.green.shade100,
                        Colors.green.shade700, Icons.check_circle_outline),

                  // Local Backup Section
                  _buildLocalBackupCard(),

                  // Google Drive Section
                  _buildGoogleDriveCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildMessageCard(
      String message, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBackupCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Local Backup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Include images option (not available for web)
            if (!kIsWeb)
              SwitchListTile(
                title: const Text('Include Images'),
                subtitle: const Text(
                    'Backup will be larger but will include all photos'),
                value: _includeImages,
                onChanged: (value) {
                  setState(() {
                    _includeImages = value;
                  });
                },
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create Backup'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Backup'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _shareBackup,
              icon: const Icon(Icons.share),
              label: const Text('Share Backup'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleDriveCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Drive',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!_driveService.isSignedIn)
              _buildDriveSignInSection()
            else
              _buildDriveSignedInSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriveSignInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
            'Sign in to Google Drive to backup and sync your data across devices.'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _signInToGoogleDrive,
          icon: const Icon(Icons.login),
          label: const Text('Sign in to Google Drive'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
          ),
        ),
      ],
    );
  }

  Widget _buildDriveSignedInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.account_circle),
          ),
          title: Text(_driveService.userName),
          subtitle: Text(_driveService.userEmail),
          trailing: TextButton.icon(
            onPressed: _signOutFromGoogleDrive,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
          ),
        ),
        const Divider(),
        const Text(
          'Google Drive Backups',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_backupFiles.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No backups found in Google Drive'),
            ),
          )
        else
          _buildBackupFilesList(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _refreshDriveFiles,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupFilesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _backupFiles.length,
      itemBuilder: (context, index) {
        final file = _backupFiles[index];
        final fileName = file.name ?? 'Unnamed Backup';
        final modifiedTime = file.modifiedTime != null
            ? DateFormat('MMM d, yyyy h:mm a').format(file.modifiedTime!)
            : 'Unknown date';
        final fileSize = _formatFileSize(int.tryParse(file.size ?? '0'));

        return ListTile(
          title: Text(fileName),
          subtitle: Text('$modifiedTime • $fileSize'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionButton(
                icon: Icons.restore,
                onPressed: () => _restoreFromDrive(file),
                tooltip: 'Restore from this backup',
              ),
              ActionButton(
                icon: Icons.delete,
                onPressed: () => _deleteFromDrive(file),
                color: Colors.grey,
                tooltip: 'Delete this backup',
              ),
            ],
          ),
        );
      },
    );
  }
}
