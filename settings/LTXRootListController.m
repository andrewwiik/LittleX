#include "LTXRootListController.h"
#include "LTXAppSettingsController.h"
#import "OrderedDictionary.h"
#include <spawn.h>

#import "../headers/Preferences/Preferences.h"

#if __cplusplus
extern "C" {
#endif
    CFSetRef SBSCopyDisplayIdentifiers();
    NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);

#if __cplusplus
}
#endif

static OrderedDictionary *dataSourceUser;

@implementation LTXRootListController

- (NSArray *)specifiers {
	if (_specifiers == nil) {
		NSMutableArray *testingSpecs = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
    [testingSpecs addObjectsFromArray:[self appSpecifiers]];
    _specifiers = testingSpecs;
  }
    
	return _specifiers;
}

-(NSMutableArray*)appSpecifiers {
    NSMutableArray *specifiers = [NSMutableArray array];
    
    NSArray *displayIdentifiers = [(__bridge NSSet *)SBSCopyDisplayIdentifiers() allObjects];

    NSMutableDictionary *apps = [NSMutableDictionary new];
    for (NSString *appIdentifier in displayIdentifiers) {
        NSString *appName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(appIdentifier);
        if (appName) {
            [apps setObject:appName forKey:appIdentifier];
        }
    }

    dataSourceUser = (OrderedDictionary*)[apps copy];
    dataSourceUser = (OrderedDictionary*)[self trimDataSource:dataSourceUser];
    dataSourceUser = [self sortedDictionary:dataSourceUser];

    PSSpecifier* groupSpecifier = [PSSpecifier groupSpecifierWithName:@"Applications:"];
    [specifiers addObject:groupSpecifier];
    
    for (NSString *bundleIdentifier in dataSourceUser.allKeys) {
        NSString *displayName = dataSourceUser[bundleIdentifier];
        
        PSSpecifier *spe = [PSSpecifier preferenceSpecifierNamed:displayName target:self set:nil get:@selector(getIsWidgetSetForSpecifier:) detail:[LTXAppSettingsController class] cell:PSLinkListCell edit:nil];
        [spe setProperty:@"LTXAppSettingsController" forKey:@"detail"];
        [spe setProperty:[NSNumber numberWithBool:YES] forKey:@"isController"];
        [spe setProperty:[NSNumber numberWithBool:YES] forKey:@"enabled"];
        [spe setProperty:bundleIdentifier forKey:@"bundleIdentifier"];
        [spe setProperty:bundleIdentifier forKey:@"appIDForLazyIcon"];
        [spe setProperty:@YES forKey:@"useLazyIcons"];
        [specifiers addObject:spe];
    }
    
    return specifiers;
}

-(NSDictionary*)trimDataSource:(NSDictionary*)dataSource {
    NSMutableDictionary *mutable = [dataSource mutableCopy];
    
    NSArray *bannedIdentifiers = [[NSArray alloc] initWithObjects:
                                  @"com.apple.AdSheet",
                                  @"com.apple.AdSheetPhone",
                                  @"com.apple.AdSheetPad",
                                  @"com.apple.DataActivation",
                                  @"com.apple.DemoApp",
                                  @"com.apple.fieldtest",
                                  @"com.apple.iosdiagnostics",
                                  @"com.apple.iphoneos.iPodOut",
                                  @"com.apple.TrustMe",
                                  @"com.apple.WebSheet",
                                  @"com.apple.springboard",
                                  @"com.apple.purplebuddy",
                                  @"com.apple.datadetectors.DDActionsService",
                                  @"com.apple.FacebookAccountMigrationDialog",
                                  @"com.apple.iad.iAdOptOut",
                                  @"com.apple.ios.StoreKitUIService",
                                  @"com.apple.TextInput.kbd",
                                  @"com.apple.MailCompositionService",
                                  @"com.apple.mobilesms.compose",
                                  @"com.apple.quicklook.quicklookd",
                                  @"com.apple.ShoeboxUIService",
                                  @"com.apple.social.remoteui.SocialUIService",
                                  @"com.apple.WebViewService",
                                  @"com.apple.gamecenter.GameCenterUIService",
                                  @"com.apple.appleaccount.AACredentialRecoveryDialog",
                                  @"com.apple.CompassCalibrationViewService",
                                  @"com.apple.WebContentFilter.remoteUI.WebContentAnalysisUI",
                                  @"com.apple.PassbookUIService",
                                  @"com.apple.uikit.PrintStatus",
                                  @"com.apple.Copilot",
                                  @"com.apple.MusicUIService",
                                  @"com.apple.AccountAuthenticationDialog",
                                  @"com.apple.MobileReplayer",
                                  @"com.apple.SiriViewService",
                                  @"com.apple.TencentWeiboAccountMigrationDialog",
                                  @"com.apple.AskPermissionUI",
                                  @"com.apple.Diagnostics",
                                  @"com.apple.GameController",
                                  @"com.apple.HealthPrivacyService",
                                  @"com.apple.InCallService",
                                  @"com.apple.mobilesms.notification",
                                  @"com.apple.PhotosViewService",
                                  @"com.apple.PreBoard",
                                  @"com.apple.PrintKit.Print-Center",
                                  @"com.apple.SharedWebCredentialViewService",
                                  @"com.apple.share",
                                  @"com.apple.CoreAuthUI",
                                  @"com.apple.webapp",
                                  @"com.apple.webapp1",
                                  @"com.apple.family",
                                  nil];
    for (NSString *key in bannedIdentifiers) {
        [mutable removeObjectForKey:key];
    }
    
    return mutable;
}

-(OrderedDictionary*)sortedDictionary:(OrderedDictionary*)dict {
    NSArray *sortedValues;
    OrderedDictionary *mutable = [OrderedDictionary dictionary];
    sortedValues = [[dict allValues] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *value in sortedValues) {
        NSString *key = [[dict allKeysForObject:value] objectAtIndex:0];
        [mutable setObject:value forKey:key];
    }
    return mutable;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
  NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
  NSMutableDictionary *settings = [NSMutableDictionary dictionary];
  [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
  return ([settings objectForKey:specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
  NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
  NSMutableDictionary *settings = [NSMutableDictionary dictionary];
  [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
  [settings setObject:value forKey:specifier.properties[@"key"]];
  [settings writeToFile:path atomically:YES];
}

- (void)respring {
  pid_t pid;
  int status;
  const char* args[] = {"killall", "-9", "backboardd", NULL};
  posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
  waitpid(pid, &status, WEXITED);
}
@end
