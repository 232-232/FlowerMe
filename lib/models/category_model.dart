class CategoryModel {
  const CategoryModel({
    required this.code,
    required this.name,
    this.picUrl,
    this.ratingKey = 999,
  });

  final String code;
  final String name;
  final String? picUrl;
  final int ratingKey;

  factory CategoryModel.fromSnapshot(String code, Map<Object?, Object?> data) {
    final ratingKeyRaw = data['ratingKey'];
    final ratingKey = ratingKeyRaw != null ? (int.tryParse(ratingKeyRaw.toString()) ?? 999) : 999;
    
    return CategoryModel(
      code: code,
      name: (data['name'] as String?) ?? code,
      picUrl: data['pic'] as String?,
      ratingKey: ratingKey,
    );
  }
}
