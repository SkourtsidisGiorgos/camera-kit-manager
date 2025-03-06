import 'package:camera_kit_manager/presentation/widgets/ui_components.dart';
import 'package:flutter/material.dart';

class MessageUtils {
  static Future<bool> showImportWarningDialog(
      BuildContext context, String message, String confirmMsg) async {
    return await ConfirmationDialog.show(
      context: context,
      title: 'Warning',
      message: message,
      confirmText: confirmMsg,
      isDangerous: true,
    );
  }
}
