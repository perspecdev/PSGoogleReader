//
//  PSGoogleReaderAppDelegate.h
//  PSGoogleReader
//
//  Created by Daniel Isenhower ( daniel@perspecdev.com ).
//  Copyright 2011 PerspecDev Solutions, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PSGoogleReader.h"

@class RootViewController;

@class DetailViewController;

@interface PSGoogleReaderAppDelegate : NSObject <UIApplicationDelegate, PSGoogleReaderDelegate> {
    PSGoogleReader *googleReader;
    int networkActivityCounter;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;

@property (nonatomic, weak) IBOutlet UISplitViewController *splitViewController;

@property (nonatomic, weak) IBOutlet RootViewController *rootViewController;

@property (nonatomic, weak) IBOutlet DetailViewController *detailViewController;

@end
