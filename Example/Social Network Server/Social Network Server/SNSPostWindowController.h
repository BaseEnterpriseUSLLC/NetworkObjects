//
//  SNSPostWindowController.h
//  Social Network Server
//
//  Created by Alsey Coleman Miller on 2/16/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SNSRepresentedObjectWindowController.h"

@interface SNSPostWindowController : SNSRepresentedObjectWindowController <NSTextStorageDelegate>

@property (strong) IBOutlet NSTextView *textView;

@end
