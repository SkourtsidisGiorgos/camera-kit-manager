import 'dart:io';
import 'package:camera_kit_manager/core/utils/file_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/constants.dart';

class GoogleDriveService {
  // Add additional scopes and configure properly
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/drive.file',
    ],
    // Ensuring the client properly identifies on Android
    signInOption: SignInOption.standard,
  );

  // Singleton pattern
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  GoogleSignInAccount? _currentUser;
  bool get isSignedIn => _currentUser != null;
  String get userName => _currentUser?.displayName ?? '';
  String get userEmail => _currentUser?.email ?? '';

  // Sign in to Google with improved error handling
  Future<bool> signIn() async {
    try {
      // Force a fresh sign-in flow by signing out first
      await _googleSignIn.signOut();

      // Begin interactive sign-in process
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('Sign-in cancelled by user');
        return false;
      }

      _currentUser = account;
      debugPrint('Successfully signed in as: ${account.email}');
      return true;
    } on Exception catch (error) {
      debugPrint('Error signing in: ${error.runtimeType} - $error');

      if (error.toString().contains('ApiException: 10')) {
        debugPrint('OAuth client configuration issue. Check Firebase console.');
      }

      return false;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      debugPrint('Successfully signed out');
    } catch (error) {
      debugPrint('Error signing out: $error');
    }
  }

  // Get authenticated HTTP client
  Future<http.Client> _getHttpClient() async {
    if (_currentUser == null) {
      throw Exception('User not signed in to Google');
    }

    try {
      // Ensure fresh tokens
      await _currentUser!.clearAuthCache();
      final authHeaders = await _currentUser!.authHeaders;
      final httpClient = http.Client();
      return _AuthClient(httpClient, authHeaders);
    } catch (e) {
      debugPrint('Error getting auth headers: $e');
      // Attempt to refresh authentication
      await signIn();
      if (_currentUser == null) {
        throw Exception('Failed to refresh authentication');
      }
      final authHeaders = await _currentUser!.authHeaders;
      final httpClient = http.Client();
      return _AuthClient(httpClient, authHeaders);
    }
  }

  // Upload backup file to Google Drive
  Future<String?> uploadBackup(File file, String fileName) async {
    try {
      debugPrint('Uploading backup to Google Drive: ${file.path}');
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Check if app folder exists, create if it doesn't
      final folderName = AppStrings.appTitle;
      String? folderId = await _getFolderIdByName(driveApi, folderName);

      folderId ??= await _createFolder(driveApi, folderName);

      if (folderId == null) {
        throw Exception('Failed to create or find app folder in Google Drive');
      }

      // Prepare file metadata
      final fileMetadata = drive.File(
        name: fileName,
        parents: [folderId],
        description:
            'Camera Kit Manager Backup - ${DateTime.now().toIso8601String()}',
        mimeType:
            file.path.endsWith('.zip') ? 'application/zip' : 'application/json',
      );

      final fileLength = await file.length();
      debugPrint(
          'Uploading file of size: ${FileUtils.formatFileSize(fileLength)}');

      final media = drive.Media(
        file.openRead(),
        fileLength,
      );

      final driveFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      debugPrint('File uploaded to Google Drive with ID: ${driveFile.id}');
      return driveFile.id;
    } catch (e) {
      debugPrint('Error uploading to Google Drive: $e');
      return null;
    }
  }

  Future<File?> downloadBackup(String fileId) async {
    try {
      debugPrint('Downloading backup from Google Drive, ID: $fileId');
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Get file metadata
      final file = await driveApi.files.get(fileId) as drive.File;
      if (file.name == null) {
        throw Exception('File name is null');
      }

      final fileName = file.name!;
      debugPrint('Downloading file: $fileName');

      // Create media object for download
      drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final directory = await getTemporaryDirectory();
      final localFile = File('${directory.path}/$fileName');

      // Stream data to file
      List<int> dataStore = [];
      await for (var data in media.stream) {
        dataStore.addAll(data);
      }
      await localFile.writeAsBytes(dataStore);

      debugPrint('File downloaded to: ${localFile.path}');
      debugPrint(
          'File size: ${FileUtils.formatFileSize(await localFile.length())}');

      return localFile;
    } catch (e) {
      debugPrint('Error downloading from Google Drive: $e');
      return null;
    }
  }

  // Get list of backup files from Google Drive
  Future<List<drive.File>> getBackupFiles() async {
    try {
      debugPrint('Fetching backup files from Google Drive');
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      // Find app folder
      final folderName = AppStrings.appTitle;
      String? folderId = await _getFolderIdByName(driveApi, folderName);

      if (folderId == null) {
        debugPrint('App folder not found in Google Drive');
        return [];
      }

      // List files in folder
      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final files = fileList.files
              ?.where((file) =>
                  file.name?.endsWith('.json') == true ||
                  file.name?.endsWith('.zip') == true)
              .toList() ??
          [];

      debugPrint('Found ${files.length} backup files');
      return files;
    } catch (e) {
      debugPrint('Error fetching backup files: $e');
      return [];
    }
  }

  // Get or create app folder ID
  Future<String?> _getFolderIdByName(
      drive.DriveApi driveApi, String folderName) async {
    try {
      final result = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        debugPrint(
            'Found existing app folder in Google Drive: ${result.files!.first.id}');
        return result.files!.first.id;
      }
      debugPrint('App folder not found in Google Drive');
      return null;
    } catch (e) {
      debugPrint('Error finding folder: $e');
      return null;
    }
  }

  // Create folder in Google Drive
  Future<String?> _createFolder(
      drive.DriveApi driveApi, String folderName) async {
    try {
      debugPrint('Creating app folder in Google Drive: $folderName');
      final folder = drive.File(
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
      );

      final result = await driveApi.files.create(folder);
      debugPrint('Created folder with ID: ${result.id}');
      return result.id;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return null;
    }
  }

  // Delete a file from Google Drive
  Future<bool> deleteFile(String fileId) async {
    try {
      debugPrint('Deleting file from Google Drive, ID: $fileId');
      final client = await _getHttpClient();
      final driveApi = drive.DriveApi(client);

      await driveApi.files.delete(fileId);
      debugPrint('File deleted successfully');
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
