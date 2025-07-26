import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class FirebaseAuthService {
  static const _serviceAccountJson = {
    "type": "service_account",
    "project_id": "dots-b3559",
    "private_key_id": "0c2f3e65c470e9c83099c9138a75dad3553765c7",
    "private_key": """-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCv0PIYHvy/UDyG
8HTMWYYUBqWsMNBYTswdVDdzSnG+9iru81PjqXmb4kKKf4dMGVLNvNYXM1uZ7KjQ
fVF5dBX0ngAacXIWbWdbq59DbKXqsNjStbwTZjBOnQ+whL1kYcY3TR68XIBJMV5v
55XNJcmEobxGM7PBdNhDxDa0CDYAOjIosIZ1Im0qzIYD49Jj9ZspYLydagjtOI66
Db/xjZnN32dObVCx9FyVIHXoO8ByzeZYOBcGXj7JEYUTcP79rvJEenfDOYvyM/rn
U4uT8toDJpn5cVbn7eJdDJH9AUhzoMQLn5ICEghmHDyfoZNnCvubZypti6geDIh7
Rp++C4TFAgMBAAECggEAF1vkMmK5k2SCai474mOZjgMVE2PX5oevlEz6Ygm3w5aa
vS0cjfCYHOcqjpKjg++QYg/PBP2Yk8KO6kZgIwoSmbG9U0YT0Zl/BD2w1wkyIRSW
diZZot0umV9CNKJqNFJOPs4zAXUrwS27PZRwAXXeCI5hgJVBcnhG/HfvCavWmuBo
DMFTmGzR9c4X14zQuV094louIUqCCe1K5GxAmfPZT/xsp1DGaxupNp5zKkQSDC+H
oG81QN0N9c829cegrPY/gttjA3itUWkibjceHBE5wBOkbDZJ2s/tJqPvGG2nnuiT
i+fzq7ouOAbdaKinsMEj/8RyaPbiokyGEI/xrt+OSQKBgQDhKpbCZYqBCTFMqw9P
l/v9wn0o0536a+zE776N7IvYFE6DAiA7fofF0bYHCsQsKjRBHIrHF6HGn73esX0W
3jdaFqHDUgsUObsyudNwcAD/W/gKRrN4HVwgLaxGOM0sCd+ascH2LMZJSoNMPGRE
HIn3NRPXBsTY/ZgwJ67+VMsgbQKBgQDH5FeDDGJG1DqwhrZ4T2PmE/CrJARGpdTc
KrIRzDD5VX5SMtAOcxEzqsfLVOLcX8fJw7+q4b1Glp55b7PQd6RyNlTlx+LcxL2d
JZFxY7hK8MKwmhrez3TSZ60ZPOTO6wnoYhcwGnr1Wn949B/rtLRfdsi/T/PxmePJ
DdEOx7OuuQKBgH14BPAoMui6XZ1SSMLadxGtWZ7xZLuRfiszSOS+5iIvFpzMB3f/
htrFhAAikLPnhJyvselFEuGiS+QW1RR0GTX7HILBaekITnbys46Y6wVgkzPut7z7
50ULDk9HAZVDnzUNTn7F7mwSuF033ctSd9Kn4flVDUW48iALTOjuCQ51AoGAPATl
+eVYBOhojuSEGW/NESJfmyN/XS8h0NHJEer7sYHoIgo7ynrmaVsYDod4bq8bsAtk
m4yYZn+HKfNOTIQADoMdzrjL93njbTIAj8lfZrEP5DMBanFkJGEY6oEMOsz79pit
WbY5wT3hFJJIm19w4VErSbZaCusoKBBL+2IfI5ECgYEArNCiEQXcX/GE+bkuv/vO
5isI3RwP+3tBRsR91NHMNDLk8UKgxC/DkXJf1ZzU6GmSBuheBnts2/gfu5e0cLeS
rQTzjWGJX3UqTSyafL8iVDUD4ol4qcIV4vgML365ML9T/5zAtlb0k0zjkb7G1XhA
84AvY9HguxMDceUDBpoDXsU=
-----END PRIVATE KEY-----""",
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
    'https://www.googleapis.com/auth/cloud-platform'
  ];

  Future<String> getAccessToken() async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
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