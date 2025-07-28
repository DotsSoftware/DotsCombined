import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class FirebaseAuthService {
  static const _serviceAccountJson = {
  "type": "service_account",
  "project_id": "dots-b3559",
  "private_key_id": "9828916518aae6ee63dee0f5efb5bf1b990ddfba",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC4gJhJcOQnDkvc\nP+RiDdSl7hYl3KBDlDo/hp1RyoxzKLqzwrqSRBEMFfZN7WIEUZJV/2whdOI7oEFt\n2Z5O+JeDqNblMw5WMTjlGHkDR3ZcDHrv9oIGjF4NXtkT36esXNjVbEUKbwLlD24K\nEpxZy6/zbXwiFieIPvzlZmd5Xo7fKxYqmetYiirOc8X5wSk/bLuKADGEOyHyamd/\n0HgBVsoVkoOTF2verBLdvib5UTvgnM2ov5xb/mnbbeAGlZALkieeSW1j4spGO4Sk\nwGO/6sFG2s91UTO113gi8YwHOAP2ae8ZMnTJle8seVg2iQebzLH+/Zj69hpIIKsQ\nDSLUxhzlAgMBAAECggEADHgqcqo1zTru3xWVXJglM0quRgRNc4vIzQLOzpiTGfRa\ne+ww+lIt2cSBNz6QJY0SyAuhdfhlktSPn3o59AniiZQnY+mpsiMU/ozDHvjdM7bn\nNyEQpBsn/xzWLHzs4t4KjJAK8XvTtQHwNK+R0BLPUzMm1NHs/Y0OP/3GCAKfQs9T\n0VhUHtq/BQZksAUU2ANAUbXpnoY7rBnPCwiL8kSTAptxQ6dbSskuCxLtqSZkqSxo\n4EsOfOUcB6WsV8y3+SutIAvPsWaDNxzUrzfGXfIRXdwO6+guRyN22OonLylfwddi\nhvGHZJlf+jUqcPOu/sSX6z2p0XZR13HwsXn4v6M4YQKBgQD1kl3mxX8hB5ra/uqL\njLbw9+000uMMiA158kllHaW87uRmlDfEFiQnj5FFhb0sXSPlvPm37f2ifnNlsa6a\ns6D63XZmAdWvTlGbzxK5NTlmKNvxSlN7G4L7/7M4wKc5JxGHrB7yV1T1XkdMtElH\nQx62iKmU5gnXBPAXYb8b1Da24QKBgQDAVlYzwWs/43ZRPkXIejFqZcmuQCfw+9OB\nfrKGOIXYlpCHQDxZ9w9DGYX5/xlAa8G6YRO+bjqF3RqdKAEcRs+XfhYTHj4j0ZOo\niDP7nnpQh6saVlVYlSSkziajE3C0bgjs62dw7R2zTVPVX+GSvzUaLUC4+x9sygea\n1pDUD85ahQKBgFGgTUYf75nzBS41/ZBVPZnrTxV347COqKwYNP0/VY/veEwAiGjN\nU0czGX6abb8JVp1Oq1LP8LbKgWEUJo2Vl7TLWEef5H9Y8RdxRS/62RF0E2eo5QbO\npkNNQy1iHDOLIPCP7dlv3fWRWPHOG21sihDybCvqKusl4QhknTmK2IUBAoGAXQAi\nNGpc+op45nXO9k4nYMQRDgGVjo+lyKLDneTsyzqabdugkvvEVHSd9LDlu+Gezgks\nq9LO13V+7eivCMYwkJb2A46HC3jGBiK9x/fsOs4u7NA7+lY7XrkTs5ytzYC7Lhvx\na4gr6UwFslHnV7a+7YZeGlPK8SaLINKJOxDdfaUCgYAUZIxpgvhgfY+NtgysDcGc\nxewumxc7Ba0kVyMFiYsI5DJxBDqkJ9L3aayunf8OvAj7sHzwY6QXjwE8PfEjZMYV\nhGZ25qU1Bvew7B+/Ic/pdvQ077qwANyxduife3ImF9uuXZPNG7RNn0yukXO4iElf\ne6CJGLr6YxGO2/6GKCPa7g==\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-ecgab@dots-b3559.iam.gserviceaccount.com",
  "client_id": "106002613230535720514",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-ecgab%40dots-b3559.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
};

  static const _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
    'https://www.googleapis.com/auth/cloud-platform',
  ];

  Future<String> getAccessToken() async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(
        _serviceAccountJson,
      );
      final client = await clientViaServiceAccount(credentials, _scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      print('Error getting access token: $e');
      rethrow;
    }
  }
}
