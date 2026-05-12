import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';

enum LegalDocType { privacyPolicy, termsOfService }

class LegalScreen extends StatefulWidget {
  final LegalDocType docType;

  const LegalScreen({super.key, required this.docType});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  // ── URLs ─────────────────────────────────────────────────────────────────
  // Update these to your Firebase Hosting project URL after deployment.
  // Example: https://your-project-id.web.app/privacy-policy
  static const String _privacyPolicyUrl =
      'https://YOUR_PROJECT_ID.web.app/privacy-policy';
  static const String _termsUrl =
      'https://YOUR_PROJECT_ID.web.app/terms-of-service';

  String get _url => widget.docType == LegalDocType.privacyPolicy
      ? _privacyPolicyUrl
      : _termsUrl;

  String get _title => widget.docType == LegalDocType.privacyPolicy
      ? 'Privacy Policy'
      : 'Terms of Service';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bgCream)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _isLoading = false;
            _hasError = true;
          }),
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_hasError)
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'Retry',
                onPressed: _reload,
              ),
          ],
        ),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: AppColors.bgCream,
            child: Stack(
              children: [
                // ── WebView ───────────────────────────────────────────────
                if (!_hasError)
                  WebViewWidget(controller: _controller),

                // ── Loading overlay ───────────────────────────────────────
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.orange,
                      strokeWidth: 2.5,
                    ),
                  ),

                // ── Error state ───────────────────────────────────────────
                if (_hasError && !_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.error,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Failed to load',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMid,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
