Pod::Spec.new do |s|
  s.name             = 'rivium_push_voip'
  s.version          = '0.1.2'
  s.summary          = 'VoIP call handling add-on for RiviumPush push notifications.'
  s.description      = <<-DESC
VoIP call handling add-on for RiviumPush push notifications.
Thin wrapper around native RiviumPushVoip SDK.
Provides native incoming call UI using CallKit on iOS.
                       DESC
  s.homepage         = 'https://rivium.co/cloud/rivium-push'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rivium' => 'support@rivium.co' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # Native RiviumPush VoIP SDK (CocoaPods)
  s.dependency 'RiviumPushVoip', '~> 0.1'
end
