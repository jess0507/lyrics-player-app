import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// 產生一個新的後端歌詞任務 id(`user/{uid}/lyrics/{jobId}`)。
///
/// 由 Firestore 在本機產生自動 id(不需網路);Firebase 不可用時退回同格式
/// (20 碼英數)的本機亂數——此時本來就無法登入送出任務,只是不讓流程在
/// 這裡先拋例外。
String newLyricsJobId() {
  try {
    return FirebaseFirestore.instance.collection('lyrics').doc().id;
  } catch (_) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(20, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
}
