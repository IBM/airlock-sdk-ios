//
//  Constants.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 15/12/2016.
//
//

import Foundation

let SUPPORTED_AIRLOCK_VERSIONS                  = ["V2.5","V3.0"]
let CURRENT_AIRLOCK_VERSION                     = "V3.0"

let LAST_FEATURES_RESULTS_KEY                   = "airlockLastFeaturesResults"
let LAST_PULL_TIME_KEY                          = "airlockLastPullTime"
let LAST_RUNTIME_DOWNLOAD_TIME_KEY              = "airlockLastRuntimeDownloadTime"
let LAST_EXPERIMENTS_RESULTS_KEY                = "airlockExperimentsResults"
let LAST_MERGED_RUNTIME_KEY                     = "airlockLastMergedRunTime"


let RUNTIME_FILE_MODIFICATION_TIME_KEY          = "airlockRuntimeFileModificationTime"
let TRANSLATION_FILE_MODIFICATION_TIME_KEY      = "airlockTranslationFileModificationTime"
let JS_UTILS_FILE_MODIFICATION_TIME_KEY         = "airlockUtilsFileModificationTime"
let BRANCH_FILE_MODIFICATION_TIME_KEY           = "airlockBranchFileModificationTime"
let STREAMS_RUNTIME_FILE_MODIFICATION_TIME_KEY  = "airlockStreamsRuntimeFileModificationTime"
let STREAMS_JS_UTILS_FILE_MODIFICATION_TIME_KEY = "airlockStreamUtilsFileModificationTime"
let NOTIFS_RUNTIME_FILE_MODIFICATION_TIME_KEY   = "airlockNotificationsRuntimeFileModificationTime"

let LAST_CONTEXT_STRING_KEY                     = "airlockLastContextString"
let LAST_PURCHASES_IDS_KEY                      = "airlockLastPurchasesIds"
let LAST_PURCHASES_ENTITLEMENTS_KEY             = "airlockLastPurchasesEntitlements"
let LAST_CALCULATE_TIME_KEY                     = "airlockLastCalculateTime"
let LAST_SYNC_TIME_KEY                          = "airlockLastSyncTime"
let RUNTIME_FILE_NAME_KEY                       = "airlockRuntime"
let TRANSLATION_FILE_NAME_KEY                   = "airlockTranslations"
let JS_UTILS_FILE_NAME_KEY                      = "airlockJSUtils"
let BRANCH_FILE_NAME_KEY                        = "airlockBranch"
let STREAMS_RUNTIME_FILE_NAME_KEY               = "airlockStreamsRuntime"
let STREAMS_JS_UTILS_FILE_NAME_KEY              = "airlockStreamsJSUtils"
let NOTIFS_RUNTIME_FILE_NAME_KEY                = "airlockNotificationsRuntime"
let APP_USER_GROUPS_KEY                         = "airlockUserGroups"
let APP_RANDOM_NUM_KEY                          = "airlockAppRandomNum"
let APP_FEATURES_NUMBERS_KEY                    = "airlockFeaturesNumbers"
let APP_EXPERIMENTS_NUMBERS_KEY                 = "airlockExperimentsNumbers"
let APP_ENTITLEMENTS_NUMBERS_KEY                = "airlockEntitlementsNumbers"
let JSON_FIELD_INTERNAL_USER_GROUPS             = "internalUserGroups"
let JSON_FIELD_S3_PATH                          = "devS3Path"
let JSON_FIELD_CDN_PATH                         = "s3Path"

