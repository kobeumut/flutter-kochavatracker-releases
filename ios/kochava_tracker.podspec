#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint kochava_tracker.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'kochava_tracker'
  s.version          = '1.1.2'
  s.summary          = 'The KochavaTracker Flutter SDK. Kochava is a leading mobile attribution and analytics platform.'
  s.description      = <<-DESC
  A lightweight and easy to integrate SDK, providing first-class integration with Kochava’s installation attribution and analytics platform.
                       DESC
  s.homepage         = 'https://www.kochava.com'
  s.license          = { :type => 'Commercial', :file => '../LICENSE' }
  s.author           = { 'Kochava' => 'sdkdev@kochava.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.private_header_files = 'Classes/KochavaSDK/*.h'
  s.public_header_files = 'Classes/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '10.3'
  s.requires_arc = true
  s.static_framework = true
  
  # Add KochavaTracker Dependency
  s.dependency 'KochavaTrackeriOS', '4.3.1'
  s.dependency 'KochavaAdNetworkiOS', '4.3.1'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
