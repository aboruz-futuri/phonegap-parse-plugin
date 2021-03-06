#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString * ecb = nil;
static NSMutableDictionary * launchNotification = nil;
static NSString * const PPAppId = @"appId";
static NSString * const PPClientKey = @"clientKey";
static NSString * const PPReceivedInForeground = @"receivedInForeground";

@implementation CDVParsePlugin

- (void)resetBadge:(CDVInvokedUrlCommand *)command {
    NSLog(@"ParsePlugin.resetBadge");
    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    currentInstallation.badge = 0;
    // [currentInstallation saveEventually];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void)initialize: (CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        @synchronized(self) {
            CDVPluginResult* pluginResult = nil;
            
            NSString *appId = [command.arguments objectAtIndex:0];
            NSString *clientKey = [command.arguments objectAtIndex:1];
            [[NSUserDefaults standardUserDefaults] setObject:appId forKey:PPAppId];
            [[NSUserDefaults standardUserDefaults] setObject:clientKey forKey:PPClientKey];
            
            [Parse setApplicationId:appId clientKey:clientKey];
            
            // Register for notifications
            if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
                UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                                        settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound
                                                        categories:nil];
                [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
            else {
                [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
                 UIRemoteNotificationTypeBadge |
                 UIRemoteNotificationTypeAlert |
                 UIRemoteNotificationTypeSound];
            }
            
            PFInstallation *currentInstallation = [PFInstallation currentInstallation];
            NSError *error = nil;
            [currentInstallation save:&error];
            if (error != nil) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void)getInstallationId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *installationId = currentInstallation.installationId;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:installationId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getInstallationObjectId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *objectId = currentInstallation.objectId;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:objectId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getSubscriptions: (CDVInvokedUrlCommand *)command
{
    NSArray *channels = [PFInstallation currentInstallation].channels;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:channels];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)subscribe: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *channel = [command.arguments objectAtIndex:0];
    [currentInstallation addUniqueObject:channel forKey:@"channels"];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *channel = [command.arguments objectAtIndex:0];
    [currentInstallation removeObject:channel forKey:@"channels"];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end

@implementation AppDelegate (CDVParsePlugin)

void MethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(applicationDidBecomeActive:));
}

- (void)noop_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
}

- (void)swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
    // Call existing method
    [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:newDeviceToken];
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
}

- (NSString *)getJson:(NSDictionary *)data {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:(NSJSONWritingOptions)NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData) {
        NSLog(@"getJson error: %@", error.localizedDescription);
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}

- (void)noop_applicationDidBecomeActive:(UIApplication *)application {
}

- (void)swizzled_applicationDidBecomeActive:(UIApplication *)application {
    // Call existing method
    [self swizzled_applicationDidBecomeActive:application];
    // Reset the badge on app open
    application.applicationIconBadgeNumber = 0;
}

- (void)handleRemoteNotification:(UIApplication *)application payload:(NSMutableDictionary *)payload {

    // track analytics when the app was opened as a result of tapping a remote notification
    if (![[payload objectForKey:PPReceivedInForeground] boolValue]) {
        [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:payload];
    }

    // send the callback to the webview
    if (ecb) {
        NSString *jsString = [NSString stringWithFormat:@"%@(%@);", ecb, [self getJson:payload]];

        if ([self.viewController.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
            // perform the selector on the main thread to bypass known iOS issue: http://goo.gl/0E1iAj
            [self.viewController.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
        }
    }
}

@end
