import 'package:flutter/services.dart';

const _channel = MethodChannel('mechi/job_actions');

Future<bool> openJobDirections(Uri destination) =>
    _open('directions', destination.toString());

Future<bool> openJobDialler(String phone) async =>
    RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(phone) &&
    await _open('dial', phone);

Future<bool> _open(String method, String argument) async {
  try {
    return await _channel.invokeMethod<bool>(method, argument) == true;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
