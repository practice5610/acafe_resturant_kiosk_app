import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/common/enums/product_sort_type_enum.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/data/datasource/local/cache_response.dart';
import 'package:acafe_customer/features/order/domain/models/reorder_product_model.dart';
import 'package:acafe_customer/helper/api_checker_helper.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/main.dart';

class ProductProvider extends DataSyncProvider {
  final ProductRepo? productRepo;

  ProductProvider({required this.productRepo});

  // Latest products
  ProductModel? _latestProductModel;
  ProductModel? _recommendedProductModel;
  ProductModel? _popularLocalProductModel;
  ProductModel? _flavorfulMenuProductMenu;
  bool _isLoading = false;
  int? _quantity = 1;
  List<bool> _addOnActiveList = [];
  List<int?> _addOnQtyList = [];
  int popularOffset = 1;
  final int _cartIndex = -1;
  final List<String> _productTypeList = ['all', 'non_veg', 'veg'];
  List<List<bool?>> _selectedVariations = [];
  bool _variationSeeMoreButtonStatus = false;
  List<bool>? _isRequiredSelected;
  bool _isShowProductReview = false;



  bool get isLoading => _isLoading;
  // List<int> get variationIndex => _variationIndex;
  int? get quantity => _quantity;
  List<bool> get addOnActiveList => _addOnActiveList;
  List<int?> get addOnQtyList => _addOnQtyList;
  int get cartIndex => _cartIndex;
  List<String> get productTypeList => _productTypeList;
  List<List<bool?>> get selectedVariations => _selectedVariations;
  bool get variationSeeMoreButtonStatus => _variationSeeMoreButtonStatus;
  List<bool>?  get isRequiredSelected => _isRequiredSelected;
  int _latestProductRequestToken = 0;

  ProductModel? get latestProductModel => _latestProductModel;
  ProductModel? get recommendedProductModel => _recommendedProductModel;
  ProductModel? get popularLocalProductModel => _popularLocalProductModel;
  ProductModel? get flavorfulMenuProductMenuModel => _flavorfulMenuProductMenu;
  bool get  isShowProductReview =>  _isShowProductReview;




  Future<void> getLatestProductList(int offset, bool reload, {bool isUpdate = true, ProductSortType? sortType}) async {

    final ProductSortType selectedSort = sortType ?? ProductSortType.defaultType;
    final int requestToken = offset == 1 ? ++_latestProductRequestToken : _latestProductRequestToken;

    if(offset == 1) {
      await fetchAndSyncData(
        fetchFromLocal: ()=> productRepo!.getLatestProductList<CacheResponseData>(offset: offset, type: selectedSort, source: DataSourceEnum.local),
        fetchFromClient: ()=> productRepo!.getLatestProductList(offset: offset, type: selectedSort, source: DataSourceEnum.client),
        onResponse: (data, _){
          if (requestToken != _latestProductRequestToken) return;
          _latestProductModel = ProductModel.fromJson(data);
          notifyListeners();
        },
      );
    }else {
      if(_latestProductModel == null || offset != 1) {
        ApiResponseModel? response = await productRepo?.getLatestProductList(offset: offset, type: selectedSort, source: DataSourceEnum.client);
        if (response?.response?.data != null && response?.response?.statusCode == 200) {
          if(offset == 1){
            _latestProductModel = ProductModel.fromJson(response?.response?.data);
          } else {
            _latestProductModel?.totalSize = ProductModel.fromJson(response?.response?.data).totalSize;
            _latestProductModel?.offset = ProductModel.fromJson(response?.response?.data).offset;
            _latestProductModel?.products?.addAll(ProductModel.fromJson(response?.response?.data).products ?? []);
          }

          notifyListeners();

        } else {
          ApiCheckerHelper.checkApi(response!);

        }
      }
    }



  }

