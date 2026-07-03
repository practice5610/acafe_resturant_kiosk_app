class ReviewModel {
  Reviews? reviews;
  Rating? rating;

  ReviewModel({this.reviews, this.rating});

  ReviewModel.fromJson(Map<String, dynamic> json) {
    reviews = json['reviews'] != null ? Reviews.fromJson(json['reviews']) : null;
    rating = json['rating_info'] != null ? Rating.fromJson(json['rating_info']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (reviews != null) {
      data['reviews'] = reviews!.toJson();
    }
    if (rating != null) {
      data['rating_info'] = rating!.toJson();
    }
    return data;
  }
}

class Reviews {
  List<Review>? reviewList;
  int? totalSize;
  int? limit;
  int? offset;

  Reviews(
      {this.reviewList,
        this.totalSize,
        this.limit,
        this.offset});

  Reviews.fromJson(Map<String, dynamic> json) {
    if (json['reviews'] != null) {
      reviewList = <Review>[];
      json['reviews'].forEach((v) {
        reviewList!.add(Review.fromJson(v));
      });
    }
    totalSize = int.tryParse('${json['total_size']}');
    limit = int.tryParse('${json['limit']}');
    offset = int.tryParse('${json['offset']}');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (reviewList != null) {
      data['reviews'] = reviewList!.map((v) => v.toJson()).toList();
    }
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['limit'] = limit;
    return data;
  }
}


class Review {
  int? id;
  int? productId;
  int? userId;
  String? comment;
  List<String>? attachment;
  int? rating;
  String? createdAt;
  String? updatedAt;
  int? orderId;

  Review(
      {this.id,
        this.productId,
        this.userId,
        this.comment,
        this.attachment,
        this.rating,
        this.createdAt,
        this.updatedAt,
        this.orderId});

  Review.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    productId = json['product_id'];
    userId = json['user_id'];
    comment = json['comment'];
    attachment = json['attachment'].cast<String>();
    rating = json['rating'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    orderId = json['order_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_id'] = productId;
    data['user_id'] = userId;
    data['comment'] = comment;
    data['attachment'] = attachment;
    data['rating'] = rating;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['order_id'] = orderId;
    return data;
  }
}



class Rating {
  int ? ratingCount;
  double? averageRating;
  List<RatingGroupCount>? ratingGroupCount;

  Rating({this.ratingCount, this.averageRating, this.ratingGroupCount});

  Rating.fromJson(Map<String, dynamic> json) {
    ratingCount = int.tryParse(json['total_review'].toString());
    averageRating = double.tryParse(json['average_rating'].toString());
    if (json['rating_group_count'] != null) {
      ratingGroupCount = <RatingGroupCount>[];
      json['rating_group_count'].forEach((v) {
        ratingGroupCount!.add(RatingGroupCount.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['rating_review'] = ratingCount;
    data['average_rating'] = averageRating;
    if (ratingGroupCount != null) {
      data['rating_group_count'] =
          ratingGroupCount!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class RatingGroupCount {
  double? reviewRating;
  int? total;

  RatingGroupCount({this.reviewRating, this.total});

  RatingGroupCount.fromJson(Map<String, dynamic> json) {
    reviewRating = json['rating'] != null ? double.parse(json['rating'].toString()) : null;
    total = json['total'] != null ? int.parse(json['total'].toString()) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['rating'] = reviewRating;
    data['total'] = total;
    return data;
  }
}