let SERVER_RUNTIME_FILE_NAME                    = "AirlockRuntime"
let SERVER_BRANCH_RUNTIME_FILE_NAME             = "AirlockRuntimeBranch"
let SERVER_JS_UTILS_FILE_NAME                   = "AirlockUtilities"
let SERVER_PRODUCTS_FILE_NAME                   = "products.json"
let SERVER_PRODUCT_RUNTIME_FILE_NAME            = "productRuntime.json"
let SERVER_BRANCHES_FILE_NAME                   = "AirlockBranches.json"
let SERVER_BRANCHES_RUNTIME_FILE_NAME           = "AirlockBranchesRuntime.json"
let SERVERS_FILE_NAME                           = "airlockServers.json"
let SERVER_DEFAULTS_FILE_NAME                   = "AirlockDefaults.json"
let SERVER_USERS_GROUPS_FILE_NAME               = "userGroups.json"
let SERVER_USERS_GROUPS_RUNTIME_FILE_NAME       = "AirlockUserGroupsRuntime.json"
let SERVER_TRANSLATION_FILE_PREFIX              = "strings__"
let SERVER_BRANCHES_FOLDER_NAME                 = "branches"
let SERVER_STREAMS_RUNTIME_FILE_NAME            = "AirlockStreams"
let SERVER_STREAMS_JS_UTILS_FILE_NAME           = "AirlockStreamsUtilities"
let SERVER_NOTIFS_RUNTIME_FILE_NAME             = "AirlockNotifications"

let SERVER_DEV_SUFFIX                           = "DEVELOPMENT"
let SERVER_PROD_SUFFIX                          = "PRODUCTION"
let LAST_RUNTIME_SUFFIX_KEY                     = "airlockRuntimeSuffix"

let JSON_SUFFIX                                 = ".json"
let TXT_SUFFIX                                  = ".txt"

let AIRLOCK_VERSION_KEY                         = "airlockVersion"
let AIRLOCK_SEASON_ID_KEY                       = "airlockSeasonID"
let LAST_KNOWN_DEVICE_LANGUAGE                  = "lastKnownDeviceLanguage"

let LAST_DATE_VARIANT_JOINED                    = "lastDateVariantJoined"

let DOUBLE_LENGTH_STRINGS_KEY                   = "airlockDoubleLengthStrings"

let TIMEOUT_INTERVAL_FOR_REQUESTS               = 10

let JSON_SEASON_MIN_VERSION                     = "minVersion"
let JSON_SEASON_MAX_VERSION                     = "maxVersion"

//-----------------------------------------------------------------------------------------

let OVERRIDING_SERVER_NAME_KEY                  = "overridingSrvName"
let OVERRIDING_BRANCH_ID_KEY                    = "overridingBranchId"
let OVERRIDING_BRANCH_NAME_KEY                  = "overridingBranchName"
let OVERRIDING_DEFAULTS_FILE_KEY                = "overridingDefaultsFile"

//------------------------------------------------------------------------------------------

let CONTEXT                                     = "context"
let TRANSLATIONS                                = "translations"
let IS_DOUBLE_LENGTH_STRINGS                    = "isDoubleLengthStrings"

//----------------------------------------------------------------------
let EXPERIMENT_ANALYTICS_PROP                   = "analytics"
let EXPERIMENT_ANALYTICS_FEATURES_PROP          = "featuresAndConfigurationsForAnalytics"
let EXPERIMENT_ANALYTICS_ATTRIBUTES_PROP        = "featuresAttributesForAnalytics"
let EXPERIMENT_WHITE_LIST_PROP                  = "inputFieldsForAnalytics"
let EXPERIMENT_ATTRIBUTES_NAME_PROP             = "name"
let EXPERIMENT_ATTRIBUTES_ATTRS_PROP            = "attributes"
let CONTEXT_WHITE_LIST_PROP                     = "inputFieldsForAnalytics"
let SEND_TO_ANALYTICS_PROP                      = "sendToAnalytics"
let CONFIGURATION_ATTRIBUTES_PROP               = "configAttributesForAnalytics"
let PREMIUM_RULE_PROP                           = "premiumRule"
let ENTITLEMENT_PROP                            = "entitlement"
let PREMIUM_PROP                                = "premium"

