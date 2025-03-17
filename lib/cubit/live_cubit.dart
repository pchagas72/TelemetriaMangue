import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

part 'live_state.dart';

class Packet {
  double time = 0;
  double speed = 0;
  double rpm = 0;
  double temperatureMotor = 0;
  double temperatureCVT = 0;
  double soc = 0;
  double voltage = 0;
  double current = 0;
  double latitude = 0;
  double longitude = 0;
  double accx = 0;
  double accy = 0;
  double accz = 0;
  double roll = 0;
  double pitch = 0;
}

class LiveCubit extends Cubit<LiveState> {
  LiveCubit() : super(LiveInitial());

  void startEmittingFloats() {
    List<Packet> packets = [];
    List<Packet> newPackets = [];

    for (int i = 0; i < 400; i += 1) {
      Packet dummy = Packet();
      dummy.speed = 0;
      dummy.time = 0;

      packets.add(dummy);
      newPackets.add(dummy);
    }

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      var url = Uri.parse("http://69.55.61.114:1880/data");
      var result = await http.get(url);

      if (result.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(result.body);

        List<double> timeJson = parseResult(jsonResponse, 'timestamp');
        List<double> speeds = parseResult(jsonResponse, 'speed');
        List<double> rpms = parseResult(jsonResponse, 'rpm');
        List<double> temperatureMotors = parseResult(jsonResponse, 'motor');
        List<double> temperatureCVTs = parseResult(jsonResponse, 'cvt');
        List<double> socs = parseResult(jsonResponse, 'soc');
        List<double> voltages = parseResult(jsonResponse, 'volt');
        List<double> currents = parseResult(jsonResponse, 'current');
        List<double> latitudes = parseResult(jsonResponse, 'latitude');
        List<double> longitudes = parseResult(jsonResponse, 'longitude');
        List<double> accxs = parseResult(jsonResponse, 'acc_x');
        List<double> accys = parseResult(jsonResponse, 'acc_y');
        List<double> acczs = parseResult(jsonResponse, 'acc_z');
        List<double> rolls = parseResult(jsonResponse, 'roll');
        List<double> pitchs = parseResult(jsonResponse, 'pitch');

        newPackets = [];

        for (double i = 0; i < timeJson.length; i++) {
          Packet packet = Packet();
          packet.time = i;
          packet.speed = speeds[i.toInt()];
          packet.rpm = rpms[i.toInt()];
          packet.temperatureMotor = temperatureMotors[i.toInt()];
          packet.temperatureCVT = temperatureCVTs[i.toInt()];
          packet.soc = socs[i.toInt()];
          packet.voltage = voltages[i.toInt()];
          packet.current = currents[i.toInt()];
          packet.latitude = latitudes[i.toInt()];
          packet.longitude = longitudes[i.toInt()];
          packet.accx = accxs[i.toInt()];
          packet.accy = accys[i.toInt()];
          packet.accz = acczs[i.toInt()];
          packet.roll = rolls[i.toInt()];
          packet.pitch = pitchs[i.toInt()];
          newPackets.add(packet);
        }

        // var uniqueMap = {for (var obj in newPackets) obj.time: obj};
        // newPackets = uniqueMap.values.toList();
      }
    });

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (packets != newPackets) {
        packets = newPackets;
        packets = newPackets;
        emit(DataState(packets: packets));
      }
    });
  }
}

@override
Widget build(BuildContext context) {
  throw UnimplementedError();
}

List<double> parseResult(List<dynamic> jsonResponse, String dataField) {
  List<double> timeJson =
      jsonResponse.map<double>((item) => item[dataField].toDouble()).toList();
  return timeJson.reversed.toList();
}
