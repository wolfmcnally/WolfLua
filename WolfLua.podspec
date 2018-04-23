Pod::Spec.new do |s|
  s.name             = 'WolfLua'
  s.version          = '0.1.0'
  s.summary          = 'An integration of the Lua scripting language with Swift.'

  s.homepage         = 'https://github.com/wolfmcnally/WolfLua'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wolfmcnally' => 'wolf@wolfmcnally.com' }
  s.source           = { :git => 'https://github.com/wolfmcnally/WolfLua.git', :tag => s.version.to_s }

  s.swift_version = '4.1'

  s.ios.deployment_target = '9.3'

  s.source_files = 'WolfLua/Classes/**/*'

# s.dependency 'WolfCore', '~> 2.2'
  s.dependency 'CLua'
end
