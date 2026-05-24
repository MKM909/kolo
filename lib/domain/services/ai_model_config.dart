const defaultGeminiModelName = 'gemini-3.1-flash-lite';

const koloAiModelOptions = [
  AiModelOption(
    label: 'Gemini 3.1 Flash Lite',
    modelName: defaultGeminiModelName,
    description: 'Fastest and cheapest default for everyday Kolo guidance.',
  ),
  AiModelOption(
    label: 'Gemini 3.1 Flash',
    modelName: 'gemini-3.1-flash',
    description: 'Balanced reasoning for fuller budget and spending chats.',
  ),
  AiModelOption(
    label: 'Gemini 3.1 Pro',
    modelName: 'gemini-3.1-pro',
    description: 'Deeper reasoning for complex planning and reviews.',
  ),
];

class AiModelOption {
  const AiModelOption({
    required this.label,
    required this.modelName,
    required this.description,
  });

  final String label;
  final String modelName;
  final String description;
}

String koloAiModelNameOrDefault(String? modelName) {
  for (final option in koloAiModelOptions) {
    if (option.modelName == modelName) return option.modelName;
  }
  return defaultGeminiModelName;
}

String koloAiModelLabel(String? modelName) {
  final selected = koloAiModelNameOrDefault(modelName);
  for (final option in koloAiModelOptions) {
    if (option.modelName == selected) return option.label;
  }
  return koloAiModelOptions.first.label;
}

String koloAiModelKeySlug(String modelName) {
  return modelName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'(^_|_$)'), '');
}
