import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const BolidApp());
}

class BolidApp extends StatelessWidget {
  const BolidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telemetria Bolidu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MqttServerClient client = MqttServerClient('68.210.36.189', 'flutter_client');
  
  String statusText = 'Rozłączono';
  String receivedData = 'Brak danych';

  @override
  void initState() {
    super.initState();
    connectToBroker();
  }

  Future<void> connectToBroker() async {
    client.port = 1883;
    client.logging(on: true); // Pomaga w debugowaniu w konsoli VS Code
    client.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client_1')
        .authenticateAs('bolid', 'Hydrive123')
        .startClean();
    
    client.connectionMessage = connMess;

    try {
      setState(() => statusText = 'Łączenie...');
      await client.connect();
    } catch (e) {
      setState(() => statusText = 'Błąd połączenia: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() => statusText = 'Połączono z serwerem!');
      
      // Subskrypcja tematu z danymi bolidu
      client.subscribe('bolid/telemetria', MqttQos.atMostOnce);

      // Nasłuchiwanie na przychodzące wiadomości
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        setState(() {
          receivedData = pt;
        });
      });
    } else {
      setState(() => statusText = 'Odrzucono połączenie');
      client.disconnect();
    }
  }

  // Funkcja symulująca nadawanie danych (zastępuje na razie ESP32)
  void simulateCarData() {
    if (client.connectionStatus!.state != MqttConnectionState.connected) return;

    final builder = MqttClientPayloadBuilder();
    
    // Tworzymy symulowanego JSON-a
    final Map<String, dynamic> fakeData = {
      "predkosc": 120 + (DateTime.now().second % 10), // Symulacja zmiany prędkości
      "temperatura": 85.5,
      "timestamp": DateTime.now().toIso8601String()
    };
    
    builder.addString(jsonEncode(fakeData));

    client.publishMessage(
      'bolid/telemetria', 
      MqttQos.atMostOnce, 
      builder.payload!
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bolid Telemetria (Test)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: client.connectionStatus?.state == MqttConnectionState.connected 
                  ? Colors.green.shade100 
                  : Colors.red.shade100,
              child: Text('Status: $statusText', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
            const Text('Ostatnie odebrane dane (Subskrypcja):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                receivedData,
                style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: simulateCarData,
              icon: const Icon(Icons.send),
              label: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Symuluj wysłanie danych z bolidu', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}