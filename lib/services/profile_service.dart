import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

class ProfileDetail {
  ProfileDetail({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dob,
    required this.email,
    required this.contact,
    required this.address,
    required this.photoUrl,
    this.userType = '',
    this.department = '',
    this.designation = '',
    this.joinDate = '',
    this.employeeId = 0,
  });

  /// The API returns both the legacy key spellings (Username/Contact — what already-installed app versions
  /// read) and the real column names (UserName/ContactNo); prefer the real ones.
  factory ProfileDetail.fromJson(Map<String, dynamic> j) => ProfileDetail(
        username: (j['UserName'] ?? j['Username'])?.toString() ?? '',
        firstName: j['FirstName']?.toString() ?? '',
        lastName: j['LastName']?.toString() ?? '',
        gender: j['Gender']?.toString() ?? '',
        dob: j['DOB']?.toString() ?? '',
        email: j['Email']?.toString() ?? '',
        contact: (j['ContactNo'] ?? j['Contact'])?.toString() ?? '',
        address: j['Address']?.toString() ?? '',
        photoUrl: resolvePhotoUrl(j['DisplayPicture']?.toString()),
        userType: j['UserType']?.toString() ?? '',
        department: j['Department']?.toString() ?? '',
        designation: j['Designation']?.toString() ?? '',
        joinDate: j['JoinDate']?.toString() ?? '',
        employeeId: int.tryParse('${j['EmployeeID'] ?? 0}') ?? 0,
      );

  final String username;
  final String firstName;
  final String lastName;
  final String gender;

  /// yyyy-MM-dd, or empty when neither source holds a plausible date of birth.
  final String dob;
  final String email;
  final String contact;
  final String address;
  final String? photoUrl;
  final String userType;
  final String department;
  final String designation;
  final String joinDate;
  final int employeeId;

  String get fullName => '$firstName $lastName'.trim();
}

class ProfileSaveResult {
  ProfileSaveResult({required this.userName, required this.usernameChanged});
  final String userName;
  final bool usernameChanged;
}

class ProfileService {
  final _client = ApiClient.instance;

  Future<ProfileDetail?> getMyProfile() async {
    final res = await _client.get('/EmployeeApp/GetMyProfile');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : ProfileDetail.fromJson(list.first);
  }

  /// Edit my basic details, including the username (= the handle I sign in with). The server validates
  /// everything (and writes both the login record and the HR employee record); any problem comes back as
  /// a plain-language message which is thrown as an [ApiException] to show as-is.
  Future<ProfileSaveResult> updateMyBasicDetails({
    required String firstName,
    required String lastName,
    required String gender,
    required String dob,
    required String email,
    required String contactNo,
    required String address,
    required String userName,
  }) async {
    final res = await _client.post('/EmployeeApp/UpdateMyBasicDetails', data: {
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'dob': dob,
      'email': email,
      'contactNo': contactNo,
      'address': address,
      'userName': userName,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update your details.'));
    }
    return ProfileSaveResult(
      userName: data['userName']?.toString() ?? userName,
      usernameChanged: data['usernameChanged'] == true,
    );
  }

  /// (available, message) for the live "is this username free?" hint.
  Future<(bool, String)> checkUsername(String userName) async {
    final res = await _client.get('/EmployeeApp/CheckUsernameAvailable', query: {'userName': userName});
    final data = res.data as Map<String, dynamic>;
    return (data['available'] == true, data['message']?.toString() ?? '');
  }

  /// Returns how many OTHER devices were signed out as a result (a password change signs them all out).
  Future<int> changePassword({required String currentPassword, required String newPassword, required String confirmPassword}) async {
    final res = await _client.post('/EmployeeApp/ChangeMyPassword', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not change the password.'));
    }
    return int.tryParse('${data['signedOutOtherDevices'] ?? 0}') ?? 0;
  }

  /// Bytes rather than a dart:io File path — image_picker's XFile works the same way on both mobile and
  /// web, and MultipartFile.fromFile needs dart:io, which isn't available on web.
  Future<String> uploadPhoto(Uint8List bytes, String filename) async {
    final form = FormData.fromMap({'photo': MultipartFile.fromBytes(bytes, filename: filename)});
    final res = await _client.post('/EmployeeApp/UploadProfilePhoto', form: form);
    final data = res.data as Map<String, dynamic>;
    final photoUrl = resolvePhotoUrl(data['photoUrl'] as String?);
    if (data['message'] != 'success' || photoUrl == null) {
      throw ApiException(extractMessage(data, 'Could not upload photo.'));
    }
    return photoUrl;
  }
}
