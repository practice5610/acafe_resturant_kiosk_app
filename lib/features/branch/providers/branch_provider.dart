import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:provider/provider.dart';

class BranchProvider extends DataSyncProvider {
  final SplashRepo? splashRepo;

  BranchProvider({required this.splashRepo});

  int? _selectedBranchId;

  int? get selectedBranchId => _selectedBranchId;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  int _branchTabIndex = 0;

  int get branchTabIndex => _branchTabIndex;
  bool _showSearchBox = false;

  bool get showSearchBox => _showSearchBox;

  List<BranchValue>? _branchValueList;

  List<BranchValue>? get branchValueList => _branchValueList;


  void updateSearchBox(bool status) {
    _showSearchBox = status;
    notifyListeners();
  }

  void updateTabIndex(int index, {bool isUpdate = true}) {
    _branchTabIndex = index;
    if (isUpdate) {
      notifyListeners();
    }
  }


  void updateBranchId(int? value, {bool isUpdate = true}) {
    _selectedBranchId = value;
    if (isUpdate) {
      notifyListeners();
    }
  }

  int getBranchId() => splashRepo?.getBranchId() ?? -1;

  Future<void> setBranch(int id, SplashProvider splashProvider) async {
    await splashRepo!.setBranchId(id);
    notifyListeners();
  }

  Branches? getBranch({int? id}) {
    int branchId = id ?? getBranchId();
    Branches? branch;
    ConfigModel config = Provider
        .of<SplashProvider>(Get.context!, listen: false)
        .configModel!;
    if (config.branches != null && config.branches!.isNotEmpty) {
      branch = config.branches!.firstWhere((branch) => branch!.id == branchId,
          orElse: () => null);
      if (branch == null) {
        splashRepo!.setBranchId(-1);
      }
    }
    return branch;
  }



}