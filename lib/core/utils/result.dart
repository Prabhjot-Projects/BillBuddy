/// A generic success/failure wrapper used across services and processes.
///
/// Why this exists: several parts of the pipeline (OCR, AI parsing, image
/// decoding) can fail in ways the caller needs to react to differently —
/// e.g. "OCR returned nothing" should show a retake prompt, while
/// "network timeout calling Gemini" should offer a retry. Swallowing
/// exceptions into a string (the old pattern) hid these differences and
/// let error text silently flow into downstream logic as if it were data.
///
/// `Result<T>` forces callers to explicitly branch on success vs failure
/// via pattern matching (`switch`), so a failure can never be
/// accidentally treated as valid data.
sealed class Result<T> {
  const Result();

  factory Result.success(T value) = Success<T>;
  factory Result.failure(AppFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Returns the success value, or null if this is a failure.
  T? get valueOrNull => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };

  /// Transforms the success value, passing failures through unchanged.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(value: final v) => Result.success(transform(v)),
      Failure<T>(failure: final f) => Result.failure(f),
    };
  }

  /// Chains another Result-returning operation, short-circuiting on failure.
  /// This is what lets us compose OCR -> validate -> parse without
  /// nested try/catch at every step.
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    return switch (this) {
      Success<T>(value: final v) => await transform(v),
      Failure<T>(failure: final f) => Result.failure(f),
    };
  }

  /// Pattern-match both branches at once. Forces the caller to handle
  /// both cases explicitly rather than checking isSuccess and forgetting
  /// the else branch.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => onSuccess(v),
      Failure<T>(failure: final f) => onFailure(f),
    };
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}

/// Categorized failure reasons. Using an enum + message (rather than raw
/// exception objects) keeps the UI layer decoupled from *which* package
/// threw the error — the UI only needs to know the category to decide
/// what to show the user (retry button? retake photo? contact support?).
enum FailureType {
  cameraError,
  ocrFailed,
  emptyText,
  invalidReceiptFormat,
  aiParsingFailed,
  aiResponseMalformed,
  networkError,
  storageError,
  unknown,
}

class AppFailure {
  final FailureType type;
  final String message;
  final Object? cause;

  const AppFailure({required this.type, required this.message, this.cause});

  @override
  String toString() => 'AppFailure($type): $message';
}
