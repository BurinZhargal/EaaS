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
  /// Sending system objects to Delphi AI 
  void _sendToDelphiKnowledgeBase(int geom, int vel, int delta) {
    print('MCP -> text generation for Delphi AI Prompt..');
    
    // Crawling data from FPGA Hardware and Prolog logic driver
    String promptForDelphi = _generateDelphiPrompt(
      geomCode: geom,
      velocity: vel,
      deltaArea: delta,
    );

    // Output text, you can paste it to Delphi AI directly 
    print('=================== PROMPT FOR DELPHI ACTIONS ===================');
    print(promptForDelphi);
    print('=================================================================');

    // The invocation of other system classes
    _actuatorController.add('TRIGGER_DELPHI_LOG');
  }

  /// toString
  String _generateDelphiPrompt({required int geomCode, required int velocity, required int deltaArea}) {
    final DateTime now = DateTime.now();
    
    return '''
System: the classification error (Ecology as a Service).
Time: ${now.toIsoServerYearMonthDay()} ${now.toIsoServerHourMinuteSecond()}

Architecture:
- Hardware: smart wastebin or robot with trashbox  (FPGA, finite automata).
- Logical driver: prolog knowledge base  (/prologWasteKB/main.pro).
- Prolog program returned: [unknown_target -> log_to_delphi_ai]. 

IN vector of features (data from Camera with  OpenCV and JK-trigger summatorz):
1. Geometry contour code (GeomCode): $geomCode
2. Velocity of centroid shift (Velocity): $velocity ед/кадр
3. The difference of delta volume of the area (DeltaArea): $deltaArea (dynamic of deformation)

Expert of Delphi AI do the following:
Based on the project structure and vector of features (for example, new type of multilayer paper cover , TetrapakTM or destroyed pieces of waste paper). 
Write the recommendation:
1. Which new logical predicate will help to determine that unknown type of waste?
2. Do we need to reconfigure comparator of FPGA Hardware to improve the precision of trashbin full indication?
''';
  }
  

  void dispose() {
    _prologProcess?.kill();
    _actuatorController.close();
    print('MCP: shut down!');
  }
}
