enum AdminTab {
  daily,
  customers,
  dashboard,
  approvals,
  report;

  static AdminTab fromIndex(int index) {
    return AdminTab.values.firstWhere(
      (tab) => tab.index == index,
      orElse: () => AdminTab.daily,
    );
  }
}
