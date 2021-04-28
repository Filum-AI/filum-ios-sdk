#
# Be sure to run `pod lib lint FilumBDP.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'FilumBDP'
  s.version          = '0.1.0'
  s.summary          = 'Filum Business Data Platform IOS SDK'

  s.description      = <<-DESC
  Filum IOS SDK to send events to Filum Event API
                       DESC

  s.homepage         = 'https://github.com/Filum-AI/filum-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hoanghiep106' => 'hoanghiepnguyen106@gmail.com' }
  s.source           = { :git => 'https://github.com/Filum-AI/filum-ios-sdk', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'FilumBDP/Classes/**/*'
  
end
