// A pretend wallet. The assistant can "send" a transfer or a red packet and the
// user can accept it. None of this is real money, it only exists for the mood.

class WalletTx {
  WalletTx({required this.id, required this.chatId, required this.title, required this.amount, required this.kind, required this.at, this.status = 'pending'});
  final String id;
  final String chatId;
  final String title;

  /// positive when money came in
  final double amount;

  /// 'transfer' or 'redpacket'
  final String kind;
  final int at;

  /// pending, accepted, declined
  String status;

  Map<String, dynamic> toJson() => {'id': id, 'chatId': chatId, 'title': title, 'amount': amount, 'kind': kind, 'at': at, 'status': status};
  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        chatId: j['chatId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        kind: j['kind'] as String? ?? 'transfer',
        at: (j['at'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'pending',
      );
}

class Wallet {
  double balance = 0;
  final List<WalletTx> txs = [];
  var _seq = 0;

  static const maxSingle = 1000000.0;

  /// Creates the pending record the chat bubble points at.
  WalletTx offer({required String chatId, required double amount, required String title, required String kind, int? now}) {
    final a = amount.clamp(0.01, maxSingle).toDouble();
    final tx = WalletTx(id: 'tx_${DateTime.now().microsecondsSinceEpoch}_${_seq++}', chatId: chatId, title: title, amount: double.parse(a.toStringAsFixed(2)), kind: kind, at: now ?? DateTime.now().millisecondsSinceEpoch);
    txs.insert(0, tx);
    return tx;
  }

  WalletTx? byId(String id) => txs.where((t) => t.id == id).firstOrNull;

  bool accept(String id) {
    final t = byId(id);
    if (t == null || t.status != 'pending') return false;
    t.status = 'accepted';
    balance = double.parse((balance + t.amount).toStringAsFixed(2));
    return true;
  }

  bool decline(String id) {
    final t = byId(id);
    if (t == null || t.status != 'pending') return false;
    t.status = 'declined';
    return true;
  }

  /// Buys something in the shop: deducts the price and records an already
  /// accepted tx with a negative amount, so the history reads as a spend.
  /// Returns false when the balance does not cover it.
  bool spend(double amount, {required String title, int? now}) {
    final a = amount.clamp(0.01, maxSingle).toDouble();
    if (balance < a) return false;
    balance = double.parse((balance - a).toStringAsFixed(2));
    txs.insert(0, WalletTx(id: 'tx_${DateTime.now().microsecondsSinceEpoch}_${_seq++}', chatId: '', title: title, amount: -double.parse(a.toStringAsFixed(2)), kind: 'shop', at: now ?? DateTime.now().millisecondsSinceEpoch, status: 'accepted'));
    return true;
  }

  Map<String, dynamic> toJson() => {'balance': balance, 'txs': [for (final t in txs) t.toJson()]};

  void loadJson(Map<String, dynamic> j) {
    balance = (j['balance'] as num?)?.toDouble() ?? 0;
    txs
      ..clear()
      ..addAll([for (final e in (j['txs'] as List? ?? const [])) WalletTx.fromJson(Map<String, dynamic>.from(e as Map))]);
  }
}
