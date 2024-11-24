// pubspec.yaml dependencies yang dibutuhkan:
/*
dependencies:
  flutter:
    sdk: flutter
  qr_code_scanner: ^1.0.1
  google_mobile_ads: ^3.1.0
  in_app_purchase: ^3.1.11
  shared_preferences: ^2.2.2
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const QRViewExample(),
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String result = '';
  InterstitialAd? _interstitialAd;
  bool isPremium = false;
  static const String _adUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test Ad Unit ID
  static const String _productId = 'remove_ads_premium';
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
    _initInAppPurchase();
    if (!isPremium) {
      _loadInterstitialAd();
    }
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isPremium = prefs.getBool('isPremium') ?? false;
    });
  }

  void _initInAppPurchase() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle error here
    });
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      return;
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({_productId});

    if (response.notFoundIDs.isNotEmpty) {
      // Handle the error - products not found
      return;
    }

    if (response.productDetails.isEmpty) {
      // No products available
      return;
    }

    // Products are available
    final productDetails = response.productDetails.first;
    // You can store this for later use
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Grant premium features
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPremium', true);
        setState(() {
          isPremium = true;
        });
      }
    }
  }

  Future<void> _buyPremium() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({_productId});

    if (response.productDetails.isNotEmpty) {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: response.productDetails.first);
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd(); // Load the next ad
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner Pro'),
        actions: [
          if (!isPremium)
            IconButton(
              icon: const Icon(Icons.shop),
              onPressed: _buyPremium,
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Scan result: $result',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData.code ?? '';
      });

      if (!isPremium) {
        _showInterstitialAd();
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _interstitialAd?.dispose();
    _subscription.cancel();
    super.dispose();
  }
}