  Future<void> getPopularLocalProductList(int offset, bool reload, { bool isUpdate = true, DataSourceEnum source = DataSourceEnum.local}) async {

    if(reload) {
      _popularLocalProductModel = null;

      if(isUpdate) {
        notifyListeners();
      }
    }

    if(offset == 1) {
      fetchAndSyncData(
        fetchFromLocal: ()=> productRepo!.getPopularProductList<CacheResponseData>(offset: offset, source: DataSourceEnum.local),
        fetchFromClient: ()=> productRepo!.getPopularProductList(offset: offset, source: DataSourceEnum.client),
        onResponse: (data, _){
          _popularLocalProductModel = ProductModel.fromJson(data);
          notifyListeners();
        },
      );
    }else {
      ApiResponseModel? response = await productRepo?.getPopularProductList(offset: offset, source: DataSourceEnum.client);

      if (response?.response?.data != null && response?.response?.statusCode == 200) {
        if(offset == 1){
          _popularLocalProductModel = ProductModel.fromJson(response?.response?.data);
        } else {
          _popularLocalProductModel?.totalSize = ProductModel.fromJson(response?.response?.data).totalSize;
          _popularLocalProductModel?.offset = ProductModel.fromJson(response?.response?.data).offset;
          _popularLocalProductModel?.products?.addAll(ProductModel.fromJson(response?.response?.data).products ?? []);
        }

        notifyListeners();

      } else {
        ApiCheckerHelper.checkApi(response!);

      }
    }

  }

  Future<void> getRecommendedProductList(int offset, bool reload, { bool isUpdate = true}) async {

    if(reload) {
      _recommendedProductModel = null;

      if(isUpdate) {
        notifyListeners();
      }
    }

    if(offset == 1) {
      fetchAndSyncData(
        fetchFromLocal: ()=> productRepo!.getRecommendedProductApi<CacheResponseData>(offset: offset, source: DataSourceEnum.local),
        fetchFromClient: ()=> productRepo!.getRecommendedProductApi(offset: offset, source: DataSourceEnum.client),
        onResponse: (responseData, _) {
          _recommendedProductModel = ProductModel.fromJson(responseData);
        },
      );
    }else {
      if((_recommendedProductModel == null) || (offset != 1)) {
        ApiResponseModel? response = await productRepo?.getRecommendedProductApi(offset: offset, source: DataSourceEnum.client);
        if (response?.response?.data != null && response?.response?.statusCode == 200) {
          if(offset == 1){
            _recommendedProductModel = ProductModel.fromJson(response?.response?.data);
          } else {
            _recommendedProductModel?.totalSize = ProductModel.fromJson(response?.response?.data).totalSize;
            _recommendedProductModel?.offset = ProductModel.fromJson(response?.response?.data).offset;
            _recommendedProductModel?.products?.addAll(ProductModel.fromJson(response?.response?.data).products ?? []);
          }

          notifyListeners();

        } else {
          ApiCheckerHelper.checkApi(response!);

        }
      }
    }



  }

  Future<void> getFlavorfulMenuProductMenuList(int offset, bool reload, { bool isUpdate = true}) async {

    if(reload) {
      _flavorfulMenuProductMenu = null;

      if(isUpdate) {
        notifyListeners();
      }
    }

    if(offset == 1) {
      fetchAndSyncData(
        fetchFromLocal: ()=> productRepo!.getFlavorFulMenuProductApi<CacheResponseData>(offset: offset, source: DataSourceEnum.local),
        fetchFromClient: ()=> productRepo!.getFlavorFulMenuProductApi(offset: offset, source: DataSourceEnum.client),
        onResponse: (responseData, _) {
          _flavorfulMenuProductMenu = ProductModel.fromJson(responseData);
        },
      );

    }else {
      if(_flavorfulMenuProductMenu == null || offset != 1) {
        ApiResponseModel? response = await productRepo?.getFlavorFulMenuProductApi(offset: offset, source: DataSourceEnum.client);

        if (response?.response?.data != null && response?.response?.statusCode == 200) {
          if(offset == 1){
            _flavorfulMenuProductMenu = ProductModel.fromJson(response?.response?.data);

          } else {
            _flavorfulMenuProductMenu?.totalSize = ProductModel.fromJson(response?.response?.data).totalSize;
            _flavorfulMenuProductMenu?.offset = ProductModel.fromJson(response?.response?.data).offset;
            _flavorfulMenuProductMenu?.products?.addAll(ProductModel.fromJson(response?.response?.data).products ?? []);
          }

          notifyListeners();

        } else {
          ApiCheckerHelper.checkApi(response!);

        }
      }
    }





  }


