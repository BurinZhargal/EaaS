import 'dart:convert';
import 'dart:io';
import 'dart:async';

class EaaSMasterMCP {
  Process? _prologProcess;
  
  final String _prologKBPath = '../../prologWasteKB/main.pro';
  
  final _actuatorController = StreamController<String>.broadcast();
  Stream<String> get actuatorCommands => _actuatorController.stream;

  ///  SWI-Prolog
  Future<void> initializeOrchestrator() async {
    try {
      _prologProcess = await Process.start(
        'swipl', 
        ['-q', '-s', _prologKBPath],
        runInShell: true,
      );

      _prologProcess!.stderr
          .transform(utf8.decoder)
          .listen((stderrData) {
            print('MCP [Prolog Error]: $stderrData');
          });

      print('MCP: server running. attempt to launch Prolog knowledge base driver: $_prologKBPath');
    } catch (e) {
      print('MCP [Critical Error]: Error swipl invocation $_prologKBPath: $e');
    }
  }

  ///Sending data from OpenCV (geometry, velocity, volume's delta
  void orchestrateMetrics({
    required int geomCode, 
    required int velocity, 
    required int deltaArea,
  }) {
    if (_prologProcess == null) {
      print('MCP: Prolog Proccess not responding.Make sure youre setup neccessary components correctly');
      return;
    }

    String query = 'analyze_stream($geomCode, $velocity, $deltaArea, Trash, Action).\n';
    _prologProcess!.stdin.write(query);

    _prologProcess!.stdout
        .transform(utf8.decoder)
        .first 
        .then((String output) {
          _parsePrologResponse(output, geomCode, velocity, deltaArea);
        });
  }

  void _parsePrologResponse(String response, int geom, int vel, int delta) {
    final cleanResponse = response.trim();
    if (cleanResponse.isEmpty) return;

    print('MCP [Prolog Output]: $cleanResponse');

    if (cleanResponse.contains('open_fast_gate') || cleanResponse.contains('candy_waste')) {
      _actuatorController.add('OPEN_FAST_GATE'); // paper / the candy paper
    } else if (cleanResponse.contains('open_main_chute') || cleanResponse.contains('plastic_bottle')) {
      _actuatorController.add('OPEN_MAIN_CHUTE'); // plastic
    } else if (cleanResponse.contains('log_to_delphi_ai') || cleanResponse.contains('unknown_target')) {
      _sendToDelphiKnowledgeBase(geom, vel, delta);
    }
  }

  void _sendToDelphiKnowledgeBase(int geom, int vel, int delta) {
    print('MCP -> sending unknown waste type to Delphi AI: Geom=$geom, Vel=$vel');
    _actuatorController.add('TRIGGER_DELPHI_LOG');
  }

  void dispose() {
    _prologProcess?.kill();
    _actuatorController.close();
    print('MCP: shut down!');
  }
}
