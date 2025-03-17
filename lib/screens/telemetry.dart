import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mangueweb/screens/settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:mangueweb/screens/home_screen.dart';
import 'package:mangueweb/screens/live_screen.dart';
//import 'package:syncfusion_flutter_gauges/gauges.dart';
//import 'package:google_fonts/google_fonts.dart';

// ------------------------------
// VARIÁVEIS GLOBAIS E CONFIGURAÇÕES
// ------------------------------

// Controle da porta serial

// ---------------------------------
// WIDGET PRINCIPAL: TELEMETRYSCREEN

// TODO: implement readdata
// ---------------------------------

class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({Key? key}) : super(key: key);

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  Timer? _readTimer;

  int spotIndex = 0;
  late SerialPort port;
  late bool isOpen;
  late SerialPortConfig config;
  List<int> buffer = [];
  bool leituraAtiva = true;

  Future<void> initSerialPort() async {
    List<String> availablePorts = SerialPort.availablePorts;
    debugPrint('Available ports: $availablePorts');

    String targetPort = 'COM4';
    if (availablePorts.contains(targetPort)) {
      debugPrint('Found port: COM4');
      port = SerialPort(targetPort);

      // Tenta abrir a porta
      isOpen = port.openReadWrite();
      if (isOpen) {
        debugPrint('Port $targetPort opened successfully.');
        config = SerialPortConfig()
          ..baudRate = 115200
          ..bits = 8
          ..stopBits = 1
          ..parity = SerialPortParity.none;
        port.config = config;
        readData(); // inicia a leitura dos dados
      } else {
        debugPrint('Failed to open port $targetPort.');
        // Opcional: tente reabrir após um pequeno delay
        await Future.delayed(Duration(milliseconds: 1));
        isOpen = port.openReadWrite();
        if (isOpen) {
          debugPrint('Port $targetPort opened successfully on retry.');
          config = SerialPortConfig()
            ..baudRate = 115200
            ..bits = 8
            ..stopBits = 1
            ..parity = SerialPortParity.none;
          port.config = config;
          readData();
        }
      }
    } else {
      debugPrint('Port $targetPort not available.');
    }
  }

  @override
  void dispose() {
    debugPrint("Saindo da tela de rádio: cancelando Timer e fechando a porta.");
    _readTimer?.cancel();
    _readTimer = null;

    try {
      if (port.isOpen) {
        port.close();
        debugPrint('Porta ${port.name} fechada com sucesso.');
      } else {
        debugPrint('Porta ${port.name} já estava fechada.');
      }
    } catch (e, stackTrace) {
      debugPrint('Erro ao fechar a porta ${port.name}: $e');
      debugPrint('StackTrace: $stackTrace');
    }

    super.dispose();
  }

  void processPacket(List<int> packet) {
    debugPrint('Processing packet: $packet');

    double convertBytesToDouble(
        int b0, int b1, int b2, int b3, int b4, int b5, int b6, int b7) {
      final byteData = ByteData(8);
      byteData.setInt8(0, b0);
      byteData.setInt8(1, b1);
      byteData.setInt8(2, b2);
      byteData.setInt8(3, b3);
      byteData.setInt8(4, b4);
      byteData.setInt8(5, b5);
      byteData.setInt8(6, b6);
      byteData.setInt8(7, b7);

      return byteData.getFloat64(0, Endian.little);
    }

    double bytesToFloat(int value22, int value23, int value24, int value25,
        {Endian endian = Endian.little}) {
      ByteData byteData = ByteData(4);

      if (endian == Endian.little) {
        byteData.setUint8(0, value22);
        byteData.setUint8(1, value23);
        byteData.setUint8(2, value24);
        byteData.setUint8(3, value25);
      }

      return byteData.getFloat32(0, endian);
    }

    int raw_acc_x = ((value3 << 8) | value2).toSigned(16);
    print("Valor bruto (int16): $raw_acc_x");
    acc_x = raw_acc_x * 6.17e-5;
    print("Aceleração em X: ${acc_x.toStringAsFixed(2)}");

    int raw_acc_y = ((value5 << 8) | value4).toSigned(16);
    print("Valor bruto (int16): $raw_acc_y");
    acc_y = raw_acc_y * 6.17e-5;
    print("Aceleração em y: ${acc_y.toStringAsFixed(2)}");

    int raw_acc_z = ((value7 << 8) | value6).toSigned(16);
    print("Valor bruto (int16): $raw_acc_z");
    acc_z = raw_acc_z * 6.17e-5;
    print("Aceleração em z: ${acc_z.toStringAsFixed(2)}");

    //acc_y = (value5 << 8) | value4;
    //acc_z = (value7 << 8) | value6;
    dps_x = (value9 << 8) | value8;
    dps_y = (value11 << 8) | value10;
    dps_z = (value13 << 8) | value12;
    rpm = (value15 << 8) | value14;
    speed = (value17 << 8) | value16;
    double latitude = convertBytesToDouble(packet[25], packet[26], packet[27],
        packet[28], packet[29], packet[30], packet[31], packet[32]);

    double longitude = convertBytesToDouble(packet[33], packet[34], packet[35],
        packet[36], packet[37], packet[38], packet[39], packet[40]);
    int timestamp =
        (value42) | (value43 << 8) | (value44 << 16) | (value45 << 24);
    double valueLittleEndian =
        bytesToFloat(value22, value23, value24, value25, endian: Endian.little);
    roundedValue = (valueLittleEndian * 10000).roundToDouble() / 10000;

    temperature = value18;
    flags = value19;
    soc = value20;
    cvt = value21;
    sat = value46;
    debugPrint('acc_x: $acc_x');
    debugPrint('acc_y: $acc_y');
    debugPrint('acc_z: $acc_z');
    debugPrint('dps_x: $dps_x');
    debugPrint('dps_y: $dps_y');
    debugPrint('dps_z: $dps_z');
    debugPrint('rpm: $rpm');
    debugPrint('speed: $speed');
    debugPrint('temperature: $temperature');
    debugPrint('flags: $flags');
    debugPrint('soc: $soc');
    debugPrint('cvt: $cvt');
    debugPrint('volt: $roundedValue');
    debugPrint('latitude: $latitude');
    debugPrint('longitude: $longitude');
    debugPrint('timestamp: $timestamp');
    debugPrint('sat: $sat');
  }

  /// Lê os dados da porta serial periodicamente e atualiza as variáveis e gráficos
  void readData() {
    _readTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final availableBytes = port.bytesAvailable;
        if (availableBytes > 0) {
          final data = port.read(availableBytes);
          if (data.isNotEmpty) {
            // Acumula os dados lidos no buffer
            buffer.addAll(data);

            // Se o buffer tiver ao menos 50 bytes (tamanho do pacote esperado)
            if (buffer.length >= 50) {
              // Atribui os 50 primeiros bytes às variáveis (mantendo sua lógica original)
              for (int i = 0; i < 50; i++) {
                if (i < buffer.length) {
                  switch (i) {
                    case 0:
                      value1 = buffer[i];
                      break;
                    case 1:
                      value2 = buffer[i];
                      break;
                    case 2:
                      value3 = buffer[i];
                      break;
                    case 3:
                      value4 = buffer[i];
                      break;
                    case 4:
                      value5 = buffer[i];
                      break;
                    case 5:
                      value6 = buffer[i];
                      break;
                    case 6:
                      value7 = buffer[i];
                      break;
                    case 7:
                      value8 = buffer[i];
                      break;
                    case 8:
                      value9 = buffer[i];
                      break;
                    case 9:
                      value10 = buffer[i];
                      break;
                    case 10:
                      value11 = buffer[i];
                      break;
                    case 11:
                      value12 = buffer[i];
                      break;
                    case 12:
                      value13 = buffer[i];
                      break;
                    case 13:
                      value14 = buffer[i];
                      break;
                    case 14:
                      value15 = buffer[i];
                      break;
                    case 15:
                      value16 = buffer[i];
                      break;
                    case 16:
                      value17 = buffer[i];
                      break;
                    case 17:
                      value18 = buffer[i];
                      break;
                    case 18:
                      value19 = buffer[i];
                      break;
                    case 19:
                      value20 = buffer[i];
                      break;
                    case 20:
                      value21 = buffer[i];
                      break;
                    case 21:
                      value22 = buffer[i];
                      break;
                    case 22:
                      value23 = buffer[i];
                      break;
                    case 23:
                      value24 = buffer[i];
                      break;
                    case 24:
                      value25 = buffer[i];
                      break;
                    case 25:
                      value26 = buffer[i];
                      break;
                    case 26:
                      value27 = buffer[i];
                      break;
                    case 27:
                      value28 = buffer[i];
                      break;
                    case 28:
                      value29 = buffer[i];
                      break;
                    case 29:
                      value30 = buffer[i];
                      break;
                    case 30:
                      value31 = buffer[i];
                      break;
                    case 31:
                      value32 = buffer[i];
                      break;
                    case 32:
                      value33 = buffer[i];
                      break;
                    case 33:
                      value34 = buffer[i];
                      break;
                    case 34:
                      value35 = buffer[i];
                      break;
                    case 35:
                      value36 = buffer[i];
                      break;
                    case 36:
                      value37 = buffer[i];
                      break;
                    case 37:
                      value38 = buffer[i];
                      break;
                    case 38:
                      value39 = buffer[i];
                      break;
                    case 39:
                      value40 = buffer[i];
                      break;
                    case 40:
                      value41 = buffer[i];
                      break;
                    case 41:
                      value42 = buffer[i];
                      break;
                    case 42:
                      value43 = buffer[i];
                      break;
                    case 43:
                      value44 = buffer[i];
                      break;
                    case 44:
                      value45 = buffer[i];
                      break;
                    case 45:
                      value46 = buffer[i];
                      break;
                    case 46:
                      value47 = buffer[i];
                      break;
                    default:
                      break;
                  }
                }
              }
              // Processa o pacote de 50 bytes para atualizar as variáveis globais
              processPacket(buffer.sublist(0, 50));
              buffer.removeRange(0, 50);

              // Atualiza os gráficos – incrementa o contador de tempo e adiciona novos pontos
              setState(() {
                timeCounter++;
                // Usa o valor lido de 'speed' e 'acc_x' (atualizado na função processPacket)
                speedSpots.add(FlSpot(timeCounter, speed.toDouble()));
                accXSpots.add(FlSpot(timeCounter, acc_x.toDouble()));
                accYSpots.add(FlSpot(timeCounter, acc_y.toDouble()));
                accZSpots.add(FlSpot(timeCounter, acc_z.toDouble()));
                rpmSpots.add(FlSpot(timeCounter, rpm.toDouble()));
                rollSpots.add(FlSpot(timeCounter, roundedValue.toDouble()));

                // Opcional: Limita o número de pontos exibidos para manter o gráfico "limpo"
                if (speedSpots.length > 30) speedSpots.removeAt(0);
                if (accXSpots.length > 30) accXSpots.removeAt(0);
                if (accYSpots.length > 30) accYSpots.removeAt(0);
                if (accZSpots.length > 30) accZSpots.removeAt(0);
                if (rollSpots.length > 30) rollSpots.removeAt(0);
              });
            }
          }
        } else {
          debugPrint('No data available to read.');
        }
      } catch (e, stackTrace) {
        debugPrint('Error reading data: $e');
        debugPrint('StackTrace: $stackTrace');
      }
    });
  }

