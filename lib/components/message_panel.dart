import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoid/nanoid.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:provider/provider.dart';
import '../classes/global.dart';
import '../classes/msg.dart';
import '../classes/payload.dart';
import '../database/database_helper.dart';
import '../encyption/rsa.dart';
import 'view_file.dart';

/// This component is used in the ChatPage.
/// It is the message bar where the message is typed on and sent to
/// connected devices.

class MessagePanel extends StatefulWidget {
  const MessagePanel({Key? key, required this.converser}) : super(key: key);
  final String converser;

  @override
  State<MessagePanel> createState() => _MessagePanelState();
}

class _MessagePanelState extends State<MessagePanel> {
  TextEditingController myController = TextEditingController();
  File _selectedFile = File('');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        //multiline text field
        maxLines: null,
        controller: myController,
        decoration: InputDecoration(
          icon: const Icon(Icons.person),
          hintText: 'Send Message?',
          labelText: 'Send Message ',
          suffixIcon: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _navigateToFilePreviewPage(context),
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                onPressed: () => _sendMessage(context),
                icon: const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage(BuildContext context) {
    var msgId = nanoid(21);
    if (myController.text.isEmpty) {
      return;
    }
    // Encode the message to base64

    String data = jsonEncode({
      "sender": Global.myName,
      "type": "text",
      "data": myController.text,
    });

    String date = DateTime.now().toUtc().toString();

    Global.cache[msgId] = Payload(
      msgId,
      Global.myName,
      widget.converser,
      data,
      date,
    );
    insertIntoMessageTable(
      Payload(
        msgId,
        Global.myName,
        widget.converser,
        data,
        date,
      ),
    );

    RSAPublicKey publicKey = Global.myPublicKey!;
    // Encrypt the message
    Uint8List encryptedMessage = rsaEncrypt(
        publicKey, Uint8List.fromList(utf8.encode(myController.text)));

    String myData = jsonEncode({
      "sender": Global.myName,
      "type": "text",
      "data": base64Encode(encryptedMessage),
    });

    Provider.of<Global>(context, listen: false).sentToConversations(
      Msg(myData, "sent", date, msgId),
      widget.converser,
    );

    // refreshMessages();
    myController.clear();
  }

  /// This function is used to navigate to the file preview page and check the file size.
  void _navigateToFilePreviewPage(BuildContext context) async {
    //max size of file is 30 MB
    double sizeKbs = 0;
    const int maxSizeKbs = 30 * 1024;
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if(result != null) {
      sizeKbs = result.files.single.size / 1024;
    }


    if (sizeKbs > maxSizeKbs) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('File Size Exceeded'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  //file size in MB
                  title: Text('File Size: ${(sizeKbs / 1024).ceil()} MB'),
                  subtitle: const Text(
                      'File size should not exceed 30 MB'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
      return;
    }

//this function is used to open the file preview dialog
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('File Preview'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(

                  title: Text('File Name: ${_selectedFile.path
                      .split('/')
                      .last}', overflow: TextOverflow.ellipsis,),
                  subtitle: Text(
                      'File Size: ${(sizeKbs / 1024).floor()} MB'),
                ),
                ElevatedButton(
                  onPressed: () => FilePreview.openFile(_selectedFile.path),
                  child: const Text('Open File'),
                ),
              ],
            ),
            actions: [

              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
              IconButton(
                onPressed: () {
          Navigator.pop(context);
          _sendFileMessage(context, _selectedFile);

          },
                icon: const Icon(
                  Icons.send,
                ),
              ),
            ],
          );
        },
      );
    }
  }


/// This function is used to send the file message.
  void _sendFileMessage(BuildContext context, File file) async{
    var msgId = nanoid(21);

    String fileName = _selectedFile.path.split('/').last;
    String filePath = file.path;

    String data = jsonEncode({
      "sender": Global.myName,
      "type": "file",
      "fileName": fileName,
      "filePath": filePath,
    });

    String date = DateTime.now().toUtc().toString();
    Global.cache[msgId] = Payload(
      msgId,
      Global.myName,
      widget.converser,
      data,
      date,
    );
    insertIntoMessageTable(
      Payload(
        msgId,
        Global.myName,
        widget.converser,
        data,
        date,
      ),
    );

    Provider.of<Global>(context, listen: false).sentToConversations(
      Msg(data, "sent", date, msgId),
      widget.converser,
    );

  }

}
