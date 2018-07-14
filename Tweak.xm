#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreGraphics/CoreGraphics.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>

#import "headers/SpringBoard/SpringBoard.h"

@interface UIScreen (Priv)
- (UIEdgeInsets)_sceneSafeAreaInsets;
@end

static BOOL actuallySupportsForce = NO;


static CGFloat screenCornerRadius = 19;

static BOOL floatingDockSupported = YES;

static BOOL isActualIPhoneX = NO;

static BOOL wantsDock = YES;
static BOOL wantsStatusBar = YES;
static BOOL wantsHomeBar = YES;
static BOOL wantsRoundedSwitcherCards = YES;
static BOOL wantsKeyboardDock = YES;

static BOOL shouldForceModern = YES;

static CGFloat bottomBarInset = 20;

static BOOL properFixedBounds = YES;
static BOOL properBounds = NO;
static BOOL isEnabledInApp = YES;

static BOOL reduceRowsBy1 = TRUE;

static NSInteger switcherKillStyle = 0;

static NSDictionary *globalSettings;

@interface SBHomeGrabberSettings : NSObject
- (void)setEnabled:(BOOL)enabled;
- (void)setAutoHideOverride:(NSInteger)override;
- (NSInteger)autoHideOverride;
@end 

@interface SBHomeScreenSettings : NSObject
- (SBHomeGrabberSettings *)grabberSettings;
@end

@interface SBRootSettings : NSObject
- (SBHomeScreenSettings *)homeScreenSettings;
@end

@interface SBPrototypeController : NSObject
+ (instancetype)sharedInstance;
- (SBRootSettings *)rootSettings;
@end


static void bundleIdentifierBecameVisible(NSString *bundleIdentifier) {
	if (bundleIdentifier && globalSettings) {
		if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
			[[[[[NSClassFromString(@"SBPrototypeController") sharedInstance] rootSettings] homeScreenSettings] grabberSettings] setAutoHideOverride:wantsHomeBar ? 0x7fffffffffffffff : 5];
		} else {
			BOOL shouldShow = YES;
			NSDictionary *appSettings = [globalSettings objectForKey:bundleIdentifier];
			if (appSettings) {
				shouldShow = (BOOL)[[appSettings objectForKey:@"isEnabled"]?:@TRUE boolValue];
				if (shouldShow) {
					if ([appSettings objectForKey:@"homeBar"] == nil) {
						shouldShow = (BOOL)[[globalSettings objectForKey:@"homeBar"]?:@TRUE boolValue];
					} else {
						shouldShow = (BOOL)[[appSettings objectForKey:@"homeBar"]?:@YES boolValue];
					}
				}
			} else {
				shouldShow = (BOOL)[[globalSettings objectForKey:@"homeBar"]?:@TRUE boolValue];
			}
			[[[[[NSClassFromString(@"SBPrototypeController") sharedInstance] rootSettings] homeScreenSettings] grabberSettings] setAutoHideOverride:shouldShow ? 0x7fffffffffffffff : 5];
		}
	}
}

static void bundleIdentifierBecameHidden(NSString *bundleIdentifier) {
	if (bundleIdentifier && globalSettings) {
		if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		} else {
			BOOL shouldShow = YES;
			NSDictionary *appSettings = [globalSettings objectForKey:bundleIdentifier];
			if (appSettings) {
				shouldShow = (BOOL)[[appSettings objectForKey:@"isEnabled"]?:@TRUE boolValue];
				if (shouldShow) {
					if (![appSettings objectForKey:@"homeBar"]) {
						shouldShow = shouldShow = (BOOL)[[globalSettings objectForKey:@"homeBar"]?:@TRUE boolValue];
					} else {
						shouldShow = (BOOL)[[appSettings objectForKey:@"homeBar"]?:@YES boolValue];
					}
				}
			} else {
				shouldShow = (BOOL)[[globalSettings objectForKey:@"homeBar"]?:@TRUE boolValue];
			}
			if (!shouldShow) {
				[[[[[NSClassFromString(@"SBPrototypeController") sharedInstance] rootSettings] homeScreenSettings] grabberSettings] setAutoHideOverride:wantsHomeBar ? 0x7fffffffffffffff : 5];
			}
		}
	}
}

%hook SBFloatingDockController
+ (BOOL)isFloatingDockSupported {
	if (!wantsDock) return NO;
	return floatingDockSupported;
}

- (BOOL)_systemGestureManagerAllowsFloatingDockGesture {
	return NO;
}
%end

