import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../debug/dc_log.dart';
import '../models/saved_address.dart';
import '../services/image_picker_service.dart';
import '../services/local_storage_service.dart';

class UserProfileProvider extends ChangeNotifier {
  static const String _defaultName = '';
  static const String _defaultPhone = '';

  static const String _keyName      = 'profile_name';
  static const String _keyPhone     = 'profile_phone';
  static const String _keyAvatar    = 'profile_avatar';
  static const String _keyAddress   = 'profile_address';      // legacy single address
  static const String _keyAddresses = 'profile_addresses_v2'; // new multi-address list
  static const String _keyUid       = 'profile_uid';

  String _name  = _defaultName;
  String _phone = _defaultPhone;
  String _uid   = '';
  Uint8List? _avatarBytes;

  /// Multi-address book. The default address is the one with isDefault == true.
  List<SavedAddress> _addresses = [];

  String get name    => _name;
  String get phone   => _phone;
  String get uid     => _uid;
  Uint8List? get avatarBytes => _avatarBytes;

  /// All saved addresses (copy).
  List<SavedAddress> get addresses => List.unmodifiable(_addresses);

  /// The active (default) address, or null if none saved.
  SavedAddress? get defaultAddress =>
      _addresses.isEmpty ? null : _addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => _addresses.first,
      );

  /// The primary address text for displaying in the profile header.
  String get address => defaultAddress?.fullAddress ?? '';

  /// True if the user has completed a real Firebase OTP sign-in.
  bool get isLoggedIn => _uid.isNotEmpty;

  /// True when we have saved name, phone, and at least one address.
  bool get hasCheckoutDetails =>
      _name.trim().isNotEmpty &&
      _name != _defaultName &&
      _phone.trim().length == 10 &&
      _addresses.isNotEmpty;

  /// Phone formatted as "+91 XXXXX XXXXX"
  String get displayPhone {
    final p = _phone.replaceAll(RegExp(r'\s'), '');
    if (p.length == 10) {
      return '+91 ${p.substring(0, 5)} ${p.substring(5)}';
    }
    return '+91 $p';
  }

  bool get isGuest => _name == _defaultName;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadProfile() async {
    _name  = await LocalStorageService.getString(_keyName)  ?? _defaultName;
    _phone = await LocalStorageService.getString(_keyPhone) ?? _defaultPhone;
    _uid   = await LocalStorageService.getString(_keyUid)   ?? '';

    if (_phone == '9876543210') _phone = ''; // Wipe legacy default

    // Load multi-address list
    await _loadAddresses();

    if (_uid.isNotEmpty) {
      if (kIsWeb) {
        _uid = '';
        await LocalStorageService.setString(_keyUid, '');
      } else {
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            _uid = '';
            await LocalStorageService.setString(_keyUid, '');
          }
        } catch (_) {
          _uid = '';
          await LocalStorageService.setString(_keyUid, '');
        }
      }
    }

    final avatarB64 = await LocalStorageService.getString(_keyAvatar);
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        _avatarBytes = base64Decode(avatarB64);
      } catch (_) {
        _avatarBytes = null;
      }
    }
  }

  Future<void> _loadAddresses() async {
    // Try new multi-address key
    final jsonStr = await LocalStorageService.getString(_keyAddresses);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _addresses = list
            .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
            .toList();
        return;
      } catch (_) {}
    }

    // Migrate from legacy single address key
    final legacy = await LocalStorageService.getString(_keyAddress) ?? '';
    if (legacy.isNotEmpty) {
      _addresses = [
        SavedAddress(
          id: 'home',
          label: 'home',
          fullAddress: legacy,
          isDefault: true,
        ),
      ];
      await _persistAddresses();
    }
  }

  Future<void> _persistAddresses() async {
    final jsonStr = jsonEncode(_addresses.map((a) => a.toJson()).toList());
    await LocalStorageService.setString(_keyAddresses, jsonStr);
    // Keep legacy key in sync with the default address so old code still works.
    await LocalStorageService.setString(_keyAddress, address);

    // Sync to Firebase
    final p = _phone.replaceAll(RegExp(r'\D'), '');
    if (p.length >= 10) {
      final last10Digits = p.substring(p.length - 10);
      try {
        final Map<String, dynamic> fbData = {};
        for (final addr in _addresses) {
          final type = addr.label.toLowerCase(); // home, work, other
          fbData[type] = {
            'datas': addr.fullAddress,
            'gps': addr.gpsCoords ?? '',
          };
        }
        await FirebaseDatabase.instance.ref('root/useradress/$last10Digits').set(fbData);
      } catch (e) {
        debugPrint('Address firebase sync error: $e');
      }
    }
  }

  // ── Firebase Auth sync ────────────────────────────────────────────────────

  Future<void> signInFromAuth(User user) async {
    final phone = (user.phoneNumber ?? '').replaceFirst('+91', '').trim();
    debugPrint('--- DEBUG: UserProfileProvider signInFromAuth with phone: "$phone" ---');
    _uid = user.uid;
    if (phone.isNotEmpty) _phone = phone;
    await LocalStorageService.setString(_keyUid,   _uid);
    await LocalStorageService.setString(_keyPhone, _phone);
    notifyListeners();
  }

  Future<void> signOut() async {
    _uid   = '';
    _name  = _defaultName;
    _phone = '';
    await LocalStorageService.setString(_keyUid,   '');
    await LocalStorageService.setString(_keyPhone, '');
    await LocalStorageService.setString(_keyName,  _defaultName);
    notifyListeners();
  }

  // ── Profile fields ────────────────────────────────────────────────────────

  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (_name == trimmed || trimmed.isEmpty) return;
    _name = trimmed;
    await LocalStorageService.setString(_keyName, trimmed);
    notifyListeners();
  }

  Future<void> updatePhone(String phone) async {
    final trimmed = phone.trim();
    if (_phone == trimmed) return;
    _phone = trimmed;
    await LocalStorageService.setString(_keyPhone, trimmed);
    notifyListeners();
  }

  Future<void> updateNameAndPhone(String name, String phone) async {
    debugPrint('--- DEBUG: UserProfileProvider updateNameAndPhone called: "$name", "$phone" ---');
    final trimmedName  = name.trim();
    final trimmedPhone = phone.trim();
    bool changed = false;
    if (trimmedName.isNotEmpty && _name != trimmedName) {
      _name = trimmedName;
      await LocalStorageService.setString(_keyName, trimmedName);
      changed = true;
    }
    if (_phone != trimmedPhone) {
      _phone = trimmedPhone;
      await LocalStorageService.setString(_keyPhone, trimmedPhone);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ── Address book ──────────────────────────────────────────────────────────

  /// Add a new address; automatically set as default if it's the first one.
  Future<void> addAddress(SavedAddress addr) async {
    final isFirst = _addresses.isEmpty;
    final normalized = addr.copyWith(isDefault: isFirst || addr.isDefault);
    // If the new one is default, clear all others.
    if (normalized.isDefault) {
      _addresses = _addresses
          .map((a) => a.copyWith(isDefault: false))
          .toList();
    }
    _addresses.add(normalized);
    await _persistAddresses();
    notifyListeners();
  }

  /// Update an existing address by id.
  Future<void> updateAddress(SavedAddress updated) async {
    final idx = _addresses.indexWhere((a) => a.id == updated.id);
    if (idx < 0) return;
    if (updated.isDefault) {
      _addresses = _addresses
          .map((a) => a.id == updated.id ? updated : a.copyWith(isDefault: false))
          .toList();
    } else {
      _addresses[idx] = updated;
    }
    await _persistAddresses();
    notifyListeners();
  }

  /// Remove an address by id. If it was default, promote the next one.
  Future<void> removeAddress(String id) async {
    final wasDefault = _addresses.any((a) => a.id == id && a.isDefault);
    _addresses.removeWhere((a) => a.id == id);
    if (wasDefault && _addresses.isNotEmpty) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    await _persistAddresses();
    notifyListeners();
  }

  /// Set an existing address as the default.
  Future<void> setDefaultAddress(String id) async {
    _addresses = _addresses
        .map((a) => a.copyWith(isDefault: a.id == id))
        .toList();
    await _persistAddresses();
    notifyListeners();
  }

  // ── Checkout helpers (kept for backward compat.) ──────────────────────────

  Future<void> saveCheckoutDetails({
    required String name,
    required String phone,
    required String address,
    String? gpsCoords,
    String label = 'home',
  }) async {
    debugPrint('--- DEBUG: UserProfileProvider saveCheckoutDetails called: phone="$phone" ---');
    final trimmedName    = name.trim();
    final trimmedPhone   = phone.trim();
    final trimmedAddress = address.trim();
    bool changed = false;
    if (trimmedName.isNotEmpty && _name != trimmedName) {
      _name = trimmedName;
      await LocalStorageService.setString(_keyName, trimmedName);
      changed = true;
    }
    if (_phone != trimmedPhone) {
      _phone = trimmedPhone;
      await LocalStorageService.setString(_keyPhone, trimmedPhone);
      changed = true;
    }

    if (trimmedAddress.isNotEmpty) {
      // Upsert: update existing home address or add new one.
      final existing = _addresses.indexWhere(
        (a) => a.label.toLowerCase() == label.toLowerCase(),
      );
      final newAddr = SavedAddress(
        id: existing >= 0 ? _addresses[existing].id : label,
        label: label,
        fullAddress: trimmedAddress,
        gpsCoords: gpsCoords,
        isDefault: existing >= 0 ? _addresses[existing].isDefault : _addresses.isEmpty,
      );
      if (existing >= 0) {
        await updateAddress(newAddr);
      } else {
        await addAddress(newAddr);
      }
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> clearCheckoutDetails() async {
    if (!hasCheckoutDetails && _addresses.isEmpty) return;
    _name  = _defaultName;
    _phone = '';
    _addresses = [];
    await LocalStorageService.setString(_keyName,      _defaultName);
    await LocalStorageService.setString(_keyPhone,     '');
    await LocalStorageService.setString(_keyAddress,   '');
    await LocalStorageService.setString(_keyAddresses, '');
    notifyListeners();
  }

  // ── Legacy single-address setter (still used by checkout page) ────────────

  Future<void> updateAddressLegacy(String addressText) async {
    final trimmed = addressText.trim();
    if (trimmed.isEmpty) return;
    final existing = _addresses.indexWhere(
      (a) => a.label.toLowerCase() == 'home',
    );
    final newAddr = SavedAddress(
      id: existing >= 0 ? _addresses[existing].id : 'home',
      label: 'home',
      fullAddress: trimmed,
      isDefault: existing >= 0 ? _addresses[existing].isDefault : true,
    );
    if (existing >= 0) {
      await updateAddress(newAddr);
    } else {
      await addAddress(newAddr);
    }
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> pickAndUpdateAvatar() async {
    try {
      final bytes = await ImagePickerService.pickImageBytes();
      if (bytes == null) return;
      _avatarBytes = bytes;
      await LocalStorageService.setString(_keyAvatar, base64Encode(bytes));
      notifyListeners();
    } catch (e) {
      dcLog('Profile', 'Avatar pick error: $e');
    }
  }

  Future<void> clearAvatar() async {
    _avatarBytes = null;
    await LocalStorageService.remove(_keyAvatar);
    notifyListeners();
  }
}
