import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _kDefaultUrl = String.fromEnvironment(
  'ZEREXA_WEBVIEW_URL',
  defaultValue: 'https://video.zerexa.net',
);

void main() {
  runApp(const ZerexaVideoApp());
}

class ZerexaVideoApp extends StatelessWidget {
  const ZerexaVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zerexa Video',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1F2937),
          titleTextStyle: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isLoading = true;
  String _currentUrl = _kDefaultUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() => _progress = progress);
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            // Hide the web app's own header/footer chrome so the
            // mobile shell feels native.
            _controller.runJavaScript('''
              (function() {
                var header = document.querySelector('header');
                if (header && window.innerWidth < 768) header.style.display = 'none';
                var footer = document.querySelector('footer');
                if (footer && window.innerWidth < 768) footer.style.display = 'none';
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load: ${error.description}'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_kDefaultUrl));
  }

  Future<void> _reload() async {
    await _controller.reload();
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
    }
  }

  Future<void> _openHome() async {
    await _controller.loadRequest(Uri.parse(_kDefaultUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.play_circle_outline, size: 22),
            const SizedBox(width: 8),
            const Text('Zerexa Video'),
            const Spacer(),
            if (_isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _progress > 0 ? _progress / 100 : null,
                ),
              )
            else
              const Icon(Icons.cloud_done, size: 18, color: Color(0xFF22C55E)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: _openHome,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _goBack,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Forward',
            onPressed: _goForward,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _reload,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) async {
              switch (value) {
                case 'copy_url':
                  // ignore: avoid_print
                  print('Current URL: $_currentUrl');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('URL: $_currentUrl')),
                    );
                  }
                  break;
                case 'reload':
                  await _reload();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'copy_url', child: Text('Show current URL')),
              const PopupMenuItem(value: 'reload', child: Text('Reload')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
