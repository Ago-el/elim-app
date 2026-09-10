import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://elim-ap.onrender.com',
  );

  // Récupère le token pour les requêtes
  Future<Map<String, String>> headers() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'
    };
  }

  // GET
  Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: await headers());
    return decode(r);
  }

  // POST
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await headers(),
      body: jsonEncode(body),
    );
    return decode(r);
  }

  // Gère la réponse de l'API
  dynamic decode(http.Response r) {
    dynamic d;
    try {
      d = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {
      d = r.body;
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(d is Map ? (d['detail'] ?? 'Erreur serveur') : 'Erreur serveur (${r.statusCode})');
    }
    return d;
  }

  // 1. Connexion Admin
  Future<Map> connexionAdmin(String email, String motDePasse) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/admin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": motDePasse}),
    );
    return decode(r);
  }

  // 2. Créer Église - version française
  Future<Map> creerEglise(String nom, String pays, String ville) async {
    return await post('/api/v1/churches', {
      "name": nom,
      "country": pays,
      "city": ville,
    });
  }

  // 3. Créer Église - version anglaise pour main.dart
  Future<void> createChurch(String name, String country, String region) async {
    await post('/api/v1/churches', {
      "name": name,
      "country": country,
      "city": region, // ton API utilise "city"
    });
  }
}
