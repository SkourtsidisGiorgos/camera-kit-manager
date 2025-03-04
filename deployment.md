# Deployment Instructions for Camera Kit Manager

## Common Prerequisites

1. Flutter SDK installed and updated to the latest stable version
   ```bash
   flutter upgrade
   ```

2. Ensure your app is configured correctly in `pubspec.yaml` with appropriate name, description, and version

3. Generate Hive adapters if you haven't already:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. Check that everything is ready:
   ```bash
   flutter doctor
   ```

## iOS Deployment

### Prerequisites
- Mac computer with Xcode 14 or newer
- Apple Developer account ($99/year)
- Physical iOS device (optional for testing)

### Steps for App Store Deployment

1. **Configure app settings**
   - Update `ios/Runner/Info.plist` with appropriate permissions descriptions:
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>Camera Kit Manager needs camera access to take photos of equipment</string>
     <key>NSPhotoLibraryUsageDescription</key>
     <string>Camera Kit Manager needs photo library access to select images</string>
     ```

2. **Prepare app icons**
   - Replace placeholder icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
   - You can use tools like [App Icon Generator](https://appicon.co/) to create all required sizes

3. **Configure app signing**
   - Open the iOS project in Xcode:
     ```bash
     cd ios
     open Runner.xcworkspace
     ```
   - In Xcode, go to Runner > Signing & Capabilities
   - Sign in with your Apple Developer account
   - Choose your team and set up bundle identifier (e.g., com.yourname.camerakitmanager)

4. **Create build archive**
   - Make sure your app version and build number are set in `pubspec.yaml`
   - Run:
     ```bash
     flutter build ipa
     ```
   - This creates a build archive at `build/ios/archive/Runner.xcarchive`

5. **Upload to App Store Connect**
   - Open the archive in Xcode:
     ```bash
     open build/ios/archive/Runner.xcarchive
     ```
   - Click "Distribute App" > "App Store Connect" > "Upload"
   - Follow the prompts, maintaining default settings in most cases
   - Wait for upload to complete and processing to finish

6. **Configure App Store listing**
   - Log in to [App Store Connect](https://appstoreconnect.apple.com/)
   - Create a new app if needed
   - Add screenshots, description, keywords, and other required metadata
   - Complete all required information including privacy policy
   - Submit for review

### TestFlight Distribution

After uploading to App Store Connect:
1. Go to the TestFlight tab in App Store Connect
2. Configure testing information
3. Add internal or external testers by email
4. Testers will receive an email invitation to download TestFlight app and test

## Android Deployment

### Prerequisites
- Java Development Kit (JDK) 8 or newer
- Keystore file for signing your app (create once and keep securely)

### Create a Keystore (one-time setup)
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Configure Signing

1. Create `android/key.properties` file (don't commit to Git):
   ```
   storePassword=your_keystore_password
   keyPassword=your_key_password
   keyAlias=upload
   storeFile=/path/to/your/upload-keystore.jks
   ```

2. Configure Gradle to use your keystore in `android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       // ...
       
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               // ...
           }
       }
   }
   ```

### Steps for Google Play Store Deployment

1. **Prepare app icons and assets**
   - Ensure `android/app/src/main/res` has appropriate icons
   - Create a feature graphic (1024x500) and screenshots for Play Store

2. **Update AndroidManifest.xml**
   - Ensure required permissions are set in `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
     <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
     ```

3. **Build release APK or App Bundle**
   - For App Bundle (recommended):
     ```bash
     flutter build appbundle
     ```
   - For APK:
     ```bash
     flutter build apk --release
     ```

4. **Create a Google Play Developer account**
   - Sign up at [Google Play Console](https://play.google.com/console/) ($25 one-time fee)

5. **Create a new app in Google Play Console**
   - Click "Create app"
   - Enter app name, default language, and app type
   - Complete all store listing details:
     - Description
     - Screenshots
     - Feature graphic
     - Icon
     - Categorization
     - Content rating (complete questionnaire)
     - Privacy policy URL

6. **Upload your AAB or APK**
   - Go to "Production" > "Create new release"
   - Upload the AAB from `build/app/outputs/bundle/release/app-release.aab`
   - Or APK from `build/app/outputs/flutter-apk/app-release.apk`
   - Add release notes

7. **Review and roll out**
   - Complete all sections marked with warning icons
   - Review app details and submission
   - Select rollout percentage (can start with a smaller percentage)
   - Submit for review

### Direct APK Distribution

If you want to distribute your app outside the Play Store:
1. Build a release APK:
   ```bash
   flutter build apk --release --split-per-abi
   ```
2. Find APKs in `build/app/outputs/flutter-apk/`
3. Share these APK files directly with users (email, website download, etc.)
4. Users will need to enable "Install from unknown sources" in their device settings

## Web Deployment

### Prerequisites
- Web server or hosting service account (Firebase, GitHub Pages, Netlify, etc.)

### Build for Web

1. **Create a web build**
   ```bash
   flutter build web
   ```
   
   - For better performance, use:
   ```bash
   flutter build web --release --web-renderer canvaskit
   ```

2. **Customize web output (optional)**
   - Modify `web/index.html` for SEO, custom scripts, or styling
   - Replace `web/favicon.png` with your app icon
   - Update `web/manifest.json` with app details

### Firebase Hosting (Recommended)

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize Firebase in your project**
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project
   - Specify `build/web` as your public directory
   - Configure as a single-page app: Yes
   - Set up automatic builds and deploys: No (for now)

4. **Deploy to Firebase**
   ```bash
   firebase deploy --only hosting
   ```

5. **Access your deployed app**
   - Firebase will provide a URL like `https://your-project-id.web.app`

### GitHub Pages

1. **Create a GitHub repository** for your project

2. **Add a GitHub workflow file** `.github/workflows/web-deploy.yml`:
   ```yaml
   name: Deploy to GitHub Pages

   on:
     push:
       branches: [ main ]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: subosito/flutter-action@v2
           with:
             channel: 'stable'
         - run: flutter pub get
         - run: flutter build web --release
         - name: Deploy
           uses: peaceiris/actions-gh-pages@v3
           with:
             github_token: ${{ secrets.GITHUB_TOKEN }}
             publish_dir: ./build/web
   ```

3. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

4. **Configure GitHub Pages**
   - Go to repository Settings > Pages
   - Set source to "gh-pages" branch
   - Your app will be available at `https://username.github.io/repository-name/`

### Other Hosting Options

- **Netlify/Vercel/etc.**:
  1. Create an account
  2. Connect to your Git repository
  3. Set build command to: `flutter build web --release`
  4. Set publish directory to: `build/web`

- **Traditional Web Hosting**:
  1. Build your app: `flutter build web --release`
  2. Upload contents of `build/web` to your hosting provider via FTP or their control panel

## Important Deployment Notes

1. **Version Tracking**:
   - Always update `version` in `pubspec.yaml` before new releases
   - Follow semantic versioning (e.g., 1.0.0+1)
   - The number after the + is the build number, which must be incremented for each store submission

2. **Testing**:
   - Always test your app on real devices before deployment
   - Consider using Firebase Test Lab, TestFlight, or Google Play internal testing

3. **Privacy Policy**:
   - Both App Store and Play Store require a privacy policy
   - Create a simple website or GitHub page with your privacy policy

4. **App Store Review Guidelines**:
   - iOS apps typically take 1-3 days for review
   - Be prepared to address rejection issues

5. **Localization**:
   - Consider adding localization support if your app will be used internationally

6. **Analytics and Crash Reporting**:
   - Consider adding Firebase Analytics and Crashlytics before launch