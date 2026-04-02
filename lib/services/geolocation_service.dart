import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;

class LocationInfo {
  final String cidade;
  final String bairro;
  final double latitude;
  final double longitude;

  LocationInfo({
    required this.cidade,
    required this.bairro,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() =>
      'LocationInfo(cidade=$cidade, bairro=$bairro, lat=$latitude, lng=$longitude)';
}

class GeolocationService {
  /// Solicita permissão de geolocalização
  static Future<bool> requestLocationPermission() async {
    print('Requisitando permissão de geolocalização...');
    try {
      final permission = await Geolocator.checkPermission();
      print('Permissão atual: $permission');

      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        print('Resultado da solicitação: $result');
        return result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        print('Permissão já concedida');
        return true;
      } else if (permission == LocationPermission.deniedForever) {
        print('Permissão negada permanentemente. Abrindo configurações...');
        await Geolocator.openLocationSettings();
        return false;
      }
      return false;
    } catch (e) {
      print('Erro ao solicitar permissão: $e');
      return false;
    }
  }

  /// Obtém a localização atual do usuário
  static Future<Position?> getAtualPosition() async {
    print('Obtendo posição atual...');
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Sem permissão de geolocalização');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Posição obtida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Erro ao obter posição: $e');
      return null;
    }
  }

  /// Obtém informações de localização (cidade, bairro) de uma posição
  static Future<LocationInfo?> getLocationInfo(
      double latitude, double longitude) async {
    print('Obtendo informações de localização para ($latitude, $longitude)...');
    try {
      final placemarks =
          await geo.placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        print('Nenhum placemark encontrado');
        return null;
      }

      final mark = placemarks[0];
      print(
          'Placemark: ${mark.street}, ${mark.subLocality}, ${mark.locality}, ${mark.administrativeArea}');

      final cidade = (mark.locality?.trim().isNotEmpty ?? false)
          ? mark.locality!
          : (mark.administrativeArea?.trim().isNotEmpty ?? false)
              ? mark.administrativeArea!
              : 'Desconhecido';

      final bairro = (mark.subLocality?.trim().isNotEmpty ?? false)
          ? mark.subLocality!
          : (mark.street?.trim().isNotEmpty ?? false)
              ? mark.street!
              : 'Desconhecido';

      final info = LocationInfo(
        cidade: cidade,
        bairro: bairro,
        latitude: latitude,
        longitude: longitude,
      );
      print('LocationInfo: $info');
      return info;
    } catch (e) {
      print('Erro ao obter informações de localização: $e');
      return null;
    }
  }

  /// Captura a localização completa do usuário
  static Future<LocationInfo?> captureLocationWithInfo() async {
    print('Capturando localização com informações...');
    try {
      final position = await getAtualPosition();
      if (position == null) {
        print('Não foi possível obter a posição');
        return null;
      }

      final info = await getLocationInfo(position.latitude, position.longitude);
      return info;
    } catch (e) {
      print('Erro ao capturar localização: $e');
      return null;
    }
  }

  /// Gera URL do Google Maps para uma coordenada
  static String getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  /// Abre Google Maps para uma coordenada (retorna a URL para o usuário abrir)
  static String getGoogleMapsUrlForDisplay(double latitude, double longitude) {
    // Formato: q=latitude,longitude
    return getGoogleMapsUrl(latitude, longitude);
  }
}
