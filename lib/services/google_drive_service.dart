import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:http/io_client.dart';
import '../utils/constants.dart';
import '../services/backup_service.dart';

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  // Singleton pattern
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  GoogleSignInAccount? _currentUser;
  bool get isSignedIn => _currentUser != null;
  String get userName => _currentUser?.displayName ?? '';
  String get userEmail => _currentUser?.email ?? '';

  // Sign in to Google
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }
      _currentUser = account;
      return true;
    } catch (error) {
      debugPrint('Error signing in: $error');
      return false;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (error) {
      debugPrint('Error signing out: $error');
    }
  }

  // Get authenticated HTTP client
  Future<http.Client> _getHttpClient() async {
    if (_currentUser == null) {
      throw Exception('User not signed in to Google');
    }

    final authHeaders = await _currentUser!.authHeaders;
    final httpClient = http.Client();
    return _AuthClient(httpClient, authHeaders);
  }

  // Upload backup file to Google Drive
  Future<String?> uploadBackup(File file, String fileName) async {
    try {
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Check if app folder exists, create if it doesn't
      final folderName = AppStrings.appTitle;
      String? folderId = await _getFolderIdByName(driveApi, folderName);
      
      if (folderId == null) {
        folderId = await _createFolder(driveApi, folderName);
      }

      // Prepare file metadata
      final fileMetadata = drive.File(
        name: fileName,
        parents: [folderId!],
        description: 'Camera Kit Manager Backup - ${DateTime.now().toIso8601String()}',
        mimeType: 'application/octet-stream',
      );

      // Upload file content
      final media = drive.Media(
        file.openRead(),
        await file.length(),
      );

      final driveFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      return driveFile.id;
    } catch (e) {
      debugPrint('Error uploading to Google Drive: $e');
      return null;
    }
  }

  // Download backup file from Google Drive
  Future<File?> downloadBackup(String fileId) async {
    try {
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Get file metadata
      final file = await driveApi.files.get(fileId) as drive.File;
      final fileName = file.name ?? 'backup.json';

      // Get file content
      drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final localFile = File('${directory.path}/$fileName');
      
      List<int> dataStore = [];
      await for (var data in media.stream) {
        dataStore.addAll(data);
      }
      await localFile.writeAsBytes(dataStore);
      
      return localFile;
    } catch (e) {
      debugPrint('Error downloading from Google Drive: $e');
      return null;
    }
  }

  // Get list of backup files from Google Drive
  Future<List<drive.File>> getBackupFiles() async {
    try {
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Find app folder
      final folderName = AppStrings.appTitle;
      String? folderId = await _getFolderIdByName(driveApi, folderName);
      
      if (folderId == null) {
        return [];
      }

      // List files in folder
      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime, size)',
      );

      return fileList.files?.where((file) => 
        file.name?.endsWith('.json') == true || 
        file.name?.endsWith('.zip') == true
      ).toList() ?? [];
    } catch (e) {
      debugPrint('Error fetching backup files: $e');
      return [];
    }
  }

  // Get or create app folder ID
  Future<String?> _getFolderIdByName(drive.DriveApi driveApi, String folderName) async {
    try {
      final result = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error finding folder: $e');
      return null;
    }
  }

  // Create folder in Google Drive
  Future<String?> _createFolder(drive.DriveApi driveApi, String folderName) async {
    try {
      final folder = drive.File(
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
      );

      final result = await driveApi.files.create(folder);
      return result.id;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return null;
    }
  }

  // Delete a file from Google Drive
  Future<bool> deleteFile(String fileId) async {
    try {
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      await driveApi.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }
}

// Helper class for authenticated requests
class _AuthClient extends http.BaseClient {
  final http.Client _client;
  final Map<String, String> _headers;

  _AuthClient(this._client, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
