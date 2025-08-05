import 'package:shared_preferences/shared_preferences.dart';

Future<bool> isAppInBackground() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('app_background') ?? false;
}