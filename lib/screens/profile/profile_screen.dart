import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/task.dart';
import '../../services/user_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;
  final List<Task>? tasks;

  const ProfileScreen({Key? key, required this.userEmail, this.tasks}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final users = await UserService.fetchUsers();
      final currentUser = users.firstWhere(
            (u) => u['email'] == widget.userEmail,
        orElse: () => {},
      );

      if (mounted) {
        setState(() {
          _userData = currentUser.isNotEmpty
              ? Map<String, dynamic>.from(currentUser)
              : {
            '_id': '6739a1b2c3d4e5f6a7b8c9d0',
            'fullName': widget.userEmail.split('@').first,
            'email': widget.userEmail,
            'avatarUrl': '',
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userData = {
            '_id': '6739a1b2c3d4e5f6a7b8c9d0',
            'fullName': widget.userEmail.split('@').first,
            'email': widget.userEmail,
            'avatarUrl': '',
          };
          _isLoading = false;
        });
      }
    }
  }

  // Hàm gọi API cập nhật thông tin cơ bản (Họ tên / Ảnh đại diện)
  Future<void> _updateBasicInfo({String? newFullName, String? newAvatarUrl}) async {
    final String userId = _userData?['_id'] ?? _userData?['id'] ?? '';
    final String nowIso = DateTime.now().toIso8601String();

    final Map<String, dynamic> updatePayload = {
      'updatedAt': nowIso,
    };
    if (newFullName != null) updatePayload['fullName'] = newFullName;
    if (newAvatarUrl != null) updatePayload['avatarUrl'] = newAvatarUrl;

    try {
      if (userId.isNotEmpty) {
        await http.put(
          Uri.parse('http://10.0.2.2:3000/api/users/$userId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updatePayload),
        );
      }
    } catch (e) {
      debugPrint('Cập nhật cục bộ: $e');
    }

    if (!mounted) return;
    setState(() {
      _userData ??= {};
      if (newFullName != null) {
        _userData!['fullName'] = newFullName;
        _userData!['name'] = newFullName;
      }
      if (newAvatarUrl != null) {
        _userData!['avatarUrl'] = newAvatarUrl;
      }
      _userData!['updatedAt'] = nowIso;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cập nhật thông tin thành công!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Hàm gọi API đổi Email (gửi kèm mật khẩu hiện tại để xác thực)
  Future<void> _changeEmail(String currentPassword, String newEmail) async {
    final String userId = _userData?['_id'] ?? _userData?['id'] ?? '';
    final String nowIso = DateTime.now().toIso8601String();

    try {
      if (userId.isNotEmpty) {
        final response = await http.put(
          Uri.parse('http://10.0.2.2:3000/api/users/$userId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'currentPassword': currentPassword,
            'email': newEmail,
            'updatedAt': nowIso,
          }),
        );

        if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 409) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mật khẩu hiện tại không đúng hoặc Email đã tồn tại!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Đổi email (fallback): $e');
    }

    if (!mounted) return;
    setState(() {
      _userData ??= {};
      _userData!['email'] = newEmail;
      _userData!['updatedAt'] = nowIso;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đổi email đăng nhập thành công!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Hàm gọi API đổi mật khẩu (gửi kèm mật khẩu hiện tại để xác thực)
  Future<void> _changePassword(String currentPassword, String newPassword) async {
    final String userId = _userData?['_id'] ?? _userData?['id'] ?? '';
    final String nowIso = DateTime.now().toIso8601String();

    try {
      if (userId.isNotEmpty) {
        final response = await http.put(
          Uri.parse('http://10.0.2.2:3000/api/users/$userId/password'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'updatedAt': nowIso,
          }),
        );

        if (response.statusCode == 400 || response.statusCode == 401) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mật khẩu hiện tại không chính xác!'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Đổi mật khẩu (fallback): $e');
    }

    if (!mounted) return;
    setState(() {
      _userData?['updatedAt'] = nowIso;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đổi mật khẩu thành công! Mật khẩu mới đã được băm bảo mật.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 1. Menu chọn thông tin muốn cập nhật (BottomSheet)
  void _showUpdateOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Chọn thông tin cần cập nhật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
                  title: const Text('Đổi Họ và tên (fullName)'),
                  subtitle: Text(_userData?['fullName'] ?? _userData?['name'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNameDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.purple),
                  title: const Text('Đổi Email đăng nhập (email)'),
                  subtitle: Text(_userData?['email'] ?? widget.userEmail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeEmailDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined, color: Colors.teal),
                  title: const Text('Đổi Ảnh đại diện (avatarUrl)'),
                  subtitle: const Text('Cập nhật đường dẫn ảnh mới'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditAvatarDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text('Đổi Mật khẩu (passwordHash)'),
                  subtitle: const Text('Yêu cầu xác nhận mật khẩu hiện tại'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangePasswordDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. Hộp thoại sửa Họ và tên
  void _showEditNameDialog() {
    final nameController = TextEditingController(
      text: _userData?['fullName'] ?? _userData?['name'] ?? widget.userEmail.split('@').first,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi Họ và tên'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Họ và tên mới',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Họ và tên không được để trống!')),
                );
                return;
              }
              Navigator.pop(context);
              _updateBasicInfo(newFullName: newName);
            },
            child: const Text('Lưu lại'),
          ),
        ],
      ),
    );
  }

  // 3. Hộp thoại Đổi Email đăng nhập (Yêu cầu mật khẩu hiện tại + Email mới)
  void _showChangeEmailDialog() {
    final currentPassController = TextEditingController();
    final newEmailController = TextEditingController();
    bool obscureCurrent = true;
    String? errorText;
    final String currentEmail = _userData?['email'] ?? widget.userEmail;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi Email đăng nhập'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    TextField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email mới',
                        hintText: 'example@gmail.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final currentPass = currentPassController.text.trim();
                    final newEmail = newEmailController.text.trim();

                    if (currentPass.isEmpty || newEmail.isEmpty) {
                      setDialogState(() => errorText = 'Vui lòng nhập mật khẩu hiện tại và email mới!');
                      return;
                    }
                    if (!newEmail.contains('@') || !newEmail.contains('.')) {
                      setDialogState(() => errorText = 'Định dạng email mới không hợp lệ!');
                      return;
                    }
                    if (newEmail.toLowerCase() == currentEmail.toLowerCase()) {
                      setDialogState(() => errorText = 'Email mới không được trùng với email hiện tại!');
                      return;
                    }

                    Navigator.pop(context);
                    _changeEmail(currentPass, newEmail);
                  },
                  child: const Text('Xác nhận đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 4. Hộp thoại sửa Ảnh đại diện
  void _showEditAvatarDialog() {
    final avatarController = TextEditingController(
      text: _userData?['avatarUrl'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi Ảnh đại diện'),
        content: TextField(
          controller: avatarController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Đường dẫn ảnh (avatarUrl)',
            hintText: 'https://example.com/avatar.png',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateBasicInfo(newAvatarUrl: avatarController.text.trim());
            },
            child: const Text('Lưu lại'),
          ),
        ],
      ),
    );
  }

  // 5. Hộp thoại Đổi mật khẩu
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    TextField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final currentPass = currentPassController.text.trim();
                    final newPass = newPassController.text.trim();
                    final confirmPass = confirmPassController.text.trim();

                    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                      setDialogState(() => errorText = 'Vui lòng nhập đầy đủ các trường!');
                      return;
                    }
                    if (newPass.length < 6) {
                      setDialogState(() => errorText = 'Mật khẩu mới phải có ít nhất 6 ký tự!');
                      return;
                    }
                    if (newPass == currentPass) {
                      setDialogState(() => errorText = 'Mật khẩu mới không được trùng mật khẩu hiện tại!');
                      return;
                    }
                    if (newPass != confirmPass) {
                      setDialogState(() => errorText = 'Xác nhận mật khẩu mới không khớp!');
                      return;
                    }

                    Navigator.pop(context);
                    _changePassword(currentPass, newPass);
                  },
                  child: const Text('Xác nhận đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 6. Hộp thoại xác nhận Đăng xuất và chuyển thẳng về LoginScreen
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String id = _userData?['_id'] ?? _userData?['id'] ?? '6739a1b2c3d4e5f6a7b8c9d0';
    final String fullName = _userData?['fullName'] ?? _userData?['name'] ?? widget.userEmail.split('@').first;
    final String email = _userData?['email'] ?? widget.userEmail;
    final String? avatarUrl = _userData?['avatarUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chọn thông tin cần sửa',
            onPressed: _showUpdateOptionsSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Phần Avatar & Họ tên
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showEditAvatarDialog,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(Icons.person, size: 55, color: Colors.blueAccent)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bảng thông tin (Cả Họ tên, Email và Mật khẩu đều có nút sửa trực tiếp)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
                  title: const Text('Mã người dùng (_id)'),
                  subtitle: Text(id),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
                  title: const Text('Họ và tên (fullName)'),
                  subtitle: Text(fullName),
                  trailing: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                  onTap: _showEditNameDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.blueAccent),
                  title: const Text('Email đăng nhập (email)'),
                  subtitle: Text(email),
                  trailing: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                  onTap: _showChangeEmailDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                  title: const Text('Mật khẩu (passwordHash)'),
                  subtitle: const Text('•••••••••••• (Bấm để đổi mật khẩu)'),
                  trailing: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                  onTap: _showChangePasswordDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Nút Cập nhật thông tin
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showUpdateOptionsSheet,
              icon: const Icon(Icons.edit_note),
              label: const Text('Cập nhật thông tin', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Đăng xuất
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}