  void initData(Product? product, CartModel? cart) {
    _selectedVariations = [];
    _addOnQtyList = [];
    _addOnActiveList = [];

    if(cart != null) {
      _quantity = cart.quantity;
      _selectedVariations.addAll(cart.variations!);
      List<int?> addOnIdList = [];
      for (var addOnId in cart.addOnIds!) {
        addOnIdList.add(addOnId.id);
      }
      for (var addOn in product!.addOns!) {
        // A default add-on is on no matter what the saved line says. Editing an
        // older line whose add-on was not default when it was saved must not be
        // the one way a locked add-on can come back off.
        if(addOn.isDefault) {
          _addOnActiveList.add(true);
          _addOnQtyList.add(1);
        } else if(addOnIdList.contains(addOn.id)) {
          _addOnActiveList.add(true);
          _addOnQtyList.add(cart.addOnIds![addOnIdList.indexOf(addOn.id)].quantity);
        }else {
          _addOnActiveList.add(false);
          _addOnQtyList.add(1);
        }
      }
    }else {
      _quantity = 1;
      if(product!.variations != null){
        for(int index=0; index<product.variations!.length; index++) {
          _selectedVariations.add([]);
          for(int i=0; i < product.variations![index].variationValues!.length; i++) {
            _selectedVariations[index].add(false);
          }
        }
      }

      if(product.addOns != null){
        for (int i = 0; i < product.addOns!.length; i++) {
          // Defaults come pre-selected — that is the whole point of the flag.
          _addOnActiveList.add(product.addOns![i].isDefault);
          _addOnQtyList.add(1);
        }
      }

    }
  }

  void setAddOnQuantity(bool isIncrement, int index) {
    if (isIncrement) {
      _addOnQtyList[index] = _addOnQtyList[index]! + 1;
    } else {
      _addOnQtyList[index] = _addOnQtyList[index]! - 1;
    }
    notifyListeners();
  }

  void setQuantity(bool isIncrement) {
    if (isIncrement) {
      _quantity = _quantity! + 1;
    } else {
      _quantity = _quantity! - 1;
    }
    notifyListeners();
  }

  void setCartVariationIndex(int index, int i, Product? product, bool isMultiSelect) {
    if(!isMultiSelect) {
      for(int j = 0; j < _selectedVariations[index].length; j++) {
        if(product!.variations![index].isRequired!){
          _selectedVariations[index][j] = j == i;
        }else{
          if(_selectedVariations[index][j]!){
            _selectedVariations[index][j] = false;
          }else{
            _selectedVariations[index][j] = j == i;
          }
        }
      }
    } else {
      if(!_selectedVariations[index][i]! && selectedVariationLength(_selectedVariations, index) >= product!.variations![index].max!) {
        showCustomSnackBarHelper('${getTranslated('maximum_variation_for', Get.context!)} ${product.variations![index].name
        } ${getTranslated('is', Get.context!)} ${product.variations![index].max}', isToast: true);

      }else {
        _selectedVariations[index][i] = !_selectedVariations[index][i]!;
      }
    }
    notifyListeners();
  }
  int selectedVariationLength(List<List<bool?>> selectedVariations, int index) {
    int length = 0;
    for(bool? isSelected in selectedVariations[index]) {
      if(isSelected!) {
        length++;
      }
    }
    return length;
  }


  void addAddOn(bool isAdd, int index) {
    _addOnActiveList[index] = isAdd;
    notifyListeners();
  }