// Variáveis dos dados

// Função que processa o pacote recebido
  double acc_x = 0;
  double acc_y = 0;
  double acc_z = 0;
  int dps_x = 0;
  int dps_y = 0;
  int dps_z = 0;
  int rpm = 0;
  int speed = 0;
  int temperature = 0;
  int flags = 0;
  int soc = 0;
  int cvt = 0;
  int sat = 0;
  double roundedValue = 0.0;

  int value1 = 0,
      value2 = 0,
      value3 = 0,
      value4 = 0,
      value5 = 0,
      value6 = 0,
      value7 = 0,
      value8 = 0,
      value9 = 0,
      value10 = 0;
  int value11 = 0,
      value12 = 0,
      value13 = 0,
      value14 = 0,
      value15 = 0,
      value16 = 0,
      value17 = 0,
      value18 = 0,
      value19 = 0,
      value20 = 0;
  int value21 = 0,
      value22 = 0,
      value23 = 0,
      value24 = 0,
      value25 = 0,
      value26 = 0,
      value27 = 0,
      value28 = 0,
      value29 = 0,
      value30 = 0;
  int value31 = 0,
      value32 = 0,
      value33 = 0,
      value34 = 0,
      value35 = 0,
      value36 = 0,
      value37 = 0,
      value38 = 0,
      value39 = 0,
      value40 = 0;
  int value41 = 0,
      value42 = 0,
      value43 = 0,
      value44 = 0,
      value45 = 0,
      value46 = 0,
      value47 = 0;

