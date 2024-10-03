import 'package:flutter/material.dart';
import 'score_viewer.dart';
import 'package:millimeters/millimeters.dart';

/// Flutter code sample for [NavigationRail].

void main() async {
  runApp(Millimeters.fromView(child: const NavigationRailExampleApp()));
}

class NavigationRailExampleApp extends StatelessWidget {
  const NavigationRailExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: NavRailExample(),
    );
  }
}

// taxa inscrição 450
// parte terrestre 2400 libras = R$ 17 mil
// parte aérea  1900 dólares = R$ 10 mil

class NavRailExample extends StatelessWidget {
  const NavRailExample({super.key});

  @override
  Widget build(BuildContext context) {
    var mm = Millimeters.of(context).mm;
    var size = MediaQuery.sizeOf(context);
    var unity = Size(mm(1), mm(1));
    var sizeInMm = Size(size.width / unity.width, size.height / unity.height);

    return Scaffold(
      body: Row(
        children: <Widget>[
          // This is the main content.
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Alguma coisa aqui'),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.fast_forward_outlined)),
              IconButton(
                  onPressed: () async {
                    await checkInstallation();
                    List<String> svgs = await createSvgs(sizeInMm);
                    if (context.mounted) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ScoreViewer(svgs: svgs)));
                    }
                  },
                  icon: const Icon(Icons.play_arrow_outlined)),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.fast_rewind_outlined))
            ],
          ),
        ],
      ),
    );
  }
}
