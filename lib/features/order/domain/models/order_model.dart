import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/helper/json_parser_helper.dart';

class OrderModel {
  int? totalSize;
  int? limit;
  int? offset;
  List<Order>? orderList;

  OrderModel({this.totalSize, this.limit, this.offset, this.orderList});

  OrderModel.fromJson(Map<String, dynamic> json) {
    totalSize = int.tryParse(json['total_size'].toString());
    limit = int.tryParse(json['limit'].toString());
    offset = int.tryParse(json['offset'].toString());
    if (json['orders'] != null) {
      orderList = <Order>[];
      for (final dynamic v in json['orders']) {
        try {
          orderList!.add(Order.fromJson(Map<String, dynamic>.from(v as Map)));
        } catch (error, stack) {
          debugPrint('OrderModel: failed to parse order: $error\n$stack');
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_size'] = totalSize;
    data['limit'] = limit;
    data['offset'] = offset;
    if (orderList != null) {
      data['orders'] = orderList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}


class Order {
  int? _id;
  int? _userId;
  double? _orderAmount;
  double? _couponDiscountAmount;
  String? _couponDiscountTitle;
  String? _paymentStatus;
  String? _orderStatus;
  double? _totalTaxAmount;
  String? _paymentMethod;
  String? _transactionReference;
  int? _deliveryAddressId;
  String? _createdAt;
  String? _updatedAt;
  int? _deliveryManId;
  double? _deliveryCharge;
  String? _orderNote;
  List<int>? _addOnIds;
  List<Details>? _details;
  DeliveryMan? _deliveryMan;
  int? _detailsCount;
  String? _orderType;
  String? _deliveryTime;
  String? _deliveryDate;
  double? _extraDiscount;
  DeliveryAddress? _deliveryAddress;
  String? _preparationTime;
  bool? _isProductAvailable;
  List<OrderPartialPayment>? _orderPartialPayments;
  bool? _isGuest;
  bool? _isCutlery;
  List<String>? _productImageList;
  Branches? _branches;
  OfflinePaymentInformation? _offlinePaymentInformation;
  OrderChangeAmount? _orderChangeAmount;
  double? _bringChangeAmount;
  double? _referralDiscount;




  Order(
      {int? id,
        int? userId,
        double? orderAmount,
        double? couponDiscountAmount,
        String? couponDiscountTitle,
        String? paymentStatus,
        String? orderStatus,
        double? totalTaxAmount,
        String? paymentMethod,
        String? transactionReference,
        int? deliveryAddressId,
        String? createdAt,
        String? updatedAt,
        String? checked,
        int? deliveryManId,
        double? deliveryCharge,
        String? orderNote,
        List<int>? addOnIds,
        List<Details>? details,
        DeliveryMan? deliveryMan,
        int? detailsCount,
        String? deliveryTime,
        String? deliveryDate,
        String? orderType,
        double? extraDiscount,
        DeliveryAddress? deliveryAddress,
        String? preparationTime,
        bool? isProductAvailable,
        List<OrderPartialPayment>? orderPartialPayments,
        bool? isGuest,
        bool? isCutlery,
        List<String>? productImageList,
        Branches? branches,
        OfflinePaymentInformation? offlinePaymentInformation,
        OrderChangeAmount? orderChangeAmount,
        double? bringChangeAmount,
        double? referralDiscount,

      }) {
    _id = id;
    _userId = userId;
    _orderAmount = orderAmount;
    _couponDiscountAmount = couponDiscountAmount;
    _couponDiscountTitle = couponDiscountTitle;
    _paymentStatus = paymentStatus;
    _orderStatus = orderStatus;
    _totalTaxAmount = totalTaxAmount;
    _paymentMethod = paymentMethod;
    _transactionReference = transactionReference;
    _deliveryAddressId = deliveryAddressId;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _deliveryManId = deliveryManId;
    _deliveryCharge = deliveryCharge;
    _orderNote = orderNote;
    _addOnIds = addOnIds;
    _details = details;
    _deliveryMan = deliveryMan;
    _detailsCount = detailsCount;
    _orderType = orderType;
    _deliveryTime = deliveryTime;
    _deliveryDate = deliveryDate;
    _extraDiscount = extraDiscount;
    _deliveryAddress = deliveryAddress;
    _preparationTime = preparationTime;
    _isProductAvailable = isProductAvailable;
    _orderPartialPayments = orderPartialPayments;
    _isGuest = isGuest;
    _isCutlery = isCutlery;
    _productImageList = productImageList;
    _branches = branches;
    _offlinePaymentInformation = offlinePaymentInformation;
    _orderChangeAmount = orderChangeAmount;
    _bringChangeAmount = bringChangeAmount;
    _referralDiscount = referralDiscount;

  }

  int? get id => _id;
  int? get userId => _userId;
  double? get orderAmount => _orderAmount;
  double? get couponDiscountAmount => _couponDiscountAmount;
  String? get couponDiscountTitle => _couponDiscountTitle;
  String? get paymentStatus => _paymentStatus;
  String? get orderStatus => _orderStatus;
  double? get totalTaxAmount => _totalTaxAmount;
  // ignore: unnecessary_getters_setters
  String? get paymentMethod => _paymentMethod;
  // ignore: unnecessary_getters_setters
  set paymentMethod(String? method) => _paymentMethod = method;
  String? get transactionReference => _transactionReference;
  int? get deliveryAddressId => _deliveryAddressId;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  int? get deliveryManId => _deliveryManId;
  double? get deliveryCharge => _deliveryCharge;
  String? get orderNote => _orderNote;
  List<int>? get addOnIds => _addOnIds;
  List<Details>? get details => _details;
  DeliveryMan? get deliveryMan => _deliveryMan;
  int? get detailsCount => _detailsCount;
  String? get orderType => _orderType;
  String? get deliveryTime => _deliveryTime;
  String? get deliveryDate => _deliveryDate;
  double? get extraDiscount => _extraDiscount;
  DeliveryAddress? get deliveryAddress => _deliveryAddress;
  String? get preparationTime => _preparationTime;
  bool? get isProductAvailable => _isProductAvailable;
  List<OrderPartialPayment>? get orderPartialPayments => _orderPartialPayments;
  bool? get isGuest => _isGuest;
  bool? get isCutlery => _isCutlery;
  List<String>? get productImageList => _productImageList;
  Branches? get branches => _branches;
  OfflinePaymentInformation? get offlinePaymentInformation => _offlinePaymentInformation;
  OrderChangeAmount? get orderChangeAmount => _orderChangeAmount;
  double? get bringChangeAmount => _bringChangeAmount;
  double? get referralDiscount => _referralDiscount;



  Order.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _userId = json['user_id'];
    _orderAmount = parseJsonDouble(json['order_amount']);
    _couponDiscountAmount = parseJsonDouble(json['coupon_discount_amount']);
    _couponDiscountTitle = json['coupon_discount_title'];
    _paymentStatus = json['payment_status'];
    _orderStatus = json['order_status'];
    _totalTaxAmount = parseJsonDouble(json['total_tax_amount']);
    _paymentMethod = json['payment_method'];
    _transactionReference = json['transaction_reference'];
    _deliveryAddressId = json['delivery_address_id'];
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _deliveryManId = json['delivery_man_id'];
    _deliveryCharge = parseJsonDouble(json['delivery_charge']);
    _orderNote = json['order_note'];
    _detailsCount = json['details_count'];
    if(json['add_on_ids'] != null) {
      _addOnIds = json['add_on_ids'].cast<int>();
    }
    if (json['details'] != null) {
      _details = [];
      json['details'].forEach((v) {
        _details!.add(Details.fromJson(v));
      });
    }
    _deliveryMan = json['delivery_man'] != null
        ? DeliveryMan.fromJson(json['delivery_man'])
        : null;
    _orderType = json['order_type'];
    _deliveryTime = json['delivery_time'];
    _deliveryDate = json['delivery_date'];
    if(json['extra_discount'] != null){
      try{
        _extraDiscount = double.parse(json['extra_discount']);
      }catch(e){
        _extraDiscount = json['extra_discount'];
      }
    }
    _deliveryAddress = json['delivery_address'] != null
        ? DeliveryAddress.fromJson(json['delivery_address'])
        : null;
    _preparationTime = json['preparation_time'].toString();
   // print('order pre time -- $_preparationTime');
    _isProductAvailable = int.tryParse('${json['is_product_available']}') == 1 ? true : false;
    try{
      _orderPartialPayments = json["order_partial_payments"] == null ? [] : List<OrderPartialPayment>.from(json["order_partial_payments"]!.map((x) => OrderPartialPayment.fromMap(x)));

    }catch(error){
      debugPrint('order model-> _orderPartialPayments $error');
    }
    _isGuest = '${json["is_guest"]}'.contains('1');
    _isCutlery = '${json["is_cutlery_required"]}'.contains('1');
    _productImageList = json.containsKey('product_images') ? json['product_images'].cast<String>() : null;

    if(json['branch'] != null) {
      _branches = Branches.fromJson(json['branch']);
    }
    _offlinePaymentInformation = json["offline_payment_information"] == null
        ? null : OfflinePaymentInformation.fromMap(json["offline_payment_information"]);

    _orderChangeAmount = json["order_change_amount"] == null
        ? null : OrderChangeAmount.fromJson(json["order_change_amount"]);
    _bringChangeAmount = double.tryParse( json['bring_change_amount'].toString());
    _referralDiscount = double.tryParse( json['referral_discount'].toString());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['user_id'] = _userId;
    data['order_amount'] = _orderAmount;
    data['coupon_discount_amount'] = _couponDiscountAmount;
    data['coupon_discount_title'] = _couponDiscountTitle;
    data['payment_status'] = _paymentStatus;
    data['order_status'] = _orderStatus;
    data['total_tax_amount'] = _totalTaxAmount;
    data['payment_method'] = _paymentMethod;
    data['transaction_reference'] = _transactionReference;
    data['delivery_address_id'] = _deliveryAddressId;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['delivery_man_id'] = _deliveryManId;
    data['delivery_charge'] = _deliveryCharge;
    data['order_note'] = _orderNote;
    data['add_on_ids'] = _addOnIds;
    data['details_count'] = _detailsCount;
    if (_details != null) {
      data['details'] = _details!.map((v) => v.toJson()).toList();
    }
    if (_deliveryMan != null) {
      data['delivery_man'] = _deliveryMan!.toJson();
    }
    data['order_type'] = _orderType;
    data['delivery_time'] = _deliveryTime;
    data['delivery_date'] = _deliveryDate;
    data['extra_discount'] = _extraDiscount;
    if (_deliveryAddress != null) {
      data['delivery_address'] = _deliveryAddress!.toJson();
    }
    data['order_partial_payments'] = _orderPartialPayments;
    data['is_cutlery_required'] = _isCutlery;
    data['bring_change_amount'] = _bringChangeAmount;
    data['referral_discount'] = _referralDiscount;
    return data;
  }
}
class DeliveryAddress {
  int? _id;
  String? _addressType;
  String? _contactPersonNumber;
  String? _address;
  double? _latitude;
  double? _longitude;
  String? _createdAt;
  String? _updatedAt;
  int? _userId;
  String? _contactPersonName;

  DeliveryAddress(
      {int? id,
        String? addressType,
        String? contactPersonNumber,
        String? address,
        double? latitude,
        double? longitude,
        String? createdAt,
        String? updatedAt,
        int? userId,
        String? contactPersonName}) {
    _id = id;
    _addressType = addressType;
    _contactPersonNumber = contactPersonNumber;
    _address = address;
    _latitude = latitude;
    _longitude = longitude;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _userId = userId;
    _contactPersonName = contactPersonName;
  }

  int? get id => _id;
  String? get addressType => _addressType;
  String? get contactPersonNumber => _contactPersonNumber;
  String? get address => _address;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  int? get userId => _userId;
  String? get contactPersonName => _contactPersonName;

  DeliveryAddress.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _addressType = json['address_type'];
    _contactPersonNumber = json['contact_person_number'];
    _address = json['address'];
    _latitude = double.tryParse(json['latitude'].toString());
    _longitude = double.tryParse(json['longitude'].toString());
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _userId = json['user_id'];
    _contactPersonName = json['contact_person_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['address_type'] = _addressType;
    data['contact_person_number'] = _contactPersonNumber;
    data['address'] = _address;
    data['latitude'] = _latitude;
    data['longitude'] = _longitude;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['user_id'] = _userId;
    data['contact_person_name'] = _contactPersonName;
    return data;
  }
}

class Details {
  int? _id;
  int? _productId;
  int? _orderId;
  double? _price;
  double? _discountOnProduct;
  String? _discountType;
  int? _quantity;
  double? _taxAmount;
  String? _createdAt;
  String? _updatedAt;

  Details(
      {int? id,
        int? productId,
        int? orderId,
        double? price,
        String? productDetails,
        double? discountOnProduct,
        String? discountType,
        int? quantity,
        double? taxAmount,
        String? createdAt,
        String? updatedAt,
        String? addOnIds,
        String? variant}) {
    _id = id;
    _productId = productId;
    _orderId = orderId;
    _price = price;
    _discountOnProduct = discountOnProduct;
    _discountType = discountType;
    _quantity = quantity;
    _taxAmount = taxAmount;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
  }

  int? get id => _id;
  int? get productId => _productId;
  int? get orderId => _orderId;
  double? get price => _price;
  double? get discountOnProduct => _discountOnProduct;
  String? get discountType => _discountType;
  int? get quantity => _quantity;
  double? get taxAmount => _taxAmount;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;

  Details.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _productId = json['product_id'];
    _orderId = json['order_id'];
    _price = parseJsonDouble(json['price']);
    _discountOnProduct = parseJsonDouble(json['discount_on_product']);
    _discountType = json['discount_type'];
    _quantity = json['quantity'];
    _taxAmount = parseJsonDouble(json['tax_amount']);
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['product_id'] = _productId;
    data['order_id'] = _orderId;
    data['price'] = _price;
    data['discount_on_product'] = _discountOnProduct;
    data['discount_type'] = _discountType;
    data['quantity'] = _quantity;
    data['tax_amount'] = _taxAmount;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    return data;
  }
}

class DeliveryMan {
  int? _id;
  String? _fName;
  String? _lName;
  String? _phone;
  String? _email;
  String? _identityNumber;
  String? _identityType;
  String? _identityImage;
  String? _image;
  String? _password;
  String? _createdAt;
  String? _updatedAt;
  String? _authToken;
  String? _fcmToken;

  DeliveryMan(
      {int? id,
        String? fName,
        String? lName,
        String? phone,
        String? email,
        String? identityNumber,
        String? identityType,
        String? identityImage,
        String? image,
        String? password,
        String? createdAt,
        String? updatedAt,
        String? authToken,
        String? fcmToken}) {
    _id = id;
    _fName = fName;
    _lName = lName;
    _phone = phone;
    _email = email;
    _identityNumber = identityNumber;
    _identityType = identityType;
    _identityImage = identityImage;
    _image = image;
    _password = password;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _authToken = authToken;
    _fcmToken = fcmToken;
  }

  int? get id => _id;
  String? get fName => _fName;
  String? get lName => _lName;
  String? get phone => _phone;
  String? get email => _email;
  String? get identityNumber => _identityNumber;
  String? get identityType => _identityType;
  String? get identityImage => _identityImage;
  String? get image => _image;
  String? get password => _password;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  String? get authToken => _authToken;
  String? get fcmToken => _fcmToken;

  DeliveryMan.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _fName = json['f_name'];
    _lName = json['l_name'];
    _phone = json['phone'];
    _email = json['email'];
    _identityNumber = json['identity_number'];
    _identityType = json['identity_type'];
    _identityImage = json['identity_image'];
    _image = json['image'];
    _password = json['password'];
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _authToken = json['auth_token'];
    _fcmToken = json['fcm_token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['f_name'] = _fName;
    data['l_name'] = _lName;
    data['phone'] = _phone;
    data['email'] = _email;
    data['identity_number'] = _identityNumber;
    data['identity_type'] = _identityType;
    data['identity_image'] = _identityImage;
    data['image'] = _image;
    data['password'] = _password;
    data['created_at'] = _createdAt;
    data['updated_at'] = _updatedAt;
    data['auth_token'] = _authToken;
    data['fcm_token'] = _fcmToken;
    return data;
  }
}

class OrderPartialPayment {
  int? id;
  int? orderId;
  String? paidWith;
  double? paidAmount;
  double? dueAmount;


  OrderPartialPayment({
    this.id,
    this.orderId,
    this.paidWith,
    this.paidAmount,
    this.dueAmount,
  });

  factory OrderPartialPayment.fromJson(String str) => OrderPartialPayment.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory OrderPartialPayment.fromMap(Map<String, dynamic> json) => OrderPartialPayment(
    id: json["id"],
    orderId: json["order_id"],
    paidWith: json["paid_with"],
    paidAmount: double.parse('${json["paid_amount"]}'),
    dueAmount: double.parse('${json["due_amount"]}'),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "order_id": orderId,
    "paid_with": paidWith,
    "paid_amount": paidAmount,
    "due_amount": dueAmount,
  };
}


class OfflinePaymentInformation {
  String? paymentName;
  String? paymentNote;
  List<MethodValue>? methodInformation;

  OfflinePaymentInformation({
    this.paymentName,
    this.paymentNote,
    this.methodInformation,
  });

  factory OfflinePaymentInformation.fromJson(String str) => OfflinePaymentInformation.fromMap(json.decode(str));


  factory OfflinePaymentInformation.fromMap(Map<String, dynamic> json) => OfflinePaymentInformation(
    paymentName: json["payment_name"],
    paymentNote: json["payment_note"],
    methodInformation: json["method_information"] == null ? [] : List<MethodValue>.from(json["method_information"]!.map((x) => MethodValue.fromMap(x))),
  );
}

class MethodValue{
  final String? key;
  final String? value;

  MethodValue({this.value, this.key});

  factory MethodValue.fromMap(Map<String, dynamic> json) => MethodValue(value: json[json.keys.first], key: json.keys.first);

}

class OrderChangeAmount {
  double? orderAmount;
  double? paidAmount;
  OrderChangeAmount({this.orderAmount, this.paidAmount,});

  OrderChangeAmount.fromJson(Map<String, dynamic> json) {
    orderAmount = double.tryParse(json['order_amount'].toString());
    paidAmount = double.tryParse(json['paid_amount'].toString());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['order_amount'] = orderAmount;
    data['paid_amount'] = paidAmount;

    return data;
  }
}