%hook SBFloatingDockSuggestionsModel

- (BOOL)_shouldProcessAppSuggestion:(id)arg1 {
	return NO;
}

- (void)_setRecentsEnabled:(BOOL)enabled {
	%orig(NO);
}

- (void)setRecentsEnabled:(BOOL)enabled {
	%orig(NO);
}

- (BOOL)recentsEnabled {
	return NO;
}
%end

%hook SBRootFolderView
-(CGRect)_iconListFrameForPageRect:(CGRect)arg1 atIndex:(NSUInteger)arg2 {
	if (isActualIPhoneX || !wantsDock) return %orig;
	floatingDockSupported = NO;
	CGRect orig = %orig;
	if (orig.size.height > orig.size.width) {
		orig.size.height = orig.size.height - 20;
	}
	floatingDockSupported = YES;
	return orig;
}
%end

%hook SBFloatingDockPlatterView
+ (UIColor *)backgroundTintColor {
	return [UIColor clearColor];
}
%end

%hook SBIconListView
+ (NSUInteger)maxVisibleIconRowsInterfaceOrientation:(UIInterfaceOrientation)orientation {
	if (isActualIPhoneX || !wantsDock) return %orig;
	NSUInteger orig = %orig;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		return orig;
	} else {
		if (reduceRowsBy1) {
			return orig-1;
		}
	}
	return orig;
}

%end

%hook SBFloatingDockIconListView
+ (NSUInteger)maxIcons {
	if (!wantsDock) return %orig;
	return 10;
}
+ (NSUInteger)iconColumnsForInterfaceOrientation:(NSInteger)arg1 {
	if (!wantsDock) return %orig;
	return 10;
}
+ (NSUInteger)maxVisibleIconRowsInterfaceOrientation:(NSInteger)arg1 {
	if (!wantsDock) return %orig;
	return 1;
}
%end

%hook SBDockIconListView
+ (NSUInteger)maxIcons {
	if (!wantsDock) return %orig;
	return 6;
}
%end


%hook SBAppSwitcherSettings
- (NSInteger)effectiveKillAffordanceStyle {
	if (switcherKillStyle == 0) return %orig;
	return 2;
}

- (NSInteger)killAffordanceStyle {
	if (switcherKillStyle == 0) return %orig;
	return 2;
}

- (void)setKillAffordanceStyle:(NSInteger)style {
	if (switcherKillStyle == 0) {
		%orig;
		return;
	}
	%orig(2);
}
%end

static BOOL lie = NO;

%hook UIDevice
-(long long)userInterfaceIdiom {
	if (lie) return 1;
	else return %orig;
}
%end

@interface HomeGThing : NSObject
- (void)setHomeGestureArbiter:(id)thing;
@end

@interface SBHomeGestureArbiter : NSObject
@end

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
@end

%hook UIDevice
- (BOOL)_supportsForceTouch {
		if (%orig == YES) actuallySupportsForce = YES;
		return %orig;
}
%end

@interface FBWorkspaceEvent : NSObject
@property (nonatomic,copy) NSString * name;
@end

@interface FBProcess : NSObject
-(BOOL)isApplicationProcess;
-(BOOL)isSystemApplicationProcess;
@property (nonatomic,copy,readonly) NSString * bundleIdentifier; 
@property (getter=isForeground,nonatomic,readonly) BOOL foreground; 
-(BOOL)isForeground;
@end

@interface FBScene : NSObject
@property (nonatomic,retain,readonly) FBProcess * clientProcess; 
@end

@interface SBHomeGrabberView : NSObject
@end

%group SpringBoard

%hook SBHomeGrabberView
-(NSInteger)_calculatePresence {
	if ([self valueForKey:@"_settings"]) {
		SBHomeGrabberSettings *grabberSettings = (SBHomeGrabberSettings *)[self valueForKey:@"_settings"];
		if ([grabberSettings autoHideOverride] == 5) return 2;
	}
	return %orig;
}
%end


%hook SBHomeGrabberSettings 
- (BOOL)_isPrototypingEnabled:(id)something {
	return TRUE;
}
%end

%hook BSPlatform
- (NSInteger)homeButtonType {
	return 2;
}
%end