//----------------------------------------------------------------------
let FEATURE_ON_PROP                             = "featureON"
let VERSION_PROP                                = "version"
let ROOT_PROP                                   = "root"
let UNIQUEID_PROP                               = "uniqueId"
let FEATURES_PROP                               = "features"
let TYPE_PROP                                   = "type"
let MAX_FEATURES_ON_PROP                        = "maxFeaturesOn"
let NAME_PROP                                   = "name"
let NAMESPACE_PROP                              = "namespace"
let DEFAULT_CONFIGURATION_PROP                  = "defaultConfiguration"
let CONFIGURATION_PROP                          = "configuration"
let DEFAULT_IF_AIRLOCK_SYSTEMISDOWN_PROP        = "defaultIfAirlockSystemIsDown"
let NOCACHEDRESULTS_PROP                        = "noCachedResults"
let ENABLED_PROP                                = "enabled"
let STAGE_PROP                                  = "stage"
let MINAPPVERSION_PROP                          = "minAppVersion"
let ROLLOUTPERCENTAGE_PROP                      = "rolloutPercentage"
let ROLLOUTPERCENTAGEBITMAP_PROP                = "rolloutPercentageBitmap"
let INTERNALUSERGROUPS_PROP                     = "internalUserGroups"
let RULE_PROP                                   = "rule"
let RULESTRING_PROP                             = "ruleString"
let CONFIGURATION_RULES_PROP                    = "configurationRules"
let ORDERING_RULES_PROP                         = "orderingRules"
//----------------------------------------------------------------------

let BRANCHES_PROP                               = "branches"
let EXPERIMENTS_PROP                            = "experiments"
let EXPERIMENT_NAME_PROP                        = "experimentName"
let MIN_VERSION_PROP                            = "minVersion"
let MAX_VERSION_PROP                            = "maxVersion"
let VARIANTS_PROP                               = "variants"
let BRANCH_NAME_PROP                            = "branchName"
let MAX_EXPERIMENTS_ON_PROP                     = "maxExperimentsOn"
let BRANCH_CONFIGUATION_RULE_ITEMS              = "branchConfigurationRuleItems"
let BRANCH_FEATURE_PARENT_NAME                  = "branchFeatureParentName"
let BRANCH_FEATURES_ITEMS                       = "branchFeaturesItems"
let BRANCH_STATUS                               = "branchStatus"
let EXPERIMENTS_MX_NAME                         = "experimentsMX"
let EXPERIMENTS_MX_UID                          = "experimentsMX"
let DEFAULT_BRANCH_NAME                         = "MASTER"
let DEFAULT_VARIANT_NAME                        = "Default"
let EXPERIMENT_NAME_PREFIX                      = "experiments"
let MUTUAL_EXCLUSION_PREFIX                     = "mx"
let BRANCH_ENTITLEMENT_ITEMS                    = "branchEntitlementItems"
let BRANCH_PURCHASE_OPTIONS_ITEMS               = "branchPurchaseOptionsItems"
//----------------------------------------------------------------------

let ENTITLEMENTS_PROP                           = "entitlements"
let ENTITLEMENTS_ROOT_PROP                      = "entitlementsRoot"
let PURCHASE_OPTIONS_PROP                       = "purchaseOptions"
let INCLUDED_ENTITLEMENTS_PROP                  = "includedEntitlements"
let STORE_PRODUCT_IDS_PROP                      = "storeProductIds"
let STORE_TYPE_PROP                             = "storeType"
let PRODUCT_ID_PROP                             = "productId"

//----------------------------------------------------------------------

let STREAMS_NAMES_LIST_KEY                      = "airlockStreamsNamesList"
let STREAM_CACHE_KEY_PREFIX                     = "airlockStreamCache"
let STREAM_RESULT_KEY_PREFIX                    = "airlockStreamResult"
let STREAM_EVENTS_KEY_PREFIX                    = "airlockStreamEvents"
let STREAM_LAST_PROCESS_DATE_KEY_PREFIX         = "airlockStreamLastProcessDate"
let STREAM_VERBOSE_KEY_PREFIX                   = "airlockStreamVerbose"
let STREAM_IS_SUSPEND_EVENTS_KEY_PREFIX         = "airlockStreamSuspendEvents"
let STREAM_PERCENTAGE_KEY_PREFIX                = "airlockStreamPercentage"
let STREAMS_LIST_PROP                           = "streams"
let STREAM_NAME_PROP                            = "name"
let STREAM_FILTER_PROP                          = "filter"
let STREAM_PROCESSOR_PROP                       = "processor"
let STREAM_ENABLED_PROP                         = "enabled"
let STREAM_STAGE_PROP                           = "stage"
let STREAM_MINAPPVERSION_PROP                   = "minAppVersion"
let STREAM_INTERNALUSER_GROUPS_PROP             = "internalUserGroups"
let STREAM_ROLLOUTPERCENTAGE_PROP               = "rolloutPercentage"
let STREAM_MAX_CACHE_SIZE_KB_PROP               = "cacheSizeKB"
let STREAM_MAX_QUEUE_SIZE_KB_PROP               = "queueSizeKB"
let STREAM_MAX_QUEUED_EVENTS_PROP               = "maxQueuedEvents"

