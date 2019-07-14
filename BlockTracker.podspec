Pod::Spec.new do |s|
s.name         = "BlockTracker"
s.version      = "1.0.9"
s.summary      = "Tracking block args of Objective-C method based on BlockHook"
s.description  = <<-DESC
BlockTracker can track block arguments of a method. It's based on BlockHook.
DESC
s.homepage     = "https://github.com/yulingtianxia/BlockTracker"

s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "yulingtianxia" => "yulingtianxia@gmail.com" }
s.social_media_url = 'https://twitter.com/yulingtianxia'
s.source       = { :git => "https://github.com/yulingtianxia/BlockTracker.git", :tag => s.version.to_s }

s.source_files = "BlockTracker/*.{h,m,c}"
s.public_header_files = "BlockTracker/*.h"

s.ios.deployment_target = "8.0"
s.osx.deployment_target = "10.8"
#s.tvos.deployment_target = "9.0"
#s.watchos.deployment_target = "1.0"
s.requires_arc = true

s.dependency 'BlockHook', '~> 1.5.0'

end

