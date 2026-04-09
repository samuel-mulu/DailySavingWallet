import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/customers/customer_repo.dart';
import '../../data/wallet/wallet_repo.dart';

final walletRepoProvider = Provider<WalletRepo>((ref) => WalletRepo());

final customerRepoProvider = Provider<CustomerRepo>((ref) => CustomerRepo());