  /// Toggle one add-on within its group.
  ///
  /// [defaultIndexes] are the group's DEFAULT add-ons: included with the
  /// product, always on, never chargeable, and not tappable. They sit outside
  /// every rule below rather than participating in them:
  ///
  ///  * a tap on one is ignored, so the lock cannot be broken;
  ///  * single-choice applies to the NON-default remainder only, so a group
  ///    with three defaults gives the customer those three plus at most one
  ///    extra pick (four selected), never one selection total;
  ///  * they do not count toward [maxSelect], so a group cannot be filled to
  ///    its cap by its own defaults and leave the customer nothing to choose.
  void toggleAddOnInGroup({
    required int index,
    required bool isSingle,
    required List<int> groupIndexes,
    required bool isRequired,
    int? maxSelect,
    List<int> defaultIndexes = const [],
  }) {
    if (index < 0 || index >= _addOnActiveList.length) {
      return;
    }

    // Locked: it came with the product, so no tap can turn it off.
    if (defaultIndexes.contains(index)) {
      return;
    }

    if (isSingle) {
      final bool currentlyOn = _addOnActiveList[index];
      if (currentlyOn && !isRequired) {
        _addOnActiveList[index] = false;
      } else {
        // Clear only the remainder. Sweeping the whole group here would turn
        // the defaults off, which is exactly the lock this method enforces.
        for (final int i in groupIndexes) {
          if (i >= 0 && i < _addOnActiveList.length && !defaultIndexes.contains(i)) {
            _addOnActiveList[i] = i == index;
          }
        }
      }
      notifyListeners();
      return;
    }

    final bool turningOn = !_addOnActiveList[index];
    if (turningOn && maxSelect != null) {
      int count = 0;
      for (final int i in groupIndexes) {
        if (i >= 0 && i < _addOnActiveList.length && _addOnActiveList[i]
            && !defaultIndexes.contains(i)) {
          count++;
        }
      }
      if (count >= maxSelect) {
        return;
      }
    }

    _addOnActiveList[index] = turningOn;
    notifyListeners();
  }


  bool checkStock(Product product, {int? quantity}){
    int? stock;
    if(product.branchProduct?.stockType != 'unlimited' && product.branchProduct?.stock != null && product.branchProduct?.soldQuantity != null){
      stock = product.branchProduct!.stock! - product.branchProduct!.soldQuantity!;
      if(quantity != null){
        stock = stock - quantity;
      }

    }
    return stock == null || (stock > 0);
  }

  void initProductVariationStatus(int length){
    _variationSeeMoreButtonStatus = false;
    _isRequiredSelected = [];
    for(int i = 0; i < length; i++){
      _isRequiredSelected!.add(false);
    }
  }

  void setVariationSeeMoreStatus(bool status){
    _variationSeeMoreButtonStatus = status;
    notifyListeners();
  }

  void checkIsRequiredSelected({required int index, required bool isMultiSelect, int? min = 1, int? max = 1, required List<bool?> variations}){

    if (isMultiSelect) {
      int count = 0;
      for (int i = 0; i < variations.length; i++) {
        if (variations[i] == true) count++;
      }

      if (count >= min! && count <= max!) {
        _isRequiredSelected![index] = true;
      } else {
        _isRequiredSelected![index] = false;
      }
    } else {
      _isRequiredSelected![index] = true;
    }

    notifyListeners();
  }


  ReorderProductModel? _reorderProductModel;
  ReorderProductModel? get reorderProductModel => _reorderProductModel;

  Future<ReorderProductModel?> getReorderProductList(int? orderId, {isUpdate = true}) async {
    _isLoading = true;
    _reorderProductModel = null;

    if(isUpdate) {
      notifyListeners();
    }

    ApiResponseModel? response = await productRepo?.getReorderProductApi(orderId);

    if (response?.response?.data != null && response?.response?.statusCode == 200) {
      _reorderProductModel = ReorderProductModel.fromJson(response?.response?.data);
      notifyListeners();

    } else {
      ApiCheckerHelper.checkApi(response!);

    }
    _isLoading = false;
    notifyListeners();

    return reorderProductModel;

  }

  updateProductReviewShowStatus({bool isUpdate = true, bool value = false}){
    _isShowProductReview = value;
    if(isUpdate){
      notifyListeners();
    }
  }

}
