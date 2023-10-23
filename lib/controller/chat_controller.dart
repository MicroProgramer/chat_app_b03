import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mondaytest/helper/constants.dart';
import 'package:mondaytest/helper/firebase_helpers.dart';

import '../Models/Student.dart';
import '../Models/message_model.dart';
import '../helper/Fcm.dart';

class ChatController extends GetxController {
  var isEmojiVisible = false.obs;
  FocusNode focusNode = FocusNode();
  var textEditingController = TextEditingController();
  String receiver_id;
  Rx<Student?> receiverObservable = Rx(null);

  @override
  void onInit() {
    super.onInit();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        isEmojiVisible.value = false;
      }
    });
    updateParticipants();
    startReceiverStream();
    startOnlineStatusStream();
  }

  @override
  void onClose() {
    super.onClose();
    textEditingController.dispose();
  }

  ChatController({
    required this.receiver_id,
  });

  void startReceiverStream() {
    usersRef.doc(receiver_id).snapshots().listen((event) {
      receiverObservable.value =
          Student.fromMap(event.data() as Map<String, dynamic>);
    });
  }

  void startOnlineStatusStream() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      update();
    });
  }

  void sendMessage(String text, {String type = 'text'}) async {
    if (text.isNotEmpty) {
      FCM.sendMessageSingle(
        currentUser!.displayName ?? "New Message",
        type == 'text' ? text : 'image',
        receiverObservable.value?.token ?? "",
        {},
      );

      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var message = MessageModel(
          id: timestamp.toString(),
          text: text,
          sender_id: currentUser!.uid,
          timestamp: timestamp,
          receiver_id: receiver_id,
          message_type: type);

      var roomPath = chatsRef.child(getRoomId(receiver_id, currentUser!.uid));

      roomPath.update({'lastMessage': jsonEncode(message.toMap())});
      roomPath
          .child("messages")
          .child(timestamp.toString())
          .set(message.toMap());
      textEditingController.clear();
    }
  }

  String getRoomId(String user1, String user2) {
    var merge = "$user1$user2";
    var charList = merge.split('');
    charList.sort((a, b) => a.compareTo(b));
    return charList.join();
  }

  void pickImage() async {
    var pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      var file = File(pickedFile.path);
      var url = await FirebaseStorageUtils.uploadImage(
          file,
          'chats/${getRoomId(receiver_id, currentUser!.uid)}',
          DateTime.now().millisecondsSinceEpoch.toString());
      sendMessage(url, type: 'image');
    }
  }

  void updateParticipants() async {
    var id = getRoomId(currentUser!.uid, receiver_id);
    chatsRef.child(id).update({
      'participants': [currentUser!.uid, receiver_id],
      'id': id,
      'name': 'Name',
      'roomType': 'chat'
    });
  }
}
