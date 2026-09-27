import '../core/api_client.dart';
import '../models/models.dart';

class VisitService {
  final _client = ApiClient.instance;

  Future<List<VisitAssignment>> getMyVisitAssignments() async {
    final res = await _client.get('/EmployeeApp/GetMyVisitAssignments');
    return (res.data as List).cast<Map<String, dynamic>>().map(VisitAssignment.fromJson).toList();
  }

  Future<TripDetail?> getTripDetail(int tripId) async {
    final res = await _client.get('/EmployeeApp/GetTripDetail', query: {'tripId': tripId});
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : TripDetail.fromJson(list.first);
  }

  Future<List<TripPing>> getTripPings(int tripId) async {
    final res = await _client.get('/EmployeeApp/GetTripPings', query: {'tripId': tripId});
    return (res.data as List).cast<Map<String, dynamic>>().map(TripPing.fromJson).toList();
  }

  Future<Map<String, dynamic>> startTrip(int assignmentId, double? lat, double? lng) async {
    final res = await _client.post('/EmployeeApp/StartTrip', data: {
      'assignmentId': assignmentId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not start trip.'));
    }
    return data;
  }

  Future<void> endTrip(int tripId, double? lat, double? lng) async {
    final res = await _client.post('/EmployeeApp/EndTrip', data: {
      'tripId': tripId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not end trip.'));
    }
  }

  Future<void> saveTripPing(int tripId, double lat, double lng) async {
    await _client.post('/EmployeeApp/SaveTripPing', data: {'tripId': tripId, 'lat': lat, 'lng': lng});
  }

  // Battery-friendly tracking (2026-09-27): flushes a whole batch of locally-cached pings in one call —
  // pingsJson is a JSON-encoded array of {"lat":..,"lng":..,"capturedOn":"..."} objects, each keeping the
  // timestamp it was actually captured at on the phone. Best-effort by design (caller decides what to do
  // with the cached rows on failure — normally just leave them cached and retry next cycle).
  Future<void> saveTripPingsBatch(int tripId, String pingsJson) async {
    await _client.post('/EmployeeApp/SaveTripPingsBatch', data: {'tripId': tripId, 'pingsJson': pingsJson});
  }

  // anomalyType: 'LocationOff' | 'NetworkOff'. Fired the instant the app detects GPS/connectivity dropped
  // while a trip is InProgress — notifies admins server-side (once per open anomaly, not once per call).
  Future<void> reportTripAnomaly(int tripId, String anomalyType) async {
    await _client.post('/EmployeeApp/ReportTripAnomaly', data: {'tripId': tripId, 'anomalyType': anomalyType});
  }

  Future<void> resolveTripAnomaly(int tripId, String anomalyType) async {
    await _client.post('/EmployeeApp/ResolveTripAnomaly', data: {'tripId': tripId, 'anomalyType': anomalyType});
  }

  Future<void> updateTripTaskStatus(int tripId, String taskStatusId) async {
    final res = await _client.post('/EmployeeApp/UpdateTripTaskStatus', data: {'tripId': tripId, 'taskStatusId': taskStatusId});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update task status.'));
    }
  }

  Future<void> submitTripExpense({
    required int tripId,
    required String expenseDate,
    String? category,
    String? description,
    required double amount,
  }) async {
    final res = await _client.post('/EmployeeApp/SubmitTripExpense', data: {
      'TripID': tripId,
      'ExpenseDate': expenseDate,
      if (category != null) 'Category': category,
      if (description != null) 'Description': description,
      'Amount': amount,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not add expense.'));
    }
  }

  // ---- Admin ----

  Future<List<VisitAssignment>> getVisitAssignmentAdminList({String? search, String? statusId}) async {
    final res = await _client.get('/EmployeeApp/GetVisitAssignmentAdminList', query: {
      if (search != null) 'search': search,
      if (statusId != null) 'statusId': statusId,
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(VisitAssignment.fromJson).toList();
  }

  Future<void> saveVisitAssignment({
    required int employeeId,
    required String title,
    String? notes,
    required double destinationLat,
    required double destinationLng,
    String? destinationAddress,
    String? scheduledDate,
  }) async {
    final res = await _client.post('/EmployeeApp/SaveVisitAssignment', data: {
      'EmployeeID': employeeId,
      'Title': title,
      if (notes != null) 'Notes': notes,
      'DestinationLat': destinationLat,
      'DestinationLng': destinationLng,
      if (destinationAddress != null) 'DestinationAddress': destinationAddress,
      if (scheduledDate != null) 'ScheduledDate': scheduledDate,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not assign visit.'));
    }
  }

  Future<void> deleteVisitAssignment(int id) async {
    final res = await _client.post('/EmployeeApp/DeleteVisitAssignment', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not delete visit.'));
    }
  }

  // Admin-initiated reminder — nudges the employee assigned to this visit.
  Future<void> sendReminder(int assignmentId) async {
    final res = await _client.post('/EmployeeApp/SendVisitReminder', data: {'id': assignmentId});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not send reminder.'));
    }
  }

  Future<List<ActiveTrip>> getActiveTripsForTracking() async {
    final res = await _client.get('/EmployeeApp/GetActiveTripsForTracking');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(ActiveTrip.fromJson).toList();
  }

  Future<List<TripPing>> getTripPingsAdmin(int tripId) async {
    final res = await _client.get('/EmployeeApp/GetTripPingsAdmin', query: {'tripId': tripId});
    return (res.data as List).cast<Map<String, dynamic>>().map(TripPing.fromJson).toList();
  }
}