%hook SBMainDisplaySceneManager
- (void)_noteDidChangeToVisibility:(NSUInteger)visibility forScene:(FBScene *)scene {
	NSString *bundleIdentifier = nil;
	if (scene) {
		bundleIdentifier = scene.clientProcess.bundleIdentifier;
	}

	if (bundleIdentifier && 
		([[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:bundleIdentifier] || [bundleIdentifier isEqualToString:@"com.apple.springboard"])) {
		if (visibility != 1) {
			bundleIdentifierBecameHidden(bundleIdentifier);

		} else {
			bundleIdentifierBecameVisible(bundleIdentifier);
		}
	}
}
%end

%end


%hook SBFluidSwitcherGestureManager
- (BOOL)_shouldBeginBottomEdgePanGesture:(id)arg1 {
	floatingDockSupported = NO;
	BOOL orig = %orig;
	floatingDockSupported = YES;
	return orig;
}
%end

static BOOL fakeRadius = NO;

@interface SBGridSwitcherPersonality : NSObject
- (void)setSwitcherViewController:(id)controller;
- (CGRect)frameForIndex:(NSUInteger)index mode:(NSInteger)mode;
- (CGRect)_frameForContainerViewForIndex:(NSUInteger)index;
- (CGRect)_frameForContainerView;
- (BOOL)isIndexVisible:(NSUInteger)index ignoreInsertionsAndRemovals:(BOOL)ignores;
- (void)willPerformLayout;
- (CGRect)frameForControlCenter;
- (CGFloat)statusTextHeightForControlCenter;
- (CGFloat)scaleForControlCenter;
- (CGFloat)opacityForControlCenter;
@end

@interface SBDeckSwitcherPersonality : NSObject
@property (nonatomic, retain) SBGridSwitcherPersonality *otherPersonality;
- (CGRect)frameForIndex:(NSUInteger)index mode:(NSInteger)mode;
- (CGRect)frameForControlCenter;
@end

%hook SBGridSwitcherPersonality
- (BOOL)shouldShowControlCenter {
	return NO;
}
%end

%hook SBDeckSwitcherPersonality
%property (nonatomic, retain) SBGridSwitcherPersonality *otherPersonality;
- (CGFloat)_cardCornerRadiusInAppSwitcher {
	if (isActualIPhoneX || !wantsRoundedSwitcherCards) return %orig;
	fakeRadius = YES;
	CGFloat orig = %orig;
	fakeRadius = NO;
	return orig;
}
%end

%hook UIScreen
- (BOOL)_wantsWideContentMargins {
	if (isActualIPhoneX) return %orig;
	return NO;
}

- (CGFloat)_displayCornerRadius {
	if (isActualIPhoneX) return %orig;
	if (fakeRadius) return screenCornerRadius;
	else return %orig;
}
%end

%hook UITraitCollection
+ (id)traitCollectionWithDisplayCornerRadius:(CGFloat)arg1 {
	if (isActualIPhoneX) return %orig;
	if (fakeRadius) return %orig(screenCornerRadius);
	else return %orig;
}
- (CGFloat)displayCornerRadius {
	if (isActualIPhoneX) return %orig;
	if (fakeRadius) return screenCornerRadius;
	else return %orig;
}
- (CGFloat)_displayCornerRadius {
	if (isActualIPhoneX) return %orig;
	if (fakeRadius) return screenCornerRadius;
	else return %orig;
}
%end

%hook SBDockView
- (id)traitCollection {
	if (isActualIPhoneX || !wantsDock) return %orig;
	if (!fakeRadius) {
		fakeRadius = YES;
		id orig = %orig;
		fakeRadius = NO;
		return orig;
	}
	return %orig;
}

- (void)_updateCornerRadii {
	if (isActualIPhoneX || !wantsDock) {
		%orig;
		return;
	}
	if (!fakeRadius) {
		fakeRadius = YES;
		%orig;
		fakeRadius = NO;
	} else {
		%orig;
	}
}

- (BOOL)isDockInset {
	return (isActualIPhoneX || wantsDock);
}

- (CGFloat)dockHeightPadding {
	if (!wantsDock || isActualIPhoneX) return %orig;
	if (!fakeRadius) {
		fakeRadius = YES;
		CGFloat orig = %orig;
		fakeRadius = NO;
		return orig;
	}
	return %orig;
}

- (CGFloat)dockHeight {
	if (!wantsDock || isActualIPhoneX) return %orig;
	if (!fakeRadius) {
		fakeRadius = YES;
		CGFloat orig = %orig;
		fakeRadius = NO;
		return orig;
	}
	return %orig;
}
%end

@interface _UIStatusBar
+ (void)setDefaultVisualProviderClass:(Class)classOb;
+ (void)setForceSplit:(BOOL)arg1;
@end

@interface _UIStatusBarVisualProvider_iOS : NSObject
+ (CGSize)intrinsicContentSizeForOrientation:(NSInteger)orientation;
@end

%hook _UIStatusBar
+ (BOOL)forceSplit {
	return (wantsStatusBar || isActualIPhoneX);
}

+ (void)setForceSplit:(BOOL)arg1 {
	%orig((wantsStatusBar || isActualIPhoneX));
}

+ (void)setDefaultVisualProviderClass:(Class)classOb {
	if (isActualIPhoneX) {
		%orig;
		return;
	}
	%orig(wantsStatusBar ? NSClassFromString(@"_UIStatusBarVisualProvider_Split") : NSClassFromString(@"_UIStatusBarVisualProvider_iOS"));
}
+(void)initialize {
	%orig;
	if (!isActualIPhoneX) {
		[NSClassFromString(@"_UIStatusBar") setForceSplit:wantsStatusBar];
		[NSClassFromString(@"_UIStatusBar") setDefaultVisualProviderClass:wantsStatusBar ? NSClassFromString(@"_UIStatusBarVisualProvider_Split") : NSClassFromString(@"_UIStatusBarVisualProvider_iOS")];
	}
}

-(void)_prepareVisualProviderIfNeeded {
	%orig;
	if (!isActualIPhoneX) {
		[NSClassFromString(@"_UIStatusBar") setForceSplit:wantsStatusBar];
		[NSClassFromString(@"_UIStatusBar") setDefaultVisualProviderClass:wantsStatusBar ? NSClassFromString(@"_UIStatusBarVisualProvider_Split") : NSClassFromString(@"_UIStatusBarVisualProvider_iOS")];
	}
}

+ (CGFloat)heightForOrientation:(NSInteger)orientation {
	if (isActualIPhoneX) return %orig;
	if (wantsStatusBar) {
		return [NSClassFromString(@"_UIStatusBarVisualProvider_Split") intrinsicContentSizeForOrientation:orientation].height;
	}
	return [NSClassFromString(@"_UIStatusBarVisualProvider_iOS") intrinsicContentSizeForOrientation:orientation].height;
}
%end

%hook _UIStatusBarVisualProvider_iOS
+ (Class)class {
	if (isActualIPhoneX) return %orig;
	return wantsStatusBar ? NSClassFromString(@"_UIStatusBarVisualProvider_Split") : NSClassFromString(@"_UIStatusBarVisualProvider_iOS");
}
%end

%hook UIStatusBar_Base
+ (BOOL)forceModern {
	if (isActualIPhoneX) return %orig;
	return shouldForceModern;
	return YES;
}
+ (Class)_statusBarImplementationClass {
	if (isActualIPhoneX) return %orig;
	return shouldForceModern ? NSClassFromString(@"UIStatusBar_Modern") : NSClassFromString(@"UIStatusBar");
}
%end

static BOOL (*old__IS_D2x)();
static BOOL (*old___UIScreenHasDevicePeripheryInsets)();

BOOL _IS_D2x(){
	if (!isActualIPhoneX) {
		isActualIPhoneX = old__IS_D2x();
	}
	if (!wantsStatusBar) return YES;
	return YES;
}

BOOL __UIScreenHasDevicePeripheryInsets() {
	return YES;
}

@interface AVPlayer : NSObject
@end

@interface AVPlayer (priv)
@property (nonatomic, assign) BOOL allowsExternalPlayback;
@end

%hook AVPlayer
- (id)init {
	AVPlayer *player = %orig;
	if (player && isEnabledInApp) {
		player.allowsExternalPlayback = YES;
	}
	return player;
}

- (void)setAllowsExternalPlayback:(BOOL)allows {
	%orig(isEnabledInApp ? YES : allows);
}
%end

%hook SBPIPController
+ (BOOL)isAutoPictureInPictureSupported {
	if (!isEnabledInApp) return %orig;
	return YES;
}
+ (BOOL)isPictureInPictureSupported {
	if (!isEnabledInApp) return %orig;
	return YES;
}           
%end

%group MG
extern "C" Boolean MGGetBoolAnswer(CFStringRef);
%hookf(Boolean, MGGetBoolAnswer, CFStringRef key)
{
	#define k(key_) CFEqual(key, CFSTR(key_))
	if (k("nVh/gwNpy7Jv1NOk00CMrw")
	 	|| k("ESA7FmyB3KbJFNBAsBejcg"))
		return YES;
	return %orig;
}
%end

static void Loader(){
	if (isEnabledInApp) {
		MSHookFunction(((void*)MSFindSymbol(NULL, "_IS_D2x")),(void*)_IS_D2x, (void**)&old__IS_D2x);
		MSHookFunction(((void*)MSFindSymbol(NULL, "__UIScreenHasDevicePeripheryInsets")),(void*)__UIScreenHasDevicePeripheryInsets, (void**)&old___UIScreenHasDevicePeripheryInsets);
	}
}


%hook UIScreen
- (UIEdgeInsets)_sceneSafeAreaInsets {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	if (orig.bottom == 34) orig.bottom = wantsHomeBar ? bottomBarInset : 0;
	if (!wantsStatusBar) orig.top = 20;
	return orig;
}
%end

%hook UIRemoteKeyboardWindowHosted
- (UIEdgeInsets)safeAreaInsets {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	if (NSClassFromString(@"JCPBarmojiCollectionView") && wantsKeyboardDock) {
		orig.bottom = 60;
	} else {
		orig.bottom = wantsKeyboardDock ? 44 : (wantsHomeBar ? bottomBarInset : 0);
	}
	return orig;
}
%end

%hook UIKeyboardImpl
+(UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)orientation inputMode:(id)mode {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	if (orig.bottom == 75) {
		if (NSClassFromString(@"JCPBarmojiCollectionView") && wantsKeyboardDock) {
			orig.bottom = 60;
		} else {
			orig.bottom = wantsKeyboardDock ? 44 : 0;
		}
	}
	if (orig.left == 75) orig.left = wantsKeyboardDock ? 17 : 0;
	if (orig.right == 75) orig.right = wantsKeyboardDock ? 17 : 0;
	return orig;
}

+(UIEdgeInsets)deviceSpecificStaticHitBufferForInterfaceOrientation:(NSInteger)orientation inputMode:(id)mode {
	if (isActualIPhoneX || !wantsKeyboardDock) return %orig;
	UIEdgeInsets orig = %orig;
	if (orig.bottom == 17) orig.bottom = 0;
	return orig;
}

%end

@interface UIKeyboardDockView : UIView
@property (nonatomic, assign) BOOL fakeBounds;
@end

%hook UIKeyboardDockView
%property (nonatomic, assign) BOOL fakeBounds;

- (CGRect)bounds {
	if (isActualIPhoneX || !wantsKeyboardDock) return %orig;
	if (self.fakeBounds) {
		CGRect bounds = %orig;
		if (NSClassFromString(@"JCPBarmojiCollectionView")) {
			bounds.size.height += 4;
		} else {
			bounds.size.height += 15;
		}
		return bounds;
	} else {
		return %orig;
	}
}

- (void)layoutSubviews {
	self.fakeBounds = YES;
	%orig;

	if (!isActualIPhoneX && wantsKeyboardDock) {
		for (UIView *subview in self.subviews) {
			if ([subview isKindOfClass:NSClassFromString(@"JCPBarmojiCollectionView")]) {
				CGRect frame = subview.frame;
				frame.origin.y = self.frame.size.height - 17 - frame.size.height;
				subview.frame = frame;
			}
		}
	}
	self.fakeBounds = NO;
}

%end

%hook UIInputWindowController
- (UIEdgeInsets)_viewSafeAreaInsetsFromScene {
	if (isActualIPhoneX || !wantsKeyboardDock) return %orig;
	if (NSClassFromString(@"JCPBarmojiCollectionView")) {
		return UIEdgeInsetsMake(0,0,60,0);
	} else {
		return UIEdgeInsetsMake(0,0,44,0);
	}
}
%end

@interface SBDashBoardQuickActionsView : UIView
@end

@interface SBDashBoardQuickActionsButton : UIButton
@end

@interface UIButton (ATX)
- (void)addTarget:(id)target action:(SEL)action forEvents:(int)events;
@end

%hook SBDashBoardQuickActionsView 
- (void)addTargetsToButton:(UIButton *)button {
	%orig;
	[button addTarget:self action:@selector(handleButtonPress:) forEvents:UIControlEventTouchUpInside];
}
%end

%hook SBDashBoardQuickActionsButton

- (id)initWithType:(NSInteger)type {
	SBDashBoardQuickActionsButton *button = %orig;
	[button addTarget:self action:@selector(cc_clicked) forEvents:UIControlEventTouchUpInside];
	return button;
}

%new
- (void)cc_clicked {
	if (actuallySupportsForce == NO) [self sendActionsForControlEvents:0x2000];
}
%end

%hook SBDashBoardQuickActionsViewController
+ (BOOL)deviceSupportsButtons {
	return YES;
}
%end

%hook PHInCallUtilities
- (BOOL)isIPadIdiom {
	if (!isEnabledInApp) return %orig;
	return YES;
}
%end

int uname(struct utsname *);

%group BoundsHack

%hookf(int, sysctl, const int *name, u_int namelen, void *oldp, size_t *oldlenp, const void *newp, size_t newlen) {
	if (isActualIPhoneX) return %orig;
	if (namelen == 2 && name[0] == CTL_HW && name[1] == HW_MACHINE) {
        int ret = %orig;
        if (oldp != NULL) {
            const char *mechine1 = "iPhone10,6";
            strncpy((char*)oldp, mechine1, strlen(mechine1));
        }
        return ret;
    } else{
        return %orig;
    }
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
	if (isActualIPhoneX) return %orig;
	if (strcmp(name, "hw.machine") == 0) {
        int ret = %orig;
        if (oldp != NULL) {
            const char *mechine1 = "iPhone10,6";
            strncpy((char*)oldp, mechine1, strlen(mechine1));
        }
        return ret;
    } else {
        return %orig;
    }
}

%hookf(int, uname, struct utsname *value) {
	if (isActualIPhoneX) return %orig;
	int ret = %orig;
	NSString *utsmachine = @"iPhone10,6";
	if (utsmachine) {	 
		const char *utsnameCh = utsmachine.UTF8String; 
		strcpy(value->machine, utsnameCh);

	}
    return ret;
}

%hook UIScreen
- (CGRect)nativeBounds {
	if (isActualIPhoneX) return %orig;
	CGRect bounds = %orig;
	if (bounds.size.height > bounds.size.width) {
		bounds.size.height = 2436;
		bounds.size.width = 1125;
	} else { 
		bounds.size.width = 2436;
		bounds.size.height = 1125;
	}
	return bounds;
}

- (BOOL)isInterfaceAutorotationDisabled {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		BOOL orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook UIView
- (CGRect)_convertViewPointToSceneSpaceForKeyboard:(CGRect)keyboard {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook _UIScreenRectangularBoundingPathUtilities
- (void)_loadBezierPathsForScreen:(id)screen {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		%orig;
		properFixedBounds = YES;
		properBounds = NO;
	} else {
		%orig;
	}
}
%end

%hook _UIPreviewInteractionDecayTouchForceProvider
- (id)initWithTouchForceProvider:(id)thing {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		id orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook UIPopoverPresentationController
- (CGRect)_sourceRectInContainerView {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook UIPanelBorderView
- (void)layoutSubviews {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		%orig;
		properFixedBounds = YES;
		properBounds = NO;
	} else {
		%orig;
	}
}
%end

%hook UIPeripheralHost
+ (BOOL)pointIsWithinKeyboardContent:(CGPoint)point {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		BOOL orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

- (void)setInputViews:(id)stuff animationStyle:(id)stuff1 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		%orig;
		properFixedBounds = YES;
		properBounds = NO;
	} else {
		%orig;
	}
}
%end

@interface _UIScreenFixedCoordinateSpace : NSObject
- (UIScreen *)_screen;
@end

%hook _UIScreenFixedCoordinateSpace
- (CGRect)bounds {
	CGRect bounds = %orig;
	if ([self _screen] == [UIScreen mainScreen] && !isActualIPhoneX && !properFixedBounds) {
		if (bounds.size.height > bounds.size.width) {
			bounds.size.height = 812;
			bounds.size.width = 375;
		} else { 
			bounds.size.width = 812;
			bounds.size.height = 375;
		}
	}
	return bounds;
}

-(CGRect)convertRect:(CGRect)arg1 toCoordinateSpace:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGRect)convertRect:(CGRect)arg1 fromCoordinateSpace:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGPoint)convertPoint:(CGPoint)arg1 toCoordinateSpace:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGPoint orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGPoint)convertPoint:(CGPoint)arg1 fromCoordinateSpace:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGPoint orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook UIKeyboardAssistantBar
- (void)showKeyboard:(id)keyboard {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		%orig;
		properFixedBounds = YES;
		properBounds = NO;
	} else {
		%orig;
	}
}
%end

