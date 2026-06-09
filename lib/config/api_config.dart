import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String baseUrl = 'http://rasa04.runasp.net';
static String get apiKey =>
      dotenv.env['OPENWEATHER_API_KEY'] ?? '';

      
  static const String firebaseRegister =
      '$baseUrl/api/auth/firebase/register';

  static const String firebaseLogin =
      '$baseUrl/api/auth/firebase/login';

  static const String profile =
      '$baseUrl/api/users/profile';

  static const String dashboardElderly =
      '$baseUrl/api/dashboard/elderly';

  static const String dashboardFamily =
      '$baseUrl/api/dashboard/family';


      // CONNECTIONS
static const String createConnection =
    '$baseUrl/api/connections';

static const String incomingConnections =
    '$baseUrl/api/connections/incoming';

static const String connectedFamilies =
    '$baseUrl/api/connections/families';

static const String connectedElderlies =
    '$baseUrl/api/connections/elderlies';

static String updateConnection(String connectionId) {
  return '$baseUrl/api/connections/$connectionId';
}

// ACTIVITIES
static const String createActivity =
    '$baseUrl/api/activities';

static String latestActivity(String elderlyId) {
  return '$baseUrl/api/elderlies/$elderlyId/activities/latest';
}

// ALERTS
static const String createAlert =
    '$baseUrl/api/alerts';

static String elderlyAlerts(String elderlyId) {
  return '$baseUrl/api/elderlies/$elderlyId/alerts';
}

// NOTIFICATIONS
static const String notificationToken =
    '$baseUrl/api/notifications/token';

//LOCATIONS
static const String createLocation =
    '$baseUrl/api/locations';

static String latestLocation(String elderlyId) {
  return '$baseUrl/api/elderlies/$elderlyId/locations/latest';

}

// ENVIRONMENT RECORDS
  static const String createEnvironmentRecord =
      '$baseUrl/api/environment-records';

  static String latestEnvironment(String elderlyId) {
    return '$baseUrl/api/elderlies/$elderlyId/environment-records/latest';
  }
}