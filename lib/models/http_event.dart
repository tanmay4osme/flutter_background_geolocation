part of flt_background_geolocation;

/// Event object provided to [BackgroundGeolocation.onHttp].
///
/// ## Example
///
/// ```dart
/// BackgroundGeolocation.onHttp((HttpEvent response) {
///   print('[http] success? ${response.success}, status? ${response.status}');
/// });
/// ```
///
/// # HTTP Guide
///
/// The [BackgroundGeolocation] SDK hosts its own flexible and robust native HTTP & SQLite persistence services.  To enable the HTTP service, simply configure the SDK with an [Config.url]:
///
/// ```dart
/// BackgroundGeolocation.ready(Config(
///   url: "https://my-server.com/locations",
///   autoSync: true,
///   autoSyncThreshold: 5,
///   batchSync: true,
///   maxBatchSize: 50,
///   headers: {
///     "AUTHENTICATION_TOKEN": "23kasdlfkjlksjflkasdZIds"
///   },
///   params: {
///     "user_id": 1234
///   },
///   extras: {
///     "route_id": 8675309
///   },
///   locationsOrderDirection: "DESC",
///   maxDaysToPersist: 14
/// )).then((State state) {
///   print('[ready] success: ${state}');
/// });
/// ```
///
/// ## The SQLite Database
///
/// The SDK immediately inserts each recorded location into its SQLite database.  This database is designed to act as a temporary buffer for the HTTP service and the SDK __strongly__ desires an *empty* database.  The only way that locations are destroyed from the database are:
/// - Successful HTTP response from your server (`200`, `201`, `204`).
/// - Executing [BackgroundGeolocation.destroyLocations].
/// - [Config.maxDaysToPersist] elapses and the location is destroyed.
/// - [Config.maxRecordsToPersist] destroys oldest record in favor of latest.
///
/// ## The HTTP Service
///
/// The SDK's HTTP service operates by selecting records from the database, locking them to prevent duplicate requests then uploading to your server.
/// - By default, the HTTP Service will select a single record (oldest first; see [Config.locationsOrderDirection]) and execute an HTTP request to your [Config.url].
/// - Each HTTP request is *synchronous* &mdash; the HTTP service will await the response from your server before selecting and uploading another record.
/// - If your server returns an error or doesn't respond, the HTTP Service will immediately **halt**.
/// - Configuring [Config.batchSync] __`true`__ instructs the HTTP Service to select *all* records in the database and upload them to your server in a single HTTP request.
/// - Use [Config.maxBatchSize] to limit the number of records selected for each [Config.batchSync] request.  The HTTP service will execute *synchronous* HTTP *batch* requests until the database is empty.
///
/// ## HTTP Failures
///
/// If your server does *not* return a `20x` response (eg: `200`, `201`, `204`), the SDK will __`UNLOCK`__ that record.  Another attempt to upload will be made in the future (until [Config.maxDaysToPersist]) when:
/// - When another location is recorded.
/// - Application `pause` / `resume` events.
/// - Application boot.
/// - [BackgroundGeolocation.onHeartbeat] events.
/// - [BackgroundGeolocation.onConnectivityChange] events.
/// - __iOS__ Background `fetch` events.
///
/// ```dart
/// BackgroundGeolocation.onHttp((HttpEvent response) {
///   if (!response.success) {
///     print('[onHttp] failure: ${response.status}, ${response.responseText}');
///   }
/// });
/// ```
///
/// ## Receiving the HTTP Response.
///
/// You can capture the HTTP response from your server by listening to the [BackgroundGeolocation.onHttp] event.
///
/// ## [Config.autoSync]
///
/// By default, the SDK will attempt to immediately upload each recorded location to your configured [Config.url].
/// - Use [Config.autoSyncThreshold] to throttle HTTP requests.  This will instruct the SDK to accumulate that number of records in the database before calling upon the HTTP Service.  This is a good way to **conserve battery**, since HTTP requests consume more energy/second than the GPS.
///
/// ----------------------------------------------------------------------
///
/// ⚠️ Warning:  [Config.autoSyncThreshold]
///
/// If you've configured [Config.autoSyncThreshold], it **will be ignored** during a [BackgroundGeolocation.onMotionChange] event &mdash; all queued locations will be uploaded, since:
/// - If an `onMotionChange` event fires **into the *moving* state**, the device may have been sitting dormant for a long period of time.  The plugin is *eager* to upload this state-change to the server as soon as possible.
/// - If an `onMotionChange` event fires **into the *stationary* state**, the device may be *about to* lie dormant for a long period of time.  The plugin is *eager* to upload all queued locations to the server before going dormant.
/// ----------------------------------------------------------------------
///
/// ## Manual [BackgroundGeolocation.sync]
///
/// The SDK's HTTP Service can be summoned into action at __any time__ via the method [BackgroundGeolocation.sync].
///
/// ## [Config.params], [Config.headers] and [Config.extras]
///
/// - The SDK's HTTP Service appends configured [Config.params] to root of the `JSON` data of each HTTP request.
/// - [Config.headers] are appended to each HTTP Request.
/// - [Config.extras] are appended to each recorded location and persisted to the database record.
///
/// ## Custom `JSON` Schema:  [Config.locationTemplate] and [Config.geofenceTemplate]
///
/// The default HTTP `JSON` schema for both [Location] and [Geofence] can be overridden by the configuration options [Config.locationTemplate] and [Config.geofenceTemplate], allowing you to create any schema you wish.
///
/// ## Disabling HTTP requests on Cellular connections
///
/// If you're concerned with Cellular data-usage, you can configure the plugin's HTTP Service to upload only when connected to Wifi:
///
/// ```dart
/// BackgroundGeolocation.ready(Config(
///   autoSync: true,
///   disableAutoSyncOnCellular: true
/// ));
/// ```
///
/// ## HTTP Logging
///
/// You can observe the plugin performing HTTP requests in the logs for both iOS and Android (_See Wiki [Debugging](https://github.com/transistorsoft/flutter_background_geolocation/wiki/Debugging):
///
/// ### Example
/// ```
/// ╔═════════════════════════════════════════════
/// ║ LocationService: location
/// ╠═════════════════════════════════════════════
/// ╟─ 📍 Location[45.519199,-73.617054]
/// ✅ INSERT: 70727f8b-df7d-48d0-acbd-15f10cacdf33
/// ╔═════════════════════════════════════════════
/// ║ HTTP Service
/// ╠═════════════════════════════════════════════
/// ✅ Locked 1 records
/// 🔵 HTTP POST: 70727f8b-df7d-48d0-acbd-15f10cacdf33
/// 🔵 Response: 200
/// ✅ DESTROY: 70727f8b-df7d-48d0-acbd-15f10cacdf33
/// ```
///
/// |#| Log entry               | Description                                                           |
/// |-|-------------------------|-----------------------------------------------------------------------|
/// |1| `📍Location`            | Location received from native Location API.                           |
/// |2| `✅INSERT`              | Location record inserted into SDK's SQLite database.                  |
/// |3| `✅Locked`              | SDK's HTTP service locks a record (to prevent duplicate HTTP uploads).|
/// |4| `🔵HTTP POST`           | SDK's HTTP service attempts an HTTP request to your configured `url`. |
/// |5| `🔵Response`            | Response from your server.                                            |
/// |6| `✅DESTROY|UNLOCK`      | After your server returns a __`20x`__ response, the SDK deletes that record from the database.  Otherwise, the SDK will __`UNLOCK`__ that record and try again in the future. |
///
class HttpEvent {
  /// `true` if the HTTP response was successful (`200`, `201`, `204`).
  bool success;

  /// HTTP response status.
  int status;

  /// HTTP response text.
  String responseText;

  HttpEvent(dynamic params) {
    this.success = params['success'];
    this.status = params['status'];
    this.responseText = params['responseText'];
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'status': status,
      'responseText': (responseText.length > 100)
          ? (responseText.substring(0, 100) + '...')
          : responseText
    };
  }

  String toString() {
    return "[HttpEvent " + toMap().toString() + "]";
  }
}
