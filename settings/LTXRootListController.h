#import "../headers/Preferences/Preferences.h"

@interface LTXRootListController : PSListController
-(NSDictionary*)trimDataSource:(NSDictionary*)dataSource;
-(NSMutableArray*)appSpecifiers;
@end
