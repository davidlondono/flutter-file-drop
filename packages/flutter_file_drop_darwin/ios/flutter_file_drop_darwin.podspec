#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_file_drop_darwin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_file_drop_darwin'
  s.version          = '0.1.0'
  s.summary          = 'iOS and macOS implementation for flutter_file_drop.'
  s.description      = <<-DESC
Headless iOS file and text drop support for Flutter.
                       DESC
  s.homepage         = 'https://pub.dev/packages/flutter_file_drop_darwin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_file_drop contributors' => '' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_file_drop_darwin/Sources/flutter_file_drop_darwin/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_file_drop_darwin_privacy' => ['flutter_file_drop_darwin/Sources/flutter_file_drop_darwin/PrivacyInfo.xcprivacy']}
end
