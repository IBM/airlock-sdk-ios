platform :ios, '14.0'

workspace 'AirlockSDK'

project 'AirlockSDK', 'Debug'    => :debug,
                      'Release'  => :release


# ignore all warnings from all pods
inhibit_all_warnings!
set_arc_compatibility_flag!
use_frameworks!
use_modular_headers!

source 'https://github.com/CocoaPods/Specs.git'

target :'AirlockSDK' do

  pod 'SwiftyJSON',                       '~> 5.0.0'
  pod 'Alamofire',                        '5.4.0'

  target :'AirlockSDKTests' do
    inherit! :search_paths

    # Add pods specific to the sample app
    
  end
end

target :'AirlockSDKExample' do
end
