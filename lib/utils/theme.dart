import 'package:flutter/material.dart';

// Define the appGradient
const LinearGradient appGradient = LinearGradient(
  colors: [
    Color(0xFF1E3A8A), // Primary blue
    Color(0xFF3B82F6), // Lighter blue for gradient effect
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Define the appTheme
ThemeData appTheme() {
  return ThemeData(
    primaryColor: const Color(0xFF1E3A8A),
    scaffoldBackgroundColor:
        Colors.transparent, // Transparent to allow gradient backgrounds
    cardTheme: CardThemeData(
      // Changed from CardTheme to CardThemeData
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: Colors.black.withOpacity(0.3),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: TextStyle(color: Colors.grey[600]),
    ),
  );
}
