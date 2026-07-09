import 'package:agconnect_core/agconnect_core.dart';

Future<void> initializeAgc() async {
  final builder = AGConnectOptionsBuilder()
    ..productId = '101653523864494205'
    ..appId = '118256823'
    ..cpId = '10086000953940259'
    ..clientId = '1990028531408592704'
    ..clientSecret =
        'BCA8B760521B5EA5F0E1C71EEFC7058A2896EA694CEB70467B0DDF620E29561B'
    ..apiKey =
        'DgEDAH1VnSCiRnC/hOSeuYt4vagWjKeujKU74itOVF9wnGPypNdi1NwN9eVJOqHncIQOn3xGePmDJPaOk8t+gIVh8aqfrq3z4yap4w=='
    ..routePolicy = AGCRoutePolicy.CHINA
    ..packageName = 'com.example.life_sense';
  await AGConnectInstance.instance.buildInstance(AGConnectOptions(builder));
}
