class ActionResult<T> {
  final bool ok;
  final bool cancelled;
  final String? message;
  final T? data;

  const ActionResult._({
    required this.ok,
    required this.cancelled,
    this.message,
    this.data,
  });

  const ActionResult.success([T? data])
      : this._(ok: true, cancelled: false, data: data);

  const ActionResult.failure([String? message])
      : this._(ok: false, cancelled: false, message: message);

  const ActionResult.cancelled()
      : this._(ok: false, cancelled: true);
}
