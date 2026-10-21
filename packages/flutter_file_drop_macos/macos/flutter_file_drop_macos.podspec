#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_file_drop_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_file_drop_macos'
  s.version          = '0.1.0'
  s.summary          = 'macOS implementation for flutter_file_drop.'
  s.description      = <<-DESC
Headless macOS file and text drop support for Flutter.
                       DESC
  s.homepage         = 'https://pub.dev/packages/flutter_file_drop_macos'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_file_drop contributors' => '' }

  s.source           = { :path => '.' }
  s.source_files = 'flutter_file_drop_macos/Sources/flutter_file_drop_macos/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_file_drop_macos_privacy' => ['flutter_file_drop_macos/Sources/flutter_file_drop_macos/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
