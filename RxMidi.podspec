#
# Be sure to run `pod lib lint RxMidi.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "RxMidi"
  s.version          = "0.4.0"
  s.summary          = "Rx extensions for working with midi interfaces."
  s.description      = <<-DESC
RxMidi provides RxSwift based extenstions for the MIKMIDI iOS MIDI library.
                       DESC

  s.homepage         = "https://github.com/lintmachine/RxMidi"
  s.license          = 'MIT'
  s.author           = { "cdann" => "cdann@lintmachine.com" }
  s.source           = { :git => "https://github.com/lintmachine/RxMidi.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/lintmachine'

  s.platform     = :ios, '9.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'RxMidi' => ['Pod/Assets/*.png']
  }

  s.dependency 'RxSwift', '~> 4.4'
  s.dependency 'RxCocoa', '~> 4.4'
  s.dependency 'MIKMIDI', '~> 1.7'
end
