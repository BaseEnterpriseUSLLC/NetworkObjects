//
//  SNCPostsTableViewController.h
//  Social Network Client
//
//  Created by Alsey Coleman Miller on 2/25/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CoreData;

@interface SNCPostsTableViewController : UITableViewController

@property NSFetchedResultsController *fetchedResultsControllers;

@property NSArray *users;

@end