//----------------------------------------------------------------------
let NOTIFS_LIST_PROP                            = "notifications"
let NOTIFS_MAX_NOTIFS_PROP                      = "maxNotifications"
let NOTIFS_MIN_INTERVAL_PROP                    = "minInterval"
let NOTIFS_LIMITATIONS_PROP                     = "notificationsLimitations"
let NOTIF_NAME_PROP                             = "name"
let NOTIF_ID_PROP                               = "uniqueId"
let NOTIF_ENABLED_PROP                          = "enabled"
let NOTIF_STAGE_PROP                            = "stage"
let NOTIF_MAX_NOTIFS_PROP                       = "maxNotifications"
let NOTIF_MIN_INTERVAL_PROP                     = "minInterval"
let NOTIF_MINAPPVERSION_PROP                    = "minAppVersion"
let NOTIF_INTERNALUSER_GROUPS_PROP              = "internalUserGroups"
let NOTIF_ROLLOUTPERCENTAGE_PROP                = "rolloutPercentage"
let NOTIF_RULESTRING_PROP                       = "registrationRule"
let NOTIF_CANCEL_RULESTRING_PROP                = "cancellationRule"
let NOTIF_TEXT_PROP                             = "text"
let NOTIF_DATE_PROP                             = "date"
let NOTIF_CONFIGURATION_PROP                    = "configuration"
let NOTIF_CONFIG_DUEDATE_PROP                   = "dueDate"
let NOTIF_CONFIG_TEXT_PROP                      = "text"
let NOTIF_CONFIG_ACTIONS_PROP                   = "actions"
let NOTIF_CONFIG_ACTION_TITLE_PROP              = "title"
let NOTIF_CONFIG_ACTION_ID_PROP                 = "id"
let NOTIF_CONFIG_ACTION_OPTIONS_PROP            = "options"
let NOTIF_CONFIG_NOTIFICATION_PROP              = "notification"
let NOTIF_CONFIG_ADDITIONAL_INFO                = "additionalInfo"
let NOTIF_CONFIG_SOUND                          = "sound"
let NOTIF_CONFIG_THUMBNAIL                      = "thumbnail"
let NOTIF_CONFIG_TITLE_PROP                     = "title"
let NOTIF_DEEPLINK_PROP                         = "deepLink"
let NOTIF_CONFIG_DEEPLINKS                      = "deepLinks"
let NOTIF_CONFIG_DEEPLINK_DEFULT                = "default"
let NOTIFICATION_PERCENTAGE_KEY_PREFIX          = "airlockNotificationsPercentage"
let NOTIFICATION_CONFIGURATION_KEY              = "AirlockNotificationConfiguration"
let NOTIFICATION_STATUS_KEY                     = "AirlockNotificationStatus"
let NOTIFICATION_HISTORY_KEY                    = "AirlockNotificationHistory"
let NOTIFICATION_FIRED_DATES_KEY                = "AirlockNotificationFiredDates"
let NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY     = "AirlockNotificationsGlobalScheduledDates"
let NOTIFICATION_GLOBAL_FIRED_DATES_KEY         = "AirlockNotificationsGlobalFireDates"
//----------------------------------------------------------------------
let AIRLOCK_USER_ID_KEY                         = "AirlockUserID"



