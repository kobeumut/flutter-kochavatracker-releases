#import "KochavaTrackerPlugin.h"
#import "KochavaTracker.h"
#import "KochavaAdNetwork.h"
#import "KVAAttribution+Internal.h"

@implementation KochavaTrackerPlugin

// Register plugin with Flutter.
+ (void)registerWithRegistrar:(NSObject <FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"kochava_tracker" binaryMessenger:[registrar messenger]];
    KochavaTrackerPlugin *instance = [[KochavaTrackerPlugin alloc] initWithChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
}

// Attempts to read an NSDictionary and returns nil if not one.
+ (NSDictionary *)readNSDictionary:(id)valueId {
    return [valueId isKindOfClass:NSDictionary.class] ? (NSDictionary *) valueId : nil;
}

// Attempts to read an NSString and returns nil if not one.
+ (NSString *)readNSString:(id)valueId {
    return [valueId isKindOfClass:NSString.class] ? (NSString *) valueId : nil;
}

// Attempts to read an NSNumber and returns nil if not one.
+ (NSNumber *)readNSNumber:(id)valueId {
    return [valueId isKindOfClass:NSNumber.class] ? (NSNumber *) valueId : nil;
}

// Takes a HEX encoded string and returns NSData. This can result in some weirdness if the input string is not HEX.
+(id)dataWithHexString:(NSString *)hexString
{
    // Discussion:  This is being employed to take the output of an NSData description (which is a hex string, such as is the case with a push notification token) and turn it back into an NSData.  This was sourced from the web and then optimized.

    // VALIDATION (RETURN)
    // ... must not be nil
    if (hexString == nil)
    {
        return nil;
    }
    
    // Must be an even number of digits
    NSUInteger hexStringLength = hexString.length;
    if (hexStringLength % 2 > 0) {
        NSLog(@"Warning:  func dataWithHexString(_:) - parameter hexString was passed a value which does not have an even number of digits. hexString = %@", hexString);
        return nil;
    }

    // Must contain only valid HEX characters.
    NSCharacterSet *chars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
    BOOL isValid = (NSNotFound == [hexString rangeOfCharacterFromSet:chars].location);
    if(!isValid) {
        NSLog(@"Warning:  func dataWithHexString(_:) - parameter hexString was passed a value which was not valid HEX. hexString = %@", hexString);
        return nil;
    }
    
    // MAIN
    // bytes and bytesPointer
    // ... default to point to some newly allocated memory
    unsigned char *bytes = (unsigned char *)malloc(hexStringLength / 2);
    unsigned char *bytesPointer = bytes;

    // ... fill with long(s) converted from two-digit strings containing base-16 representations of numbers
    for (CFIndex index = 0; index < hexStringLength; index += 2)
    {
        // buffer
        // ... set to the two-digit base 16 number located at index
        char buffer[3];
        buffer[0] = (char)[hexString characterAtIndex:index];
        buffer[1] = (char)[hexString characterAtIndex:index + 1];
        buffer[2] = '\0';

        // longInt and endPointer
        // ... set longInt to buffer converted to a long, and set endPointer to the next character in buffer after the numerical value.
        char *endPointer = NULL;
        
        long int longInt = strtol(buffer, &endPointer, 16);

        // bytesPointer
        // ... update with longInt
        *bytesPointer = (unsigned char)longInt;

        // ... advance to next position
        bytesPointer++;
    }
    
    // return
    return [NSData dataWithBytesNoCopy:bytes length:(hexStringLength / 2) freeWhenDone:YES];
}

// Decodes the attribution result from the callback or getter and returns a string.
+ (NSString *)decodeAttributionResult:(KVAAttributionResult *)attributionResult {
    if(!attributionResult.attributedBool) {
        return @"{\"attribution\":\"false\"}";
    }
    
    NSDictionary *attributionDictionary = attributionResult.rawDictionary;
    if (attributionDictionary == nil || ![NSJSONSerialization isValidJSONObject:attributionDictionary])
    {
        return @"";
    }
    return [KochavaTrackerPlugin serializeNSDictionary:attributionDictionary];
}

// Serialize an NSDictionary into an NSString
+ (NSString *)serializeNSDictionary:(NSDictionary *)dictionary {
    NSError *error = nil;
    NSData *dictionaryJSONData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    if (dictionaryJSONData == nil) {
        return @"";
    }

    NSString *result = [[NSString alloc] initWithData:dictionaryJSONData encoding:NSUTF8StringEncoding];
    if (result == nil) {
        return @"";
    }

    return result;
}

