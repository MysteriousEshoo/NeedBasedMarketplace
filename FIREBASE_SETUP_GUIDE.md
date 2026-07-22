# 🚀 Need Base Marketplace — App Setup & Firebase Guide

> **Date:** July 20, 2026
> **App:** Need Base Marketplace (Flutter)
> **Purpose:** Complete reference for Firebase free plan limits, active users, and features status

---

## 📊 SECTION 1: App Features — What's Working & What's Not

### ✅ Fully Working (Free Plan Mein Chlta Hai)

| Feature | Status | Free Plan Mein? |
|---|---|---|
| Email/Password Login & Signup | ✅ Working | ✅ **Free** |
| Google Sign-In | ✅ Working | ✅ **Free** |
| Post Need (3-Step Form) | ✅ Working | ✅ **Free** |
| Need Listing (Home Feed) | ✅ Working | ✅ **Free** |
| Search & Filter Needs | ✅ Working | ✅ **Free** |
| Need Detail Screen | ✅ Working | ✅ **Free** |
| Edit Need | ✅ Working | ✅ **Free** |
| Bookmark/Save Needs | ✅ Working | ✅ **Free** |
| Share Need (WhatsApp, Email, Copy) | ✅ Working | ✅ **Free** |
| Submit Offer | ✅ Working | ✅ **Free** |
| Accept/Reject Offer | ✅ Working | ✅ **Free** |
| ✅ **Chat Text Messages** | ✅ **Working** | ✅ **Free** |
| ✅ **Chat Images (Gallery/Camera)** | ✅ **Working** | ✅ **Free** |
| ✅ **Chat Voice Messages** | ✅ **Working** | ✅ **Free** |
| ✅ **Chat Documents (PDF, DOC, etc.)** | ✅ **Working** | ✅ **Free** |
| ✅ **Chat Videos** | ✅ **Working** | ✅ **Free** |
| Inbox (Buyer/Seller Filtered) | ✅ Working | ✅ **Free** |
| Profile (Edit, Photo Upload) | ✅ Working | ✅ **Free** |
| Dark/Light Theme | ✅ Working | ✅ **Free** |
| Seller/Buyer Mode Switch | ✅ Working | ✅ **Free** |
| Seller Registration | ✅ Working | ✅ **Free** |
| In-App Notifications | ✅ Working | ✅ **Free** |
| History (Chrome-style) | ✅ Working | ✅ **Free** |
| Help & FAQs | ✅ Working | ✅ **Free** |
| Email Verification | ✅ Working | ✅ **Free** |
| Dark/Light Mode | ✅ Working | ✅ **Free** |
| 3D Glass UI Animations | ✅ Working | ✅ **Free** |
| Responsive Layout | ✅ Working | ✅ **Free** |

### ⚠️ Partial / Simulated

| Feature | Status | Notes |
|---|---|---|
| Premium Screen | ⚠️ UI Only | No real payment connected |
| Payment Methods / Bank Accounts | ⚠️ Simulated | Fake OTP, fake bank verification |
| FCM Push Notifications | ✅ Code Ready | Needs Cloud Function deploy (Blaze plan) |
| Contact Sales (Phone/Email) | ✅ Working | Opens phone dialer / email app |

### ❌ Not Working Yet

| Feature | Status | Required For Fix |
|---|---|---|
| Voice/Video Call | ❌ Placeholder | Agora App ID dalni hai |
| Logo Images | ❌ Missing | `assets/images/` mein `logo.png`, `appbar_dark.png`, `appbar_light.png` dalni hain |

---

## 💰 SECTION 2: Firebase Free Plan Limits (Spark Plan)

### Firebase Realtime Database

| Resource | Free Limit | Kya Kaafi Hai? |
|---|---|---|
| **Simultaneous Connections** | **100 users** | 100 users ek saath online reh sakte hain |
| **Total Stored Data** | **1 GB** | Bahut hai text data ke liye |
| **Download / Month** | **10 GB** | Text chat ke liye bohot zyada hai |
| **Database Writes** | Unlimited | — |
| **Database Reads** | Unlimited | — |

### Firebase Storage (Images, Voice, Files)

| Resource | Free Limit | Kya Kaafi Hai? |
|---|---|---|
| **Total Storage** | **5 GB** | Lakhon images/files store ho sakti hain |
| **Daily Download** | **1 GB/day** | ~2000-5000 images/day download ho sakti hain |
| **Daily Upload** | Unlimited | — |
| **Daily Operations** | 20K uploads + 50K downloads | |

### Firebase Authentication

| Resource | Free Limit |
|---|---|
| **Email/Password Auth** | ✅ **Unlimited** |
| **Google Sign-In** | ✅ **Unlimited** |

---

## 👥 SECTION 3: Free Plan Mein Kitne Users Chal Sakte Hain?

### Practical Estimates Per Use Case:

