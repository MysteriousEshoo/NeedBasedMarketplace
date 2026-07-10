import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/need_model.dart';
import '../theme/app_colors.dart';
import 'need_detail_screen.dart';
import 'payment_methods_screen.dart';
import 'help_screen.dart';
import '../providers/theme_provider.dart';
import 'marketplace_mode_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentUserName = 'Loading...';
  String _currentUserEmail = 'Loading...';
  String? _profilePhotoUrl;
  String _profilePhone = '';
  String _profileCity = '';
  String _profileBio = '';
  int _myNeedsCount = 0;
  File? _selectedLocalImage;
  bool _isProfileLoading = true;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchMyNeedsCount();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isProfileLoading = false);
      return;
    }

    String name = _fallbackUserName(user);
    String email = user.email ?? 'No email connected';
    String? photoUrl = user.photoURL;
    String phone = '';
    String city = '';
    String bio = '';

    // Firestore is kept as a compatibility fallback for accounts created by
    // the existing authentication screen.
    try {
      final firestoreDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final firestoreData = firestoreDoc.data();
      if (firestoreData != null) {
        name = _firstProfileValue(firestoreData, ['name', 'displayName'], name);
        email = _firstProfileValue(firestoreData, ['email'], email);
        photoUrl =
            _nullableProfileValue(firestoreData, ['photoUrl', 'photoURL']) ??
                photoUrl;
        phone = _firstProfileValue(firestoreData, ['phone'], phone);
        city = _firstProfileValue(firestoreData, ['city', 'location'], city);
        bio = _firstProfileValue(firestoreData, ['bio'], bio);
      }
    } catch (_) {
      // Realtime Database may still be available.
    }

    // Realtime Database is the live profile source and therefore takes
    // precedence over the compatibility copy in Firestore.
    try {
      final realtimeSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .get();
      if (realtimeSnapshot.exists && realtimeSnapshot.value is Map) {
        final data = Map<String, dynamic>.from(realtimeSnapshot.value as Map);
        name = _firstProfileValue(data, ['name', 'displayName'], name);
        email = _firstProfileValue(data, ['email'], email);
        photoUrl =
            _nullableProfileValue(data, ['photoUrl', 'photoURL']) ?? photoUrl;
        phone = _firstProfileValue(data, ['phone'], phone);
        city = _firstProfileValue(data, ['city', 'location'], city);
        bio = _firstProfileValue(data, ['bio'], bio);
      }
    } catch (_) {
      // Auth data is still enough to keep the profile usable if a read fails.
    }

    if (!mounted) return;
    setState(() {
      _currentUserName = name;
      _currentUserEmail = email;
      _profilePhotoUrl = photoUrl;
      _profilePhone = phone;
      _profileCity = city;
      _profileBio = bio;
      _isProfileLoading = false;
    });
  }

  String _fallbackUserName(User user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'User';
  }

  String _firstProfileValue(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    return _nullableProfileValue(data, keys) ?? fallback;
  }

  String? _nullableProfileValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  void _fetchMyNeedsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance.ref().child('needs').onValue.listen((event) {
      if (!mounted) return;
      int count = 0;
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> allMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        allMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value as Map);
          if (data['authorId'] == user.uid ||
              data['userId'] == user.uid ||
              data['authorName'] == _currentUserName ||
              data['authorName'] == user.displayName) {
            count++;
          }
        });
      }
      setState(() => _myNeedsCount = count);
    });
  }

  Future<void> _executeNativeImageUpload() async {
    if (_isUploadingAvatar) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final imageFile = File(image.path);
        setState(() {
          _selectedLocalImage = imageFile;
          _isUploadingAvatar = true;
        });
        await _saveSelectedProfileImage(imageFile);
        if (!mounted) return;
        _showStatusToast('🎉 Image uploaded successfully!');
      }
    } catch (_) {
      if (!mounted) return;
      _showStatusToast('⚠️ Error uploading image. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveSelectedProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final photoUrl = await _uploadProfileImage(user.uid, imageFile);
      final profileName = _currentUserName == 'Loading...'
          ? _fallbackUserName(user)
          : _currentUserName;
      await _saveProfileToFirebase(
        user: user,
        name: profileName,
        phone: _profilePhone,
        city: _profileCity,
        bio: _profileBio,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = photoUrl;
        _selectedLocalImage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedLocalImage = null);
      rethrow;
    }
  }

  Future<String> _uploadProfileImage(String uid, File imageFile) async {
    final ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.jpg');
    await ref.putFile(
      imageFile,
      firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  void _showStatusToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating),
    );
  }

  ImageProvider? get _profileAvatarImage {
    if (_selectedLocalImage != null) return FileImage(_selectedLocalImage!);
    final photoUrl = _profilePhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  Future<void> _saveProfileToFirebase({
    required User user,
    required String name,
    required String phone,
    required String city,
    required String bio,
    String? photoUrl,
  }) async {
    final cleanName =
        name.trim().isEmpty ? _fallbackUserName(user) : name.trim();
    final cleanPhone = phone.trim();
    final cleanCity = city.trim();
    final cleanBio = bio.trim();
    final cleanPhotoUrl = photoUrl?.trim();

    final realtimeData = <String, dynamic>{
      'uid': user.uid,
      'name': cleanName,
      'displayName': cleanName,
      'email': user.email ?? _currentUserEmail,
      'phone': cleanPhone,
      'city': cleanCity,
      'location': cleanCity,
      'bio': cleanBio,
      'updatedAt': ServerValue.timestamp,
    };
    if (cleanPhotoUrl != null && cleanPhotoUrl.isNotEmpty) {
      realtimeData['photoUrl'] = cleanPhotoUrl;
      realtimeData['photoURL'] = cleanPhotoUrl;
    }

    final firestoreData = Map<String, dynamic>.from(realtimeData)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    // Persist to the app's live Realtime Database first. A successful return
    // from this method always means the profile exists at /users/{uid}.
    await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(user.uid)
        .update(realtimeData);

    await user.updateDisplayName(cleanName);
    if (cleanPhotoUrl != null && cleanPhotoUrl.isNotEmpty) {
      await user.updatePhotoURL(cleanPhotoUrl);
    }
    await user.reload();

    // Keep existing Firestore-based features compatible, but do not report a
    // failed profile save if this optional mirror or old listings cannot be
    // updated due to their own security rules.
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(firestoreData, SetOptions(merge: true));
    } catch (_) {}
    try {
      await _syncProfileNameToNeeds(user.uid, cleanName);
    } catch (_) {}
  }

  Future<void> _syncProfileNameToNeeds(String uid, String name) async {
    final needsRef = FirebaseDatabase.instance.ref().child('needs');
    final snapshot = await needsRef.get();
    if (!snapshot.exists || snapshot.value is! Map) return;

    final updates = <String, dynamic>{};
    final needsMap = snapshot.value as Map<dynamic, dynamic>;
    needsMap.forEach((key, value) {
      if (value is! Map) return;
      final data = Map<String, dynamic>.from(value);
      if (data['authorId'] == uid || data['userId'] == uid) {
        updates['${key.toString()}/authorName'] = name;
        updates['${key.toString()}/userName'] = name;
      }
    });

    if (updates.isNotEmpty) {
      await needsRef.update(updates);
    }
  }

  Future<void> _openEditProfileSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showStatusToast('Please login to edit your profile.');
      return;
    }
    if (_isProfileLoading) {
      _showStatusToast('Please wait while your profile loads.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _currentUserName);
    final phoneController = TextEditingController(text: _profilePhone);
    final cityController = TextEditingController(text: _profileCity);
    final bioController = TextEditingController(text: _profileBio);
    File? pickedImage;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark =
                Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
            final surface = isDark ? AppColors.surface : Colors.white;
            final textPrimary =
                isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
            ImageProvider? previewImage;
            if (pickedImage != null) {
              previewImage = FileImage(pickedImage!);
            } else if (_profilePhotoUrl != null &&
                _profilePhotoUrl!.isNotEmpty) {
              previewImage = NetworkImage(_profilePhotoUrl!);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: AppColors.textTertiary.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () async {
                                      final image = await ImagePicker()
                                          .pickImage(
                                              source: ImageSource.gallery,
                                              imageQuality: 85);
                                      if (image == null) return;
                                      setSheetState(() {
                                        pickedImage = File(image.path);
                                      });
                                    },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.10),
                                    backgroundImage: previewImage,
                                    child: previewImage == null
                                        ? const Icon(Icons.person_rounded,
                                            color: AppColors.primaryLight,
                                            size: 42)
                                        : null,
                                  ),
                                  Container(
                                    height: 32,
                                    width: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your name';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              if (value.trim().length > 60) {
                                return 'Name must be 60 characters or less';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) return null;
                              final digits =
                                  phone.replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 10 || digits.length > 15) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: cityController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: bioController,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                            maxLength: 250,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }

                                      setSheetState(() => isSaving = true);
                                      try {
                                        String? photoUrl = _profilePhotoUrl;
                                        if (pickedImage != null) {
                                          photoUrl = await _uploadProfileImage(
                                              user.uid, pickedImage!);
                                        }

                                        await _saveProfileToFirebase(
                                          user: user,
                                          name: nameController.text,
                                          phone: phoneController.text,
                                          city: cityController.text,
                                          bio: bioController.text,
                                          photoUrl: photoUrl,
                                        );

                                        if (!mounted || !sheetContext.mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _currentUserName =
                                              nameController.text.trim();
                                          _profilePhone =
                                              phoneController.text.trim();
                                          _profileCity =
                                              cityController.text.trim();
                                          _profileBio =
                                              bioController.text.trim();
                                          _profilePhotoUrl = photoUrl;
                                          _selectedLocalImage = null;
                                        });
                                        Navigator.pop(sheetContext);
                                        _showStatusToast('Profile updated.');
                                      } catch (e) {
                                        if (sheetContext.mounted) {
                                          setSheetState(() => isSaving = false);
                                        }
                                        if (mounted) {
                                          _showStatusToast(
                                            'Could not update profile. Please check your connection and try again.',
                                          );
                                        }
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded,
                                      color: Colors.white),
                              label: Text(
                                isSaving ? 'Saving...' : 'Save Profile',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    bioController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDarkMode ? AppColors.textTertiary : const Color(0xFF94A3B8);
    final Color headerGradientTop =
        isDarkMode ? const Color(0xFF0F1524) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildGradientHeader(
              headerGradientTop: headerGradientTop,
              bg: bg,
              surface: surface,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 20),
            _buildStatsRow(
              surface: surface,
              border: border,
              textPrimary: textPrimary,
              textTertiary: textTertiary,
            ),
            const SizedBox(height: 28),
            _buildMenuList(
              surface: surface,
              border: border,
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientHeader({
    required Color headerGradientTop,
    required Color bg,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final avatarImage = _profileAvatarImage;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [headerGradientTop, bg],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: ClipOval(
                  child: CircleAvatar(
                    backgroundColor: surface,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person_rounded,
                            size: 54, color: AppColors.primaryLight)
                        : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _executeNativeImageUpload,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.primary),
                  child: _isUploadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentUserName,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: textPrimary,
                fontSize: 24,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUserEmail,
            style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13),
          ),
          if (_profileCity.isNotEmpty || _profileBio.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_profileCity.isNotEmpty)
              Text(
                _profileCity,
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            if (_profileBio.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _profileBio,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isProfileLoading ? null : _openEditProfileSheet,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textTertiary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(Icons.description_rounded, 'My Needs',
              '$_myNeedsCount', surface, border, textPrimary, textTertiary),
          _buildStatCard(Icons.handshake_rounded, 'Active Offers', '3', surface,
              border, textPrimary, textTertiary),
          _buildStatCard(Icons.verified_user_rounded, 'Status', 'Verified User',
              surface, border, textPrimary, textTertiary),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value,
      Color surface, Color border, Color textPrimary, Color textTertiary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList({
    required Color surface,
    required Color border,
    required Color textPrimary,
  }) {
    final sections = [
      {
        'title': 'MY STUFF',
        'items': [
          {
            'icon': Icons.description_rounded,
            'label': 'My Needs',
            'page': _MyNeedsScreen(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              authorName: _currentUserName,
            )
          },
          {
            'icon': Icons.bookmark_rounded,
            'label': 'Saved Offers / Bookmarks',
            'page': const _SavedOffersPipelineScreen()
          },
        ]
      },
      {
        'title': 'PREFERENCES',
        'items': [
          {
            'icon': Icons.settings_rounded,
            'label': 'Settings Console',
            'page': const _FullEnterpriseSettingsScreen()
          },
          {
            'icon': Icons.swap_horiz_rounded,
            'label': 'Switch to Seller / Buyer Mode',
            'page': const MarketplaceModeScreen()
          },
        ]
      }
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((sec) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
                child: Text(sec['title'] as String,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
              ),
              ...(sec['items'] as List<Map<String, dynamic>>).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border)),
                  child: ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: AppColors.primaryLight, size: 22),
                    title: Text(item['label'] as String,
                        style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.textTertiary, size: 14),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => item['page'] as Widget)),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SavedOffersPipelineScreen extends StatelessWidget {
  const _SavedOffersPipelineScreen();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);

    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
          backgroundColor: surface,
          title:
              Text('Saved Requirements', style: TextStyle(color: textPrimary)),
          iconTheme: IconThemeData(color: textPrimary),
          centerTitle: true),
      body: user == null
          ? Center(
              child: Text('Session missing.',
                  style: TextStyle(color: textPrimary)))
          : StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('users_saved_needs')
                  .child(user.uid)
                  .onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> savedSnapshot) {
                if (savedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!savedSnapshot.hasData ||
                    savedSnapshot.data!.snapshot.value == null) {
                  return Center(
                      child: Text('No bookmarked items found.',
                          style: TextStyle(color: textSecondary)));
                }

                final Map<dynamic, dynamic> savedMap =
                    savedSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final Set<String> savedIds =
                    savedMap.keys.map((e) => e.toString()).toSet();

                return StreamBuilder(
                  stream:
                      FirebaseDatabase.instance.ref().child('needs').onValue,
                  builder: (context,
                      AsyncSnapshot<DatabaseEvent> masterFeedSnapshot) {
                    if (masterFeedSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Need> bookmarkedList = [];
                    if (masterFeedSnapshot.hasData &&
                        masterFeedSnapshot.data!.snapshot.value != null) {
                      final Map<dynamic, dynamic> allMap = masterFeedSnapshot
                          .data!.snapshot.value as Map<dynamic, dynamic>;
                      allMap.forEach((key, value) {
                        if (savedIds.contains(key)) {
                          final data = Map<String, dynamic>.from(value as Map);
                          bookmarkedList.add(Need(
                            id: key,
                            title: data['title'] ?? '',
                            description: data['description'] ?? '',
                            category: data['category'] ?? '',
                            budget: data['budget'] ?? 0,
                            timeElapsed: 'Saved',
                            urgency: data['urgency'] == 'high'
                                ? Urgency.high
                                : Urgency.medium,
                            authorName: data['authorName'] ?? '',
                            offers: data['offers'] ?? 0,
                            companyName: data['company'],
                            condition: data['condition'] == null
                                ? null
                                : (data['condition'] == 'Used'
                                    ? ProductCondition.used
                                    : ProductCondition.new_),
                            paymentMethod: data['paymentMethod'] == null
                                ? null
                                : (data['paymentMethod'] == 'Online Deposit'
                                    ? PaymentMethod.onlineDeposit
                                    : PaymentMethod.cash),
                            location: data['location'],
                            authorId: data['authorId'] ?? data['userId'],
                            userId: data['userId'] ?? data['authorId'],
                            userName: data['userName'] ?? data['authorName'],
                            isPremium: data['isPremium'] ?? false,
                          ));
                        }
                      });
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: bookmarkedList.length,
                      itemBuilder: (context, index) {
                        final need = bookmarkedList[index];
                        return Card(
                          color: surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: border)),
                          child: ListTile(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        NeedDetailScreen(need: need))),
                            title: Text(need.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary)),
                            trailing: Text('Rs. ${need.budget}',
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

// ----------------------------------------------------------------------------
// FULL SETTINGS SCREEN
// ----------------------------------------------------------------------------

class _FullEnterpriseSettingsScreen extends StatefulWidget {
  const _FullEnterpriseSettingsScreen();

  @override
  State<_FullEnterpriseSettingsScreen> createState() =>
      _FullEnterpriseSettingsScreenState();
}

class _FullEnterpriseSettingsScreenState
    extends State<_FullEnterpriseSettingsScreen> {
  bool _pushNotifications = true;
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  void _loadNotificationSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref()
        .child('user_settings')
        .child(user.uid)
        .child('notifications')
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        if (mounted) {
          setState(() {
            _notificationsEnabled = snapshot.value as bool? ?? true;
          });
        }
      }
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref()
          .child('user_settings')
          .child(user.uid)
          .child('notifications')
          .set(value);

      _showCoreFeedback(
          value ? '🔔 Notifications enabled' : '🔕 Notifications disabled');
    } catch (e) {
      setState(() => _notificationsEnabled = !value);
      _showCoreFeedback('Error: ${e.toString()}');
    }
  }

  Future<void> _confirmLogoutFromSession() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will return to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgentMedium,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      _showCoreFeedback('Logout failed: ${e.toString()}');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your profile, needs, offers, saved items, notifications, and chats from the app database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgentHigh,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showCoreFeedback('No active session found.');
      return;
    }

    var progressShown = false;

    try {
      await _reauthenticateForAccountDeletion(user);
      if (!mounted) return;

      _showBlockingProgress('Deleting account...');
      progressShown = true;

      await _tryDeleteUserAppData(user.uid);
      await user.delete();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (progressShown) Navigator.of(context, rootNavigator: true).pop();
      _showCoreFeedback(_friendlyAuthDeleteMessage(e));
    } catch (e) {
      if (!mounted) return;
      if (progressShown) Navigator.of(context, rootNavigator: true).pop();
      _showCoreFeedback(_friendlyDeleteError(e));
    }
  }

  void _showBlockingProgress(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> _reauthenticateForAccountDeletion(User user) async {
    final providerIds = user.providerData.map((p) => p.providerId).toSet();

    if (providerIds.contains('password') && user.email != null) {
      final password = await _requestPasswordForDelete();
      if (password == null || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Account deletion cancelled.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providerIds.contains('google.com')) {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Google confirmation was cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  Future<String?> _requestPasswordForDelete() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Current password',
            prefixIcon: Icon(Icons.lock_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgentHigh,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  // ✅ FIXED: Added async keyword
  Future<void> _tryDeleteUserAppData(String uid) async {
    try {
      await _deleteUserAppData(uid);
    } catch (_) {}
  }

  Future<void> _deleteUserAppData(String uid) async {
    final db = FirebaseDatabase.instance.ref();
    final firestore = FirebaseFirestore.instance;
    final ownNeedIds = <String>{};

    final needsSnapshot = await db.child('needs').get();
    if (needsSnapshot.exists && needsSnapshot.value is Map) {
      final needsMap = needsSnapshot.value as Map<dynamic, dynamic>;
      needsMap.forEach((key, value) {
        if (value is! Map) return;
        final data = Map<String, dynamic>.from(value);
        if (data['authorId'] == uid || data['userId'] == uid) {
          final needId = key.toString();
          ownNeedIds.add(needId);
        }
      });
    }

    for (final needId in ownNeedIds) {
      await _tryRealtimeRemove(db.child('needs').child(needId));
      await _tryRealtimeRemove(db.child('offers').child(needId));
      await _tryRealtimeRemove(db.child('chats').child(needId));
    }

    final userChatsSnapshot = await db.child('user_chats').child(uid).get();
    if (userChatsSnapshot.exists && userChatsSnapshot.value is Map) {
      final userChats = userChatsSnapshot.value as Map<dynamic, dynamic>;
      for (final entry in userChats.entries) {
        final channelKey = entry.key;
        final value = entry.value;
        if (value is! Map) continue;
        final chat = Map<String, dynamic>.from(value);
        final channelId = channelKey.toString();
        final needId = chat['needId']?.toString();
        final peerId = chat['peerId']?.toString();

        if (needId != null &&
            needId.isNotEmpty &&
            !ownNeedIds.contains(needId)) {
          await _tryRealtimeRemove(
            db.child('chats').child(needId).child(channelId),
          );
        }
        if (peerId != null && peerId.isNotEmpty) {
          await _tryRealtimeRemove(
            db.child('user_chats').child(peerId).child(channelId),
          );
        }
      }
    }

    final offersSnapshot = await db.child('offers').get();
    if (offersSnapshot.exists && offersSnapshot.value is Map) {
      final offersByNeed = offersSnapshot.value as Map<dynamic, dynamic>;
      for (final needEntry in offersByNeed.entries) {
        final needKey = needEntry.key;
        final value = needEntry.value;
        if (value is! Map) continue;
        final needId = needKey.toString();
        if (ownNeedIds.contains(needId)) continue;

        final offers = value as Map<dynamic, dynamic>;
        for (final offerEntry in offers.entries) {
          final offerKey = offerEntry.key;
          final offerValue = offerEntry.value;
          if (offerValue is! Map) continue;
          final offer = Map<String, dynamic>.from(offerValue);
          if (offer['sellerId'] == uid) {
            await _tryRealtimeRemove(
              db.child('offers').child(needId).child(offerKey.toString()),
            );
          }
        }
      }
    }

    final savedNeedsSnapshot = await db.child('users_saved_needs').get();
    if (savedNeedsSnapshot.exists && savedNeedsSnapshot.value is Map) {
      final savedByUser = savedNeedsSnapshot.value as Map<dynamic, dynamic>;
      // ✅ FIXED: Using for loop instead of forEach
      for (final entry in savedByUser.entries) {
        if (entry.value is! Map) continue;
        final savedUserId = entry.key.toString();
        for (final needId in ownNeedIds) {
          await _tryRealtimeRemove(
            db.child('users_saved_needs').child(savedUserId).child(needId),
          );
        }
      }
    }

    await _tryRealtimeRemove(db.child('notifications').child(uid));
    await _tryRealtimeRemove(db.child('user_chats').child(uid));
    await _tryRealtimeRemove(db.child('user_settings').child(uid));
    await _tryRealtimeRemove(db.child('users_saved_needs').child(uid));

    await _deleteFirestoreQuery(
      firestore.collection('needs').where('userId', isEqualTo: uid),
    );
    await _deleteFirestoreQuery(
      firestore.collection('needs').where('authorId', isEqualTo: uid),
    );
    await _deleteFirestoreQuery(
      firestore.collection('offers').where('sellerId', isEqualTo: uid),
    );
    for (final needId in ownNeedIds) {
      await _deleteFirestoreQuery(
        firestore.collection('offers').where('needId', isEqualTo: needId),
      );
    }
    await _deleteFirestoreCollection(
      firestore.collection('users').doc(uid).collection('notifications'),
    );
    await _tryFirestoreDelete(firestore.collection('users').doc(uid));
  }

  Future<void> _tryRealtimeRemove(DatabaseReference ref) async {
    try {
      await ref.remove();
    } catch (_) {}
  }

  Future<void> _tryFirestoreDelete(DocumentReference ref) async {
    try {
      await ref.delete();
    } catch (_) {}
  }

  Future<void> _deleteFirestoreCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ✅ FIXED: Added async keyword
  Future<void> _deleteFirestoreQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    while (true) {
      final snapshot = await query.limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _friendlyAuthDeleteMessage(FirebaseAuthException e) {
    if (e.code == 'cancelled') {
      return e.message ?? 'Account deletion cancelled.';
    }
    if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
      return 'Password confirmation failed.';
    }
    if (e.code == 'requires-recent-login') {
      return 'Please login again, then delete your account from settings.';
    }
    return 'Account deletion failed: ${e.message ?? e.code}';
  }

  String _friendlyDeleteError(Object e) {
    final message = e.toString();
    if (message.contains('google_sign_in_web') ||
        message.contains('appClientId') ||
        message.contains('ClientID not set')) {
      return 'Google account confirmation is not configured for web. Try deleting after logging in with email/password, or add a Google web client ID.';
    }
    return 'Account deletion failed: $message';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    final Color currentBg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color currentSurface = isDarkMode ? AppColors.surface : Colors.white;
    final Color currentBorder =
        isDarkMode ? AppColors.border : const Color(0xFFCBD5E1);
    final Color currentText =
        isDarkMode ? AppColors.textPrimary : Colors.black87;
    final Color currentSubText =
        isDarkMode ? AppColors.textTertiary : Colors.black54;

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        backgroundColor: currentSurface,
        title: Text('Settings', style: TextStyle(color: currentText)),
        centerTitle: true,
        iconTheme: IconThemeData(color: currentText),
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          _buildSectionHeader('👤 PROFILE ACTIONS & SECURITY'),
          _buildActionTileWithCustomHook(
              'Change Username',
              'Only alphanumeric chars. Limited to 1 change per 30 days.',
              Icons.account_circle_rounded,
              _executeLiveUsernameChangeProcedure,
              currentSurface,
              currentBorder,
              currentText,
              currentSubText),
          _buildActionTileWithCustomHook(
              'Change Password',
              'Verify secure re-auth context or send reset links.',
              Icons.vpn_key_rounded,
              _executeSecurePasswordModFlow,
              currentSurface,
              currentBorder,
              currentText,
              currentSubText),
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2))),
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded,
                  color: AppColors.primaryLight, size: 22),
              title: Text('Contact Sales Team',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              subtitle: const Text(
                  'Initiate direct call or compose official email channels',
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textTertiary, size: 14),
              onTap: _handleContactSalesAction,
            ),
          ),
          _buildSectionHeader('🔔 NOTIFICATIONS'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('In-App Notifications',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  _notificationsEnabled
                      ? 'You will receive real-time alerts for messages and offers'
                      : 'You will not receive any notifications',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          _buildSectionHeader('🔒 SECURITY & BIOMETRICS'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('Fingerprint Unlock',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  'Unlock app using your device physical fingerprint scanner',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _fingerprintEnabled,
              onChanged: (v) {
                setState(() => _fingerprintEnabled = v);
                _triggerBiometricSetupConsole('fingerprint');
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: SwitchListTile(
              activeColor: AppColors.primaryLight,
              title: Text('Face ID / Recognition',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text(
                  'Enable quick device look vectors for seamless authentication routing',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              value: _faceIdEnabled,
              onChanged: (v) {
                setState(() => _faceIdEnabled = v);
                _triggerBiometricSetupConsole('faceid');
              },
            ),
          ),
          _buildSectionHeader('🌍 APP PREFERENCES'),
          _buildSwitchRow(
            'Dark Mode Theme',
            'Switch between bright and dark looks',
            isDarkMode,
            (v) {
              themeProvider.setDarkMode(v);
              _showCoreFeedback(v
                  ? '🌙 Premium Dark Mode activated.'
                  : '☀️ Clean Light Mode activated.');
            },
            currentSurface,
            currentBorder,
            currentText,
            currentSubText,
          ),
          _buildSectionHeader('💳 PAYMENTS'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primaryLight, size: 20),
              title: Text('Payment Methods',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text('Manage your linked digital bank wallets',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                  color: AppColors.textTertiary, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen()),
                );
              },
            ),
          ),
          _buildSectionHeader('🛠️ SUPPORT & LEGAL'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: currentSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentBorder)),
            child: ListTile(
              leading: const Icon(Icons.help_outline_rounded,
                  color: AppColors.primaryLight, size: 20),
              title: Text('Help Center / FAQs',
                  style: TextStyle(
                      color: currentText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              subtitle: Text('Access documentation guides',
                  style: TextStyle(color: currentSubText, fontSize: 11)),
              trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                  color: AppColors.textTertiary, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildActionItem(
              'Logout from Session',
              'Disconnect current active user authentication tokens',
              Icons.power_settings_new_rounded,
              AppColors.urgentMedium,
              onTap: _confirmLogoutFromSession),
          _buildActionItem(
              'Delete Account',
              'Permanently remove your profile and marketplace data',
              Icons.delete_forever_rounded,
              AppColors.urgentHigh,
              onTap: _confirmDeleteAccount),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper Methods
  // --------------------------------------------------------------------------

  void _triggerBiometricSetupConsole(String type) async {
    bool isFingerprint = type == 'fingerprint';
    if ((isFingerprint && !_fingerprintEnabled) ||
        (!isFingerprint && !_faceIdEnabled)) {
      _showCoreFeedback(
          '${isFingerprint ? "Fingerprint" : "Face ID"} unlock disabled.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
          Navigator.pop(context);
          _showCoreFeedback(
              '🎉 ${isFingerprint ? "Fingerprint" : "Face ID"} activation setup completed successfully!');
        });

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        final Color popSubText =
            isDarkMode ? AppColors.textSecondary : Colors.black54;

        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: AppColors.primary.withOpacity(0.5))),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    isFingerprint
                        ? Icons.fingerprint_rounded
                        : Icons.face_retouching_natural_rounded,
                    size: 72,
                    color: AppColors.primaryLight),
                const SizedBox(height: 20),
                Text(
                    isFingerprint
                        ? 'SCANNING FINGERPRINT...'
                        : 'RECOGNIZING FACE...',
                    style: TextStyle(
                        color: popText,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Text(
                    isFingerprint
                        ? 'Please place your registered finger firmly against the device biometric sensor layout matrix.'
                        : 'Please position your device directly in front of your face and look straight into the camera lens node.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: popSubText, fontSize: 12)),
                const SizedBox(height: 24),
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primaryLight)),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _executeLiveUsernameChangeProcedure() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDatabaseRef = FirebaseDatabase.instance
        .ref()
        .child('users_cooldown_metadata')
        .child(user.uid);
    final snapshot = await userDatabaseRef.get();

    int? lastChangedTimestamp;
    if (snapshot.exists) {
      final Map<dynamic, dynamic> meta =
          snapshot.value as Map<dynamic, dynamic>;
      lastChangedTimestamp = meta['usernameLastChanged'] as int?;
    }

    if (lastChangedTimestamp != null) {
      final lastChangedDate =
          DateTime.fromMillisecondsSinceEpoch(lastChangedTimestamp);
      final daysDifference = DateTime.now().difference(lastChangedDate).inDays;
      if (daysDifference < 30) {
        _showSecureAlertPopup('Access Denied',
            'You can only change your username once a month. Please try again after 30 days.');
        return;
      }
    }

    final usernameInputController =
        TextEditingController(text: user.displayName);
    bool isProcessing = false;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: Text('Update Username',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: popText, fontSize: 16)),
          content: TextField(
            controller: usernameInputController,
            style: TextStyle(color: popText),
            decoration: const InputDecoration(
              labelText: 'New Username',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintText: 'Only letters & numbers allowed',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final String rawValue =
                          usernameInputController.text.trim();
                      final RegExp alphanumericCheck =
                          RegExp(r'^[a-zA-Z0-9]+$');
                      if (!alphanumericCheck.hasMatch(rawValue)) {
                        _showCoreFeedback(
                            '⚠️ Error: Username can only contain letters or numbers.');
                        return;
                      }

                      setDialogState(() => isProcessing = true);
                      try {
                        await user.updateDisplayName(rawValue);
                        await userDatabaseRef.set({
                          'usernameLastChanged':
                              DateTime.now().millisecondsSinceEpoch
                        });
                        await user.reload();
                        _showCoreFeedback(
                            '🎉 Username changed successfully to @$rawValue');
                        if (!mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Name',
                      style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  void _executeSecurePasswordModFlow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final reEnterPassController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        final Color popBg = isDarkMode ? AppColors.surface : Colors.white;
        final Color popText =
            isDarkMode ? AppColors.textPrimary : Colors.black87;
        return AlertDialog(
          backgroundColor: popBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: Text('Change Password',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: popText, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
                  decoration: const InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
                  decoration: const InputDecoration(
                      labelText: 'Enter New Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                TextField(
                  controller: reEnterPassController,
                  obscureText: true,
                  style: TextStyle(color: popText),
                  decoration: const InputDecoration(
                      labelText: 'Re-enter New Password',
                      labelStyle: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            Navigator.pop(context);
                            _triggerMaskedEmailForgotPasswordProcess(
                                user.email ?? '');
                          },
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final currentText = currentPassController.text.trim();
                      final newText = newPassController.text.trim();
                      final reEnterText = reEnterPassController.text.trim();

                      if (currentText.isEmpty ||
                          newText.isEmpty ||
                          reEnterText.isEmpty) {
                        _showCoreFeedback(
                            '⚠️ Please fill all password fields.');
                        return;
                      }

                      if (newText != reEnterText) {
                        _showCoreFeedback(
                            '⚠️ Error: New passwords do not match!');
                        return;
                      }

                      setDialogState(() => isProcessing = true);
                      try {
                        AuthCredential credential =
                            EmailAuthProvider.credential(
                                email: user.email!, password: currentText);
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newText);
                        _showCoreFeedback('🎉 Password changed successfully.');
                        if (!mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        _showCoreFeedback(
                            '⚠️ Re-Authentication failed: Current password mismatch.');
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password',
                      style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  void _triggerMaskedEmailForgotPasswordProcess(String fullEmail) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: fullEmail);
      String maskedEmail = fullEmail;
      if (fullEmail.contains('@')) {
        final splitParts = fullEmail.split('@');
        final prefix = splitParts[0];
        if (prefix.length > 2) {
          maskedEmail = '${prefix.substring(0, 2)}******@${splitParts[1]}';
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          final bool isDarkMode = themeProvider.isDarkMode;

          return AlertDialog(
            backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.accent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read_rounded,
                    size: 48, color: AppColors.accent),
                const SizedBox(height: 14),
                Text(
                  'TRANSMISSION SENT',
                  style: TextStyle(
                      color:
                          isDarkMode ? AppColors.textPrimary : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                    'A link has been sent to $maskedEmail. Check your inbox to safely update configuration mappings.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          );
        },
      );

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showCoreFeedback('⚠️ Failed to route password reset transmission.');
    }
  }

  void _showSecureAlertPopup(String title, String desc) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.urgentHigh)),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.urgentHigh,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          content: Text(desc,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Acknowledged',
                    style: TextStyle(color: AppColors.primaryLight)))
          ],
        );
      },
    );
  }

  void _handleContactSalesAction() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        final bool isDarkMode = themeProvider.isDarkMode;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CONTACT SALES REPRESENTATIVE',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.phone_in_talk_rounded,
                    color: AppColors.primaryLight),
                title: Text('Direct Phone Channel',
                    style: TextStyle(
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                        fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Tap to invoke device system dial pad launcher',
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _showCoreFeedback(
                      'Invoking device dial pad context for [+92 300 1234567]...');
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded,
                    color: AppColors.primaryLight),
                title: Text('Official Corporate Mailbox',
                    style: TextStyle(
                        color:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                        fontWeight: FontWeight.bold)),
                subtitle: const Text('Compose a direct contract transmission',
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _showCoreFeedback(
                      'Launching local mail context to [sales@marketplace.com]...');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏳ $featureName: Coming Soon...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCoreFeedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating));
  }

  // --------------------------------------------------------------------------
  // Build Helper Widgets
  // --------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title,
          style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5)),
    );
  }

  Widget _buildActionTileWithCustomHook(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback actionHook,
      Color surface,
      Color border,
      Color text,
      Color subText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryLight, size: 20),
        title: Text(title,
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle:
            Text(subtitle, style: TextStyle(color: subText, fontSize: 11)),
        trailing: const Icon(Icons.keyboard_arrow_right_rounded,
            color: AppColors.textTertiary, size: 18),
        onTap: actionHook,
      ),
    );
  }

  Widget _buildSwitchRow(
      String title,
      String sub,
      bool val,
      ValueChanged<bool> onChange,
      Color surface,
      Color border,
      Color text,
      Color subText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: SwitchListTile(
        activeColor: AppColors.primaryLight,
        title: Text(title,
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(sub, style: TextStyle(color: subText, fontSize: 11)),
        value: val,
        onChanged: onChange,
      ),
    );
  }

  Widget _buildActionItem(
    String title,
    String sub,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2))),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        subtitle: Text(sub,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        onTap: onTap ?? () => _showComingSoon(title),
      ),
    );
  }
}

