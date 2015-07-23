//
//  APManagedDocument.m
//  MultiDocument
//
//  Created by David Trotz on 8/30/13.
//  Copyright (c) 2013 AppPoetry LLC. All rights reserved.
//

#import "APManagedDocument.h"
#import "APManagedDocumentManager.h"
#import "APManagedDocumentDelegate.h"
#import <CoreData/CoreData.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

static const int ddLogLevel = DEFAULT_LOG_LEVEL;

NSString * const APPersistentStoreCoordinatorStoresWillChangeNotification = @"APPersistentStoreCoordinatorStoresWillChangeNotification";
NSString * const APPersistentStoreCoordinatorStoresDidChangeNotification = @"APPersistentStoreCoordinatorStoresDidChangeNotification";

static __strong NSString* gPersistentStoreName = @"persistentStore";

@interface APManagedDocument () {
    
}
@end

@interface APManagedDocumentManager (hidden)
- (void)_contextInitializedForDocument:(APManagedDocument*)document success:(BOOL)success;
@end

@implementation APManagedDocument
// Don't use this initializer with this class as it will result in a thrown
//          exception.
- (id)initWithFileURL:(NSURL *)url {
    @throw [NSException exceptionWithName:@"Invalid initializer called." reason:@"Use APManagedDocument's initWithDocumentName: instead." userInfo:nil];
}

+ (void)initialize {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* tmp = [mainBundle objectForInfoDictionaryKey:@"APManagedDocumentPersistentStoreName"];
    if ([tmp length] > 0) {
        gPersistentStoreName = tmp;
    }
}

- (id)initWithDocumentIdentifier:(NSString*)identifier {
    APManagedDocumentManager* manager = [APManagedDocumentManager sharedDocumentManager];
    NSURL* documentURL = [manager urlForDocumentWithIdentifier:identifier];
    self = [super initWithFileURL:documentURL];
    if (self != nil) {
        // Since both open and save will use the same completion handlers we
        // create a named block to call on completion
        void (^completionHandler)(BOOL) = ^(BOOL success) {
           dispatch_async(dispatch_get_main_queue(), ^{
              [manager _contextInitializedForDocument:self success:success];
           });
        };
        
        self.persistentStoreOptions = [manager optionsForDocumentWithIdentifier:identifier];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[documentURL path]]) {
            [self openWithCompletionHandler:completionHandler];
        }else {
            [self saveToURL:documentURL forSaveOperation:UIDocumentSaveForCreating completionHandler:completionHandler];
        }
        _documentIdentifier = identifier;
    }
    return self;
}

- (void)scheduleSave {
    [self updateChangeCount:UIDocumentChangeDone];
}

- (void)saveNow
{
	[self saveNow: nil];
}

- (void)saveNow:(void (^)(BOOL success))completionHandler
{
	[self saveToURL:self.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:completionHandler];
}

#ifdef DEBUG
-(void)saveToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation completionHandler:(void (^)(BOOL))completionHandler
{
	DDLogDebug(@"Saving document %@", self);
	[super saveToURL:url forSaveOperation:saveOperation completionHandler:completionHandler];
}
#endif

- (void)handleError:(NSError *)rootError userInteractionPermitted:(BOOL)userInteractionPermitted
{
	DDLogError(@"Document failed to save: %@", rootError.localizedDescription);

	NSArray* errors = [[rootError userInfo] objectForKey:NSDetailedErrorsKey];
	if(errors != nil && errors.count > 0) {
		for (NSError *error in errors) {
			DDLogError(@"  Error: %@", error.userInfo);
		}
	} else {
		DDLogError(@"  %@", rootError.userInfo);
	}

	id <APManagedDocumentDelegate> delegate = [[APManagedDocumentManager sharedDocumentManager] documentDelegate];
	if ([delegate respondsToSelector:@selector(documentFailedToSave:error:userInteractionPermitted:)]) {
		[delegate documentFailedToSave: self error: rootError userInteractionPermitted: userInteractionPermitted];
	}
}

+ (NSString*)persistentStoreName {
    return gPersistentStoreName;
}
@end
