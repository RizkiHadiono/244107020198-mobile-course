import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// ==========================================
// 1. BACKGROUND HANDLER
// ==========================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
}

void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

// ==========================================
// 2. TIGA HANDLER & PAYLOAD GABUNGAN
// ==========================================
final _local = FlutterLocalNotificationsPlugin();
String? pendingDeepLink;

Future<void> initLocalNotifications(void Function(String route) go) async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await _local.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (response) {
      if (response.payload != null) go(response.payload!);
    },
  );
}

void listenForeground(void Function(String route) go) {
  FirebaseMessaging.onMessage.listen((message) async {
    final route = routeFromMessage(message.data);
    const androidDetails = AndroidNotificationDetails(
      'pengumuman', 'Pengumuman Kampus',
      importance: Importance.high, priority: Priority.high,
    );
    
    await _local.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Pengumuman',
      body: message.notification?.body ?? '',
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: route,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    go(routeFromMessage(message.data));
  });
}

Future<void> handleTerminated(void Function(String route) go) async {
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) go(routeFromMessage(initial.data));
  if (pendingDeepLink != null) go(pendingDeepLink!);
}

// ==========================================
// FUNGSI PENDUKUNG & PERMISSION
// ==========================================
Future<void> requestNotificationPermission() async {
  await FirebaseMessaging.instance.requestPermission();
}

Future<void> initFcmToken({required Function(String) onToken}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) onToken(token);
}

// ==========================================
// 4. TOPIC MESSAGING
// ==========================================
Future<void> subscribeToCampusTopic() async {
  await FirebaseMessaging.instance.subscribeToTopic('pengumuman-kampus');
  debugPrint("Berhasil berlangganan topik: pengumuman-kampus");
}

Future<void> unsubscribeFromCampusTopic() async {
  await FirebaseMessaging.instance.unsubscribeFromTopic('pengumuman-kampus');
  debugPrint("Berhasil berhenti berlangganan dari topik: pengumuman-kampus");
}

// ==========================================
// REFACTORING: Ekstraksi Rute
// ==========================================
String routeFromMessage(Map<String, dynamic> data) {
  final route = data['route']?.toString() ?? '/';
  return route.startsWith('/') ? route : '/$route';
}