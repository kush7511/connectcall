/// Firestore collection names, kept in one place so a rename
/// only touches one file.
class FirestoreCollections {
  static const users = 'users';
  static const calls = 'calls';
  static const callHistory = 'call_history';
}

/// Enum-like string constants for call type / status, mirrored
/// in CallModel. Kept as plain strings because they're stored
/// directly in Firestore documents.
class CallType {
  static const audio = 'audio';
  static const video = 'video';
}

class CallStatus {
  static const calling = 'calling'; // caller is dialing
  static const ringing = 'ringing'; // callee's phone is ringing
  static const connected = 'connected';
  static const ended = 'ended';
  static const rejected = 'rejected';
  static const missed = 'missed';
  static const busy = 'busy';
  static const failed = 'failed';
}

class AppConstants {
  static const appName = 'ConnectCall';
  static const tagline = 'Connect with anyone, anywhere.';
}
