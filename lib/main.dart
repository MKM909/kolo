import 'package:flutter/material.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_liquid_aether_orb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseBootstrapResult = await FirebaseBootstrap.tryInitialize();
  runApp(KoloApp(firebaseBootstrapResult: firebaseBootstrapResult));
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KoloOverlayBubble(),
    ),
  );
}

class KoloOverlayBubble extends StatelessWidget {
  const KoloOverlayBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 174),
                margin: const EdgeInsets.only(right: 8, bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: const BoxDecoration(
                  color: KoloColors.surfaceDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Kolo is here. Want to talk before you spend?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const KoloLiquidAetherOrb(size: 58),
            ],
          ),
        ),
      ),
    );
  }
}
