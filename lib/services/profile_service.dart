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
  });

  factory ProfileDetail.fromJson(Map<String, dynamic> j) => ProfileDetail(
        username: j['Username']?.toString() ?? '',
        firstName: j['FirstName']?.toString() ?? '',
        lastName: j['LastName']?.toString() ?? '',
        gender: j['Gender']?.toString() ?? '',
        dob: j['DOB']?.toString() ?? '',
        email: j['Email']?.toString() ?? '',
        contact: j['Contact']?.toString() ?? '',
        address: j['Address']?.toString() ?? '',
        photoUrl: resolvePhotoUrl(j['DisplayPicture']?.toString()),
      );

  final String username;
  final String firstName;
  final String lastName;
  final String gender;
  final String dob;
  final String email;
  final String contact;
  final String address;
  final String? photoUrl;
}

class ProfileService {
  final _client = ApiClient.instance;

  Future<ProfileDetail?> getMyProfile() async {
    final res = await _client.get('/EmployeeApp/GetMyProfile');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : ProfileDetail.fromJson(list.first);
  }

  Future<void> updateMyProfile({
    required String firstname,
    required String lastname,
    required String gender,
    required String dob,
    required String emailid,
    required String contact,
    required String address,
  }) async {
    final res = await _client.post('/EmployeeApp/UpdateMyProfile', data: {
      'firstname': firstname,
      'lastname': lastname,
      'gender': gender,
      'DOB': dob,
      'emailid': emailid,
      'Contact': contact,
      'Address': address,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update profile.'));
    }
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