| User Activity Level | Max Active Users | Explanation |
|---|---|---|
| **Light Use** (sirf text chat, koi file share nahi) | **~100 users** | Realtime Database 100 concurrent connections ki limit hai |
| **Medium Use** (kabhi kabhi photo ya voice bhejte hain) | **~50-70 users** | Storage download limit consider ki gayi |
| **Heavy Use** (regular images, voice, documents, videos) | **~30-50 users** | Zyada files upload/download hongi to jaldi limit touch hogi |

> ⚠️ **Important:** 100 se zyada users ek saath online aayein to Firebase naye connections reject karega.
> 
> Jab aapke 50+ active users ho jayein to Blaze plan (pay-as-you-go) mein switch karna sochna.

### Real-world Usage Calculation:

Agar 50 users rozana chat karein to kya hoga:

| Activity | Per User / Day | 50 Users / Day | Monthly Total | Free Limit |
|---|---|---|---|---|
| Text messages (50/day) | ~5 KB | 250 KB | ~7.5 MB | 10 GB ✅ |
| Images (3/day, 300 KB each) | ~900 KB | 45 MB | ~1.35 GB | 10 GB ✅ (still safe) |
| Voice messages (5/day, 200 KB each) | ~1 MB | 50 MB | ~1.5 GB | 10 GB ✅ |
| Documents (1/day, 1 MB each) | ~1 MB | 50 MB | ~1.5 GB | 10 GB ✅ |
| **Total Download** | **~2.9 MB** | **~145 MB** | **~4.35 GB** | **10 GB ✅** |

**🔴 Red Alert (Tab Upgrade Sochna):**
- Jab 100+ concurrent users ho jayein
- Jab daily download 800 MB+ touch kare
- Jab storage 3 GB+ ho jaye

---

## 📋 SECTION 4: Features Ke Liye Kya Karna Hai?

### ✅ Files, Images, Voice, Documents Sharing — ABHI CHLTA HAI

**Aapko kuch nahi karna.** Code bilkul ready hai. Bus:

```bash
flutter run
```

se app run karein, sab kaam karega!

### ❌ Voice/Video Call Ke Liye (Agora)

Abhi `call_service.dart` mein placeholder hai. Isko kaam karne ke liye:

1. [Agora.io](https://www.agora.io) par free account banayein
2. Naya project create karein (App ID lein)
3. `lib/services/call_service.dart` mein ye line update karein:
   ```dart
   static const String _appId = 'YOUR_AGORA_APP_ID';  // ← yahan apna App ID dalain
   ```
4. **Agora Free Tier:** 10,000 minutes free (first year)

### 🔔 FCM Push Notifications Ke Liye (Jab App Band Ho)

Yeh feature **free plan pe deploy nahi ho sakta**. Iske liye chahiye:

| Requirement | Cost |
|---|---|
| Firebase Blaze Plan | Pay-as-you-go (usually $1-5/month for small apps) |
| Node.js installed | Free |
| Firebase CLI installed | Free |

Jab deploy karna chahain to ye commands chalain:

```bash
cd functions
npm install
firebase login
firebase deploy --only functions
```

---

## 🔧 SECTION 5: Required Setup Checklist

### 🟢 Jitna Bhi Na Ho to App Test Karein

- [ ] `flutter pub get` karein
- [ ] `flutter run` karein
- [ ] Login/Signup test karein
- [ ] Need post karein
- [ ] Chat karein (text, image, voice bhejein)
- [ ] Profile update karein
- [ ] Theme toggle karein

### 🟡 Next Steps (Jab Time Ho)

- [ ] `assets/images/` folder mein logo images dalain (logo.png, appbar_dark.png, appbar_light.png)
- [ ] Agora App ID lein voice/video call ke liye
- [ ] Firebase Blaze plan activate karein FCM push notifications ke liye

### 🔴 Future (Jab Users Barhein)

- [ ] Jab 100+ users ho jayein to Firebase Blaze plan switch karein
- [ ] Jab 1000+ users ho jayein to backend server setup karein
- [ ] Real payment gateway integrate karein

---

## 📞 Quick Contact Config

Aapki app mein sales team contact settings already Firebase se live aati hain:

```
Phone: +92 300 1234567
Email: sales@marketplace.com
```

Yeh values Firebase Console mein `app_config/contact_sales/` node se manage hoti hain — app mein code change ki zaroorat nahi.

---

## 🎯 Summary

| Question | Answer |
|---|---|
| **Kya abhi app free mein chl sakti hai?** | ✅ **Haan, bilkul!** |
| **Kitne users free mein chal sakte hain?** | **30-100 users** (use case ke hisaab se) |
| **File/voice/image sharing ke liye kya karna hai?** | **Kuch nahi — already working!** |
| **Kya storage upgrade karna padega?** | ❌ **Nahi, free 5GB kaafi hai abhi** |
| **Voice call ke liye kya chahiye?** | Agora.io se free App ID lena hai |
| **Push notifications ke liye kya chahiye?** | Firebase Blaze plan + Cloud Function deploy |
| **Kab pay karna shuru karna padega?** | Jab 100+ active users ho jayein |


*Generated by Need Base Marketplace Assistant — July 20, 2026*
