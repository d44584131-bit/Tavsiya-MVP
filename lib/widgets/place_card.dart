class PlaceCardData {
  final String id;
  final String name;
  final String category; // 'restaurant' | 'cafe' | 'park' | 'mall'
  final double rating;
  final int reviewsCount;
  final String district;
  final String? status; // 'pending' | 'rejected' | null (= approved)
  final bool isChain; // сеть заведений — несколько филиалов у одного профиля
  final List<String> branches; // адреса филиалов, заполнено только у сетей

  const PlaceCardData({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.district,
    this.status,
    this.isChain = false,
    this.branches = const [],
  });
}