%hook UIApplicationRotationFollowingController
- (void)window:(id)window setupWithInterfaceOrientation:(NSInteger)orientation {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		%orig;
		properFixedBounds = YES;
		properBounds = NO;
	} else {
		%orig;
	}
}
%end

%hook UIScreenMode
- (CGSize)size {
	if (isActualIPhoneX) return %orig;
	return CGSizeMake(1125,2436);
}
%end

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	if (orig.top > 30) orig.bottom = wantsHomeBar ? bottomBarInset : 0;
	else {
		if (orig.left < 10) orig.left = wantsHomeBar ? bottomBarInset : 0;
		else if (orig.right < 10) orig.right = wantsHomeBar ? bottomBarInset : 0; 
	}
	return orig;
}
%end

%hook UIScrollView
- (UIEdgeInsets)adjustedContentInset {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	if (orig.top == 64 && wantsStatusBar) orig.top = 88;
	if (orig.top == 32 && wantsStatusBar) orig.top = 0;
	return orig;
}
%end
%end


%hook UIViewController
- (BOOL)prefersHomeIndicatorAutoHidden {
	if (!wantsHomeBar && !isActualIPhoneX) return YES;
	return %orig;
}
%end

%hook UIView
+ (UIEdgeInsets)tfn_systemSafeAreaInsetsForInterfaceOrientation:(NSInteger)orientation withStatusBarHidden:(BOOL)hidden {
	if (properFixedBounds && !isActualIPhoneX) {
		UIEdgeInsets unmod = %orig;
		properFixedBounds = NO;
		UIEdgeInsets orig = %orig;
		if (!wantsHomeBar) orig.bottom = unmod.bottom;
		else {
			if (orig.bottom > bottomBarInset) orig.bottom = bottomBarInset;
		}
		if (!wantsStatusBar) orig.top = unmod.top;
		properFixedBounds = YES;
		properBounds = YES;
		return orig;
	} else {
		return %orig;
	}
}
%end

