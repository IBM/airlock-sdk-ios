Pod::Spec.new do |s|

    s.name                  = 'AirLockSDK'
    s.version               = '6.0-beta2'
    s.summary               = 'An SDK to interact with the Airlock framework.'
    s.description           = 'An SDK to interact with the Airlock framework.'
    s.homepage              = 'https://github.com/IBM/airlock-sdk-ios/blob/master/README.md'


    s.license               = {
                                :type => 'MIT',
                                :file => LICENSE
                              }
    s.author                = {
                                'Gil Fuchs'         => 'gilfuchs@il.ibm.com',
                                'Yoav Ben-Yair'     => 'yoavbe@il.ibm.com',
                                'Elik Katz'         => 'elikk@il.ibm.com',
                                'Vladislav Rybak'   => 'vrybak@il.ibm.com'
                              }
    s.source                = {
                                :git => 'git@github.com:IBM/airlock-sdk-ios.git',
                                :tag => s.version.to_s
                              }

    s.platform              = :ios, '11.0'
    s.ios.deployment_target = '11.0'
    s.swift_versions        = ['5.0']
    s.requires_arc          = true
    s.compiler_flags        = '-fmodules'
    s.source_files          = 'AirLockSDK/Classes/**/*.{swift,m,h}'
    s.frameworks            = 'UIKit', 'Foundation'
    s.resource_bundles      = { 'AirLockSDK' => ['AirLockSDK/Classes/**/*.{storyboard}', 'AirLockSDK/Classes/images.xcassets'] }

    s.dependency 'Alamofire',   '~> 5.0.0-beta.6'
    s.dependency 'SwiftyJSON',  '~> 5.0.0'

end
