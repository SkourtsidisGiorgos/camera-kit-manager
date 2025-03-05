import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';

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

  Future<void> _refreshDriveFiles() async {
    if (!_driveService.isSignedIn) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final files = await _driveService.getBackupFiles();
      setState(() {
        _backupFiles = files;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load backup files: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInToGoogleDrive() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await _driveService.signIn();
      if (success) {
        setState(() {
          _successMessage = 'Signed in successfully to Google Drive';
        });
        _refreshDriveFiles();
      } else {
        setState(() {
          _errorMessage = 'Google Drive sign-in was canceled';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in to Google Drive: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOutFromGoogleDrive() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _driveService.signOut();
      setState(() {
        _backupFiles = [];
        _successMessage = 'Signed out from Google Drive';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign out: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final backupFile =
          await _backupService.createBackup(includeImages: _includeImages);
      setState(() {
        _successMessage = 'Backup created successfully';
      });

      // Show options dialog
      if (!mounted) return;
      _showBackupOptionsDialog(backupFile);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create backup: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _backupService.shareBackup(includeImages: _includeImages);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to share backup: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadBackupToDrive(File backupFile) async {
    if (!_driveService.isSignedIn) {
      await _signInToGoogleDrive();
      if (!_driveService.isSignedIn) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final fileName = backupFile.path.split('/').last;
      final fileId = await _driveService.uploadBackup(backupFile, fileName);

      if (fileId != null) {
        setState(() {
          _successMessage = 'Backup uploaded to Google Drive successfully';
        });
        _refreshDriveFiles();
      } else {
        setState(() {
          _errorMessage = 'Failed to upload backup to Google Drive';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload to Google Drive: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Show warning dialog
      if (!mounted) return;
      final proceedWithImport = await _showImportWarningDialog();
      if (!proceedWithImport) {
        setState(() => _isLoading = false);
        return;
      }

      final backupFile = await _backupService.pickBackupFile();
      if (backupFile == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No backup file selected';
        });
        return;
      }

      final success = await _backupService.restoreFromBackup(backupFile);
      if (success) {
        setState(() {
          _successMessage = 'Backup restored successfully';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to restore backup';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to import backup: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreFromDrive(drive.File driveFile) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Show warning dialog
      if (!mounted) return;
      final proceedWithImport = await _showImportWarningDialog();
      if (!proceedWithImport) {
        setState(() => _isLoading = false);
        return;
      }

      final localFile = await _driveService.downloadBackup(driveFile.id!);
      if (localFile == null) {
        setState(() {
          _errorMessage = 'Failed to download backup file';
        });
        return;
      }

      final success = await _backupService.restoreFromBackup(localFile);
      if (success) {
        setState(() {
          _successMessage = 'Backup restored successfully';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to restore backup';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to restore from Google Drive: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFromDrive(drive.File driveFile) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text(
            'Are you sure you want to delete "${driveFile.name}" from Google Drive?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await _driveService.deleteFile(driveFile.id!);
      if (success) {
        setState(() {
          _successMessage = 'Backup deleted successfully';
        });
        _refreshDriveFiles();
      } else {
        setState(() {
          _errorMessage = 'Failed to delete backup';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete from Google Drive: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showImportWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Warning'),
            content: const Text(
              'Importing a backup will REPLACE ALL CURRENT DATA. This cannot be undone.\n\nDo you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Import & Replace Data'),
              ),
            ],
          ),
        ) ??
        false;
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error/Success Messages
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Local Backup Section
                  Card(
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
                  ),

                  // Google Drive Section
                  Card(
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
                          if (!_driveService.isSignedIn) ...[
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
                          ] else ...[
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
                            if (_backupFiles.isEmpty) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child:
                                      Text('No backups found in Google Drive'),
                                ),
                              ),
                            ] else ...[
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _backupFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _backupFiles[index];
                                  final fileName =
                                      file.name ?? 'Unnamed Backup';
                                  final modifiedTime = file.modifiedTime != null
                                      ? DateFormat('MMM d, yyyy h:mm a')
                                          .format(file.modifiedTime!)
                                      : 'Unknown date';
                                  final fileSize = _formatFileSize(
                                      int.tryParse(file.size ?? '0'));

                                  return ListTile(
                                    title: Text(fileName),
                                    subtitle: Text('$modifiedTime • $fileSize'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.restore),
                                          onPressed: () =>
                                              _restoreFromDrive(file),
                                          tooltip: 'Restore from this backup',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.grey),
                                          onPressed: () =>
                                              _deleteFromDrive(file),
                                          tooltip: 'Delete this backup',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
