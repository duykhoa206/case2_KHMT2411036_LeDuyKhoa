import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  // URL backend Node.js (Nếu chạy máy ảo Android dùng 10.0.2.2, máy thật dùng IP LAN của máy tính)
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  static Future<List<Map<String, String>>> fetchUsers({String searchQuery = ''}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users?search=$searchQuery'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List usersJson = data['data'];
        return usersJson.map((user) => {
          'id': user['id'].toString(),
          'name': user['name'].toString(),
          'email': user['email'].toString(),
        }).toList();
      } else {
        throw Exception('Không thể tải danh sách người dùng');
      }
    } catch (e) {
      print('Lỗi gọi API users: $e');
      return [];
    }
  }
}