import '../core/api_client.dart';
import '../models/models.dart';

/// HR Documents (Offer Letter, Appointment Letter, Experience Certificate, Relieving Letter, Salary
/// Certificate, or any custom letter type added on the admin web side) — issued-to-me documents only,
/// mirroring EmployeeAppController's GetMyDocuments/MyDocumentView/DownloadMyDocument.
class DocumentService {
  final _client = ApiClient.instance;

  Future<List<EmployeeDocumentRecord>> getMyDocuments() async {
    final res = await _client.get('/EmployeeApp/GetMyDocuments');
    return (res.data as List).cast<Map<String, dynamic>>().map(EmployeeDocumentRecord.fromJson).toList();
  }

  /// A real PDF, not JSON — meant to be handed to url_launcher so it opens in the device's own
  /// browser/PDF viewer (this app has no in-app PDF viewer). The token travels as a query param since
  /// an externally-launched URL can't carry the X-Auth-Token header ApiClient normally attaches.
  String downloadUrl(int documentId) {
    return '${ApiConfig.baseUrl}/EmployeeApp/DownloadMyDocument?documentId=$documentId&token=${_client.token}';
  }
}
