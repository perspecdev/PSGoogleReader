//
//  TODO: Add UITableView, etc to make a cleaner demo UI, rather than just spitting everything out via NSLog
//
//  PSGoogleReaderAppDelegate.m
//  PSGoogleReader
//
//  Created by Daniel Isenhower ( daniel@perspecdev.com ).
//  Copyright 2011 PerspecDev Solutions, LLC. All rights reserved.
//

#import "PSGoogleReaderAppDelegate.h"

#import "RootViewController.h"

@implementation PSGoogleReaderAppDelegate


@synthesize window=_window;

@synthesize splitViewController=_splitViewController;

@synthesize rootViewController=_rootViewController;

@synthesize detailViewController=_detailViewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // Add the split view controller's view to the window and display.
    self.window.rootViewController = self.splitViewController;
    [self.window makeKeyAndVisible];
    
    networkActivityCounter = 0;
    
    NSString *username = @"google-reader-username";
    NSString *password = @"google-reader-password";
    googleReader = [[PSGoogleReader alloc] init];
    // you should store googleReader.SID when the googleReaderInitializedAndReady method returns, then
    // pass that value to initWithSID: rather than always logging in with the user's username & password
    [googleReader loginWithUsername:username withPassword:password];
    googleReader.delegate = self; // see below for delegate methods
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc {
    [googleReader release];
    
    [_window release];
    [_splitViewController release];
    [_rootViewController release];
    [_detailViewController release];
    [super dealloc];
}

# pragma mark - PSGoogleReaderDelegate methods

- (void)googleReaderIncrementNetworkActivity {
    if (networkActivityCounter++ == 0) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    }
}

- (void)googleReaderDecrementNetworkActivity {
    if (--networkActivityCounter <= 0) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        networkActivityCounter = 0; // just in case
    }
}

- (void)googleReaderInitializedAndReady {
    NSLog(@"PSGoogleReader initialized and ready");
    NSLog(@"Retrieving reading list...");
    [googleReader retrieveReadingList];
}

- (void)googleReaderNeedsLogin {
    NSLog(@"Google Reader needs login");
}

- (void)googleReaderReadingListData:(NSArray *)items {
    for (NSDictionary *item in items) {
        NSLog(@"%@", [item objectForKey:@"title"]);
    }
}

- (BOOL)googleReaderIsReadyForMoreItems {
    return YES;
}

- (void)googleReaderReadingListDataComplete {
    NSLog(@"Reading list data complete");
}

- (void)googleReaderCouldNotGetReadingList {
    NSLog(@"Could not get reading list");
}

- (void)googleReaderSubscriptionList:(NSArray *)aSubscriptionList {
    //
}

- (void)googleReaderIsReadSynced:(NSString *)itemId {
    //
}

- (void)googleReaderSubscriptionAdded {
    //
}

- (void)googleReaderCouldNotAddSubscription {
    //
}

- (void)googleReaderSubscriptionRemoved {
    //
}

- (void)googleReaderCouldNotRemoveSubscription {
    //
}

- (void)googleReaderURLError:(NSError *)error {
    NSLog(@"URL Error: %@", [error description]);
}

@end
