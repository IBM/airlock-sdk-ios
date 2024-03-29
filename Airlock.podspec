Pod::Spec.new do |s|

    s.name                  = 'Airlock'
    s.version               = '8.0.22'
    s.summary               = 'An SDK to interact with the Airlock framework.'
    s.description           = 'An SDK to interact with the Airlock framework.'
    s.homepage              = 'https://github.com/TheWeatherCompany/airlock-sdk-ios/blob/master/README.md'


    s.license               = {
                                :type => 'PROPRIETARY',
                                :text => '(c) Copyright TWC Product and Technology LLC  2011, 2019. All rights reserved.'
                              }
    s.author                = {
								'Gil Fuchs'         => 'gilfuchs@il.ibm.com',
								'Yoav Ben-Yair'     => 'yoavbe@il.ibm.com',
								'Elik Katz'         => 'elikk@il.ibm.com'
                              }
    s.source                = {
                                :git => 'git@github.com:TheWeatherCompany/airlock-sdk-ios.git',
                                :tag => s.version.to_s
                              }

    s.platform              = :ios, '14.0'
    s.ios.deployment_target = '14.0'
    s.swift_versions        = ['5.0']
    s.requires_arc          = true
    s.compiler_flags        = '-fmodules'
    s.source_files          = 'AirlockSDK/Shared/**/*.{swift,m,h}'
    s.frameworks            = 'UIKit', 'Foundation'
    s.resource_bundles      = { 'Airlock' => ['AirLockSDK/Shared/Debug UI/Storyboards/**/*.{storyboard}', 'AirLockSDK/Shared/Debug UI/Assets/images.xcassets'] }
    s.static_framework 		= true
    s.dependency 'Alamofire',   '5.4.0'
    s.dependency 'SwiftyJSON',  '~> 5.0.0'
end