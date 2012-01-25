//
//  RootViewController.h
//  PSGoogleReader
//
//  Created by Daniel Isenhower ( daniel@perspecdev.com ).
//  Copyright 2011 PerspecDev Solutions, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController;

@interface RootViewController : UITableViewController {

}

		
@property (nonatomic, strong) IBOutlet DetailViewController *detailViewController;

@end
