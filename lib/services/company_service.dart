import '../core/api_client.dart';

class CompanyProfile {
  CompanyProfile({required this.companyName, this.logoUrl});

  factory CompanyProfile.fromJson(Map<String, dynamic> json) => CompanyProfile(
        companyName: json['companyName'] as String? ?? 'JMM InfoTech',
        logoUrl: json['logoUrl'] as String?,
      );

  final String companyName;
  final String? logoUrl;
}

/// Company branding (name/logo) for the login screen and app bar — public endpoint (no auth token
/// needed), since the login screen calls this before any user is signed in. See
/// MVC.Web/Controllers/API/EmployeeAppController.cs's GetCompanyProfile.
class CompanyService {
  Future<CompanyProfile?> getCompanyProfile() async {
    try {
      final res = await ApiClient.instance.get('/EmployeeApp/GetCompanyProfile');
      return CompanyProfile.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
