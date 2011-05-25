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

@interface PSGoogleReaderAppDelegate : NSObject <UIApplicationDelegate, PSGooglReaderDelegate> {
    PSGoogleReader *googleReader;
    int networkActivityCounter;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UISplitViewController *splitViewController;

@property (nonatomic, retain) IBOutlet RootViewController *rootViewController;

@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;

@end
