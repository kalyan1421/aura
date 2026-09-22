/// Avatar evolution stages (RULES.md section 4). Stages never regress.
enum AuraStage {
  spark(0),
  ember(100),
  glow(400),
  radiance(1200),
  constellation(3000);

  const AuraStage(this.threshold);

  /// All-time Starlight at which this stage begins.
  final int threshold;

  /// The next stage, or `null` at [constellation].
  AuraStage? get next =>
      index + 1 < AuraStage.values.length ? AuraStage.values[index + 1] : null;

  /// Parses a wire name (`spark` … `constellation`); unknown → [spark].
  static AuraStage fromName(String? name) => AuraStage.values.firstWhere(
    (s) => s.name == name,
    orElse: () => AuraStage.spark,
  );

  /// The later of two stages (used so the shown stage never regresses).
  AuraStage atLeast(AuraStage other) => index >= other.index ? this : other;
}