// @override
// void dispose() {
//   _readTimer?.cancel();
//   _readTimer = null;
//
//   try {
//     if (port.isOpen) {
//       port.close();
//       debugPrint('Porta ${port.name} fechada com sucesso.');
//     } else {
//       debugPrint('Porta ${port.name} já estava fechada.');
//     }
//   } catch (e, stackTrace) {
//     debugPrint('Erro ao fechar a porta ${port.name}: $e');
//     debugPrint('StackTrace: $stackTrace');
//   }
//
//   super.dispose();
// }

  double timeCounter = 0;
  List<FlSpot> speedSpots = [FlSpot(0, 0)];
  List<FlSpot> accXSpots = [FlSpot(0, 0)];
  List<FlSpot> rollSpots = [FlSpot(0, 0)];
  List<FlSpot> accYSpots = [FlSpot(0, 0)];
  List<FlSpot> accZSpots = [FlSpot(0, 0)];
  List<FlSpot> rpmSpots = [FlSpot(0, 0)];

  @override
  void initState() {
    super.initState();
    debugPrint("Entrando na tela de rádio: iniciando a conexão serial.");
    initSerialPort();
  }

  // @override
// void dispose() {
//   debugPrint("Saindo da tela de rádio: cancelando Timer e fechando a porta.");
//   _readTimer?.cancel();
//   if (port.isOpen) {
//     port.close();
//     debugPrint("Porta ${port.name} fechada com sucesso.");
//   }
//   super.dispose();
// }

  /// Inicializa a porta serial e inicia a leitura dos dados

  // Widget para gráficos
  // Atualize também o buildLineChart para não fixar uma altura específica:
  /// Widget para construir o gráfico de linhas (para aceleração e RPM)
  Widget buildLineChart(String title, List<FlSpot> spots, Color color) {
    final double maxX = spots.isNotEmpty ? spots.last.x : 20.0;
    final double minX = maxX > 20 ? maxX - 20 : 0.0;
    double maxY, minY;
    List<double> leftTitles;

    if (title.startsWith("Aceleração")) {
      maxY = 3;
      minY = -3;
      leftTitles = [-3, -2, -1, 0, 1, 2, 3];
    } else if (title == "RPM") {
      maxY = 6000;
      minY = 0;
      // Aqui você pode ampliar as opções de valores conforme sua necessidade
      leftTitles = [0, 1000, 2000, 3000, 4000, 5000, 6000];
    } else {
      maxY = spots.isNotEmpty
          ? (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 3)
          : 10.0;
      minY = spots.isNotEmpty
          ? (spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 3)
          : -10.0;
      leftTitles = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título do gráfico
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Gráfico de linha com os números do eixo à esquerda exibindo a métrica
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              lineTouchData: const LineTouchData(enabled: false),
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.green.shade200,
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: Colors.green.shade200,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 70,
                    getTitlesWidget: (value, meta) {
                      if (leftTitles.contains(value)) {
                        String label = value.toStringAsFixed(0);
                        // Adiciona unidade conforme o tipo do gráfico
                        if (title.startsWith("Aceleração")) {
                          label += "g";
                        } else if (title == "RPM") {
                          label += " rpm";
                        }
                        return Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[900],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toStringAsFixed(0)}s',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.green.shade300, width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  shadow: Shadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Exibe um Card com título e valor (ex.: "Acc X: 1.2")
  Widget _buildDataCard(String title, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 16, color: Colors.green[900]),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe uma linha com 3 dados (para os valores do acelerômetro)
  Widget _buildDataRow(String label1, dynamic value1, String label2,
      dynamic value2, String label3, dynamic value3) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDataText(label1, value1),
          _buildDataText(label2, value2),
          _buildDataText(label3, value3),
        ],
      ),
    );
  }

  /// Exibe um texto com o dado e seu valor
  Widget _buildDataText(String label, dynamic value) {
    return Expanded(
      child: Text(
        '$label: ${value.toString()}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.green[900],
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Card customizado para os gráficos
  Widget _dataCard(Widget child, double width, double height) {
    return Card(
      elevation: 4,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: child,
        ),
      ),
    );
  }

  /// Exibe o gráfico de RPM e o velocímetro com os botões abaixo.
  Widget _buildChartAndButtonsLayout(BuildContext context) {
    // Obtém a velocidade atual (último valor de speedSpots)
    final double currentSpeed = speedSpots.isNotEmpty ? speedSpots.last.y : 0;
    final double currentrpm = rpmSpots.isNotEmpty ? rpmSpots.last.y : 0;

    return Flexible(
      flex: 10,
      child: Column(
        children: [
          // Linha com o gráfico de RPM e o velocímetro
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: rpmWidget(rpmatual: currentrpm),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: VelocimetroWidget(velocidadeAtual: currentSpeed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Linha com os botões Live e Home centralizados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 182, 235, 185),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LiveScreen()),
                  );
                },
                child: const Text(
                  'Live',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 182, 235, 185),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                },
                child: const Text(
                  'Home',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/navbar_logo.png',
              height: 80,
              width: 80,
            ),
            const SizedBox(width: 8),
            Text(
              'Rádio',
              style: TextStyle(
                fontFamily: 'Georgia',
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade800,
        elevation: 4,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade200,
              Colors.green.shade700,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Seção 1: Dados das acelerações (com valores ao lado dos nomes)

            // Seção 2: Gráficos de aceleração (X, Y, Z) com eixo lateral fixo e métricas
            Flexible(
              flex: 8,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _dataCard(
                            buildLineChart("Aceleração X = $acc_x", accXSpots,
                                Colors.green.shade400),
                            double.infinity,
                            600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dataCard(
                            buildLineChart("Aceleração Y = $acc_y", accYSpots,
                                Colors.green.shade600),
                            double.infinity,
                            600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dataCard(
                            buildLineChart("Aceleração Z = $acc_z", accZSpots,
                                Colors.green.shade800),
                            double.infinity,
                            600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Bloco 2: Dados - Temperatura e CVT
            Flexible(
              flex: 2,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      _buildDataText("Motor", "$temperature°C"),
                      _buildDataText("CVT", "$cvt°C"),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bloco 3: Dados - Voltagem e SOC
            Flexible(
              flex: 2,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      _buildDataText("Tensão", roundedValue),
                      _buildDataText("SOC", soc),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Seção 5: Gráfico de RPM e Velocímetro com os botões abaixo
            _buildChartAndButtonsLayout(context),
          ],
        ),
      ),
    );
  }
}

/// Widget personalizado para o velocímetro
class VelocimetroWidget extends StatelessWidget {
  final double velocidadeAtual;
  const VelocimetroWidget({Key? key, required this.velocidadeAtual})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Velocidade: ${velocidadeAtual.toStringAsFixed(2)} km/h",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 8),
        // Gauge do velocímetro
        SizedBox(
          height: 200,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 60,
                interval: 10,
                pointers: <GaugePointer>[
                  NeedlePointer(
                    value: velocidadeAtual,
                    needleColor: Colors.blue,
                    knobStyle: KnobStyle(color: Colors.blue),
                  )
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}

class rpmWidget extends StatelessWidget {
  final double rpmatual;
  const rpmWidget({Key? key, required this.rpmatual}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "RPM: ${rpmatual.toStringAsFixed(2)} km/h",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 8),
        // Gauge do velocímetro
        SizedBox(
          height: 200,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 60,
                interval: 10,
                pointers: <GaugePointer>[
                  NeedlePointer(
                    value: rpmatual,
                    needleColor: Colors.blue,
                    knobStyle: KnobStyle(color: Colors.blue),
                  )
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}
