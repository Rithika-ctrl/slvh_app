/// Category Model
/// 
/// Represents a product category in the SLVH Smart Shop.
/// Each category can contain multiple products.

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert Firestore document to CategoryModel
  factory CategoryModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return CategoryModel(
      id: docId,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      sortOrder: data['sortOrder'] as int? ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert CategoryModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Create a copy with updated fields
  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
