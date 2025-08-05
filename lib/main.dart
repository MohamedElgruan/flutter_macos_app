import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';

// ✅ دالة لمعالجة الرسائل في الخلفية، يجب أن تكون على مستوى أعلى (top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تهيئة Firebase في الخلفية
  await Firebase.initializeApp();
  showFlutterNotification(message);
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// ✅ دالة مساعدة لإظهار الإشعارات
Future<void> showFlutterNotification(RemoteMessage message) async {
  const androidDetails = AndroidNotificationDetails(
    'car_service_channel',
    'إشعارات خدمات السيارات',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    ticker: 'Car Service Running',
  );
  const notifDetails = NotificationDetails(android: androidDetails);
  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? '📢 إشعار جديد',
    message.notification?.body ?? '',
    notifDetails,
    payload: 'https://www.alyseer.com.ly',
  );
}

// ✅ دالة لحفظ الأخطاء في مجلد خارجي
Future<void> logErrorToFile(String error) async {
  try {
    // نستخدم getApplicationDocumentsDirectory لتخزين الملفات الخاصة بالتطبيق
    final dir = await getApplicationDocumentsDirectory();
    final errorFile = File('${dir.path}/error_log.txt');
    final timestamp = DateTime.now().toIso8601String();
    await errorFile.writeAsString("[$timestamp] $error\n",
        mode: FileMode.append);
  } catch (e) {
    // في وضع الإصدار، لا تستخدم print()
    // يمكنك استخدام Fluttertoast أو logErrorToFile() لحفظ الخطأ
    Fluttertoast.showToast(msg: "⚠️ فشل حفظ الخطأ: $e", backgroundColor: Colors.redAccent);
  }
}

// ✅ دالة لطلب إذن الوصول إلى التخزين الخارجي
// تم تغيير الإذن إلى Permission.storage وهو أقل تقييدًا من manageExternalStorage
Future<void> requestStoragePermission() async {
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تهيئة الإشعارات المحلية
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      final url = response.payload;
      if (url != null && url.isNotEmpty) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    },
  );

  // إعداد معالج رسائل الخلفية
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // طلب إذن الإشعارات للمنصات التي تتطلب ذلك
  await FirebaseMessaging.instance.requestPermission();

  // إعداد معالج أخطاء واجهة المستخدم
  FlutterError.onError = (details) {
    final errorMsg = details.exceptionAsString();
    Fluttertoast.showToast(msg: "⚠️ خطأ: $errorMsg", backgroundColor: Colors.redAccent);
    logErrorToFile("UI Error: $errorMsg");
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'تطبيق السيارات',
      debugShowCheckedModeBanner: false,
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final phoneController = TextEditingController();
  final iidController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // إعداد معالج رسائل الواجهة الأمامية
    FirebaseMessaging.onMessage.listen(showFlutterNotification);
    _checkAppStatusAndPermissions();
  }

  // ✅ دالة جديدة للتحقق من حالة التطبيق والأذونات
  Future<void> _checkAppStatusAndPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final isBackground = prefs.getBool('app_background') ?? false;

    // طلب الأذونات عند تشغيل التطبيق
    await requestStoragePermission();

    if (isBackground) {
      showFlutterNotification(const RemoteMessage(
        notification: RemoteNotification(
          title: 'ℹ️ التطبيق يعمل',
          body: 'لا حاجة لفتحه من جديد',
        ),
      ));
      // لا تستخدم return هنا، بل انتقل إلى حالة معينة
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من البيانات'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.2,
            child: Image.asset(
              'assets/car_parts_icon.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف المسجل به في التطبيق',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                    hintText: 'أدخل رقم الهاتف',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: iidController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'رقم التفعيل (من واجهة المتصفح)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                    hintText: 'أدخل رمز التفعيل',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () => _handleConfirmation(context),
                  icon: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isLoading ? 'جاري المعالجة...' : 'تأكيد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmation(BuildContext context) async {
    setState(() => isLoading = true);
    final phone = phoneController.text.trim();
    final iid = iidController.text.trim();
    final token = await FirebaseMessaging.instance.getToken();

    if (phone.isNotEmpty && iid.isNotEmpty && token != null) {
      await sendPhoneAndTokenToApi(phone, token, iid);
    } else {
      Fluttertoast.showToast(
        msg: "يرجى إدخال كل البيانات",
        backgroundColor: Colors.red,
      );
      await logErrorToFile("🔴 بيانات ناقصة: phone=$phone, iid=$iid, token=$token");
    }
    setState(() => isLoading = false);
  }

  Future<void> sendPhoneAndTokenToApi(String phone, String token, String iid) async {
    final uri = Uri.parse('https://www.alyseer.com.ly/RegisterFcmToken.aspx');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'phone': phone, 'fcmToken': token, 'iid': iid},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_background', true); // حفظ حالة عمل التطبيق في الخلفية

        final dir = await getApplicationDocumentsDirectory(); // استخدام مجلد التطبيق
        final userFile = File('${dir.path}/user_data.txt');
        await userFile.writeAsString(jsonEncode({"phone": phone, "iid": iid}));

        Fluttertoast.showToast(msg: "✅ تم الحفظ والتفعيل", backgroundColor: Colors.green);
        showFlutterNotification(RemoteMessage(
          notification: RemoteNotification(
            title: '✅ تم التفعيل',
            body: 'تم تفعيل تطبيق خدمات السيارات بنجاح',
          ),
        ));

        // بدلاً من إغلاق التطبيق، قم بنقله إلى الخلفية
        SystemNavigator.pop();

      } else {
        Fluttertoast.showToast(msg: "فشل الإرسال: ${response.statusCode}", backgroundColor: Colors.orange);
        await logErrorToFile("❌ رمز حالة الاستجابة: ${response.statusCode}");
      }
    } on TimeoutException {
      Fluttertoast.showToast(msg: "⏳ انتهى وقت الانتظار", backgroundColor: Colors.deepOrange);
      await logErrorToFile("⏱️ انتهاء المهلة");
    } catch (e) {
      // ✅ في وضع الإصدار، لا يمكن الاعتماد على print
      // لذا، نقوم باستخدام Fluttertoast وحفظ الخطأ في ملف
      Fluttertoast.showToast(msg: "⚠️ خطأ: $e", backgroundColor: Colors.redAccent);
      await logErrorToFile("⚠️ استثناء أثناء الإرسال: $e");
    }
  }
}