%group ExtraHooks
%hook UIScreen
+ (UIEdgeInsets)sc_safeAreaInsets {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets orig = %orig;
	orig.top = 0;
	orig.bottom = wantsHomeBar ? [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets].bottom : 0;
	return orig;
}

+ (UIEdgeInsets)sc_safeAreaInsetsForInterfaceOrientation:(UIInterfaceOrientation)orientation {
	if (isActualIPhoneX) return %orig;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		UIEdgeInsets insets = [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets];
		return UIEdgeInsetsMake(0, wantsStatusBar ? insets.top : 20, 0, wantsHomeBar ? insets.bottom : 0);
	} else {
		UIEdgeInsets orig = %orig;
		orig.top = 0;
		orig.bottom = wantsHomeBar ? [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets].bottom : 0;
		return orig;
	}
}

+ (UIEdgeInsets)sc_visualSafeInsets {
	if (isActualIPhoneX) return %orig;
 	UIEdgeInsets orig = %orig;
	orig.top = 0;
	orig.bottom = wantsHomeBar ? [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets].bottom : 0;
	return orig;
}

+ (UIEdgeInsets)sc_filterSafeInsets {
	if (isActualIPhoneX) return %orig;
 	UIEdgeInsets insets = [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets];
	return UIEdgeInsetsMake(wantsStatusBar ? insets.top : 20,0,0,0);
}

