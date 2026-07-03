import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/date_converter_helper.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/main.dart';

class ProductHelper{
  static bool isProductAvailable({required Product product})=>
      product.availableTimeStarts != null && product.availableTimeEnds != null
          ? DateConverterHelper.isAvailable(product.availableTimeStarts!, product.availableTimeEnds!) : false;

  static ({List<Variation>? variatins, double? price}) getBranchProductVariationWithPrice(Product? product){

    List<Variation>? variationList;
    double? price;

    if(product?.branchProduct != null && (product?.branchProduct?.isAvailable ?? false)) {
      variationList = product?.branchProduct?.variations;
      price = product?.branchProduct?.price;

    }else{
      variationList = product?.variations;
      price = product?.price;
    }

    return (variatins: variationList, price: price);
  }


}