class _MyNeedsScreen extends StatelessWidget {
  final String userId;
  final String authorName;
  const _MyNeedsScreen({required this.userId, required this.authorName});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color bg =
        isDarkMode ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDarkMode ? AppColors.surface : Colors.white;
    final Color border =
        isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDarkMode ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDarkMode ? AppColors.textSecondary : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
          backgroundColor: surface,
          title: Text('My Active Requirements',
              style: TextStyle(color: textPrimary)),
          iconTheme: IconThemeData(color: textPrimary),
          centerTitle: true),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref().child('needs').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Need> myFilteredList = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> allMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            allMap.forEach((key, value) {
              final data = Map<String, dynamic>.from(value as Map);
              final ownsNeed = (userId.isNotEmpty &&
                      (data['authorId'] == userId ||
                          data['userId'] == userId)) ||
                  data['authorName'] == authorName;
              if (ownsNeed) {
                myFilteredList.add(Need(
                  id: key,
                  title: data['title'] ?? '',
                  description: data['description'] ?? '',
                  category: data['category'] ?? '',
                  budget: data['budget'] ?? 0,
                  timeElapsed: 'Active Log',
                  urgency:
                      data['urgency'] == 'high' ? Urgency.high : Urgency.medium,
                  authorName: data['authorName'] ?? '',
                  offers: data['offers'] ?? 0,
                  companyName: data['company'],
                  condition: data['condition'] == null
                      ? null
                      : (data['condition'] == 'Used'
                          ? ProductCondition.used
                          : ProductCondition.new_),
                  paymentMethod: data['paymentMethod'] == null
                      ? null
                      : (data['paymentMethod'] == 'Online Deposit'
                          ? PaymentMethod.onlineDeposit
                          : PaymentMethod.cash),
                  location: data['location'],
                  authorId: data['authorId'] ?? data['userId'],
                  userId: data['userId'] ?? data['authorId'],
                  userName: data['userName'] ?? data['authorName'],
                  isPremium: data['isPremium'] ?? false,
                ));
              }
            });
          }

          if (myFilteredList.isEmpty) {
            return Center(
                child: Text('You haven\'t posted any requirements yet.',
                    style: TextStyle(color: textSecondary)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: myFilteredList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = myFilteredList[index];
              return Card(
                color: surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NeedDetailScreen(need: item))),
                  title: Text(item.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textPrimary)),
                  subtitle: Text(item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary)),
                  trailing: Text('Rs. ${item.budget}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
