import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static Future<bool> loggedIn() async {
    final p=await SharedPreferences.getInstance();
    return (p.getString('token')??'').isNotEmpty;
  }
  static Future<void> save(String token,Map<String,dynamic> user) async {
    final p=await SharedPreferences.getInstance();
    await p.setString('token',token);
    await p.setString('name','${user['first_name']??''} ${user['last_name']??''}'.trim());
    await p.setString('email',user['email']?.toString()??'');
    await p.setString('role',user['role']?.toString()??'member');
  }
  static Future<Map<String,String>> user() async {
    final p=await SharedPreferences.getInstance();
    return {'name':p.getString('name')??'Membre ELIM','email':p.getString('email')??'','role':p.getString('role')??'member'};
  }
  static Future<void> clear() async {
    final p=await SharedPreferences.getInstance();
    await p.remove('token'); await p.remove('name'); await p.remove('email'); await p.remove('role');
  }
}