// Initialize the plugin with the method channel to communicate with Dart.
- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
    self = [super init];
    if (self) {
        _channel = channel;
    }
    return self;
}

// Handle a method call from the Dart layer.
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"executeAdvancedInstruction" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *keyString = [KochavaTrackerPlugin readNSString:valueDictionary[@"key"]];
        NSString *valueString = [KochavaTrackerPlugin readNSString:valueDictionary[@"value"]];
        if(keyString.length == 0) {
            result(@"Failed");
            return;
        }
        
        if([@"INTERNAL_UNCONFIGURE" isEqualToString:keyString]) {
            [KVATrackerProduct.shared shutdownWithDeleteLocalDataBool:NO];
            result(@"success");
            return;
        }
        
        if([@"INTERNAL_RESET" isEqualToString:keyString]) {
            [KVATrackerProduct.shared shutdownWithDeleteLocalDataBool:YES];
            result(@"success");
            return;
        }
        
        [KVATracker.shared executeAdvancedInstructionWithIdentifierString:keyString valueObject:valueString];
        result(@"success");
        
    } else if ([@"configure" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        [self configure:valueDictionary.mutableCopy];
        result(@"success");

    } else if ([@"getAttribution" isEqualToString:call.method]) {
        NSString * attributionString = @"";
        if(KVATracker.shared.startedBool)
        {
            attributionString = [KochavaTrackerPlugin decodeAttributionResult:KVATracker.shared.attribution.result];
        }
        result(attributionString);

    } else if ([@"getDeviceId" isEqualToString:call.method]) {
        NSString *deviceIdString = @"";
        if(KVATracker.shared.startedBool)
        {
            deviceIdString = KVATracker.shared.deviceIdString;
            if (deviceIdString == nil)
            {
                deviceIdString = @"";
            }
        }
        result(deviceIdString);

    } else if ([@"getVersion" isEqualToString:call.method]) {
        NSString *sdkVersionString = @"";
        if(KVATracker.shared.startedBool)
        {
            sdkVersionString = KVATracker.shared.sdkVersionString;
            if (sdkVersionString == nil)
            {
                sdkVersionString = @"";
            }
        }
        result(sdkVersionString);

    } else if ([@"setAppLimitAdTracking" isEqualToString:call.method]) {
        NSNumber *valueNumber = [KochavaTrackerPlugin readNSNumber:call.arguments];
        if (valueNumber == nil) {
            result(@"Failed");
            return;
        }
        BOOL value = [valueNumber boolValue];
        [KVATracker.shared setAppLimitAdTrackingBool:value];
        result(@"success");

    } else if ([@"setIdentityLink" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        for(id key in valueDictionary)
        {
            NSString *value = valueDictionary[key];
            [[KVATracker.shared identityLink] registerWithNameString:key identifierString:value];
        }
        result(@"success");

    } else if ([@"setSleep" isEqualToString:call.method]) {
        NSNumber *valueNumber = [KochavaTrackerPlugin readNSNumber:call.arguments];
        if (valueNumber == nil) {
            result(@"Failed");
            return;
        }
        BOOL value = [valueNumber boolValue];
        [KVATracker.shared setSleepBool:value];
        result(@"success");

    } else if ([@"getSleep" isEqualToString:call.method]) {
        result(@(KVATracker.shared.sleepBool));

    } else if ([@"addPushToken" isEqualToString:call.method]) {
        NSString *valueString = [KochavaTrackerPlugin readNSString:call.arguments];
        if(valueString.length == 0) {
            result(@"Failed");
            return;
        }
        NSData *tokenData = [self.class dataWithHexString:valueString];
        if (tokenData == nil) {
            result(@"Failed");
            return;
        }
        [KVAPushNotificationsToken addWithData:tokenData];
        result(@"success");

    } else if ([@"removePushToken" isEqualToString:call.method]) {
        NSString *valueString = [KochavaTrackerPlugin readNSString:call.arguments];
        if(valueString.length == 0) {
            result(@"Failed");
            return;
        }
        NSData *tokenData = [self.class dataWithHexString:valueString];
        if (tokenData == nil) {
            result(@"Failed");
            return;
        }
        [KVAPushNotificationsToken removeWithData:tokenData];
        result(@"success");

    } else if ([@"sendEventString" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *nameString = [KochavaTrackerPlugin readNSString:valueDictionary[@"name"]];
        NSString *infoString = [KochavaTrackerPlugin readNSString:valueDictionary[@"info"]];
        if(nameString.length == 0) {
            result(@"Failed");
            return;
        }
        [KVAEvent sendCustomWithNameString:nameString infoString:infoString];
        result(@"success");

    } else if ([@"sendEventMapObject" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *nameString = [KochavaTrackerPlugin readNSString:valueDictionary[@"name"]];
        NSDictionary *infoDictionary = [KochavaTrackerPlugin readNSDictionary:valueDictionary[@"info"]];
        if(nameString.length == 0) {
            result(@"Failed");
            return;
        }
        [KVAEvent sendCustomWithNameString:nameString infoDictionary:infoDictionary];
        result(@"success");

    } else if ([@"sendEventAppleAppStoreReceipt" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *nameString = [KochavaTrackerPlugin readNSString:valueDictionary[@"name"]];
        NSDictionary *infoDictionary = [KochavaTrackerPlugin readNSDictionary:valueDictionary[@"info"]];
        NSString *appStoreReceiptBase64EncodedString = [KochavaTrackerPlugin readNSString:valueDictionary[@"appStoreReceiptBase64EncodedString"]];
        if(nameString.length == 0) {
            result(@"Failed");
            return;
        }

        KVAEvent *event = [KVAEvent customEventWithNameString:nameString];
        if(infoDictionary != nil)
        {
            event.infoDictionary = infoDictionary;
        }
        if(appStoreReceiptBase64EncodedString.length > 0)
        {
            event.appStoreReceiptBase64EncodedString = appStoreReceiptBase64EncodedString;
        }
        [event send];
        result(@"success");

    } else if ([@"sendEventGooglePlayReceipt" isEqualToString:call.method]) {
        // Not supported on this platform.
        result(@"success");

    } else if ([@"sendDeepLink" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *urlString = [KochavaTrackerPlugin readNSString:valueDictionary[@"openURLString"]];
        NSString *sourceApplicationString = [KochavaTrackerPlugin readNSString:valueDictionary[@"sourceApplicationString"]];

        // Create and send the deeplink event.
        KVAEvent *event = [KVAEvent eventWithType:KVAEventType.deeplink];
        if(urlString.length > 0)
        {
            event.uriString = urlString;
        }
        if(sourceApplicationString.length > 0)
        {
            event.sourceString = sourceApplicationString;
        }
        [event send];
        result(@"success");

    } else if ([@"processDeeplink" isEqualToString:call.method]) {
        NSDictionary *valueDictionary = [KochavaTrackerPlugin readNSDictionary:call.arguments];
        if (valueDictionary == nil) {
            result(@"Failed");
            return;
        }
        NSString *id = [KochavaTrackerPlugin readNSString:valueDictionary[@"id"]];
        NSString *path = [KochavaTrackerPlugin readNSString:valueDictionary[@"path"]];
        NSURL *pathUrl = nil;
        if (path.length > 0) {
            pathUrl = [NSURL URLWithString:path];
        }
        NSNumber *timeout = [KochavaTrackerPlugin readNSNumber:valueDictionary[@"timeout"]];
        NSTimeInterval timeoutTimeInterval = 10.0;
        if (timeout != nil) {
            timeoutTimeInterval = timeout.doubleValue;
        }

        // Process the deeplink.
        [KVADeeplink processWithURL:pathUrl timeoutTimeInterval:timeoutTimeInterval completionHandler:^(KVADeeplink *_Nonnull deeplink) {
            // Serialize the response deeplink inside a dictionary with the request id.
            NSObject *deeplinkAsForContextObject = [deeplink kva_asForContextObjectWithContext:KVAContext.sdkWrapper];
            NSDictionary *deeplinkDictionary = [deeplinkAsForContextObject isKindOfClass:NSDictionary.class] ? (NSDictionary *) deeplinkAsForContextObject : nil;

            NSMutableDictionary *responseDictionary = [[NSDictionary alloc] init].mutableCopy;
            responseDictionary[@"id"] = id;
            responseDictionary[@"deeplink"] = deeplinkDictionary;

            NSString *response = [KochavaTrackerPlugin serializeNSDictionary:responseDictionary];
            if (response.length == 0) {
                response = @"{}";
            }

            // Emit the deeplink event notification.
            [self.channel invokeMethod:@"deeplinkCallback" arguments:response];
        }];
        result(@"success");

    } else if ([@"enableAppTrackingTransparencyAutoRequest" isEqualToString:call.method]) {
        KVATracker.shared.appTrackingTransparency.autoRequestTrackingAuthorizationBool = YES;
        result(@"success");

    } else {
        result(FlutterMethodNotImplemented);
    }
}

// Configure and start the SDK.
- (void)configure:(NSMutableDictionary *)parametersDictionary {
    // logLevel
    NSString *logLevelString = parametersDictionary[@"logLevel"];
    if ([@"never" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.never];
    } else if ([@"error" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.error];
    } else if ([@"warn" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.warn];
    } else if ([@"info" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.info];
    } else if ([@"debug" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.debug];
    } else if ([@"trace" isEqualToString:logLevelString])
    {
        [KVALog.shared setLevel:KVALogLevel.trace];
    }
    
    // Register the ad network product for SKaD support.
    [KVAAdNetworkProduct.shared register];
    
    // AppTrackingTransparency
    NSNumber *attEnabled = parametersDictionary[@"att_enabled"];
    if(attEnabled != nil)
    {
        KVATracker.shared.appTrackingTransparency.enabledBool = [attEnabled boolValue];
    }
    NSNumber *attWaitTIme = parametersDictionary[@"att_wait_time"];
    if(attWaitTIme != nil)
    {
        KVATracker.shared.appTrackingTransparency.authorizationStatusWaitTimeInterval = [attWaitTIme doubleValue];
    }
    NSNumber *attAutoRequest = parametersDictionary[@"att_auto_request"];
    if(attAutoRequest != nil)
    {
        KVATracker.shared.appTrackingTransparency.autoRequestTrackingAuthorizationBool = [attAutoRequest boolValue];
    }
    
    // containerAppGroupIdentifier
    NSString *containerAppGroupIdentifier = parametersDictionary[@"container_app_group_identifier"];
    if(containerAppGroupIdentifier != nil)
    {
        KVAAppGroups.shared.deviceAppGroupIdentifierString = containerAppGroupIdentifier;
    }
    
    // iOSAppGUIDString or partnerName
    NSString *appGuid = parametersDictionary[@"iOSAppGUIDString"];
    NSString *partnerName = parametersDictionary[@"partnerName"];
    if(appGuid != nil)
    {
        [KVATracker.shared startWithAppGUIDString:appGuid];
    } else if(partnerName != nil)
    {
        [KVATracker.shared startWithPartnerNameString:partnerName];
    }
    
    // custom
    NSDictionary *custom = parametersDictionary[@"custom"];
    if(custom != nil)
    {
        for(id key in custom)
        {
            NSString *value = custom[key];
            [KVATracker.shared.customIdentifiers registerWithNameString:key identifierString:value];
        }
    }
    
    // retrieveAttribution
    BOOL retrieveAttribution = [parametersDictionary[@"retrieveAttribution"] boolValue];
    if(retrieveAttribution)
    {
        KVATracker.shared.attribution.retrieveResultBool = retrieveAttribution;
        KVATracker.shared.attribution.didRetrieveResultBlock = ^(KVAAttribution * _Nonnull attribution, KVAAttributionResult * _Nonnull attributionResult)
        {
            // For legacy purposes this needs to be made to look like the v3 response until we change the attribution handler over on the Unity side.
            NSString * attributionString = [KochavaTrackerPlugin decodeAttributionResult:attributionResult];
            [self.channel invokeMethod:@"attributionCallback" arguments:attributionString];
        };
    }
    
    // limitAdTracking
    NSNumber *limitAdTracking = parametersDictionary[@"limitAdTracking"];
    if(limitAdTracking != nil)
    {
        [KVATracker.shared setAppLimitAdTrackingBool:[limitAdTracking boolValue]];
    }
    
    // identityLink
    NSDictionary *identityLink = parametersDictionary[@"identityLink"];
    if(identityLink != nil)
    {
        for(id key in identityLink)
        {
            NSString *value = identityLink[key];
            [[KVATracker.shared identityLink] registerWithNameString:key identifierString:value];
        }
    }
    
    // sleepBool
    BOOL sleepBool = [parametersDictionary[@"sleepBool"] boolValue];
    if(sleepBool) {
        [KVATracker.shared setSleepBool:sleepBool];
    }
}

@end