+ (UIEdgeInsets)sc_headerSafeInsets {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets insets = [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets];
	return UIEdgeInsetsMake(wantsStatusBar ? insets.top : 20,0,0,0);
}

+ (UIEdgeInsets)sc_safeFooterButtonInset {
	if (isActualIPhoneX) return %orig;
	UIEdgeInsets insets = [[NSClassFromString(@"UIScreen") mainScreen] _sceneSafeAreaInsets];
	if (wantsStatusBar) UIEdgeInsetsMake(0,0,wantsHomeBar ? insets.bottom : 0,0);
	return %orig;
}

+ (CGFloat)sc_headerHeight {
	if (isActualIPhoneX) return %orig;
	CGFloat orig = %orig;
	if (wantsStatusBar) return orig + (wantsStatusBar ? 24 : 0);
	return orig;
}
%end

%hook CALayer
-(CGPoint)convertPoint:(CGPoint)arg1 toLayer:(id)arg2  {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGPoint orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGPoint)convertPoint:(CGPoint)arg1 fromLayer:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGPoint orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGRect)convertRect:(CGRect)arg1 toLayer:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

-(CGRect)convertRect:(CGRect)arg1 fromLayer:(id)arg2 {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		CGRect orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end

%hook UIInputViewSet
- (BOOL)inSyncWithOrientation:(NSInteger)orientation forKeyboard:(id)keyboard {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		BOOL orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}

+ (id)inputSetWithPlaceholderAndAccessoryView:(id)view {
	if (!properBounds) {
		properFixedBounds = YES;
		properBounds = YES;
		id orig = %orig;
		properFixedBounds = YES;
		properBounds = NO;
		return orig;
	} else {
		return %orig;
	}
}
%end
%end


%group ExtremeBounds
%hook UIScreen
- (CGRect)bounds {
	if (isActualIPhoneX || properBounds || (!wantsStatusBar && !wantsHomeBar)) return %orig;
	CGRect bounds = %orig;
	if (bounds.size.height > bounds.size.width) {
		bounds.size.height = 812;
	} else { 
		bounds.size.width = 812;
	}
	return bounds;
}
%end
%end


%ctor {
	NSString *mainIdentifier = [NSBundle mainBundle].bundleIdentifier;

	NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", @"com.ioscreatix.littlex"];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];

	globalSettings = settings;

	switcherKillStyle = (NSInteger)[[globalSettings objectForKey:@"switcherKillStyle"]?:@0 integerValue];
    wantsDock = (BOOL)[[globalSettings objectForKey:@"iPadDock"]?:@TRUE boolValue];
    wantsStatusBar = (BOOL)[[globalSettings objectForKey:@"statusBar"]?:@TRUE boolValue];
    shouldForceModern = wantsStatusBar;
    wantsHomeBar = (BOOL)[[globalSettings objectForKey:@"homeBar"]?:@TRUE boolValue];
    wantsKeyboardDock = (BOOL)[[globalSettings objectForKey:@"keyboardDock"]?:@TRUE boolValue];
    reduceRowsBy1 = (BOOL)[[globalSettings objectForKey:@"reduceRows"]?:@TRUE boolValue];

	NSDictionary *appSettings = [settings objectForKey:mainIdentifier];
	if (appSettings) {
		isEnabledInApp = (BOOL)[[appSettings objectForKey:@"isEnabled"]?:@TRUE boolValue];
		if (isEnabledInApp) {
			wantsStatusBar = (BOOL)[[appSettings objectForKey:@"statusBar"]?:@(wantsStatusBar) boolValue];
			shouldForceModern = wantsStatusBar;
			wantsHomeBar = (BOOL)[[appSettings objectForKey:@"homeBar"]?:@(wantsHomeBar) boolValue];
			wantsKeyboardDock = (BOOL)[[appSettings objectForKey:@"keyboardDock"]?:@(wantsKeyboardDock) boolValue];
		}
	}

	NSArray *disabledBundleIdentifiers = @[@"com.myvidster", @"com.supercell.scroll"];
	NSArray *disabledBoundsIdentifiers = @[@"com.toyopagroup.picaboo", @"com.apple.mobilephone"];
	NSArray *disabledExtremeBounds= @[@"net.whatsapp.WhatsApp"];
	if ([mainIdentifier isEqualToString:@"com.apple.springboard"]) {
        %init(SpringBoard);
    } else {
    	if ((mainIdentifier && [disabledBundleIdentifiers containsObject:mainIdentifier]) || !isEnabledInApp) {
	    	shouldForceModern = NO;
	    	wantsStatusBar = NO;
	    	wantsKeyboardDock = NO;
	    	wantsHomeBar = NO;
	    } else {
	    	if (mainIdentifier && [disabledBoundsIdentifiers containsObject:mainIdentifier]) {
	    		%init(ExtraHooks);
	    	} else {
	    		if ([disabledExtremeBounds containsObject:mainIdentifier]) {

	    		} else {
	    			if (wantsHomeBar || wantsStatusBar) {
	    				%init(ExtremeBounds);
	    			}
	    		}

	    		if (wantsHomeBar || wantsStatusBar) {
	    			%init(BoundsHack);
	    		}
	    	}
	    }
    }

    Loader();
    if (isEnabledInApp && ![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.MediaPlayer.RemotePlayerService"]) {
    	%init(MG);
    }
    %init;
    [NSClassFromString(@"_UIStatusBar") setDefaultVisualProviderClass:wantsStatusBar ? NSClassFromString(@"_UIStatusBarVisualProvider_Split") : NSClassFromString(@"_UIStatusBarVisualProvider_iOS")];
}
